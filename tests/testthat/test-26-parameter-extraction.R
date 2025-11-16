# test-26-parameter-extraction.R
# Tests for S3 parameter extraction and model validation generics
# Tests extract_model_parameters() and validate_model_requirements()

library(psychinterpreter)

# ==============================================================================
# extract_model_parameters() Tests
# ==============================================================================

test_that("extract_model_parameters.default() returns empty list", {
  analysis_type <- structure("unknown", class = "unknown")
  result <- extract_model_parameters(analysis_type, NULL)

  expect_type(result, "list")
  expect_length(result, 0)
})

test_that("extract_model_parameters.fa() extracts all FA parameters", {
  analysis_type <- structure("fa", class = "fa")

  interpretation_args <- list(
    cutoff = 0.4,
    n_emergency = 3,
    hide_low_loadings = TRUE,
    sort_loadings = FALSE
  )

  result <- extract_model_parameters(analysis_type, interpretation_args)

  expect_type(result, "list")
  expect_equal(result$cutoff, 0.4)
  expect_equal(result$n_emergency, 3)
  expect_equal(result$hide_low_loadings, TRUE)
  expect_equal(result$sort_loadings, FALSE)
})

test_that("extract_model_parameters.fa() handles NULL interpretation_args", {
  analysis_type <- structure("fa", class = "fa")
  result <- extract_model_parameters(analysis_type, NULL)

  expect_type(result, "list")
  expect_length(result, 0)
})

test_that("extract_model_parameters.fa() handles partial parameters", {
  analysis_type <- structure("fa", class = "fa")

  # Only provide some parameters
  interpretation_args <- list(
    cutoff = 0.35,
    n_emergency = 1
    # Missing: hide_low_loadings, sort_loadings
  )

  result <- extract_model_parameters(analysis_type, interpretation_args)

  expect_equal(result$cutoff, 0.35)
  expect_equal(result$n_emergency, 1)
  expect_null(result$hide_low_loadings)
  expect_null(result$sort_loadings)
})

test_that("extract_model_parameters.fa() ignores non-FA parameters", {
  analysis_type <- structure("fa", class = "fa")

  interpretation_args <- list(
    cutoff = 0.3,
    some_random_param = 123,  # Should be ignored
    another_param = "test"     # Should be ignored
  )

  result <- extract_model_parameters(analysis_type, interpretation_args)

  expect_equal(result$cutoff, 0.3)
  expect_null(result$some_random_param)
  expect_null(result$another_param)
})

test_that("extract_model_parameters.gm() extracts GM parameters (placeholder)", {
  analysis_type <- structure("gm", class = "gm")

  interpretation_args <- list(
    n_clusters = 3,
    covariance_type = "full"
  )

  result <- extract_model_parameters(analysis_type, interpretation_args)

  expect_type(result, "list")
  expect_equal(result$n_clusters, 3)
  expect_equal(result$covariance_type, "full")
})

test_that("extract_model_parameters.gm() handles NULL", {
  analysis_type <- structure("gm", class = "gm")
  result <- extract_model_parameters(analysis_type, NULL)

  expect_type(result, "list")
  expect_length(result, 0)
})

# ==============================================================================
# validate_model_requirements() Tests
# ==============================================================================

test_that("validate_model_requirements.default() passes silently", {
  analysis_type <- structure("unknown", class = "unknown")

  # Should not error
  expect_invisible(validate_model_requirements(analysis_type))
  expect_null(validate_model_requirements(analysis_type))
})

test_that("validate_model_requirements.fa() requires variable_info", {
  analysis_type <- structure("fa", class = "fa")

  # Test with NULL variable_info
  expect_error(
    validate_model_requirements(analysis_type, variable_info = NULL),
    "variable_info.*required"
  )
})

test_that("validate_model_requirements.fa() validates variable_info structure", {
  analysis_type <- structure("fa", class = "fa")

  # Test with non-data.frame
  expect_error(
    validate_model_requirements(analysis_type, variable_info = "not a data frame"),
    "must be a data frame"
  )

  # Test with missing columns
  bad_df <- data.frame(var = c("v1", "v2"))
  expect_error(
    validate_model_requirements(analysis_type, variable_info = bad_df),
    "must have 'variable' and 'description' columns"
  )
})

test_that("validate_model_requirements.fa() accepts valid variable_info", {
  analysis_type <- structure("fa", class = "fa")

  variable_info <- data.frame(
    variable = c("var1", "var2"),
    description = c("First variable", "Second variable")
  )

  # Should pass without error
  expect_invisible(validate_model_requirements(analysis_type, variable_info = variable_info))
  expect_null(validate_model_requirements(analysis_type, variable_info = variable_info))
})

test_that("validate_model_requirements.fa() accepts variable_info with extra columns", {
  analysis_type <- structure("fa", class = "fa")

  variable_info <- data.frame(
    variable = c("var1", "var2"),
    description = c("First variable", "Second variable"),
    extra_column = c("extra1", "extra2")
  )

  # Should pass - extra columns are OK
  expect_invisible(validate_model_requirements(analysis_type, variable_info = variable_info))
})

test_that("validate_model_requirements.gm() passes (placeholder)", {
  analysis_type <- structure("gm", class = "gm")

  # GM doesn't require variable_info currently
  expect_invisible(validate_model_requirements(analysis_type))
  expect_null(validate_model_requirements(analysis_type))
})

# ==============================================================================
# Integration Tests
# ==============================================================================

test_that("Parameter extraction integrates with interpret() workflow", {
  # Create minimal loadings
  loadings <- matrix(c(0.8, 0.2, 0.3, 0.7), nrow = 2, ncol = 2)
  rownames(loadings) <- c("var1", "var2")
  colnames(loadings) <- c("F1", "F2")

  variable_info <- data.frame(
    variable = c("var1", "var2"),
    description = c("First variable", "Second variable")
  )

  # Create interpretation_args with custom parameters
  interp_args <- interpretation_args(
    analysis_type = "fa",
    cutoff = 0.25,
    n_emergency = 1
  )

  skip_on_ci()
  skip_if(Sys.getenv("OLLAMA_AVAILABLE") != "true", "Ollama not available")

  result <- interpret(
    fit_results = list(loadings = loadings),
    variable_info = variable_info,
    interpretation_args = interp_args,
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20
  )

  # Verify result structure
  expect_s3_class(result, "fa_interpretation")
  expect_true("metadata" %in% names(result))
})

test_that("Validation errors are informative", {
  analysis_type <- structure("fa", class = "fa")

  # Test error message quality
  expect_error(
    validate_model_requirements(analysis_type, variable_info = NULL),
    regex = "variable_info.*required",
    class = "rlang_error"
  )

  expect_error(
    validate_model_requirements(analysis_type, variable_info = list(a = 1)),
    regex = "must be a data frame",
    class = "rlang_error"
  )
})
