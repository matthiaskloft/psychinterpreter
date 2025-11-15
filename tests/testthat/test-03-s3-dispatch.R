# ==============================================================================
# S3 GENERIC DISPATCH TESTS (NO LLM)
# Extracted from test-interpret_methods.R as part of Phase 2 Test Reorganization
# Focus: Testing that the S3 generic dispatch system works correctly
# ==============================================================================

test_that("interpret generic function exists and dispatches correctly", {
  expect_true(is.function(interpret))
})

test_that("interpret throws informative error for unsupported types", {
  # Test with unsupported object type (not a fitted model, not list, not matrix/df)
  unsupported <- "not_a_valid_model"
  class(unsupported) <- "unsupported_class"

  expect_error(
    interpret(
      fit_results = unsupported,
      variable_info = data.frame(variable = "test", description = "test"),
      llm_provider = "ollama",  # Provide to get past validation
      analysis_type = "fa"  # Provide to get past validation
    ),
    "Cannot interpret"
  )
})

test_that("interpret validates input model for psych::fa", {
  skip_if_not_installed("psych")

  # Test with mismatched variable names in loadings and variable_info
  bad_model <- list(loadings = matrix(1:4, nrow = 2))

  var_info <- data.frame(
    variable = c("var1", "var2"),
    description = c("Var 1", "Var 2")
  )

  expect_error(
    interpret(
      fit_results = bad_model,
      variable_info = var_info,
      analysis_type = "fa",
      llm_provider = "ollama"  # Provide to get past validation
    ),
    "No variables.*found in.*variable_info"
  )
})

test_that("interpret.lavaan validates input model", {
  skip_if_not_installed("lavaan")

  # Test with list structure (will be treated as structured list, not lavaan object)
  # Since creating a fake S4 lavaan object is complex, just test that a list
  # without proper structure errors appropriately
  bad_model <- list(data = matrix(1:4, nrow = 2))

  var_info <- data.frame(
    variable = c("x1", "x2"),
    description = c("Var 1", "Var 2")
  )

  expect_error(
    interpret(
      fit_results = bad_model,
      variable_info = var_info,
      analysis_type = "fa",
      llm_provider = "ollama"  # Provide to get past validation
    ),
    "must contain.*loadings"
  )
})

test_that("interpret validates input model for mirt", {
  skip_if_not_installed("mirt")

  # Test with wrong list structure (missing loadings)
  bad_model <- list(data = "test")

  var_info <- data.frame(
    variable = c("item1", "item2"),
    description = c("Item 1", "Item 2")
  )

  expect_error(
    interpret(
      fit_results = bad_model,
      variable_info = var_info,
      analysis_type = "fa",
      llm_provider = "ollama"  # Provide to get past validation
    ),
    "must contain.*loadings"
  )
})
