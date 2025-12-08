# ==============================================================================
# FA-SPECIFIC INTEGRATION TESTS (WITH LLM)
# Extracted from test-interpret_fa.R as part of Phase 2 Test Reorganization
# Focus: Edge cases and FA-specific behavior that require LLM calls
# ==============================================================================

test_that("interpret_fa comprehensive integration test", {
  skip_on_ci()
  skip_if_no_llm()

  # Use minimal fixtures for token efficiency
  loadings <- minimal_loadings()
  var_info <- minimal_variable_info()

  llm_provider <- "ollama"
  llm_model <- "gpt-oss:20b-cloud"

  # Single comprehensive test covering:
  # - Returns expected structure
  # - Token tracking works
  # - Factor names and summaries present
  # - Report generation
  result <- interpret(fit_results = list(loadings = loadings),
                        variable_info = var_info,
                        analysis_type = "fa",
                        llm_provider = llm_provider,
                        llm_model = llm_model,
                        word_limit = 20,  # Minimum for token efficiency
                        verbosity = 0)

  # Check main structure
  expect_s3_class(result, "fa_interpretation")
  expect_type(result$suggested_names, "list")
  expect_type(result$component_summaries, "list")
  expect_type(result$report, "character")

  # Check that all factors are present
  factor_names <- setdiff(names(loadings), "variable")
  expect_true(all(factor_names %in% names(result$suggested_names)))
  expect_true(all(factor_names %in% names(result$component_summaries)))

  # Check token tracking - tokens are now in llm_info
  expect_type(result$llm_info, "list")
  expect_true(is.numeric(result$llm_info$input_tokens))
  expect_true(is.numeric(result$llm_info$output_tokens))

  # Check report generation
  expect_true(nchar(result$report) > 0)
})

test_that("emergency rule behavior with n_emergency = 0", {
  skip_on_ci()
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

  llm_provider <- "ollama"
  llm_model <- "gpt-oss:20b-cloud"

  # Test with n_emergency = 0 - should mark as undefined
  result <- interpret(fit_results = list(loadings = weak_loadings),
                        variable_info = var_info,
                        analysis_type = "fa",
                        cutoff = 0.3,
                        n_emergency = 0,
                        llm_provider = llm_provider,
                        llm_model = llm_model,
                        word_limit = 20,  # Minimum for token efficiency
                        verbosity = 0)

  # Check that F2 is marked as undefined
  expect_equal(result$suggested_names$F2, "undefined")
  expect_equal(result$component_summaries$F2$llm_interpretation, "NA")

  # Check that F2 has no variables (undefined factor)
  expect_equal(nrow(result$component_summaries$F2$variables), 0)
  expect_false(result$component_summaries$F2$used_emergency_rule)

  # Check that the report indicates it's marked as undefined
  expect_true(grepl("undefined", result$report, ignore.case = TRUE))
})
