library(frasyr)
#* @apiTitle Stock Assessment API
#* @apiDescription API for stock assessment calculation using ichimomo/frasyr
#* @apiVersion 0.1.0
#* @apiContact list(name = "Rindrics", url = "https://github.com/Rindrics/yoshimoto-samonji", email = "dev+yoshimoto-samonji@rindrics.com")
#* @apiLicense list(name = "MIT", url = "https://opensource.org/licenses/MIT")
#* @apiTag vpa Operations for Virtual Population Analysis

#* Run VPA
#* @tag vpa
#* @post /v0/vpa
#*   description: "Run Virtual Population Analysis"
#* @serializer unboxedJSON
function(req) {
    body <- jsonlite::fromJSON(req$postBody)

    data <- body$data
    params <- body$params %||% list()

    result_vpa <- vpa(
        data.handler(
            caa = read.csv(data$caa_url, row.names = 1),
            waa = read.csv(data$waa_url, row.names = 1),
            maa = read.csv(data$maa_url, row.names = 1),
            M   = as.numeric(params$m %||% 0.5)
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
    setNames(
        lapply(seq_len(nrow(wcaa)), function(i) {
        x <- unlist(wcaa[i, ], use.names = FALSE)
        names(x) <- colnames(wcaa)
        as.list(x)
      }),
      paste0("age", seq_len(nrow(wcaa)) - 1)
    )
}
