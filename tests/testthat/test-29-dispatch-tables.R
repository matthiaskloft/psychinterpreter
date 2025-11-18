# Test dispatch table system in shared_config.R

# =============================================================================
# Dispatch Table Helper Tests
# =============================================================================

test_that(".dispatch_lookup returns correct value when key exists", {
  test_table <- list(
    fa = "Factor Analysis",
    gm = "Gaussian Mixture"
  )

  result <- psychinterpreter:::.dispatch_lookup(test_table, "fa")
  expect_equal(result, "Factor Analysis")
})

test_that(".dispatch_lookup returns default when key doesn't exist", {
  test_table <- list(fa = "Factor Analysis")

  result <- psychinterpreter:::.dispatch_lookup(test_table, "unknown", default = "Default Value")
  expect_equal(result, "Default Value")
})

test_that(".dispatch_lookup throws error when no default and error_message provided", {
  test_table <- list(fa = "Factor Analysis")

  expect_error(
    psychinterpreter:::.dispatch_lookup(test_table, "unknown", error_message = "Key not found"),
    "Key not found"
  )
})

test_that(".dispatch_lookup returns NULL when key missing and no default/error", {
  test_table <- list(fa = "Factor Analysis")

  result <- psychinterpreter:::.dispatch_lookup(test_table, "unknown")
  expect_null(result)
})

# =============================================================================
# Analysis Type Display Name Tests
# =============================================================================

test_that(".get_analysis_type_display_name returns correct names for known types", {
  expect_equal(
    psychinterpreter:::.get_analysis_type_display_name("fa"),
    "Factor Analysis"
  )

  expect_equal(
    psychinterpreter:::.get_analysis_type_display_name("gm"),
    "Gaussian Mixture"
  )

  expect_equal(
    psychinterpreter:::.get_analysis_type_display_name("irt"),
    "Item Response Theory"
  )

  expect_equal(
    psychinterpreter:::.get_analysis_type_display_name("cdm"),
    "Cognitive Diagnosis"
  )
})

test_that(".get_analysis_type_display_name returns input for unknown types", {
  # Should return the input as-is if not found
  expect_equal(
    psychinterpreter:::.get_analysis_type_display_name("unknown"),
    "unknown"
  )
})

# =============================================================================
# Valid Parameters Dispatch Tests
# =============================================================================

test_that(".get_valid_interpretation_params returns correct params for fa", {
  valid_params <- psychinterpreter:::.get_valid_interpretation_params("fa")

  expect_type(valid_params, "character")
  expect_true("cutoff" %in% valid_params)
  expect_true("n_emergency" %in% valid_params)
  expect_true("hide_low_loadings" %in% valid_params)
  expect_true("sort_loadings" %in% valid_params)
  expect_length(valid_params, 4)
})

test_that(".get_valid_interpretation_params returns empty for unimplemented types", {
  # IRT and CDM don't have parameters defined yet
  expect_equal(
    psychinterpreter:::.get_valid_interpretation_params("irt"),
    character(0)
  )

  expect_equal(
    psychinterpreter:::.get_valid_interpretation_params("cdm"),
    character(0)
  )
})

test_that(".get_valid_interpretation_params returns empty for unknown types", {
  expect_equal(
    psychinterpreter:::.get_valid_interpretation_params("unknown"),
    character(0)
  )
})

# =============================================================================
# Dispatch Table Integration Tests
# =============================================================================

test_that("interpretation_args uses dispatch table correctly for fa", {
  # This tests that the dispatch table is being used in interpretation_args()
  config <- interpretation_args(
    analysis_type = "fa",
    cutoff = 0.4
  )

  expect_s3_class(config, "interpretation_args")
  expect_equal(config$analysis_type, "fa")
  expect_equal(config$cutoff, 0.4)
})

test_that("interpretation_args dispatch table errors gracefully for unimplemented types", {
  # IRT is in the valid types but not yet implemented in dispatch table
  expect_error(
    interpretation_args(analysis_type = "irt"),
    "not yet implemented"
  )
})

test_that("print.interpretation_args uses dispatch table for display names", {
  config <- interpretation_args(analysis_type = "fa")

  # Capture print output (cli uses messages, not regular output)
  output <- capture.output(print(config), type = "message")

  # Should contain the display name from dispatch table
  # Output format: "── Factor Analysis Interpretation Configuration ──"
  expect_true(any(grepl("Factor Analysis", output)))
})

test_that("print.interpretation_args uses dispatch table for valid params", {
  config <- interpretation_args(
    analysis_type = "fa",
    cutoff = 0.35,
    n_emergency = 3
  )

  # Capture print output (cli uses messages, not regular output)
  output <- capture.output(print(config), type = "message")

  # Should show the valid params that were set
  # Output format: "• Cutoff: 0.35" and "• Emergency rule: Use top 3 loadings"
  expect_true(any(grepl("Cutoff: 0.35", output, fixed = TRUE)))
  expect_true(any(grepl("Use top 3 loadings", output, fixed = TRUE)))
})

test_that("build_interpretation_args uses dispatch table for valid params filtering", {
  # This tests the refactored if/else chain in build_interpretation_args
  # When we pass FA-specific params, they should be recognized via dispatch table

  result <- psychinterpreter:::build_interpretation_args(
    interpretation_args = NULL,
    analysis_type = "fa",
    cutoff = 0.35,
    n_emergency = 3,
    hide_low_loadings = TRUE
  )

  expect_s3_class(result, "interpretation_args")
  expect_equal(result$cutoff, 0.35)
  expect_equal(result$n_emergency, 3L)
  expect_equal(result$hide_low_loadings, TRUE)
})

test_that("build_interpretation_args ignores invalid params via dispatch table", {
  # Should filter out params that aren't valid for FA according to dispatch table
  result <- psychinterpreter:::build_interpretation_args(
    interpretation_args = NULL,
    analysis_type = "fa",
    cutoff = 0.35,
    invalid_param = "should be ignored"
  )

  expect_s3_class(result, "interpretation_args")
  expect_equal(result$cutoff, 0.35)
  expect_false("invalid_param" %in% names(result))
})

test_that("build_interpretation_args returns NULL for unimplemented types with params", {
  # GM has no valid params yet, so should return NULL even if params provided
  result <- psychinterpreter:::build_interpretation_args(
    interpretation_args = NULL,
    analysis_type = "gm",
    some_param = "value"
  )

  expect_null(result)
})

# =============================================================================
# Dispatch Table Extensibility Tests
# =============================================================================

test_that("dispatch tables are defined and accessible", {
  # Check that all dispatch tables exist
  expect_true(exists(".INTERPRETATION_ARGS_DISPATCH",
                     where = asNamespace("psychinterpreter")))
  expect_true(exists(".ANALYSIS_TYPE_DISPLAY_NAMES",
                     where = asNamespace("psychinterpreter")))
  expect_true(exists(".VALID_INTERPRETATION_PARAMS",
                     where = asNamespace("psychinterpreter")))
})

test_that("dispatch tables have expected structure", {
  dispatch <- get(".INTERPRETATION_ARGS_DISPATCH",
                  envir = asNamespace("psychinterpreter"))
  display <- get(".ANALYSIS_TYPE_DISPLAY_NAMES",
                 envir = asNamespace("psychinterpreter"))
  valid <- get(".VALID_INTERPRETATION_PARAMS",
               envir = asNamespace("psychinterpreter"))

  # All should be lists
  expect_type(dispatch, "list")
  expect_type(display, "character")
  expect_type(valid, "list")

  # Dispatch table should have function entries
  expect_true(all(sapply(dispatch, is.function)))

  # Display names should be character strings
  expect_true(all(sapply(display, is.character)))

  # Valid params should be character vectors
  expect_true(all(sapply(valid, is.character)))
})

test_that("all analysis types are consistently represented across dispatch tables", {
  dispatch <- get(".INTERPRETATION_ARGS_DISPATCH",
                  envir = asNamespace("psychinterpreter"))
  display <- get(".ANALYSIS_TYPE_DISPLAY_NAMES",
                 envir = asNamespace("psychinterpreter"))
  valid <- get(".VALID_INTERPRETATION_PARAMS",
               envir = asNamespace("psychinterpreter"))

  # All tables should have entries for the same analysis types
  display_types <- names(display)
  valid_types <- names(valid)

  # Display and valid should have same types
  expect_setequal(display_types, valid_types)

  # Expected types
  expected_types <- c("fa", "gm", "irt", "cdm")
  expect_setequal(display_types, expected_types)

  # Dispatch table should have at least "fa" (others may be added later)
  expect_true("fa" %in% names(dispatch))
})
