# test-24-s3-methods-direct.R
# Tests for S3 method dispatch infrastructure
# Verifies that S3 generics correctly dispatch to the appropriate methods

library(psychinterpreter)

# ==============================================================================
# S3 Generic Existence and Registration
# ==============================================================================

test_that("Core S3 generics are exported and callable", {
  # Public API generics
  expect_true(exists("interpret"))
  expect_true(exists("chat_session"))
  expect_true(exists("interpret_model"))

  # Data extraction generics
  expect_true(exists("build_analysis_data"))
  expect_true(exists("validate_list_structure"))
  expect_true(exists("extract_model_parameters"))
  expect_true(exists("validate_model_requirements"))

  # Prompt building generics
  expect_true(exists("build_system_prompt"))
  expect_true(exists("build_main_prompt"))

  # JSON parsing generics
  expect_true(exists("validate_parsed_result"))
  expect_true(exists("extract_by_pattern"))
  expect_true(exists("create_default_result"))

  # Report/output generics
  expect_true(exists("build_report"))
  expect_true(exists("create_fit_summary"))
  expect_true(exists("export_interpretation"))
})

# ==============================================================================
# build_analysis_data() Dispatch Tests
# ==============================================================================

test_that("build_analysis_data() dispatches correctly for psych::fa objects", {
  # Load FA model fixture
  minimal_fa <- readRDS(test_path("fixtures/fa/minimal_fa_model.rds"))

  # Should dispatch to build_analysis_data.fa method
  result <- build_analysis_data(
    fit_results = minimal_fa,
    analysis_type = "fa",
    cutoff = 0.3
  )

  expect_type(result, "list")
  expect_true("loadings" %in% names(result))
  expect_true("analysis_type" %in% names(result))
  expect_equal(result$analysis_type, "fa")
})

test_that("build_analysis_data() dispatches correctly for matrix input", {
  # Create loadings matrix
  loadings <- matrix(c(0.8, 0.2, 0.3, 0.7), nrow = 2, ncol = 2)
  rownames(loadings) <- c("var1", "var2")
  colnames(loadings) <- c("F1", "F2")

  # Should dispatch to build_analysis_data.matrix method
  result <- build_analysis_data(
    fit_results = loadings,
    analysis_type = "fa",
    cutoff = 0.3
  )

  expect_type(result, "list")
  expect_true("loadings" %in% names(result))
  expect_equal(nrow(result$loadings), 2)
  expect_equal(ncol(result$loadings), 2)
})

test_that("build_analysis_data() dispatches correctly for list input", {
  loadings <- matrix(c(0.8, 0.2, 0.3, 0.7), nrow = 2, ncol = 2)
  rownames(loadings) <- c("var1", "var2")
  colnames(loadings) <- c("F1", "F2")

  # Should dispatch to build_analysis_data.list method
  result <- build_analysis_data(
    fit_results = list(loadings = loadings),
    analysis_type = "fa",
    cutoff = 0.3
  )

  expect_type(result, "list")
  expect_true("loadings" %in% names(result))
})

# ==============================================================================
# validate_list_structure() Dispatch Tests
# ==============================================================================

test_that("validate_list_structure() dispatches to FA method", {
  loadings <- matrix(c(0.8, 0.2), nrow = 1, ncol = 2)

  # Should dispatch to validate_list_structure.fa
  expect_invisible(
    validate_list_structure(list(loadings = loadings), "fa")
  )
})

test_that("validate_list_structure.fa() validates loadings presence", {
  # Missing loadings should error
  expect_error(
    validate_list_structure(list(), "fa"),
    "loadings.*required"
  )
})

test_that("validate_list_structure() default method passes", {
  # Unknown analysis type should pass with default method
  expect_invisible(
    validate_list_structure(list(data = "something"), "unknown")
  )
})

# ==============================================================================
# Parameter Extraction Dispatch Tests
# ==============================================================================

test_that("extract_model_parameters() dispatches to FA method", {
  analysis_type <- structure("fa", class = "fa")
  interp_args <- list(cutoff = 0.4, n_emergency = 2)

  # Should dispatch to extract_model_parameters.fa
  params <- extract_model_parameters(analysis_type, interp_args)

  expect_type(params, "list")
  expect_equal(params$cutoff, 0.4)
  expect_equal(params$n_emergency, 2)
})

test_that("extract_model_parameters() dispatches to default for unknown types", {
  analysis_type <- structure("unknown", class = "unknown")

  # Should dispatch to .default method
  params <- extract_model_parameters(analysis_type, list(param = 1))

  expect_type(params, "list")
  expect_length(params, 0)  # Default returns empty list
})

# ==============================================================================
# validate_model_requirements() Dispatch Tests
# ==============================================================================

test_that("validate_model_requirements() dispatches to FA method", {
  analysis_type <- structure("fa", class = "fa")
  variable_info <- data.frame(
    variable = c("v1"),
    description = c("Variable 1")
  )

  # Should dispatch to validate_model_requirements.fa
  expect_invisible(
    validate_model_requirements(analysis_type, variable_info = variable_info)
  )
})

test_that("validate_model_requirements.fa() enforces variable_info requirement", {
  analysis_type <- structure("fa", class = "fa")

  # Should error when variable_info is NULL
  expect_error(
    validate_model_requirements(analysis_type, variable_info = NULL),
    "variable_info.*required"
  )
})

# ==============================================================================
# create_fit_summary() Dispatch Tests
# ==============================================================================

test_that("create_fit_summary() dispatches to FA method", {
  minimal_fa <- readRDS(test_path("fixtures/fa/minimal_fa_model.rds"))

  # Should dispatch to create_fit_summary.fa
  summary <- create_fit_summary(minimal_fa, "fa")

  expect_type(summary, "list")
})

test_that("create_fit_summary() uses default method for unknown types", {
  fake_model <- structure(list(), class = "unknown")

  # Should dispatch to .default method (returns NULL)
  summary <- create_fit_summary(fake_model, "unknown")

  expect_null(summary)
})

# ==============================================================================
# build_report() Dispatch Tests
# ==============================================================================

test_that("build_report() dispatches to FA interpretation method", {
  interpretation <- readRDS(test_path("fixtures/sample_interpretation.rds"))

  # Should dispatch to build_report.fa_interpretation
  report <- build_report(interpretation)

  expect_type(report, "character")
  expect_gt(nchar(report), 50)
})

test_that("build_report() errors for unknown interpretation types", {
  fake_interp <- structure(list(), class = "unknown_interpretation")

  # Should dispatch to .default method and error
  expect_error(
    build_report(fake_interp),
    "not implemented"
  )
})

# ==============================================================================
# Integration: Full Workflow Dispatch Chain
# ==============================================================================

test_that("interpret() uses S3 dispatch correctly for different input types", {
  # Create simple loadings matrix
  loadings <- matrix(c(0.8, 0.2, 0.3, 0.7), nrow = 2, ncol = 2)
  rownames(loadings) <- c("var1", "var2")
  colnames(loadings) <- c("F1", "F2")

  variable_info <- data.frame(
    variable = c("var1", "var2"),
    description = c("First variable", "Second variable")
  )

  # Test that structured list works (tests build_analysis_data dispatch)
  skip_on_ci()  # Skip on CI since it needs LLM
  skip_if(Sys.getenv("OLLAMA_AVAILABLE") != "true", "Ollama not available")

  result <- interpret(
    fit_results = list(loadings = loadings),
    variable_info = variable_info,
    analysis_type = "fa",
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20  # Minimal for testing
  )

  # Verify result structure and that dispatch chain worked
  expect_s3_class(result, "fa_interpretation")
  expect_true("factor_names" %in% names(result))
  expect_true("interpretations" %in% names(result))
})

# ==============================================================================
# Method Selection Logic Tests
# ==============================================================================

test_that("S3 dispatch selects correct method based on class hierarchy", {
  # Create object with multiple classes
  loadings <- matrix(c(0.8, 0.2), nrow = 1, ncol = 2)
  multi_class_obj <- structure(
    list(loadings = loadings),
    class = c("custom", "list")
  )

  # Should dispatch to build_analysis_data.list (second in hierarchy)
  result <- build_analysis_data(
    fit_results = multi_class_obj,
    analysis_type = "fa",
    cutoff = 0.3
  )

  expect_type(result, "list")
  expect_true("loadings" %in% names(result))
})

test_that("Method dispatch handles inheritance correctly", {
  # fa_interpretation inherits from interpretation
  interpretation <- readRDS(test_path("fixtures/sample_interpretation.rds"))

  # Verify class hierarchy
  expect_s3_class(interpretation, "fa_interpretation")
  expect_s3_class(interpretation, "interpretation")

  # Should dispatch to fa_interpretation method first
  report <- build_report(interpretation)
  expect_type(report, "character")
})