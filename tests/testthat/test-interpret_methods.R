# Tests for S3 interpret methods for various FA packages

test_that("interpret generic function exists and dispatches correctly", {
  expect_true(is.function(interpret))
})

test_that("interpret.default throws informative error", {
  # Test with unsupported object type
  unsupported <- list(data = "test")
  class(unsupported) <- "unsupported_class"

  expect_error(
    interpret(unsupported, variable_info = data.frame()),
    "No interpret method available"
  )
})

# ==============================================================================
# TESTS FOR PSYCH PACKAGE METHODS
# ==============================================================================

test_that("interpret.fa works with psych::fa objects", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  library(psych)

  # Use fixture with proper correlational structure (avoids FA warnings)
  data <- correlational_data()
  var_info <- correlational_var_info()
  fa_model <- fa(data, nfactors = 2, rotate = "oblimin", warnings = FALSE)

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  result <- interpret(fa_model,
                     variable_info = var_info,
                     llm_provider = provider,
                     llm_model = model,
                     word_limit = 30,  # Reduced for token efficiency
                     silent = TRUE)

  # Check result structure
  expect_s3_class(result, "fa_interpretation")
  expect_true("suggested_names" %in% names(result))
  expect_true("factor_summaries" %in% names(result))
})

test_that("interpret.fa extracts factor correlations from oblique rotation", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  library(psych)

  # Use fixture with proper correlational structure (avoids FA warnings)
  data <- correlational_data()
  var_info <- correlational_var_info()
  fa_model <- fa(data, nfactors = 2, rotate = "oblimin", warnings = FALSE)

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  result <- interpret(fa_model,
                     variable_info = var_info,
                     llm_provider = provider,
                     llm_model = model,
                     word_limit = 30,  # Reduced for token efficiency
                     silent = TRUE)

  # Should have factor correlations for oblique rotation
  expect_true(!is.null(result$factor_cor_mat))
})

test_that("interpret.fa validates input model", {
  skip_if_not_installed("psych")

  # Test with wrong class
  bad_model <- list(loadings = matrix(1:4, nrow = 2))

  var_info <- data.frame(
    variable = c("var1", "var2"),
    description = c("Var 1", "Var 2")
  )

  expect_error(
    interpret.fa(bad_model, var_info),
    "must be of class"
  )
})

test_that("interpret.principal works with psych::principal objects", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  library(psych)

  # Use fixture with proper correlational structure (avoids FA warnings)
  data <- correlational_data()
  var_info <- correlational_var_info()
  pca_model <- principal(data, nfactors = 2, rotate = "varimax")

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  result <- interpret(pca_model,
                     variable_info = var_info,
                     llm_provider = provider,
                     llm_model = model,
                     word_limit = 30,  # Reduced for token efficiency
                     silent = TRUE)

  # Check result structure
  expect_s3_class(result, "fa_interpretation")
  expect_true("suggested_names" %in% names(result))
})

test_that("interpret.principal does not extract factor correlations", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  library(psych)

  # Use fixture with proper correlational structure (avoids FA warnings)
  data <- correlational_data()
  var_info <- correlational_var_info()
  pca_model <- principal(data, nfactors = 2, rotate = "varimax")

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  result <- interpret(pca_model,
                     variable_info = var_info,
                     llm_provider = provider,
                     llm_model = model,
                     word_limit = 30,  # Reduced for token efficiency
                     silent = TRUE)

  # PCA should have NULL factor correlations (orthogonal)
  expect_true(is.null(result$factor_cor_mat))
})

# ==============================================================================
# TESTS FOR LAVAAN PACKAGE METHODS
# ==============================================================================

test_that("interpret.lavaan works with CFA models", {
  skip_if_not_installed("lavaan")
  skip_if_no_llm()

  library(lavaan)

  # Simple CFA model with HolzingerSwineford1939 dataset
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

  result <- interpret(fit,
                     variable_info = var_info,
                     llm_provider = provider,
                     llm_model = model,
                     silent = TRUE)

  # Check result structure
  expect_s3_class(result, "fa_interpretation")
  expect_true("suggested_names" %in% names(result))
  expect_true(length(result$suggested_names) == 2)  # 2 factors
})

test_that("interpret.lavaan extracts factor correlations", {
  skip_if_not_installed("lavaan")
  skip_if_no_llm()

  library(lavaan)

  # CFA model that allows factor correlation
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

  result <- interpret(fit,
                     variable_info = var_info,
                     llm_provider = provider,
                     llm_model = model,
                     silent = TRUE)

  # Should have factor correlations
  expect_true(!is.null(result$factor_cor_mat))
})

test_that("interpret.lavaan validates input model", {
  skip_if_not_installed("lavaan")

  # Test with wrong class
  bad_model <- list(data = "test")

  var_info <- data.frame(
    variable = c("x1", "x2"),
    description = c("Var 1", "Var 2")
  )

  expect_error(
    interpret.lavaan(bad_model, var_info),
    "must be of class"
  )
})

test_that("interpret.efaList works with lavaan::efa objects", {
  skip_if_not_installed("lavaan")
  skip_if_no_llm()

  library(lavaan)

  # Check if efa function is available (newer lavaan versions)
  if (!exists("efa", where = "package:lavaan")) {
    skip("lavaan::efa not available in this version")
  }

  # Run EFA
  fit <- efa(data = HolzingerSwineford1939[, 7:15],
            nfactors = 2,
            rotation = "geomin")

  var_info <- data.frame(
    variable = paste0("x", 1:9),
    description = paste("Indicator", 1:9)
  )

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  result <- interpret(fit,
                     variable_info = var_info,
                     llm_provider = provider,
                     llm_model = model,
                     silent = TRUE)

  # Check result structure
  expect_s3_class(result, "fa_interpretation")
  expect_true("suggested_names" %in% names(result))
})

# ==============================================================================
# TESTS FOR MIRT PACKAGE METHODS
# ==============================================================================

test_that("interpret.SingleGroupClass works with mirt models", {
  skip_if_not_installed("mirt")
  skip_if_no_llm()

  library(mirt)

  # Use LSAT7 dataset (built-in to mirt)
  data <- expand.table(LSAT7)

  # Fit a 2-dimensional model
  mirt_model <- mirt(data, 2, itemtype = "2PL", verbose = FALSE)

  var_info <- data.frame(
    variable = colnames(data),
    description = paste("LSAT item", 1:5)
  )

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  result <- interpret(mirt_model,
                     variable_info = var_info,
                     llm_provider = provider,
                     llm_model = model,
                     word_limit = 20,
                     silent = TRUE)

  # Check result structure
  expect_s3_class(result, "fa_interpretation")
  expect_true("suggested_names" %in% names(result))
})

test_that("interpret.SingleGroupClass validates input model", {
  skip_if_not_installed("mirt")

  # Test with wrong class
  bad_model <- list(data = "test")

  var_info <- data.frame(
    variable = c("item1", "item2"),
    description = c("Item 1", "Item 2")
  )

  expect_error(
    interpret.SingleGroupClass(bad_model, var_info),
    "must be of class"
  )
})

# ==============================================================================
# TESTS FOR CLASS VALIDATION
# ==============================================================================

test_that("all interpret methods return fa_interpretation objects", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  library(psych)

  # Use fixture with proper correlational structure (avoids FA warnings)
  data <- correlational_data()
  var_info <- correlational_var_info()

  fa_model <- fa(data, nfactors = 2, rotate = "oblimin", warnings = FALSE)

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  result <- interpret(fa_model,
                     variable_info = var_info,
                     llm_provider = provider,
                     llm_model = model,
                     word_limit = 30,  # Reduced for token efficiency
                     silent = TRUE)

  # Validate class
  expect_true(inherits(result, "fa_interpretation"))
  expect_true(inherits(result, "list"))
})
