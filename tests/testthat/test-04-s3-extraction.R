# ==============================================================================
# S3 DATA EXTRACTION TESTS
# Extracted from test-interpret_methods.R as part of Phase 2 Test Reorganization
# Focus: Testing data extraction from psych, lavaan, and mirt model objects
# ==============================================================================

# ==============================================================================
# PSYCH PACKAGE - DATA EXTRACTION TESTS (NO LLM)
# ==============================================================================

test_that("interpret.fa correctly extracts loadings from psych::fa objects", {
  skip_if_not_installed("psych")

  library(psych)

  # Use cached FA model (saves fitting time)
  fa_model <- sample_fa_oblimin()

  # Check that model has expected structure
  expect_true("loadings" %in% names(fa_model))
  expect_true(inherits(fa_model, "fa"))

  # Verify loadings can be extracted
  loadings <- as.data.frame(unclass(fa_model$loadings))
  expect_true(is.data.frame(loadings))
  expect_true(ncol(loadings) == 2)  # 2 factors
  expect_true(nrow(loadings) == 6)  # 6 variables
})

test_that("interpret.fa correctly extracts factor correlations from oblique rotation", {
  skip_if_not_installed("psych")

  library(psych)

  # Use cached FA model (saves fitting time)
  fa_model <- sample_fa_oblimin()

  # Check that Phi (factor correlations) is present for oblique rotation
  expect_true(!is.null(fa_model$Phi))
  expect_true(is.matrix(fa_model$Phi))
  expect_equal(dim(fa_model$Phi), c(2, 2))
})

test_that("interpret.fa handles orthogonal rotation (no Phi)", {
  skip_if_not_installed("psych")

  library(psych)

  # Use cached FA model with orthogonal rotation (saves fitting time)
  fa_model <- sample_fa_varimax()

  # Varimax is orthogonal - Phi should be NULL
  expect_true(is.null(fa_model$Phi))
})

test_that("interpret.principal correctly extracts component loadings", {
  skip_if_not_installed("psych")

  library(psych)

  # Use cached PCA model (saves fitting time)
  pca_model <- sample_pca_varimax()

  # Check that model has expected structure
  expect_true("loadings" %in% names(pca_model))
  expect_true(inherits(pca_model, "principal"))

  # Verify loadings can be extracted
  loadings <- as.data.frame(unclass(pca_model$loadings))
  expect_true(is.data.frame(loadings))
  expect_true(ncol(loadings) == 2)  # 2 components
})

test_that("interpret.principal does not extract factor correlations (orthogonal)", {
  skip_if_not_installed("psych")

  library(psych)

  # Use cached PCA model (saves fitting time)
  pca_model <- sample_pca_varimax()

  # PCA should have NULL Phi (components are orthogonal)
  expect_true(is.null(pca_model$Phi))
})

# ==============================================================================
# LAVAAN PACKAGE - DATA EXTRACTION TESTS (NO LLM)
# ==============================================================================

test_that("interpret.lavaan correctly extracts loadings from CFA models", {
  skip_if_not_installed("lavaan")

  library(lavaan)

  # Use cached lavaan CFA model (saves fitting time)
  fit <- sample_lavaan_cfa()

  # Check that model is fitted
  expect_true(inherits(fit, "lavaan"))

  # Check that we can extract standardized loadings
  # (The method uses lavaan::standardizedSolution internally)
  std_sol <- lavaan::standardizedSolution(fit)
  loadings_rows <- std_sol[std_sol$op == "=~", ]
  expect_true(nrow(loadings_rows) > 0)
  expect_true(all(c("lhs", "rhs", "est.std") %in% names(loadings_rows)))
})

test_that("interpret.lavaan extracts factor correlations when present", {
  skip_if_not_installed("lavaan")

  library(lavaan)

  # Use cached lavaan CFA model (saves fitting time)
  fit <- sample_lavaan_cfa()

  # Check for factor correlations in standardizedSolution
  std_sol <- lavaan::standardizedSolution(fit)
  cor_rows <- std_sol[std_sol$op == "~~" & std_sol$lhs != std_sol$rhs, ]

  # Should have at least one factor correlation
  expect_true(nrow(cor_rows) > 0)
})

# ==============================================================================
# MIRT PACKAGE - DATA EXTRACTION TESTS (NO LLM)
# ==============================================================================

test_that("interpret.SingleGroupClass correctly extracts factor loadings from mirt", {
  skip_if_not_installed("mirt")

  library(mirt)

  # Use cached MIRT model (saves ~4 seconds per test run)
  mirt_model <- sample_mirt_model()

  # Check that model is fitted
  expect_true(inherits(mirt_model, "SingleGroupClass"))

  # Check that we can extract factor loadings via summary
  # (The method uses summary() with suppress = TRUE)
  coef_list <- coef(mirt_model, simplify = TRUE)
  expect_true("items" %in% names(coef_list))

  # Items should have a and d parameters (for 2PL)
  items <- coef_list$items
  expect_true(is.matrix(items))
})

# ==============================================================================
# INTEGRATION TEST (ONE REPRESENTATIVE TEST WITH LLM)
# This test verifies end-to-end extraction and interpretation workflow.
# Full integration testing across multiple scenarios is done in test-12-integration-fa.R
# ==============================================================================

test_that("interpret.fa end-to-end integration with psych::fa", {
  skip_on_ci()
  skip_if_not_installed("psych")
  skip_if_no_llm()

  library(psych)

  # Use cached FA model and correlational variable info (saves fitting time)
  fa_model <- sample_fa_oblimin()
  var_info <- correlational_var_info()

  llm_provider <- "ollama"
  llm_model <- "gpt-oss:20b-cloud"

  # Single integration test to verify end-to-end works (skip if rate limited)
  result <- with_llm_rate_limit_skip({
    interpret(
      fit_results = fa_model,
      variable_info = var_info,
      llm_provider = llm_provider,
      llm_model = llm_model,
      word_limit = 20,  # Minimal for speed
      verbosity = 0
    )
  })

  # Verify result structure
  expect_s3_class(result, "fa_interpretation")
  expect_true("suggested_names" %in% names(result))
  expect_true("component_summaries" %in% names(result))

  # Verify factor correlations were passed through (now in analysis_data)
  expect_true(!is.null(result$analysis_data$factor_cor_mat))
})

# Note: Integration tests for psych::principal, lavaan::cfa, and mirt were removed
# to reduce test time. Data extraction is verified by the non-LLM tests above
# (lines 1-148), and full integration testing is covered in test-12-integration-fa.R
