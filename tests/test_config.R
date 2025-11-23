# Test Suite Configuration
# Helper functions for running different test subsets

#' Run only fast unit tests (no LLM calls)
#' @export
test_fast <- function() {
  # Set environment to skip all LLM tests
  Sys.setenv(CI = "true")
  testthat::test_local(filter = "^(0[1-9]|2[0-9])", reporter = "progress")
}

#' Run only integration tests (with LLM calls)
#' Requires Ollama/LLM to be running
#' @export
test_integration <- function() {
  Sys.setenv(CI = "false")
  testthat::test_local(filter = "^(1[0-4])", reporter = "progress")
}

#' Run specific test file by number
#' @param n Test number (e.g., 10 for test-10-integration-core.R)
#' @export
test_file <- function(n) {
  pattern <- sprintf("^%02d", n)
  testthat::test_local(filter = pattern, reporter = "progress")
}

#' Run all tests except performance benchmarks
#' @export
test_all_except_perf <- function() {
  testthat::test_local(filter = "^(?!.*zzz)", reporter = "progress")
}

#' Quick smoke test - minimal coverage check
#' Runs a subset of critical tests (< 30 seconds)
#' @export
test_smoke <- function() {
  Sys.setenv(CI = "true")
  testthat::test_local(
    filter = "^(01|02|03|20|21)",
    reporter = "progress"
  )
}
