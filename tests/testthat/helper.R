# Test Helper Functions
# Helper functions and utilities for psychinterpreter tests

# Fixture Loading Functions ----
# These functions use test_path() to load fixture data from RDS files
# This ensures correct paths in both interactive and automated testing

#' Get path to test fixture file
#'
#' Helper function that works in both test and interactive contexts
#' @param ... Path components to pass to test_path()
#' @return Character string with full path to fixture file
get_fixture_path <- function(...) {
  if (requireNamespace("testthat", quietly = TRUE)) {
    testthat::test_path(...)
  } else {
    # Fallback for interactive use
    file.path("tests", "testthat", ...)
  }
}

#' Load sample factor loadings
#'
#' @return A data frame with factor loadings
sample_loadings <- function() {
  readRDS(get_fixture_path("fixtures", "sample_loadings.rds"))
}

#' Load sample variable information
#'
#' @return A data frame with variable descriptions
sample_variable_info <- function() {
  readRDS(get_fixture_path("fixtures", "sample_variable_info.rds"))
}

#' Load sample factor correlation matrix
#'
#' @return A correlation matrix for oblique rotations
sample_factor_cor <- function() {
  readRDS(get_fixture_path("fixtures", "sample_factor_cor.rds"))
}

#' Load sample interpretation result
#'
#' @return A complete fa_interpretation object (fixture to avoid LLM calls)
sample_interpretation <- function() {
  readRDS(get_fixture_path("fixtures", "sample_interpretation.rds"))
}

# Minimal Fixtures (Token-Efficient) ----
# These fixtures use fewer variables and shorter descriptions for LLM tests
# Estimated token savings: ~60-70% compared to standard fixtures

#' Load minimal factor loadings (for token-efficient LLM tests)
#'
#' @return A data frame with 3 variables × 2 factors
minimal_loadings <- function() {
  readRDS(get_fixture_path("fixtures", "minimal_loadings.rds"))
}

#' Load minimal variable information (for token-efficient LLM tests)
#'
#' @return A data frame with short variable descriptions
minimal_variable_info <- function() {
  readRDS(get_fixture_path("fixtures", "minimal_variable_info.rds"))
}

#' Load minimal factor correlation matrix (for token-efficient LLM tests)
#'
#' @return A 2×2 correlation matrix
minimal_factor_cor <- function() {
  readRDS(get_fixture_path("fixtures", "minimal_factor_cor.rds"))
}

# LLM Availability Functions ----

#' Check if Ollama/LLM is available for testing
#'
#' @return Logical indicating if LLM tests can run
has_ollama <- function() {
  # Skip on CI environments (GitHub Actions, etc.)
  if (identical(Sys.getenv("CI"), "true")) {
    return(FALSE)
  }

  # Try to check if Ollama is running by attempting to load ellmer
  tryCatch({
    requireNamespace("ellmer", quietly = TRUE)
  }, error = function(e) {
    FALSE
  })
}

#' Skip test if Ollama/ellmer not available
#'
#' Skips the current test if:
#' - Running in CI environment
#' - ellmer package is not available
skip_if_no_llm <- function() {
  if (!has_ollama()) {
    testthat::skip("ellmer package not available for Ollama")
  }
}
