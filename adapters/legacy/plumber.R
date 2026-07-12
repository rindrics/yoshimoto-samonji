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

# Check DNS resolution with timeout (prevent hanging on domains like A.aG)
check_dns <- function(hostname) {
  result <- system(
    sprintf("timeout 2 nslookup %s >/dev/null 2>&1", shQuote(hostname)),
    intern = FALSE
  )
  # timeout returns 124 if timed out, nslookup returns 1 if not found
  if (result %in% c(1, 124)) {
    stop(VPAError(sprintf("Cannot resolve hostname: %s", hostname), 404))
  }
}

# Helper function to fetch CSV with explicit timeout control
rfetch_csv <- function(url) {
  tryCatch({
    hostname <- gsub("^https?://([^/?#]+).*", "\\1", url)

    # Verify DNS resolution (prevents hanging on slow/unresolvable domains)
    tryCatch(check_dns(hostname), error = function(e) {
      if (inherits(e, "VPAError")) stop(e)
      # If system call fails, continue anyway
    })

    # Fetch with curl timeout
    h <- curl::new_handle(connecttimeout = 1L, timeout = 2L)
    resp <- curl::curl_fetch_memory(url, handle = h)

    if (resp$status_code >= 400) {
      stop(VPAError(sprintf("HTTP %d for %s", resp$status_code, url), 404))
    }

    read.csv(text = rawToChar(resp$content), row.names = 1)
  }, error = function(e) {
    if (inherits(e, "VPAError")) stop(e)
    stop(VPAError(sprintf("Failed to fetch %s: %s", url, e$message), 404))
  })
}

# Validation helpers
validate_url <- function(url, param_name) {
  if (!is.character(url) || !grepl("^https?://", url)) {
    list(error = sprintf("Invalid parameter: %s must be a valid HTTP(S) URL", param_name), status = 400)
  } else {
    NULL
  }
}

validate_numeric <- function(value, param_name, required = FALSE) {
  if (required && is.null(value)) {
    return(list(error = sprintf("Invalid parameter: %s is required", param_name), status = 400))
  }
  if (!is.null(value)) {
    if (!is.numeric(value) || length(value) != 1 || any(is.na(value))) {
      return(list(error = sprintf("Invalid parameter: %s must be a single numeric value", param_name), status = 400))
    }
    if (value <= 0) {
      return(list(error = sprintf("Invalid parameter: %s must be greater than 0", param_name), status = 400))
    }
  }
  NULL
}

validate_logical <- function(value, param_name, required = FALSE, must_be_false = FALSE) {
  if (required && is.null(value)) {
    return(list(error = sprintf("Invalid parameter: %s is required", param_name), status = 400))
  }
  if (!is.null(value)) {
    if (!is.logical(value) || length(value) != 1) {
      return(list(error = sprintf("Invalid parameter: %s must be boolean", param_name), status = 400))
    }
    if (must_be_false && value != FALSE) {
      return(list(error = sprintf("Invalid parameter: %s must be false", param_name), status = 400))
    }
  }
  NULL
}

validate_year_array <- function(value, param_name, raw_json) {
  if (is.null(value)) return(NULL)

  # Check for array syntax in raw JSON
  is_array <- grepl(sprintf('"%s"\\s*:\\s*\\[', param_name), raw_json)
  if (!is_array || !is.numeric(value) || length(value) == 0 || !all(value == as.integer(value))) {
    return(list(error = sprintf("Invalid parameter: %s must be an array of integers", param_name), status = 400))
  }

  # Validate year range
  if (any(value < MINIMUM_YEAR)) {
    return(list(error = sprintf("Invalid parameter: %s values must be >= %d", param_name, MINIMUM_YEAR), status = 400))
  }
  if (any(value > MAXIMUM_YEAR)) {
    return(list(error = sprintf("Invalid parameter: %s values must be <= %d", param_name, MAXIMUM_YEAR), status = 400))
  }
  NULL
}

validate_enum <- function(value, param_name, allowed_values, required = FALSE) {
  if (required && is.null(value)) {
    return(list(error = sprintf("Invalid parameter: %s is required", param_name), status = 400))
  }
  if (!is.null(value)) {
    if (!is.character(value) || length(value) != 1 || !(value %in% allowed_values)) {
      return(list(error = sprintf("Invalid parameter: %s must be one of: %s", param_name, paste(allowed_values, collapse = ", ")), status = 400))
    }
  }
  NULL
}

# Parameter specifications for table-driven validation
PARAM_SPECS <- list(
  list(name = "m", type = "numeric"),
  list(name = "p_init", type = "numeric"),
  list(name = "pope", type = "logical"),
  list(name = "tune", type = "logical", must_be_false = TRUE),
  list(name = "fc_year", type = "year_array"),
  list(name = "tf_year", type = "year_array"),
  list(name = "term_f", type = "enum", allowed_values = c("max", "mean")),
  list(name = "stat_tf", type = "enum", allowed_values = c("mean", "median", "max", "min"))
)

# Validate a single parameter based on its specification
validate_param <- function(param_name, param_value, spec, raw_json) {
  # Explicitly specified null values are invalid
  if (!is.null(param_value)) {
    switch(spec$type,
      "numeric" = validate_numeric(param_value, param_name),
      "logical" = validate_logical(param_value, param_name, must_be_false = isTRUE(spec$must_be_false)),
      "year_array" = validate_year_array(param_value, param_name, raw_json),
      "enum" = validate_enum(param_value, param_name, spec$allowed_values),
      NULL
    )
  } else {
    NULL
  }
}

# Validate VPA request parameters
validate_vpa_params <- function(body, raw_json) {
  # Validate body is an object
  if (!is.list(body) || is.null(names(body)) || length(names(body)) == 0) {
    return(list(valid = FALSE, error = "Invalid request: body must be a JSON object", status = 400))
  }

  data <- body$data
  params <- body$params %||% list()

  # Validate data structure
  if (is.null(data) || !is.list(data) || is.data.frame(data)) {
    return(list(valid = FALSE, error = "Invalid parameter: data must be an object", status = 400))
  }

  if ("params" %in% names(body) && is.null(body$params)) {
    return(list(valid = FALSE, error = "Invalid parameter: params must be an object, not null", status = 400))
  }

  if (!is.null(body$params) && !is.list(body$params)) {
    return(list(valid = FALSE, error = "Invalid parameter: params must be an object", status = 400))
  }

  # Validate unexpected properties
  unexpected_in_body <- setdiff(names(body), c("data", "params"))
  if (length(unexpected_in_body) > 0) {
    return(list(valid = FALSE, error = sprintf("Invalid request: unexpected properties: %s", paste(unexpected_in_body, collapse = ", ")), status = 400))
  }

  unexpected_in_data <- setdiff(names(data), c("caa_url", "waa_url", "maa_url"))
  if (length(unexpected_in_data) > 0) {
    return(list(valid = FALSE, error = sprintf("Invalid parameter: unexpected properties in data: %s", paste(unexpected_in_data, collapse = ", ")), status = 400))
  }

  expected_params_props <- c("m", "fc_year", "tf_year", "term_f", "stat_tf", "pope", "tune", "p_init", "sel_update", "sel_f", "alpha", "max_dd", "abund", "min_age", "max_age")
  unexpected_in_params <- setdiff(names(params), expected_params_props)
  if (length(unexpected_in_params) > 0) {
    return(list(valid = FALSE, error = sprintf("Invalid parameter: unexpected properties in params: %s", paste(unexpected_in_params, collapse = ", ")), status = 400))
  }

  # Validate data URLs
  for (url_param in c("caa_url", "waa_url", "maa_url")) {
    err <- validate_url(data[[url_param]], url_param)
    if (!is.null(err)) return(list(valid = FALSE, error = err$error, status = err$status))
  }

  # Validate parameters (table-driven)
  for (spec in PARAM_SPECS) {
    param_name <- spec$name
    param_value <- params[[param_name]]

    # Check for explicitly specified null values
    if (param_name %in% names(params) && is.null(param_value)) {
      return(list(valid = FALSE, error = sprintf("Invalid parameter: %s must be a valid value", param_name), status = 400))
    }

    # Validate parameter if present
    err <- validate_param(param_name, param_value, spec, raw_json)
    if (!is.null(err)) return(list(valid = FALSE, error = err$error, status = err$status))
  }

  list(valid = TRUE)
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
    status_code <- 409

    # 409: Data format or processing error
    if (grepl("col.names|row.names|invalid|incompatible", error_msg, ignore.case = TRUE)) {
      error_msg <- sprintf("Data format error: %s", error_msg)
    } else {
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
      # Parse request
      log_debug(sprintf("Request postBody length: %d bytes", nchar(req$postBody)))

      if (nchar(req$postBody) == 0) {
        log_warn("POST /v0/vpa - Empty request body")
        res$status <- 400
        return(list(error = "Empty request body"))
      }

      log_debug("Attempting JSON parse...")
      body <- jsonlite::fromJSON(req$postBody)
      log_debug(sprintf("Request body parsed successfully"))

      # Validate request
      val <- validate_vpa_params(body, req$postBody)
      if (!val$valid) {
        res$status <- val$status
        return(list(error = val$error))
      }

      data <- body$data
      params <- body$params %||% list()

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
