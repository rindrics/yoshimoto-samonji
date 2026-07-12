library(frasyr)
library(jsonvalidate)
library(yaml)
library(logger)
library(curl)

# Configure logging
log_level <- Sys.getenv("LOG_LEVEL", "INFO")
log_threshold(log_level)

# VPA parameter constraints
MINIMUM_YEAR <- 1950
MAXIMUM_YEAR <- 2100

# Load request schema from openapi.yaml (single source of truth)
# Priority: env var > local path > docker path
resolve_schema_path <- function() {
  # 1. Default: docker path
  default_path <- "./schema/openapi.yaml"

  # 2. Check environment variable (override for local dev)
  env_path <- Sys.getenv("OPENAPI_SPEC_PATH", "")
  if (nzchar(env_path)) {
    if (!file.exists(env_path)) {
      stop(sprintf("OPENAPI_SPEC_PATH not found: %s", env_path))
    }
    return(env_path)
  }

  # 3. Use default if it exists
  if (file.exists(default_path)) {
    return(default_path)
  }

  stop(sprintf("Cannot find schema at %s. Set OPENAPI_SPEC_PATH for custom path.", default_path))
}

schema_path <- resolve_schema_path()
openapi_spec <- yaml::read_yaml(schema_path)
vpa_request_schema <- jsonlite::toJSON(
  openapi_spec$paths$`/v0/vpa`$post$requestBody$content$`application/json`$schema,
  auto_unbox = TRUE
)

# Custom error class for VPA errors with status code
VPAError <- function(message, status_code = 409) {
  structure(
    list(message = message, status_code = status_code),
    class = c("VPAError", "error", "condition")
  )
}

# Helper function to fetch CSV with explicit timeout control
rfetch_csv <- function(url) {
  tryCatch({
    # Extract hostname from URL for DNS resolution check
    hostname <- gsub("^https?://([^/?#]+).*", "\\1", url)

    # Check DNS resolution with timeout using system command
    # This prevents hanging on invalid domains like A.aG
    dns_check <- tryCatch({
      # Use timeout command (available on Unix/Linux) with nslookup
      # Suppress output and just check return code
      result <- system(
        sprintf("timeout 2 nslookup %s >/dev/null 2>&1", shQuote(hostname)),
        intern = FALSE
      )
      # timeout returns 124 if timed out, nslookup returns 1 if not found
      if (result %in% c(1, 124)) {
        stop(VPAError(sprintf("Cannot resolve hostname: %s", hostname), 404))
      }
      TRUE
    }, error = function(e) {
      if (inherits(e, "VPAError")) {
        stop(e)
      }
      # If system call fails, try to proceed anyway
      TRUE
    })

    # Fetch with curl timeout
    h <- curl::new_handle(connecttimeout = 1L, timeout = 2L)
    resp <- curl::curl_fetch_memory(url, handle = h)

    if (resp$status_code >= 400) {
      stop(VPAError(sprintf("HTTP %d for %s", resp$status_code, url), 404))
    }

    read.csv(text = rawToChar(resp$content), row.names = 1)
  }, error = function(e) {
    if (inherits(e, "VPAError")) {
      stop(e)
    }
    stop(VPAError(sprintf("Failed to fetch %s: %s", url, e$message), 404))
  })
}

# Helper function to load data files with error handling
load_vpa_data <- function(caa_url, waa_url, maa_url, M) {
  tryCatch({
    log_debug(sprintf("Loading CSV files: caa=%s, waa=%s, maa=%s", caa_url, waa_url, maa_url))

    # Fetch each file sequentially - stop at first error
    log_debug("Fetching caa...")
    caa_data <- rfetch_csv(caa_url)
    log_debug("Fetching waa...")
    waa_data <- rfetch_csv(waa_url)
    log_debug("Fetching maa...")
    maa_data <- rfetch_csv(maa_url)

    data.handler(
      caa = caa_data,
      waa = waa_data,
      maa = maa_data,
      M = as.numeric(M)
    )
  }, error = function(e) {
    # Handle VPAError from rfetch_csv
    if (inherits(e, "VPAError")) {
      stop(e)
    }

    error_msg <- e$message
    status_code <- 409  # default

    # 409: Data format or processing error
    if (grepl("col.names|row.names|invalid|incompatible", error_msg, ignore.case = TRUE)) {
      status_code <- 409
      error_msg <- sprintf("Data format error: %s", error_msg)
    }
    # Default: 409 Conflict
    else {
      status_code <- 409
      error_msg <- sprintf("Data processing error: %s", error_msg)
    }

    stop(VPAError(error_msg, status_code))
  })
}

#* @apiTitle Stock Assessment API
#* @apiDescription API for stock assessment calculation using ichimomo/frasyr
#* @apiVersion 0.1.0
#* @apiContact list(name = "rindrics", url = "https://github.com/rindrics/yoshimoto-samonji", email = "dev+yoshimoto-samonji@rindrics.com")
#* @apiLicense list(name = "MIT", url = "https://opensource.org/licenses/MIT")
#* @apiTag vpa Operations for Virtual Population Analysis

#* Run VPA
#* @tag vpa
#* @post /v0/vpa
#*   description: "Run Virtual Population Analysis"
#* @serializer unboxedJSON
function(req, res) {
    log_info("POST /v0/vpa - Request received")

    tryCatch({
      # Parse and validate request
      log_debug(sprintf("Request postBody length: %d bytes", nchar(req$postBody)))

      # Check for empty request body
      if (nchar(req$postBody) == 0) {
        log_warn("POST /v0/vpa - Empty request body")
        res$status <- 400
        return(list(error = "Empty request body"))
      }

      # Parse JSON (null bytes and parse errors handled by global error handler in run.R)
      log_debug("Attempting JSON parse...")
      body <- jsonlite::fromJSON(req$postBody)
      log_debug(sprintf("Request body parsed successfully"))

      # Validate body is an object (not an array)
      if (!is.list(body) || is.null(names(body)) || length(names(body)) == 0) {
        res$status <- 400
        return(list(error = "Invalid request: body must be a JSON object"))
      }

      data <- body$data
      params <- body$params %||% list()

      # Validate data is an object, not null or array
      if (is.null(data) || !is.list(data) || is.data.frame(data)) {
        res$status <- 400
        return(list(error = "Invalid parameter: data must be an object"))
      }

      # Validate params is an object, not null
      if ("params" %in% names(body) && is.null(body$params)) {
        res$status <- 400
        return(list(error = "Invalid parameter: params must be an object, not null"))
      }

      # Validate no unexpected properties in request body (internal API)
      expected_properties <- c("data", "params")
      unexpected_in_body <- setdiff(names(body), expected_properties)
      if (length(unexpected_in_body) > 0) {
        res$status <- 400
        return(list(error = sprintf("Invalid request: unexpected properties: %s", paste(unexpected_in_body, collapse = ", "))))
      }

      # Validate no unexpected properties in data object
      expected_data_props <- c("caa_url", "waa_url", "maa_url")
      unexpected_in_data <- setdiff(names(data), expected_data_props)
      if (length(unexpected_in_data) > 0) {
        res$status <- 400
        return(list(error = sprintf("Invalid parameter: unexpected properties in data: %s", paste(unexpected_in_data, collapse = ", "))))
      }

      # Validate no unexpected properties in params object
      if (!is.null(params) && length(params) > 0) {
        expected_params_props <- c("m", "fc_year", "tf_year", "term_f", "stat_tf", "pope", "tune", "p_init", "sel_update", "sel_f", "alpha", "max_dd", "abund", "min_age", "max_age")
        unexpected_in_params <- setdiff(names(params), expected_params_props)
        if (length(unexpected_in_params) > 0) {
          res$status <- 400
          return(list(error = sprintf("Invalid parameter: unexpected properties in params: %s", paste(unexpected_in_params, collapse = ", "))))
        }
      }

      # Validate data URLs (must be character strings)
      if (!is.character(data$caa_url) || !grepl("^https?://", data$caa_url)) {
        res$status <- 400
        return(list(error = "Invalid parameter: caa_url must be a valid HTTP(S) URL"))
      }
      if (!is.character(data$waa_url) || !grepl("^https?://", data$waa_url)) {
        res$status <- 400
        return(list(error = "Invalid parameter: waa_url must be a valid HTTP(S) URL"))
      }
      if (!is.character(data$maa_url) || !grepl("^https?://", data$maa_url)) {
        res$status <- 400
        return(list(error = "Invalid parameter: maa_url must be a valid HTTP(S) URL"))
      }

      # Validate numeric parameters (must be single numeric value, not array or null values)
      if ("m" %in% names(params)) {
        if (is.null(params$m) || !is.numeric(params$m) || length(params$m) != 1 || any(is.na(params$m))) {
          res$status <- 400
          return(list(error = "Invalid parameter: m must be a single numeric value"))
        }
      }
      if ("p_init" %in% names(params)) {
        if (is.null(params$p_init) || !is.numeric(params$p_init) || length(params$p_init) != 1) {
          res$status <- 400
          return(list(error = "Invalid parameter: p_init must be a single numeric value"))
        }
      }

      # Validate boolean parameters (must be single logical value, not null if provided)
      if ("pope" %in% names(params)) {
        if (is.null(params$pope) || !is.logical(params$pope) || length(params$pope) != 1) {
          res$status <- 400
          return(list(error = "Invalid parameter: pope must be boolean"))
        }
      }
      if ("tune" %in% names(params)) {
        if (is.null(params$tune) || !is.logical(params$tune) || length(params$tune) != 1 || params$tune != FALSE) {
          res$status <- 400
          return(list(error = "Invalid parameter: tune must be false"))
        }
      }

      # Validate array parameters (must be arrays of integers if provided)
      # For single-element JSON values like tf_year: 0, check raw JSON for array syntax
      if ("fc_year" %in% names(params)) {
        # Extract fc_year value from raw JSON to check if it's array syntax
        fc_year_is_array <- grepl('"fc_year"\\s*:\\s*\\[', req$postBody)
        if (!fc_year_is_array || is.null(params$fc_year) || !is.numeric(params$fc_year) || length(params$fc_year) == 0 || !all(params$fc_year == as.integer(params$fc_year))) {
          res$status <- 400
          return(list(error = "Invalid parameter: fc_year must be an array of integers"))
        }
        # fc_year values must be in valid range
        if (any(params$fc_year < MINIMUM_YEAR)) {
          res$status <- 400
          return(list(error = sprintf("Invalid parameter: fc_year values must be >= %d", MINIMUM_YEAR)))
        }
        if (any(params$fc_year > MAXIMUM_YEAR)) {
          res$status <- 400
          return(list(error = sprintf("Invalid parameter: fc_year values must be <= %d", MAXIMUM_YEAR)))
        }
      }
      if ("tf_year" %in% names(params)) {
        # Extract tf_year value from raw JSON to check if it's array syntax
        tf_year_is_array <- grepl('"tf_year"\\s*:\\s*\\[', req$postBody)
        if (!tf_year_is_array || is.null(params$tf_year) || !is.numeric(params$tf_year) || length(params$tf_year) == 0 || !all(params$tf_year == as.integer(params$tf_year))) {
          res$status <- 400
          return(list(error = "Invalid parameter: tf_year must be an array of integers"))
        }
        # tf_year values must be in valid range
        if (any(params$tf_year < MINIMUM_YEAR)) {
          res$status <- 400
          return(list(error = sprintf("Invalid parameter: tf_year values must be >= %d", MINIMUM_YEAR)))
        }
        if (any(params$tf_year > MAXIMUM_YEAR)) {
          res$status <- 400
          return(list(error = sprintf("Invalid parameter: tf_year values must be <= %d", MAXIMUM_YEAR)))
        }
      }

      # Validate string enum parameters (must be single string value, not null if provided)
      if ("term_f" %in% names(params)) {
        if (is.null(params$term_f) || !is.character(params$term_f) || length(params$term_f) != 1 || !(params$term_f %in% c("max", "mean"))) {
          res$status <- 400
          return(list(error = "Invalid parameter: term_f must be 'max' or 'mean'"))
        }
      }
      if ("stat_tf" %in% names(params)) {
        if (is.null(params$stat_tf) || !is.character(params$stat_tf) || length(params$stat_tf) != 1 || !(params$stat_tf %in% c("mean", "median", "max", "min"))) {
          res$status <- 400
          return(list(error = "Invalid parameter: stat_tf must be one of: mean, median, max, min"))
        }
      }

      # Validate VPA parameters must be positive (physical constraints)
      if ("m" %in% names(params)) {
        if (is.numeric(params$m) && length(params$m) == 1 && params$m <= 0) {
          res$status <- 400
          return(list(error = "Invalid parameter: m must be greater than 0"))
        }
      }
      if ("p_init" %in% names(params)) {
        if (is.numeric(params$p_init) && length(params$p_init) == 1 && params$p_init <= 0) {
          res$status <- 400
          return(list(error = "Invalid parameter: p_init must be greater than 0"))
        }
      }

      # Load and validate data (throws VPAError on failure)
      vpa_data <- load_vpa_data(
              data$caa_url,
              data$waa_url,
              data$maa_url,
              M = params$m %||% 0.5
          )

      # VPA calculation
      result_vpa <- vpa(
          vpa_data,
          fc.year = params$fc_year %||% 2015:2017,
          tf.year = params$tf_year %||% 2015:2016,
          term.F  = params$term_f %||% "max",
          stat.tf = params$stat_tf %||% "mean",
          Pope    = params$pope %||% TRUE,
          tune    = params$tune %||% FALSE,
          p.init  = params$p_init %||% 0.5
      )
      wcaa <- as.data.frame(result_vpa$wcaa)
      result <- setNames(
          lapply(seq_len(nrow(wcaa)), function(i) {
          x <- unlist(wcaa[i, ], use.names = FALSE)
          names(x) <- colnames(wcaa)
          as.list(x)
        }),
        paste0("age", seq_len(nrow(wcaa)) - 1)
      )

      log_info("POST /v0/vpa - VPA calculation completed")

      # Validate response (dev only)
      if (Sys.getenv("VALIDATE_RESPONSE", "false") == "true") {
        res_json <- jsonlite::toJSON(result, auto_unbox = TRUE)
        if (!jsonvalidate::json_validate(res_json, "{}")) {
          log_warn("Response validation failed for VPA endpoint")
        }
      }

      log_info(paste("VPA success"))
      res$status <- 200
      return(result)
    }, error = function(e) {
      # Handle VPAError with specific status code
      if (inherits(e, "VPAError")) {
        log_warn(sprintf("POST /v0/vpa - VPA error (%d): %s", e$status_code, e$message))
        res$status <- e$status_code
        return(list(error = e$message))
      }
      # Other errors (JSON parsing and null bytes handled by global error handler in run.R)
      else {
        log_warn(sprintf("POST /v0/vpa - Unexpected error: %s", e$message))
        res$status <- 500
        return(list(error = "Internal server error"))
      }
    })
    # Ensure function exits - tryCatch may not fully exit
    return(NULL)
}
