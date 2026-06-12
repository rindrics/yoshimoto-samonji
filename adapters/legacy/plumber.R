library(frasyr)
#* @apiTitle Stock Assessment API
#* @apiDescription API for stock assessment calculation using ichimomo/frasyr
#* @apiVersion 0.1.0
#* @apiContact list(name = "Rindrics", url = "https://github.com/Rindrics/yoshimoto-samonji", email = "dev+yoshimoto-samonji@rindrics.com")
#* @apiLicense list(name = "MIT", url = "https://opensource.org/licenses/MIT")
#* @apiTag vpa Operations for Virtual Population Analysis
#* @apiTag stock_assessment Operations for stock assessment

#* Run VPA
#* @tag vpa
#* @post /v0/vpa
#* @param urlCaa: URL to obtain catch-at-age data in csv
#* @param urlWaa: URL to obtain weight-at-age data in csv
#* @param urlMaa: URL to obtain maturation-at-age data in csv
#* @param m: Natural mortality in decimal (default: 0.5)
function(
    urlCaa = "https://raw.githubusercontent.com/ichimomo/frasyr/dev/data-raw/ex2_caa.csv",
    urlWaa = "https://raw.githubusercontent.com/ichimomo/frasyr/dev/data-raw/ex2_waa.csv",
    urlMaa = "https://raw.githubusercontent.com/ichimomo/frasyr/dev/data-raw/ex2_maa.csv",
    m      = 0.5
    ) {
    result_vpa <- vpa(
        data.handler(
            caa = read.csv(urlCaa, row.names = 1),
            waa = read.csv(urlWaa, row.names = 1),
            maa = read.csv(urlMaa, row.names = 1),
            M   = as.numeric(m)
        ),
        fc.year = 2015:2017,
        tf.year = 2015:2016,
        term.F  = "max",
        stat.tf = "mean",
        Pope    = TRUE,
        tune    = FALSE,
        p.init  = 0.5
    )
    result_vpa$wcaa
}
