cat("=== R Library Paths ===\n")
print(.libPaths())
cat("\n=== Installed Packages ===\n")
print(rownames(installed.packages())[1:20])

library(plumber)

source("patch_openapi.R")

pr <- plumber::plumb("plumber.R")
pr <- plumber::pr_set_api_spec(pr, add_openapi_schema)

pr$run(
  host = "0.0.0.0",
  port = as.integer(Sys.getenv("PLUMBER_PORT", "8000"))
)