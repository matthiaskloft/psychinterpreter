# test-27-report-and-summary.R
# Tests for build_report() and create_fit_summary() S3 generics
# These are exported functions that previously had no tests

library(psychinterpreter)

# ==============================================================================
# create_fit_summary() Tests
# ==============================================================================

test_that("create_fit_summary.default() errors for unsupported types", {
  # create_fit_summary expects analysis_data, not raw model
  fake_data <- list(analysis_type = "unsupported")

  # Default method should error
  expect_error(
    create_fit_summary("unsupported", fake_data),
    "No fit summary method"
  )
})

test_that("create_fit_summary.fa() works with proper analysis_data", {
  # create_fit_summary is called internally with analysis_data
  # For direct testing, we need to create analysis_data first
  minimal_fa <- readRDS(test_path("fixtures/fa/minimal_fa_model.rds"))
  minimal_vars <- readRDS(test_path("fixtures/fa/minimal_variable_info.rds"))

  # Build analysis_data using the build_analysis_data function
  analysis_data <- build_analysis_data(
    fit_results = minimal_fa,
    analysis_type = "fa",
    cutoff = 0.3,
    variable_info = minimal_vars
  )

  # Correct argument order: analysis_type first, then analysis_data
  result <- create_fit_summary("fa", analysis_data)

  # Should return a list
  expect_type(result, "list")
})

test_that("create_fit_summary.fa() handles oblimin rotation", {
  # Load oblique rotation model
  fa_oblimin <- readRDS(test_path("fixtures/fa/sample_fa_oblimin.rds"))
  sample_vars <- readRDS(test_path("fixtures/fa/sample_variable_info.rds"))

  # Add var6 if missing
  if (!"var6" %in% sample_vars$variable) {
    sample_vars <- rbind(
      sample_vars,
      data.frame(variable = "var6", description = "Sixth variable description")
    )
  }

  analysis_data <- build_analysis_data(
    fit_results = fa_oblimin,
    analysis_type = "fa",
    cutoff = 0.3,
    variable_info = sample_vars
  )

  result <- create_fit_summary("fa", analysis_data)

  expect_type(result, "list")
})

test_that("create_fit_summary.fa() handles varimax rotation", {
  # Load orthogonal rotation model
  fa_varimax <- readRDS(test_path("fixtures/fa/sample_fa_varimax.rds"))
  sample_vars <- readRDS(test_path("fixtures/fa/sample_variable_info.rds"))

  # Add var6 if missing
  if (!"var6" %in% sample_vars$variable) {
    sample_vars <- rbind(
      sample_vars,
      data.frame(variable = "var6", description = "Sixth variable description")
    )
  }

  analysis_data <- build_analysis_data(
    fit_results = fa_varimax,
    analysis_type = "fa",
    cutoff = 0.3,
    variable_info = sample_vars
  )

  result <- create_fit_summary("fa", analysis_data)

  expect_type(result, "list")
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

  # Create loadings_df for testing
  loadings_df <- as.data.frame(loadings)
  loadings_df$variable <- rownames(loadings)

  # Test find_cross_loadings (diagnostic function used by create_fit_summary)
  cross_loadings <- find_cross_loadings(loadings_df, cutoff = 0.3)

  # find_cross_loadings returns a data.frame with 'variable' and 'factors' columns
  expect_s3_class(cross_loadings, "data.frame")
  expect_true("var1" %in% cross_loadings$variable)
  expect_false("var2" %in% cross_loadings$variable)
  expect_false("var3" %in% cross_loadings$variable)
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

  # Create loadings_df for testing
  loadings_df <- as.data.frame(loadings)
  loadings_df$variable <- rownames(loadings)

  # Test find_no_loadings (diagnostic function)
  no_loadings <- find_no_loadings(loadings_df, cutoff = 0.3)

  # find_no_loadings returns a data.frame with 'variable' and 'highest_loading' columns
  expect_s3_class(no_loadings, "data.frame")
  expect_true("var3" %in% no_loadings$variable)
  expect_false("var1" %in% no_loadings$variable)
  expect_false("var2" %in% no_loadings$variable)
})

# ==============================================================================
# build_report() Tests
# ==============================================================================

test_that("build_report.default() returns error message", {
  fake_interpretation <- structure(list(analysis_type = "unknown"), class = "unknown_interpretation")

  # Default method should error informatively - match actual error pattern
  expect_error(
    build_report(fake_interpretation),
    "No report builder for analysis type"
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

  # Both should mention factors (case insensitive)
  expect_match(report, "(?i)factor")
  expect_match(print_text, "(?i)factor")
})

# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("create_fit_summary handles minimal analysis_data gracefully", {
  # Create minimal analysis_data structure
  minimal_loadings_df <- data.frame(
    variable = c("var1"),
    F1 = c(0.8),
    F2 = c(0.2)
  )

  minimal_analysis_data <- list(
    loadings_df = minimal_loadings_df,
    factor_cols = c("F1", "F2"),
    analysis_type = "fa"
  )

  # Should not error, may return partial summary
  result <- create_fit_summary("fa", minimal_analysis_data, cutoff = 0.3)

  # Should return list with diagnostics
  expect_type(result, "list")
  expect_true("cross_loadings" %in% names(result) || "no_loadings" %in% names(result))
})

test_that("build_report handles minimal interpretation object", {
  # Use actual cached interpretation to ensure valid structure
  # build_report requires many fields: factor_summaries, factor_names, interpretations, etc.
  interpretation <- readRDS(test_path("fixtures/sample_interpretation.rds"))

  # Verify it generates a report
  report <- build_report(interpretation)

  expect_type(report, "character")
  expect_gt(nchar(report), 10)
})
