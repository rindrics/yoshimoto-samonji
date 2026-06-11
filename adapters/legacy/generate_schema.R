spec <- plumber::plumb("plumber.R")$getApiSpec()
cat(jsonlite::toJSON(spec, pretty = TRUE), file = "../../schema/openapi.json")
