#* @apiTitle Stock Assessment API
#* @apiDescription API for stock assessment calculation using ichimomo/frasyr
#* @apiVersion 0.1.0
#* @apiContact list(name = "Rindrics", url = "https://github.com/Rindrics/yoshimoto-samonji", email = "dev+yoshimoto-samonji@rindrics.com")
#* @apiLicense list(name = "MIT", url = "https://opensource.org/licenses/MIT")
#* @apiTag vpa Operations for Virtual Population Analysis

#* Echo back the input
#* @tag vpa
#* @param msg The message to echo
#* @get /vpa/echo
function(msg="") {
  list(msg = paste0("The message is: '", msg, "'"))
}
