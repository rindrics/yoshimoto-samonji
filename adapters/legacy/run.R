pr <- plumber::pr("plumber.R")

port <- Sys.getenv("PLUMBER_PORT", "8000")
pr$run(host = "0.0.0.0", port = as.integer(port))
