library(frasyr)
#* @apiTitle Stock Assessment API
#* @apiDescription API for stock assessment calculation using ichimomo/frasyr
#* @apiVersion 0.1.0
#* @apiContact list(name = "Rindrics", url = "https://github.com/Rindrics/yoshimoto-samonji", email = "dev+yoshimoto-samonji@rindrics.com")
#* @apiLicense list(name = "MIT", url = "https://opensource.org/licenses/MIT")
#* @apiTag vpa Operations for Virtual Population Analysis
#* @apiTag stock_assessment Operations for stock assessment

#* Echo back the input
#* @tag vpa
#* @param msg The message to echo
#* @get /vpa/echo
data <- data.handler(
    caa = read.csv("../../data/ex2_caa.csv", row.names = 1),
    waa = read.csv("../../data/ex2_waa.csv", row.names = 1),
    maa = read.csv("../../data/ex2_maa.csv", row.names = 1),
    M = 0.5
)
function(msg="") {
  list(msg = paste0("The message is: '", msg, "'"))
}
