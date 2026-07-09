cat("=== R Library Paths ===\n")
print(.libPaths())
cat("\n=== Installed Packages ===\n")
print(rownames(installed.packages())[1:20])

library(plumber)

pr <- plumber::plumb("plumber.R")

pr$run(
  host = "0.0.0.0",
  port = as.integer(Sys.getenv("PLUMBER_PORT", "8000"))
)