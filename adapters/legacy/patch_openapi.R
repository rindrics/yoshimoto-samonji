# openapi_patch.R

add_openapi_schema <- function(spec) {
  spec$paths$`/v0/vpa`$post$requestBody <- vpa_request_body_schema()
  spec$paths$`/v0/vpa`$post$responses$`200` <- vpa_response_schema()
  spec
}

vpa_response_schema <- function() {
  list(
    description = "Age cohort catch-at-age data indexed by age group and year",
    content = list(
      "application/json" = list(
        schema = list(
          type = "object",
          description = "Object with age groups (e.g., age0, age1, age2...) as keys. Each age group contains yearly catch-at-age values.",
          additionalProperties = list(
            type = "object",
            description = "Year to catch weight mapping for each age group",
            additionalProperties = list(
              type = "number",
              description = "Catch weight at age for the year"
            )
          )
        ),
        example = list(
          age0 = list(
            `1988` = 6816.76,
            `1989` = 8429.68,
            `1990` = 8145.12,
            `1991` = 2817.16
          ),
          age1 = list(
            `1988` = 5234.56,
            `1989` = 6345.67,
            `1990` = 7456.78,
            `1991` = 4567.89
          )
        )
      )
    )
  )
}

vpa_request_body_schema <- function() {
  list(
    required = TRUE,
    content = list(
      "application/json" = list(
        schema = list(
          type = "object",
          required = list("data"),
          properties = list(
            data = list(
              type = "object",
              required = list("caa_url", "waa_url", "maa_url"),
              properties = list(
                caa_url = list(type = "string", format = "uri"),
                waa_url = list(type = "string", format = "uri"),
                maa_url = list(type = "string", format = "uri")
              )
            ),
            params = list(
              type = "object",
              properties = list(
                m = list(type = "number", default = 0.5),
                fc_year = list(
                  type = "array",
                  items = list(type = "integer"),
                  example = list(2015, 2016, 2017)
                ),
                tf_year = list(
                  type = "array",
                  items = list(type = "integer"),
                  example = list(2015, 2016)
                ),
                term_f = list(type = "string", default = "max"),
                stat_tf = list(type = "string", default = "mean"),
                pope = list(type = "boolean", default = TRUE),
                tune = list(type = "boolean", default = FALSE),
                p_init = list(type = "number", default = 0.5)
              )
            )
          )
        ),
        example = list(
          data = list(
            caa_url = "https://raw.githubusercontent.com/ichimomo/frasyr/dev/data-raw/ex2_caa.csv",
            waa_url = "https://raw.githubusercontent.com/ichimomo/frasyr/dev/data-raw/ex2_waa.csv",
            maa_url = "https://raw.githubusercontent.com/ichimomo/frasyr/dev/data-raw/ex2_maa.csv"
          ),
          params = list(
            m = 0.5,
            fc_year = list(2015, 2016, 2017),
            tf_year = list(2015, 2016),
            term_f = "max",
            stat_tf = "mean",
            pope = TRUE,
            tune = FALSE,
            p_init = 0.5
          )
        )
      )
    )
  )
}