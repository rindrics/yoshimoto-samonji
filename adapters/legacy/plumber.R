library(frasyr)
library(jsonvalidate)
library(yaml)
library(logger)

# Configure logging
log_level <- Sys.getenv("LOG_LEVEL", "INFO")
log_threshold(log_level)

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

# Helper function to load data files with error handling
load_vpa_data <- function(caa_url, waa_url, maa_url, M) {
  tryCatch({
    log_debug(sprintf("Loading CSV files: caa=%s, waa=%s, maa=%s", caa_url, waa_url, maa_url))
    data.handler(
      caa = read.csv(caa_url, row.names = 1),
      waa = read.csv(waa_url, row.names = 1),
      maa = read.csv(maa_url, row.names = 1),
      M = as.numeric(M)
    )
  }, error = function(e) {
    # 404: File not found (URL unreachable)
    if (grepl("cannot open the connection|HTTP error|404", e$message, ignore.case = TRUE)) {
      stop(VPAError(sprintf("Failed to download file: %s", e$message), 404))
    }
    # 409: Data format or processing error
    else if (grepl("col.names|row.names|invalid|incompatible", e$message, ignore.case = TRUE)) {
      stop(VPAError(sprintf("Data format error: %s", e$message), 409))
    }
    # Default: 409 Conflict
    else {
      stop(VPAError(sprintf("Data processing error: %s", e$message), 409))
    }
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
      body <- jsonlite::fromJSON(req$postBody)
      req_json <- jsonlite::toJSON(body, auto_unbox = TRUE)
      log_debug(sprintf("Request body: %d bytes", nchar(req_json)))

      if (!jsonvalidate::json_validate(req_json, vpa_request_schema)) {
        log_warn("POST /v0/vpa - Request validation failed")
        res$status <- 400
        return(list(error = "Invalid request: data with caa_url, waa_url, maa_url required"))
      }

      log_info("POST /v0/vpa - Request validation passed")

      data <- body$data
      params <- body$params %||% list()
      log_debug(sprintf("VPA parameters: m=%s", params$m %||% 0.5))

      # VPA calculation
      tryCatch({
      result_vpa <- vpa(
          load_vpa_data(
              data$caa_url,
              data$waa_url,
              data$maa_url,
              M = params$m %||% 0.5
          ),
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

      log_debug(sprintf("Response: %d bytes", nchar(jsonlite::toJSON(result))))
      return(result)
      }, error = function(e) {
        # Handle VPAError with specific status code
        if (inherits(e, "VPAError")) {
          log_warn(sprintf("POST /v0/vpa - VPA error (%d): %s", e$status_code, e$message))
          res$status <- e$status_code
          return(list(error = e$message))
        }
        # Default error handling
        else {
          log_warn(sprintf("POST /v0/vpa - Unexpected error: %s", e$message))
          res$status <- 500
          return(list(error = "Internal server error"))
        }
      })
    }, error = function(e) {
      # JSON parsing error handler
      if (grepl("JSON|parse", e$message, ignore.case = TRUE)) {
        log_warn(sprintf("POST /v0/vpa - JSON parsing error: %s", e$message))
        res$status <- 400
        return(list(error = "Invalid JSON in request body"))
      }
      # Other request errors
      else {
        log_warn(sprintf("POST /v0/vpa - Request error: %s", e$message))
        res$status <- 400
        return(list(error = "Bad Request"))
      }
    })
}
