# ==============================================================================
# COMPREHENSIVE TESTS FOR NEW interpret() API
# ==============================================================================
#
# Tests all usage patterns with named arguments and validates error handling
# for common misuse cases.

library(testthat)
library(psychinterpreter)

# ==============================================================================
# TEST FIXTURES
# ==============================================================================

# Helper to load fixtures
get_test_loadings <- function() {
  readRDS(test_path("fixtures/fa/minimal_loadings.rds"))
}

get_test_variable_info <- function() {
  readRDS(test_path("fixtures/fa/minimal_variable_info.rds"))
}

get_test_factor_cor_mat <- function() {
  readRDS(test_path("fixtures/fa/minimal_factor_cor.rds"))
}

# ==============================================================================
# PATTERN 1: FITTED MODEL OBJECTS
# ==============================================================================

test_that("Pattern 1: interpret() works with fitted psych::fa model", {
  skip_on_ci()

  # Load fixture
  fa_model <- readRDS(test_path("fixtures/fa/minimal_fa_model.rds"))
  var_info <- get_test_variable_info()

  # Call with named arguments
  result <- interpret(
    model_fit = fa_model,
    variable_info = var_info,
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20
  )

  # Validate
  expect_s3_class(result, "fa_interpretation")
  expect_s3_class(result, "interpretation")
  expect_s3_class(result, "list")
  expect_true("suggested_names" %in% names(result))
  expect_true("component_summaries" %in% names(result))
})

test_that("Pattern 1: interpret() works with fitted psych::principal model", {
  skip_on_ci()

  # Load fixture
  pca_model <- readRDS(test_path("fixtures/fa/minimal_pca_model.rds"))
  var_info <- get_test_variable_info()

  # Call with named arguments
  result <- interpret(
    model_fit = pca_model,
    variable_info = var_info,
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20
  )

  # Validate
  expect_s3_class(result, "fa_interpretation")
  expect_length(result$suggested_names, 2)
})

# ==============================================================================
# PATTERN 2: RAW DATA (MATRIX/DATA.FRAME) WITH model_type
# ==============================================================================

test_that("Pattern 2: interpret() works with raw loadings matrix", {
  skip_on_ci()

  loadings <- get_test_loadings()
  var_info <- get_test_variable_info()

  result <- interpret(
    model_fit = loadings,
    variable_info = var_info,
    model_type = "fa",
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20
  )

  expect_s3_class(result, "fa_interpretation")
  expect_length(result$suggested_names, 2)
})

test_that("Pattern 2: interpret() requires model_type for raw data", {
  loadings <- get_test_loadings()
  var_info <- get_test_variable_info()

  # Missing model_type should error
  expect_error(
    interpret(
      model_fit = loadings,
      variable_info = var_info
      # No model_type, no chat_session
    ),
    "model_type.*required"
  )
})

# ==============================================================================
# PATTERN 3: STRUCTURED LIST
# ==============================================================================

test_that("Pattern 3: interpret() works with structured list (loadings only)", {
  skip_on_ci()

  loadings <- get_test_loadings()
  var_info <- get_test_variable_info()

  result <- interpret(
    model_fit = list(loadings = loadings),
    variable_info = var_info,
    model_type = "fa",
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20
  )

  expect_s3_class(result, "fa_interpretation")
})

test_that("Pattern 3: interpret() works with structured list (loadings + Phi)", {
  skip_on_ci()

  loadings <- get_test_loadings()
  var_info <- get_test_variable_info()
  phi <- get_test_factor_cor_mat()

  result <- interpret(
    model_fit = list(
      loadings = loadings,
      Phi = phi
    ),
    variable_info = var_info,
    model_type = "fa",
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20
  )

  expect_s3_class(result, "fa_interpretation")
})

test_that("Pattern 3: interpret() works with structured list (loadings + factor_cor_mat)", {
  skip_on_ci()

  loadings <- get_test_loadings()
  var_info <- get_test_variable_info()
  phi <- get_test_factor_cor_mat()

  result <- interpret(
    model_fit = list(
      loadings = loadings,
      factor_cor_mat = phi  # Alternative name
    ),
    variable_info = var_info,
    model_type = "fa",
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20
  )

  expect_s3_class(result, "fa_interpretation")
})

test_that("Pattern 3: interpret() requires loadings in list", {
  var_info <- get_test_variable_info()
  phi <- get_test_factor_cor_mat()

  # List without loadings should error
  expect_error(
    interpret(
      model_fit = list(Phi = phi),  # Missing loadings
      variable_info = var_info,
      model_type = "fa"
    ),
    "loadings.*required|must contain.*loadings"
  )
})

test_that("Pattern 3: interpret() warns about unrecognized list components", {
  skip_on_ci()

  loadings <- get_test_loadings()
  var_info <- get_test_variable_info()

  expect_warning(
    interpret(
      model_fit = list(
        loadings = loadings,
        unrecognized_component = "something"
      ),
      variable_info = var_info,
      model_type = "fa",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud",
      word_limit = 20
    ),
    "Unrecognized.*ignored"
  )
})

# ==============================================================================
# PATTERN 4: CHAT SESSION
# ==============================================================================

test_that("Pattern 4: interpret() works with chat_session", {
  skip_on_ci()

  loadings <- get_test_loadings()
  var_info <- get_test_variable_info()

  # Create chat session
  chat <- chat_session(
    model_type = "fa",
    provider = "ollama",
    model = "gpt-oss:20b-cloud"
  )

  # Use with interpret()
  result <- interpret(
    chat_session = chat,
    model_fit = loadings,
    variable_info = var_info,
    word_limit = 20
  )

  expect_s3_class(result, "fa_interpretation")
})

test_that("Pattern 4: interpret() with chat_session reuses system prompt", {
  skip_on_ci()

  loadings <- get_test_loadings()
  var_info <- get_test_variable_info()

  chat <- chat_session(
    model_type = "fa",
    provider = "ollama",
    model = "gpt-oss:20b-cloud"
  )

  # First interpretation
  result1 <- interpret(
    chat_session = chat,
    model_fit = loadings,
    variable_info = var_info,
    word_limit = 20
  )

  # Second interpretation (should reuse system prompt)
  result2 <- interpret(
    chat_session = chat,
    model_fit = loadings,
    variable_info = var_info,
    word_limit = 20
  )

  # Both should succeed
  expect_s3_class(result1, "fa_interpretation")
  expect_s3_class(result2, "fa_interpretation")

  # Token counters should show multiple interpretations
  expect_gt(chat$n_interpretations, 1)
})

test_that("Pattern 4: interpret() with chat_session and fitted model", {
  skip_on_ci()

  fa_model <- readRDS(test_path("fixtures/fa/minimal_fa_model.rds"))
  var_info <- get_test_variable_info()

  chat <- chat_session(
    model_type = "fa",
    provider = "ollama",
    model = "gpt-oss:20b-cloud"
  )

  result <- interpret(
    chat_session = chat,
    model_fit = fa_model,
    variable_info = var_info,
    word_limit = 20
  )

  expect_s3_class(result, "fa_interpretation")
})

test_that("Pattern 4: interpret() with chat_session and structured list", {
  skip_on_ci()

  loadings <- get_test_loadings()
  var_info <- get_test_variable_info()
  phi <- get_test_factor_cor_mat()

  chat <- chat_session(
    model_type = "fa",
    provider = "ollama",
    model = "gpt-oss:20b-cloud"
  )

  result <- interpret(
    chat_session = chat,
    model_fit = list(
      loadings = loadings,
      Phi = phi
    ),
    variable_info = var_info,
    word_limit = 20
  )

  expect_s3_class(result, "fa_interpretation")
})

# ==============================================================================
# MISUSE CASES: ARGUMENT VALIDATION
# ==============================================================================

test_that("Misuse: interpret() errors when no arguments provided", {
  expect_error(
    interpret(),
    "No arguments provided"
  )
})

test_that("Misuse: interpret() errors when model_fit missing", {
  var_info <- get_test_variable_info()

  expect_error(
    interpret(variable_info = var_info),
    "model_fit.*required"
  )
})

test_that("Misuse: interpret() errors when variable_info missing", {
  loadings <- get_test_loadings()

  expect_error(
    interpret(model_fit = loadings, model_type = "fa"),
    "variable_info.*required"
  )
})

test_that("Misuse: interpret() errors when variable_info not a data.frame", {
  loadings <- get_test_loadings()

  expect_error(
    interpret(
      model_fit = loadings,
      variable_info = list(a = 1, b = 2),
      model_type = "fa"
    ),
    "variable_info.*must be a data frame"
  )
})

test_that("Misuse: interpret() errors when variable_info missing 'variable' column", {
  loadings <- get_test_loadings()

  expect_error(
    interpret(
      model_fit = loadings,
      variable_info = data.frame(wrong_column = c("A", "B", "C")),
      model_type = "fa"
    ),
    "variable.*column"
  )
})

test_that("Misuse: interpret() errors with invalid chat_session", {
  loadings <- get_test_loadings()
  var_info <- get_test_variable_info()

  expect_error(
    interpret(
      model_fit = loadings,
      variable_info = var_info,
      chat_session = list(not = "a_session")
    ),
    "chat_session.*must be a chat_session object"
  )
})

test_that("Misuse: interpret() warns when both chat_session and conflicting model_type", {
  skip_on_ci()

  loadings <- get_test_loadings()
  var_info <- get_test_variable_info()

  chat <- chat_session(
    model_type = "fa",
    provider = "ollama",
    model = "gpt-oss:20b-cloud"
  )

  expect_warning(
    interpret(
      chat_session = chat,
      model_fit = loadings,
      variable_info = var_info,
      model_type = "gm",  # Conflicts with chat_session's "fa"
      word_limit = 20
    ),
    "Both.*chat_session.*and.*model_type.*provided"
  )
})

test_that("Misuse: interpret() errors for unsupported model_fit type", {
  var_info <- get_test_variable_info()

  expect_error(
    interpret(
      model_fit = "not_a_valid_type",
      variable_info = var_info,
      model_type = "fa"
    ),
    "Cannot interpret"
  )
})

# ==============================================================================
# ADDITIONAL_INFO PARAMETER
# ==============================================================================

test_that("additional_info is passed correctly (not in model_fit list)", {
  skip_on_ci()

  loadings <- get_test_loadings()
  var_info <- get_test_variable_info()

  result <- interpret(
    model_fit = loadings,
    variable_info = var_info,
    model_type = "fa",
    additional_info = "This is additional context",
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20
  )

  expect_s3_class(result, "fa_interpretation")
  # additional_info should be in params (passed via ...)
  expect_true(!is.null(result$params$additional_info))
  expect_equal(result$params$additional_info, "This is additional context")
})
