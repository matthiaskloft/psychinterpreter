# Test Helper Functions
# Helper functions and utilities for psychinterpreter tests

# Fixture Cache Environment ----
# Cache environment to load fixtures only once per test session
# This significantly reduces I/O overhead during testing
.test_cache <- new.env(parent = emptyenv())

# Fixture Loading Functions ----
# These functions use test_path() to load fixture data from RDS files
# This ensures correct paths in both interactive and automated testing
# Fixtures are cached in .test_cache and loaded only once per test session

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
  cache_key <- "sample_loadings"
  if (!exists(cache_key, envir = .test_cache)) {
    .test_cache[[cache_key]] <- readRDS(get_fixture_path("fixtures", "fa", "sample_loadings.rds"))
  }
  .test_cache[[cache_key]]
}

#' Load sample variable information
#'
#' @return A data frame with variable descriptions
sample_variable_info <- function() {
  cache_key <- "sample_variable_info"
  if (!exists(cache_key, envir = .test_cache)) {
    .test_cache[[cache_key]] <- readRDS(get_fixture_path("fixtures", "fa", "sample_variable_info.rds"))
  }
  .test_cache[[cache_key]]
}

#' Load sample factor correlation matrix
#'
#' @return A correlation matrix for oblique rotations
sample_factor_cor <- function() {
  cache_key <- "sample_factor_cor"
  if (!exists(cache_key, envir = .test_cache)) {
    .test_cache[[cache_key]] <- readRDS(get_fixture_path("fixtures", "fa", "sample_factor_cor.rds"))
  }
  .test_cache[[cache_key]]
}

#' Load sample interpretation result
#'
#' @return A complete fa_interpretation object (fixture to avoid LLM calls)
sample_interpretation <- function() {
  cache_key <- "sample_interpretation"
  if (!exists(cache_key, envir = .test_cache)) {
    .test_cache[[cache_key]] <- readRDS(get_fixture_path("fixtures", "fa", "sample_interpretation.rds"))
  }
  .test_cache[[cache_key]]
}

# Minimal Fixtures (Token-Efficient) ----
# These fixtures use fewer variables and shorter descriptions for LLM tests
# Estimated token savings: ~60-70% compared to standard fixtures

#' Load minimal factor loadings (for token-efficient LLM tests)
#'
#' @return A data frame with 3 variables × 2 factors
minimal_loadings <- function() {
  cache_key <- "minimal_loadings"
  if (!exists(cache_key, envir = .test_cache)) {
    .test_cache[[cache_key]] <- readRDS(get_fixture_path("fixtures", "fa", "minimal_loadings.rds"))
  }
  .test_cache[[cache_key]]
}

#' Load minimal variable information (for token-efficient LLM tests)
#'
#' @return A data frame with short variable descriptions
minimal_variable_info <- function() {
  cache_key <- "minimal_variable_info"
  if (!exists(cache_key, envir = .test_cache)) {
    .test_cache[[cache_key]] <- readRDS(get_fixture_path("fixtures", "fa", "minimal_variable_info.rds"))
  }
  .test_cache[[cache_key]]
}

#' Load minimal factor correlation matrix (for token-efficient LLM tests)
#'
#' @return A 2×2 correlation matrix
minimal_factor_cor <- function() {
  cache_key <- "minimal_factor_cor"
  if (!exists(cache_key, envir = .test_cache)) {
    .test_cache[[cache_key]] <- readRDS(get_fixture_path("fixtures", "fa", "minimal_factor_cor.rds"))
  }
  .test_cache[[cache_key]]
}

#' Load minimal FA model fixture (for token-efficient LLM tests)
#'
#' @return A psych::fa fitted model object with 3 variables × 2 factors
minimal_fa_model <- function() {
  cache_key <- "minimal_fa_model"
  if (!exists(cache_key, envir = .test_cache)) {
    .test_cache[[cache_key]] <- readRDS(get_fixture_path("fixtures", "fa", "minimal_fa_model.rds"))
  }
  .test_cache[[cache_key]]
}

#' Load minimal PCA model fixture (for token-efficient LLM tests)
#'
#' @return A psych::principal fitted model object with 3 variables × 2 components
minimal_pca_model <- function() {
  cache_key <- "minimal_pca_model"
  if (!exists(cache_key, envir = .test_cache)) {
    .test_cache[[cache_key]] <- readRDS(get_fixture_path("fixtures", "fa", "minimal_pca_model.rds"))
  }
  .test_cache[[cache_key]]
}

# Correlational Data Fixtures (for S3 method testing) ----
# These fixtures have proper correlational structure for psych/lavaan/mirt

#' Load correlational data (for S3 method tests)
#'
#' @return A data frame with 6 variables having proper factor structure
correlational_data <- function() {
  cache_key <- "correlational_data"
  if (!exists(cache_key, envir = .test_cache)) {
    .test_cache[[cache_key]] <- readRDS(get_fixture_path("fixtures", "fa", "correlational_data.rds"))
  }
  .test_cache[[cache_key]]
}

#' Load correlational variable info (for S3 method tests)
#'
#' @return A data frame with variable descriptions for correlational data
correlational_var_info <- function() {
  cache_key <- "correlational_var_info"
  if (!exists(cache_key, envir = .test_cache)) {
    .test_cache[[cache_key]] <- readRDS(get_fixture_path("fixtures", "fa", "correlational_var_info.rds"))
  }
  .test_cache[[cache_key]]
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

  # Check if ellmer package is available
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    return(FALSE)
  }

  # Try to actually connect to Ollama and run a minimal test
  tryCatch({
    # Create a minimal chat session to test connectivity
    test_chat <- ellmer::chat(
      name = "ollama/gpt-oss:20b-cloud",
      system_prompt = "test"
    )
    # Try a simple query - if this fails, Ollama isn't properly available
    test_chat$chat("hello", echo = "none")
    return(TRUE)
  }, error = function(e) {
    # If we get any error (including HTTP 500), Ollama isn't available
    return(FALSE)
  })
}

#' Skip test if Ollama/ellmer not available
#'
#' Skips the current test if:
#' - Running in CI environment
#' - ellmer package is not available
#' - Ollama service is not running or not responding
skip_if_no_llm <- function() {
  if (!has_ollama()) {
    testthat::skip("Ollama LLM not available (either ellmer package missing or service not responding)")
  }
}
