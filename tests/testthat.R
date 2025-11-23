# This file is part of the standard testthat setup.
# It is run by R CMD check.
# You can run it manually with devtools::test()

library(testthat)
library(psychinterpreter)

# Enable parallel test execution for faster testing
# Set to FALSE on CI or if tests have timing dependencies
PARALLEL_TESTS <- identical(Sys.getenv("PARALLEL_TESTS", "true"), "true") &&
                  !identical(Sys.getenv("CI"), "true")

if (PARALLEL_TESTS) {
  # Run tests in parallel on multiple cores
  # Reserve 2 cores for system stability
  n_cores <- max(1, parallel::detectCores() - 2)
  test_check("psychinterpreter", reporter = "progress", parallel = n_cores)
} else {
  # Standard sequential execution
  test_check("psychinterpreter")
}
