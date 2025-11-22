# ==============================================================================
# PARAMETER VALIDATION TESTS (NO LLM REQUIRED)
# Extracted from test-interpret_fa.R as part of Phase 2 Test Reorganization
# ==============================================================================

library(testthat)
library(psychinterpreter)

test_that("interpret_fa validates input parameters", {
  loadings <- sample_loadings()
  var_info <- sample_variable_info()

  # Test invalid cutoff
  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              analysis_type = "fa", cutoff = -0.1),
    "must be between 0 and 1"
  )

  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              analysis_type = "fa", cutoff = 1.5),
    "must be between 0 and 1"
  )

  # Test invalid n_emergency (negative values not allowed)
  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              analysis_type = "fa", n_emergency = -1),
    "must be a non-negative integer"
  )

  # Test invalid output_format (now validated in interpret_core, needs provider)
  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              analysis_type = "fa", llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud",
              output_format = "invalid"),
    "must be either"
  )

  # Test invalid heading_level (now validated in interpret_core, needs provider)
  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              analysis_type = "fa", llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud",
              heading_level = 0),
    "between 1 and 6"
  )

  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              analysis_type = "fa", llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud",
              heading_level = 7),
    "between 1 and 6"
  )
})

test_that("interpret_fa validates loadings structure", {
  var_info <- sample_variable_info()

  # Missing variable column
  bad_loadings <- data.frame(
    ML1 = c(0.8, 0.7),
    ML2 = c(0.1, 0.15)
  )

  expect_error(
    interpret(fit_results = list(loadings = bad_loadings), variable_info = var_info,
              analysis_type = "fa", llm_provider = "ollama"),
    'No variables from.*found in'
  )

  # No factor columns
  only_vars <- data.frame(variable = c("var1", "var2"))

  expect_error(
    interpret(fit_results = list(loadings = only_vars), variable_info = var_info,
              analysis_type = "fa", llm_provider = "ollama"),
    "must contain at least one factor"
  )
})

test_that("interpret_fa validates variable_info structure", {
  loadings <- sample_loadings()

  # Missing required columns
  bad_var_info <- data.frame(
    var = c("var1", "var2")
  )

  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = bad_var_info,
              analysis_type = "fa", llm_provider = "ollama"),
    "must contain a .variable. column"
  )
})

test_that("interpret_fa validates chat_session parameter", {
  loadings <- sample_loadings()
  var_info <- sample_variable_info()

  # Test with invalid chat_session
  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              analysis_type = "fa", chat_session = "not a chat_fa"),
    "chat_session.*must be a chat_session object"
  )

  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              analysis_type = "fa", chat_session = list()),
    "chat_session.*must be a chat_session object"
  )
})

test_that("hide_low_loadings parameter validates correctly", {
  loadings <- sample_loadings()
  var_info <- sample_variable_info()

  # Test invalid hide_low_loadings
  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              analysis_type = "fa", hide_low_loadings = "yes"),
    "must be TRUE or FALSE"
  )

  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              analysis_type = "fa", hide_low_loadings = NA),
    "must be TRUE or FALSE"
  )
})
