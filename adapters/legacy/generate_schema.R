library(plumber)
library(jsonlite)

source("patch_openapi.R")

pr <- plumber::plumb("plumber.R")
pr <- plumber::pr_set_api_spec(pr, add_openapi_schema)

spec <- pr$getApiSpec()

write_json(
  spec,
  "openapi.json",
  auto_unbox = TRUE,
  pretty = TRUE
)