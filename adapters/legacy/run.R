cat("=== R Library Paths ===\n")
print(.libPaths())
cat("\n=== Installed Packages ===\n")
print(rownames(installed.packages())[1:20])

library(plumber)
library(logger)

pr <- plumber::plumb("plumber.R")

# Global error handler for malformed requests (e.g., null bytes)
MALFORMED_REQUEST_PATTERNS <- c(
  "nul character", "parse error", "EOF", "lexical error", "invalid char",
  "unexpected end", "Expected", "escape sequence", "premature", "Unterminated"
)

pr$setErrorHandler(function(req, res, err) {
  error_msg <- tryCatch(as.character(err$message), error = function(e) "Unknown error")

  # Sanitize error message (handle invalid UTF-8)
  error_msg_safe <- tryCatch(
    iconv(error_msg, from = "", to = "UTF-8", sub = "?"),
    error = function(e) "Unknown error"
  )

  log_debug(sprintf("Global error handler triggered. Error: %s", error_msg_safe))

  # Check for malformed request patterns (including null bytes)
  pattern <- paste(MALFORMED_REQUEST_PATTERNS, collapse = "|")
  if (grepl(pattern, error_msg_safe, ignore.case = TRUE)) {
    log_warn(sprintf("Malformed request: %s", error_msg_safe))
    res$status <- 400
    return(list(error = "Invalid request: malformed data"))
  }

  # Default error response
  log_error(sprintf("Unhandled error: %s", error_msg_safe))
  res$status <- 500
  return(list(error = "Internal server error"))
})

pr$run(
  host = "0.0.0.0",
  port = as.integer(Sys.getenv("PLUMBER_PORT", "8000"))
)