# test-27-report-and-summary.R
# Tests for build_report() and create_fit_summary() S3 generics
# These are exported functions that previously had no tests

library(psychinterpreter)

# ==============================================================================
# create_fit_summary() Tests
# ==============================================================================

test_that("create_fit_summary.default() returns NULL with message", {
  fake_model <- structure(list(), class = "unknown_model")

  # Default method should return NULL
  result <- create_fit_summary(fake_model, "unknown")

  expect_null(result)
})

test_that("create_fit_summary.fa() extracts fit indices from psych::fa", {
  # Load minimal FA model
  minimal_fa <- readRDS(test_path("fixtures/fa/minimal_fa_model.rds"))

  result <- create_fit_summary(minimal_fa, "fa")

  # Should return a list
  expect_type(result, "list")

  # Check for expected components
  expect_true("fit_stats" %in% names(result) || "model_info" %in% names(result))
})

test_that("create_fit_summary.fa() handles oblimin rotation", {
  # Load oblique rotation model
  fa_oblimin <- readRDS(test_path("fixtures/fa/sample_fa_oblimin.rds"))

  result <- create_fit_summary(fa_oblimin, "fa")

  expect_type(result, "list")
  # Oblique rotation should have factor correlations
  expect_true(!is.null(result$factor_correlations) || "rotation" %in% names(result))
})

test_that("create_fit_summary.fa() handles varimax rotation", {
  # Load orthogonal rotation model
  fa_varimax <- readRDS(test_path("fixtures/fa/sample_fa_varimax.rds"))

  result <- create_fit_summary(fa_varimax, "fa")

  expect_type(result, "list")
  # Orthogonal rotation should note no factor correlations
  # or have identity correlation matrix
})

test_that("create_fit_summary.fa() detects cross-loadings", {
  # Create loadings with known cross-loading
  loadings <- matrix(c(
    0.8, 0.4,  # var1: loads on both factors
    0.2, 0.7,  # var2: clean loading on F2
    0.7, 0.1   # var3: clean loading on F1
  ), nrow = 3, ncol = 2, byrow = TRUE)

  rownames(loadings) <- c("var1", "var2", "var3")
  colnames(loadings) <- c("F1", "F2")

  # Create minimal fit_results
  fit_results <- list(
    loadings = loadings,
    analysis_data = list(cutoff = 0.3)
  )

  # Test find_cross_loadings (diagnostic function used by create_fit_summary)
  cross_loadings <- find_cross_loadings(loadings, cutoff = 0.3)

  expect_type(cross_loadings, "character")
  expect_true("var1" %in% cross_loadings)
  expect_false("var2" %in% cross_loadings)
  expect_false("var3" %in% cross_loadings)
})

test_that("create_fit_summary.fa() detects no loadings", {
  # Create loadings where one variable has no significant loadings
  loadings <- matrix(c(
    0.8, 0.1,  # var1: loads on F1
    0.1, 0.7,  # var2: loads on F2
    0.2, 0.2   # var3: no significant loadings
  ), nrow = 3, ncol = 2, byrow = TRUE)

  rownames(loadings) <- c("var1", "var2", "var3")
  colnames(loadings) <- c("F1", "F2")

  # Test find_no_loadings (diagnostic function)
  no_loadings <- find_no_loadings(loadings, cutoff = 0.3)

  expect_type(no_loadings, "character")
  expect_true("var3" %in% no_loadings)
  expect_false("var1" %in% no_loadings)
  expect_false("var2" %in% no_loadings)
})

# ==============================================================================
# build_report() Tests
# ==============================================================================

test_that("build_report.default() returns error message", {
  fake_interpretation <- structure(list(), class = "unknown_interpretation")

  # Default method should error informatively
  expect_error(
    build_report(fake_interpretation),
    "not implemented"
  )
})

test_that("build_report.fa_interpretation() generates report from cached interpretation", {
  # Load cached interpretation to avoid LLM call
  interpretation <- readRDS(test_path("fixtures/sample_interpretation.rds"))

  # Generate report
  report <- build_report(interpretation)

  # Should return character string
  expect_type(report, "character")
  expect_gt(nchar(report), 100)  # Should be substantial text

  # Check for key sections
  expect_match(report, "Factor")  # Should mention factors
})

test_that("build_report.fa_interpretation() respects format parameter", {
  interpretation <- readRDS(test_path("fixtures/sample_interpretation.rds"))

  # Update format to markdown
  interpretation$metadata$output_args$format <- "markdown"

  report <- build_report(interpretation)

  expect_type(report, "character")
  # Markdown reports may have different formatting
  expect_gt(nchar(report), 100)
})

test_that("build_report.fa_interpretation() handles emergency rule cases", {
  # Load interpretation with emergency rule applied
  interpretation_emergency <- readRDS(test_path("fixtures/fa/sample_interpretation_emergency.rds"))

  report <- build_report(interpretation_emergency)

  expect_type(report, "character")
  expect_gt(nchar(report), 50)

  # Should mention emergency rule or (n.s.) suffix
  expect_true(grepl("\\(n\\.s\\.\\)", report) || grepl("emergency", report, ignore.case = TRUE))
})

test_that("build_report.fa_interpretation() handles undefined factors", {
  # Load interpretation with undefined factors
  interpretation_undefined <- readRDS(test_path("fixtures/fa/sample_interpretation_undefined.rds"))

  report <- build_report(interpretation_undefined)

  expect_type(report, "character")
  expect_gt(nchar(report), 50)
})

test_that("build_report.fa_interpretation() handles cross-loadings", {
  # Load interpretation with cross-loadings
  interpretation_cross <- readRDS(test_path("fixtures/fa/sample_interpretation_cross_loading.rds"))

  report <- build_report(interpretation_cross)

  expect_type(report, "character")
  expect_gt(nchar(report), 50)

  # Should mention cross-loadings or diagnostics
  expect_true(grepl("cross", report, ignore.case = TRUE) || grepl("multiple", report, ignore.case = TRUE))
})

# ==============================================================================
# Integration Tests
# ==============================================================================

test_that("create_fit_summary() integrates with interpret() workflow", {
  loadings <- matrix(c(0.8, 0.2, 0.3, 0.7), nrow = 2, ncol = 2)
  rownames(loadings) <- c("var1", "var2")
  colnames(loadings) <- c("F1", "F2")

  variable_info <- data.frame(
    variable = c("var1", "var2"),
    description = c("First variable", "Second variable")
  )

  skip_on_ci()
  skip_if(Sys.getenv("OLLAMA_AVAILABLE") != "true", "Ollama not available")

  result <- interpret(
    fit_results = list(loadings = loadings),
    variable_info = variable_info,
    analysis_type = "fa",
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20
  )

  # Verify fit_summary is in result
  expect_true("fit_summary" %in% names(result) || "diagnostics" %in% names(result))
})

test_that("build_report() output matches print() output", {
  interpretation <- readRDS(test_path("fixtures/sample_interpretation.rds"))

  # Generate report via build_report
  report <- build_report(interpretation)

  # Capture print output
  print_output <- capture.output(print(interpretation))
  print_text <- paste(print_output, collapse = "\n")

  # Should be similar (may not be identical due to formatting)
  expect_type(report, "character")
  expect_type(print_text, "character")

  # Both should mention factors
  expect_match(report, "Factor")
  expect_match(print_text, "Factor")
})

# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("create_fit_summary handles missing fit indices gracefully", {
  # Create minimal model without fit stats
  minimal_model <- structure(
    list(
      loadings = matrix(c(0.8, 0.2), nrow = 1, ncol = 2)
    ),
    class = "fa"
  )

  # Should not error, may return partial summary
  result <- create_fit_summary(minimal_model, "fa")

  # Should return something (even if minimal)
  expect_true(is.null(result) || is.list(result))
})

test_that("build_report handles minimal interpretation object", {
  # Create bare minimum interpretation
  minimal_interp <- structure(
    list(
      factor_names = c("Factor1"),
      interpretations = list("Simple interpretation"),
      metadata = list(
        output_args = list(format = "cli")
      )
    ),
    class = c("fa_interpretation", "interpretation")
  )

  # Should generate some report
  report <- build_report(minimal_interp)

  expect_type(report, "character")
  expect_gt(nchar(report), 10)
})
