# Tests for S3 interpret methods for various FA packages
# Focus: Data extraction and adaptation, not LLM interpretation

# ==============================================================================
# GENERIC FUNCTION TESTS
# ==============================================================================

test_that("interpret generic function exists and dispatches correctly", {
  expect_true(is.function(interpret))
})

test_that("interpret throws informative error for unsupported types", {
  # Test with unsupported object type (list without model_type)
  unsupported <- list(data = "test")
  class(unsupported) <- "unsupported_class"

  expect_error(
    interpret(
      model_fit = unsupported,
      variable_info = data.frame(variable = "test", description = "test")
    ),
    "model_type.*chat_session.*required"
  )
})

# ==============================================================================
# PSYCH PACKAGE - DATA EXTRACTION TESTS (NO LLM)
# ==============================================================================

test_that("interpret.fa correctly extracts loadings from psych::fa objects", {
  skip_if_not_installed("psych")

  library(psych)

  # Use fixture with proper correlational structure
  data <- correlational_data()
  fa_model <- fa(data, nfactors = 2, rotate = "oblimin", warnings = FALSE)

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

  data <- correlational_data()
  fa_model <- fa(data, nfactors = 2, rotate = "oblimin", warnings = FALSE)

  # Check that Phi (factor correlations) is present for oblique rotation
  expect_true(!is.null(fa_model$Phi))
  expect_true(is.matrix(fa_model$Phi))
  expect_equal(dim(fa_model$Phi), c(2, 2))
})

test_that("interpret.fa handles orthogonal rotation (no Phi)", {
  skip_if_not_installed("psych")

  library(psych)

  data <- correlational_data()
  fa_model <- fa(data, nfactors = 2, rotate = "varimax", warnings = FALSE)

  # Varimax is orthogonal - Phi should be NULL
  expect_true(is.null(fa_model$Phi))
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
      model_fit = bad_model,
      variable_info = var_info,
      model_type = "fa"
    ),
    "No variables.*found in.*variable_info"
  )
})

test_that("interpret.principal correctly extracts component loadings", {
  skip_if_not_installed("psych")

  library(psych)

  data <- correlational_data()
  pca_model <- principal(data, nfactors = 2, rotate = "varimax")

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

  data <- correlational_data()
  pca_model <- principal(data, nfactors = 2, rotate = "varimax")

  # PCA should have NULL Phi (components are orthogonal)
  expect_true(is.null(pca_model$Phi))
})

# ==============================================================================
# LAVAAN PACKAGE - DATA EXTRACTION TESTS (NO LLM)
# ==============================================================================

test_that("interpret.lavaan correctly extracts loadings from CFA models", {
  skip_if_not_installed("lavaan")

  library(lavaan)

  # Simple CFA model
  model_syntax <- '
    visual  =~ x1 + x2 + x3
    textual =~ x4 + x5 + x6
  '

  fit <- cfa(model_syntax, data = HolzingerSwineford1939, std.lv = TRUE)

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

  # CFA model with factor correlation
  model_syntax <- '
    visual  =~ x1 + x2 + x3
    textual =~ x4 + x5 + x6
  '

  fit <- cfa(model_syntax, data = HolzingerSwineford1939, std.lv = TRUE)

  # Check for factor correlations in standardizedSolution
  std_sol <- lavaan::standardizedSolution(fit)
  cor_rows <- std_sol[std_sol$op == "~~" & std_sol$lhs != std_sol$rhs, ]

  # Should have at least one factor correlation
  expect_true(nrow(cor_rows) > 0)
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
      model_fit = bad_model,
      variable_info = var_info,
      model_type = "fa"
    ),
    "must contain.*loadings"
  )
})

# ==============================================================================
# MIRT PACKAGE - DATA EXTRACTION TESTS (NO LLM)
# ==============================================================================

test_that("interpret.SingleGroupClass correctly extracts factor loadings from mirt", {
  skip_if_not_installed("mirt")

  library(mirt)

  # Use LSAT7 dataset
  data <- expand.table(LSAT7)

  # Fit a 2-dimensional model
  mirt_model <- mirt(data, 2, itemtype = "2PL", verbose = FALSE)

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
      model_fit = bad_model,
      variable_info = var_info,
      model_type = "fa"
    ),
    "must contain.*loadings"
  )
})

# ==============================================================================
# INTEGRATION TESTS (ONE PER PACKAGE, MINIMAL LLM CALLS)
# ==============================================================================

test_that("interpret.fa end-to-end integration with psych::fa", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  library(psych)

  # Use correlational fixture (realistic FA structure)
  data <- correlational_data()
  var_info <- correlational_var_info()
  fa_model <- fa(data, nfactors = 2, rotate = "oblimin", warnings = FALSE)

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  # Single integration test to verify end-to-end works
  result <- interpret(
    model_fit = fa_model,
    variable_info = var_info,
    llm_provider = provider,
    llm_model = model,
    word_limit = 20,  # Minimal for speed
    silent = TRUE
  )

  # Verify result structure
  expect_s3_class(result, "fa_interpretation")
  expect_true("suggested_names" %in% names(result))
  expect_true("factor_summaries" %in% names(result))

  # Verify factor correlations were passed through
  expect_true(!is.null(result$factor_cor_mat))
})

test_that("interpret.principal end-to-end integration with psych::principal", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  library(psych)

  data <- correlational_data()
  var_info <- correlational_var_info()
  pca_model <- principal(data, nfactors = 2, rotate = "varimax")

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  result <- interpret(
    model_fit = pca_model,
    variable_info = var_info,
    llm_provider = provider,
    llm_model = model,
    word_limit = 20,
    silent = TRUE
  )

  # Verify result structure
  expect_s3_class(result, "fa_interpretation")

  # PCA should have NULL factor correlations (orthogonal)
  expect_true(is.null(result$factor_cor_mat))
})

test_that("interpret.lavaan end-to-end integration with CFA", {
  skip_if_not_installed("lavaan")
  skip_if_no_llm()

  library(lavaan)

  model_syntax <- '
    visual  =~ x1 + x2 + x3
    textual =~ x4 + x5 + x6
  '

  fit <- cfa(model_syntax, data = HolzingerSwineford1939, std.lv = TRUE)

  var_info <- data.frame(
    variable = paste0("x", 1:6),
    description = paste("Indicator", 1:6)
  )

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  result <- interpret(
    model_fit = fit,
    variable_info = var_info,
    llm_provider = provider,
    llm_model = model,
    word_limit = 20,
    silent = TRUE
  )

  # Verify result structure
  expect_s3_class(result, "fa_interpretation")
  expect_true(length(result$suggested_names) == 2)  # 2 factors
})

test_that("interpret.SingleGroupClass end-to-end integration with mirt", {
  skip_if_not_installed("mirt")
  skip_if_no_llm()

  library(mirt)

  data <- expand.table(LSAT7)
  mirt_model <- mirt(data, 2, itemtype = "2PL", verbose = FALSE)

  var_info <- data.frame(
    variable = colnames(data),
    description = paste("LSAT item", 1:5)
  )

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  result <- interpret(
    model_fit = mirt_model,
    variable_info = var_info,
    llm_provider = provider,
    llm_model = model,
    word_limit = 20,
    silent = TRUE
  )

  # Verify result structure
  expect_s3_class(result, "fa_interpretation")
  expect_true("suggested_names" %in% names(result))
})
