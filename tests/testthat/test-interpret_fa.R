# ==============================================================================
# PARAMETER VALIDATION TESTS (NO LLM REQUIRED)
# ==============================================================================

test_that("interpret_fa validates input parameters", {
  loadings <- sample_loadings()
  var_info <- sample_variable_info()

  # Test invalid cutoff
  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              model_type = "fa", cutoff = -0.1),
    "must be between 0 and 1"
  )

  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              model_type = "fa", cutoff = 1.5),
    "must be between 0 and 1"
  )

  # Test invalid n_emergency (negative values not allowed)
  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              model_type = "fa", n_emergency = -1),
    "must be a non-negative integer"
  )

  # Test invalid output_format (now validated in interpret_core, needs provider)
  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              model_type = "fa", provider = "ollama", model = "gpt-oss:20b-cloud",
              output_format = "invalid"),
    "must be either"
  )

  # Test invalid heading_level (now validated in interpret_core, needs provider)
  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              model_type = "fa", provider = "ollama", model = "gpt-oss:20b-cloud",
              heading_level = 0),
    "between 1 and 6"
  )

  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              model_type = "fa", provider = "ollama", model = "gpt-oss:20b-cloud",
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
              model_type = "fa", provider = "ollama"),
    'No variables from.*found in'
  )

  # No factor columns
  only_vars <- data.frame(variable = c("var1", "var2"))

  expect_error(
    interpret(fit_results = list(loadings = only_vars), variable_info = var_info,
              model_type = "fa", provider = "ollama"),
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
              model_type = "fa", provider = "ollama"),
    "must contain a .variable. column"
  )
})

test_that("interpret_fa validates chat_session parameter", {
  loadings <- sample_loadings()
  var_info <- sample_variable_info()

  # Test with invalid chat_session
  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              model_type = "fa", chat_session = "not a chat_fa"),
    "chat_session.*must be a chat_session object"
  )

  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              model_type = "fa", chat_session = list()),
    "chat_session.*must be a chat_session object"
  )
})

test_that("hide_low_loadings parameter validates correctly", {
  loadings <- sample_loadings()
  var_info <- sample_variable_info()

  # Test invalid hide_low_loadings
  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              model_type = "fa", hide_low_loadings = "yes"),
    "must be TRUE or FALSE"
  )

  expect_error(
    interpret(fit_results = list(loadings = loadings), variable_info = var_info,
              model_type = "fa", hide_low_loadings = NA),
    "must be TRUE or FALSE"
  )
})

# ==============================================================================
# COMPREHENSIVE LLM INTEGRATION TEST (SINGLE TEST FOR ALL FEATURES)
# ==============================================================================

test_that("interpret_fa comprehensive integration test", {
  skip_if_no_llm()

  # Use minimal fixtures for token efficiency
  loadings <- minimal_loadings()
  var_info <- minimal_variable_info()

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  # Single comprehensive test covering:
  # - Returns expected structure
  # - Token tracking works
  # - Factor names and summaries present
  # - Report generation
  result <- interpret(fit_results = list(loadings = loadings),
                        variable_info = var_info,
                        model_type = "fa",
                        provider = provider,
                        model = model,
                        word_limit = 30,  # Reduced for token efficiency
                        silent = TRUE)

  # Check main structure
  expect_s3_class(result, "fa_interpretation")
  expect_type(result$suggested_names, "list")
  expect_type(result$factor_summaries, "list")
  expect_type(result$report, "character")

  # Check that all factors are present
  factor_names <- setdiff(names(loadings), "variable")
  expect_true(all(factor_names %in% names(result$suggested_names)))
  expect_true(all(factor_names %in% names(result$factor_summaries)))

  # Check token tracking
  # Token tracking: older versions used `run_tokens`; newer versions expose
  # numeric `input_tokens` and `output_tokens` directly on the result. Check
  # for the newer shape first, else fall back to the old `run_tokens` shape.
  if ("input_tokens" %in% names(result) && "output_tokens" %in% names(result)) {
    expect_true(is.numeric(result$input_tokens))
    expect_true(is.numeric(result$output_tokens))
  } else {
    expect_true("run_tokens" %in% names(result))
    expect_type(result$run_tokens, "list")
  }

  # Check report generation
  expect_true(nchar(result$report) > 0)
})

# ==============================================================================
# EDGE CASE TESTS (USE MINIMAL LLM CALLS OR CACHED RESULTS)
# ==============================================================================

test_that("emergency rule behavior with n_emergency = 0", {
  skip_if_no_llm()

  # Create loadings where one factor has no loadings above cutoff
  weak_loadings <- data.frame(
    variable = c("v1", "v2"),
    F1 = c(0.85, 0.75),
    F2 = c(0.05, 0.03)  # All below cutoff
  )

  var_info <- data.frame(
    variable = c("v1", "v2"),
    description = c("Item 1", "Item 2")
  )

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  # Test with n_emergency = 0 - should mark as undefined
  result <- interpret(fit_results = list(loadings = weak_loadings),
                        variable_info = var_info,
                        model_type = "fa",
                        cutoff = 0.3,
                        n_emergency = 0,
                        provider = provider,
                        model = model,
                        word_limit = 30,
                        silent = TRUE)

  # Check that F2 is marked as undefined
  expect_equal(result$suggested_names$F2, "undefined")
  expect_equal(result$factor_summaries$F2$llm_interpretation, "NA")

  # Check that F2 has no variables (undefined factor)
  expect_equal(nrow(result$factor_summaries$F2$variables), 0)
  expect_false(result$factor_summaries$F2$used_emergency_rule)

  # Check that the report indicates it's marked as undefined
  expect_true(grepl("undefined", result$report, ignore.case = TRUE))
})
