#* @apiTitle Stock Assessment API
#* @apiDescription API for stock assessment calculation using ichimomo/frasyr
#* @apiVersion 0.1.0
#* @apiContact list(name = "Rindrics", url = "https://github.com/Rindrics/yoshimoto-samonji", email = "dev+yoshimoto-samonji@rindrics.com")
#* @apiLicense list(name = "MIT", url = "https://opensource.org/licenses/MIT")
#* @apiTag vpa Operations for Virtual Population Analysis
start_server <- function() {
    pr <- plumber::pr("R/main.R")
    pr$mount("/vpa", plumber::pr("R/vpa.R"))

    spec <- pr$getApiSpec()
    jsonlite::write_json(spec, "../../schema/openapi.json", pretty = TRUE)

    port <- Sys.getenv("PLUMBER_PORT")
    pr$run(host = "0.0.0.0", port = port)
}
