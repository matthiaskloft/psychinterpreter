# ==============================================================================
# TEST: PARAMETER REGISTRY
# ==============================================================================
# Tests for the centralized parameter registry system (Phase 1 of
# parameter centralization plan).
#
# Coverage:
# - Registry structure completeness
# - get_param_default() retrieval
# - get_params_by_group() filtering
# - validate_param() single validation
# - validate_params() batch validation
# - get_registry_param_names() listing

test_that("PARAMETER_REGISTRY is complete with all required fields", {
  # All 24 parameters should be present
  expected_params <- c(
    # llm_args (8)
    "llm_provider", "llm_model", "system_prompt", "params",
    "word_limit", "interpretation_guidelines", "additional_info", "echo",
    # output_args (5)
    "format", "heading_level", "suppress_heading", "max_line_length", "silent",
    # interpretation_args FA (4)
    "cutoff", "n_emergency", "hide_low_loadings", "sort_loadings",
    # interpretation_args GM (7)
    "n_clusters", "covariance_type", "min_cluster_size", "separation_threshold",
    "profile_variables", "weight_by_uncertainty", "plot_type"
  )

  expect_equal(sort(names(PARAMETER_REGISTRY)), sort(expected_params))
  expect_length(PARAMETER_REGISTRY, 24)

  # Check each parameter has required fields
  for (param_name in names(PARAMETER_REGISTRY)) {
    param <- PARAMETER_REGISTRY[[param_name]]

    expect_true("default" %in% names(param),
                info = paste(param_name, "missing 'default' field"))
    expect_true("type" %in% names(param),
                info = paste(param_name, "missing 'type' field"))
    expect_true("range" %in% names(param),
                info = paste(param_name, "missing 'range' field"))
    expect_true("allowed_values" %in% names(param),
                info = paste(param_name, "missing 'allowed_values' field"))
    expect_true("config_group" %in% names(param),
                info = paste(param_name, "missing 'config_group' field"))
    expect_true("model_specific" %in% names(param),
                info = paste(param_name, "missing 'model_specific' field"))
    expect_true("required" %in% names(param),
                info = paste(param_name, "missing 'required' field"))
    expect_true("validation_fn" %in% names(param),
                info = paste(param_name, "missing 'validation_fn' field"))
    expect_true("description" %in% names(param),
                info = paste(param_name, "missing 'description' field"))

    # Validate field types
    expect_type(param$type, "character")
    expect_true(param$config_group %in% c("llm_args", "output_args", "interpretation_args"))
    expect_type(param$required, "logical")
    expect_type(param$validation_fn, "closure")
    expect_type(param$description, "character")
  }
})


test_that("PARAMETER_REGISTRY has correct config group assignments", {
  # llm_args (8 parameters)
  llm_params <- c("llm_provider", "llm_model", "system_prompt", "params",
                  "word_limit", "interpretation_guidelines", "additional_info", "echo")
  for (param in llm_params) {
    expect_equal(PARAMETER_REGISTRY[[param]]$config_group, "llm_args",
                 info = paste(param, "should be in llm_args"))
  }

  # output_args (5 parameters)
  output_params <- c("format", "heading_level", "suppress_heading",
                     "max_line_length", "silent")
  for (param in output_params) {
    expect_equal(PARAMETER_REGISTRY[[param]]$config_group, "output_args",
                 info = paste(param, "should be in output_args"))
  }

  # interpretation_args FA (4 parameters)
  fa_params <- c("cutoff", "n_emergency", "hide_low_loadings", "sort_loadings")
  for (param in fa_params) {
    expect_equal(PARAMETER_REGISTRY[[param]]$config_group, "interpretation_args",
                 info = paste(param, "should be in interpretation_args"))
    expect_equal(PARAMETER_REGISTRY[[param]]$model_specific, "fa",
                 info = paste(param, "should be FA-specific"))
  }

  # interpretation_args GM (7 parameters)
  gm_params <- c("n_clusters", "covariance_type", "min_cluster_size",
                 "separation_threshold", "profile_variables",
                 "weight_by_uncertainty", "plot_type")
  for (param in gm_params) {
    expect_equal(PARAMETER_REGISTRY[[param]]$config_group, "interpretation_args",
                 info = paste(param, "should be in interpretation_args"))
    expect_equal(PARAMETER_REGISTRY[[param]]$model_specific, "gm",
                 info = paste(param, "should be GM-specific"))
  }
})


test_that("PARAMETER_REGISTRY has correct default values", {
  # Critical defaults from plan
  expect_equal(PARAMETER_REGISTRY$word_limit$default, 150)
  expect_equal(PARAMETER_REGISTRY$max_line_length$default, 80L)

  # Other key defaults
  expect_equal(PARAMETER_REGISTRY$cutoff$default, 0.3)
  expect_equal(PARAMETER_REGISTRY$n_emergency$default, 2L)
  expect_equal(PARAMETER_REGISTRY$hide_low_loadings$default, FALSE)
  expect_equal(PARAMETER_REGISTRY$sort_loadings$default, TRUE)
  expect_equal(PARAMETER_REGISTRY$format$default, "cli")
  expect_equal(PARAMETER_REGISTRY$heading_level$default, 1L)
  expect_equal(PARAMETER_REGISTRY$suppress_heading$default, FALSE)
  expect_equal(PARAMETER_REGISTRY$silent$default, 0L)
  expect_equal(PARAMETER_REGISTRY$echo$default, "none")

  # NULL defaults
  expect_null(PARAMETER_REGISTRY$llm_provider$default)
  expect_null(PARAMETER_REGISTRY$llm_model$default)
  expect_null(PARAMETER_REGISTRY$system_prompt$default)
  expect_null(PARAMETER_REGISTRY$params$default)
  expect_null(PARAMETER_REGISTRY$interpretation_guidelines$default)
  expect_null(PARAMETER_REGISTRY$additional_info$default)
})


# ==============================================================================
# get_param_default() TESTS
# ==============================================================================

test_that("get_param_default() retrieves correct defaults", {
  expect_equal(get_param_default("word_limit"), 150)
  expect_equal(get_param_default("cutoff"), 0.3)
  expect_equal(get_param_default("max_line_length"), 80L)
  expect_equal(get_param_default("n_emergency"), 2L)
  expect_equal(get_param_default("format"), "cli")
  expect_equal(get_param_default("echo"), "none")
  expect_null(get_param_default("llm_model"))
})


test_that("get_param_default() errors on unknown parameter", {
  expect_error(
    get_param_default("nonexistent_param"),
    "Unknown parameter"
  )
})


# ==============================================================================
# get_params_by_group() TESTS
# ==============================================================================

test_that("get_params_by_group() filters by config group correctly", {
  # llm_args
  llm_params <- get_params_by_group("llm_args")
  expect_length(llm_params, 8)
  expect_true(all(c("llm_provider", "llm_model", "word_limit", "echo") %in% names(llm_params)))

  # output_args
  output_params <- get_params_by_group("output_args")
  expect_length(output_params, 5)
  expect_true(all(c("format", "heading_level", "silent", "max_line_length") %in% names(output_params)))

  # interpretation_args (all models: 4 FA + 7 GM = 11)
  interp_params <- get_params_by_group("interpretation_args")
  expect_length(interp_params, 11)
  expect_true(all(c("cutoff", "n_emergency", "hide_low_loadings", "sort_loadings") %in% names(interp_params)))
  expect_true(all(c("n_clusters", "min_cluster_size", "plot_type") %in% names(interp_params)))
})


test_that("get_params_by_group() filters by model type correctly", {
  # FA-specific parameters
  fa_params <- get_params_by_group("interpretation_args", model_type = "fa")
  expect_length(fa_params, 4)
  expect_true(all(c("cutoff", "n_emergency", "hide_low_loadings", "sort_loadings") %in% names(fa_params)))

  # All FA parameters should have model_specific = "fa"
  for (param in fa_params) {
    expect_equal(param$model_specific, "fa")
  }

  # GM-specific parameters
  gm_params <- get_params_by_group("interpretation_args", model_type = "gm")
  expect_length(gm_params, 7)
  expect_true(all(c("n_clusters", "covariance_type", "min_cluster_size",
                    "separation_threshold", "profile_variables",
                    "weight_by_uncertainty", "plot_type") %in% names(gm_params)))

  # All GM parameters should have model_specific = "gm"
  for (param in gm_params) {
    expect_equal(param$model_specific, "gm")
  }
})


test_that("get_params_by_group() warns when model_type used with non-interpretation_args", {
  expect_warning(
    get_params_by_group("llm_args", model_type = "fa"),
    "model_type filter only applies to interpretation_args"
  )
})


test_that("get_params_by_group() errors on invalid config group", {
  expect_error(
    get_params_by_group("invalid_group"),
    "Invalid config_group"
  )
})


# ==============================================================================
# validate_param() TESTS - VALID VALUES
# ==============================================================================

test_that("validate_param() accepts valid word_limit values", {
  expect_equal(validate_param("word_limit", 150), 150)
  expect_equal(validate_param("word_limit", 20), 20)
  expect_equal(validate_param("word_limit", 500), 500)
  expect_equal(validate_param("word_limit", 100), 100)
})


test_that("validate_param() accepts valid cutoff values", {
  expect_equal(validate_param("cutoff", 0.3), 0.3)
  expect_equal(validate_param("cutoff", 0), 0)
  expect_equal(validate_param("cutoff", 1), 1)
  expect_equal(validate_param("cutoff", 0.5), 0.5)
})


test_that("validate_param() accepts valid format values", {
  expect_equal(validate_param("format", "cli"), "cli")
  expect_equal(validate_param("format", "markdown"), "markdown")
})


test_that("validate_param() accepts valid echo values", {
  expect_equal(validate_param("echo", "none"), "none")
  expect_equal(validate_param("echo", "output"), "output")
  expect_equal(validate_param("echo", "all"), "all")
})


test_that("validate_param() accepts valid logical values", {
  expect_equal(validate_param("hide_low_loadings", TRUE), TRUE)
  expect_equal(validate_param("hide_low_loadings", FALSE), FALSE)
  expect_equal(validate_param("suppress_heading", TRUE), TRUE)
  expect_equal(validate_param("suppress_heading", FALSE), FALSE)
})


test_that("validate_param() accepts valid silent values", {
  expect_equal(validate_param("silent", 0), 0L)
  expect_equal(validate_param("silent", 1), 1L)
  expect_equal(validate_param("silent", 2), 2L)
  expect_equal(validate_param("silent", TRUE), 2L)  # Normalized
  expect_equal(validate_param("silent", FALSE), 0L)  # Normalized
})


test_that("validate_param() accepts NULL for optional parameters", {
  expect_null(validate_param("llm_model", NULL))
  expect_null(validate_param("system_prompt", NULL))
  expect_null(validate_param("params", NULL))
  expect_null(validate_param("additional_info", NULL))
})


# ==============================================================================
# validate_param() TESTS - INVALID VALUES
# ==============================================================================

test_that("validate_param() rejects invalid word_limit values", {
  expect_error(validate_param("word_limit", 10), "must be between 20 and 500")
  expect_error(validate_param("word_limit", 1000), "must be between 20 and 500")
  expect_error(validate_param("word_limit", -5), "must be between 20 and 500")
  expect_error(validate_param("word_limit", "150"), "must be a single numeric value")
})


test_that("validate_param() rejects invalid cutoff values", {
  expect_error(validate_param("cutoff", 1.5), "must be between 0 and 1")
  expect_error(validate_param("cutoff", -0.1), "must be between 0 and 1")
  expect_error(validate_param("cutoff", "0.3"), "must be a single numeric value")
})


test_that("validate_param() rejects invalid format values", {
  expect_error(validate_param("format", "html"), "must be either 'cli' or 'markdown'")
  expect_error(validate_param("format", "text"), "must be either 'cli' or 'markdown'")
})


test_that("validate_param() rejects invalid echo values", {
  expect_error(validate_param("echo", "verbose"), "must be one of: 'none', 'output', 'all'")
  expect_error(validate_param("echo", "debug"), "must be one of: 'none', 'output', 'all'")
})


test_that("validate_param() rejects invalid heading_level values", {
  expect_error(validate_param("heading_level", 0), "must be an integer between 1 and 6")
  expect_error(validate_param("heading_level", 7), "must be an integer between 1 and 6")
  expect_error(validate_param("heading_level", 3.5), "must be an integer between 1 and 6")
})


test_that("validate_param() rejects invalid max_line_length values", {
  expect_error(validate_param("max_line_length", 30), "must be between 40 and 300")
  expect_error(validate_param("max_line_length", 500), "must be between 40 and 300")
})


test_that("validate_param() rejects invalid silent values", {
  expect_error(validate_param("silent", 3), "must be 0, 1, or 2")
  expect_error(validate_param("silent", -1), "must be 0, 1, or 2")
})


test_that("validate_param() rejects invalid n_emergency values", {
  expect_error(validate_param("n_emergency", -1), "must be a non-negative integer")
  expect_error(validate_param("n_emergency", 2.5), "must be a non-negative integer")
})


test_that("validate_param() rejects invalid logical values", {
  expect_error(validate_param("hide_low_loadings", NA), "must be TRUE or FALSE")
  expect_error(validate_param("hide_low_loadings", "TRUE"), "must be TRUE or FALSE")
  expect_error(validate_param("suppress_heading", 1), "must be TRUE or FALSE")
})


test_that("validate_param() errors on unknown parameter", {
  expect_error(
    validate_param("unknown_param", 123),
    "Unknown parameter"
  )
})


# ==============================================================================
# validate_param() TESTS - throw_error = FALSE
# ==============================================================================

test_that("validate_param() returns result list when throw_error = FALSE", {
  # Valid parameter
  result <- validate_param("word_limit", 150, throw_error = FALSE)
  expect_type(result, "list")
  expect_true(result$valid)
  expect_null(result$message)

  # Invalid parameter
  result <- validate_param("word_limit", 1000, throw_error = FALSE)
  expect_type(result, "list")
  expect_false(result$valid)
  expect_type(result$message, "character")
})


test_that("validate_param() returns normalized value for silent conversion", {
  result <- validate_param("silent", TRUE, throw_error = FALSE)
  expect_true(result$valid)
  expect_equal(result$normalized, 2L)

  result <- validate_param("silent", FALSE, throw_error = FALSE)
  expect_true(result$valid)
  expect_equal(result$normalized, 0L)
})


# ==============================================================================
# validate_params() TESTS - BATCH VALIDATION
# ==============================================================================

test_that("validate_params() accepts valid parameter list", {
  params <- list(
    word_limit = 150,
    cutoff = 0.3,
    format = "cli",
    silent = 0
  )

  validated <- validate_params(params, throw_error = TRUE)
  expect_type(validated, "list")
  expect_equal(validated$word_limit, 150)
  expect_equal(validated$cutoff, 0.3)
  expect_equal(validated$format, "cli")
  expect_equal(validated$silent, 0L)
})


test_that("validate_params() normalizes silent in batch validation", {
  params <- list(
    word_limit = 150,
    silent = TRUE  # Should be normalized to 2L
  )

  validated <- validate_params(params, throw_error = TRUE)
  expect_equal(validated$silent, 2L)
})


test_that("validate_params() errors on first invalid parameter when throw_error = TRUE", {
  params <- list(
    word_limit = 1000,  # Invalid
    cutoff = 0.3
  )

  expect_error(
    validate_params(params, throw_error = TRUE),
    "Validation failed for parameter"
  )
})


test_that("validate_params() returns results when throw_error = FALSE", {
  # All valid
  params <- list(word_limit = 150, cutoff = 0.3)
  result <- validate_params(params, throw_error = FALSE)
  expect_true(result$valid)
  expect_length(result$results, 2)
  expect_length(result$invalid_params, 0)

  # Some invalid
  params <- list(word_limit = 1000, cutoff = 0.3)
  result <- validate_params(params, throw_error = FALSE)
  expect_false(result$valid)
  expect_length(result$results, 2)
  expect_equal(result$invalid_params, "word_limit")
})


test_that("validate_params() skips parameters not in registry", {
  # Custom/internal parameters should be skipped
  params <- list(
    word_limit = 150,
    custom_param = "value",  # Not in registry
    internal_flag = TRUE      # Not in registry
  )

  validated <- validate_params(params, throw_error = TRUE)
  expect_equal(validated$word_limit, 150)
  expect_equal(validated$custom_param, "value")  # Passed through unchanged
  expect_equal(validated$internal_flag, TRUE)     # Passed through unchanged
})


test_that("validate_params() errors on unnamed list", {
  expect_error(
    validate_params(list(150, 0.3)),
    "must be a named list"
  )
})


# ==============================================================================
# get_registry_param_names() TESTS
# ==============================================================================

test_that("get_registry_param_names() returns all parameter names", {
  all_names <- get_registry_param_names()
  expect_length(all_names, 24)
  expect_true(all(c("word_limit", "cutoff", "format", "echo") %in% all_names))
  expect_true(all(c("n_clusters", "plot_type") %in% all_names))
})


test_that("get_registry_param_names() filters by config group", {
  llm_names <- get_registry_param_names("llm_args")
  expect_length(llm_names, 8)
  expect_true(all(c("llm_provider", "word_limit", "echo") %in% llm_names))

  output_names <- get_registry_param_names("output_args")
  expect_length(output_names, 5)
  expect_true(all(c("format", "silent", "max_line_length") %in% output_names))

  interp_names <- get_registry_param_names("interpretation_args")
  expect_length(interp_names, 11)  # 4 FA + 7 GM
  expect_true(all(c("cutoff", "n_emergency") %in% interp_names))
  expect_true(all(c("n_clusters", "plot_type") %in% interp_names))
})


# ==============================================================================
# INTEGRATION TESTS
# ==============================================================================

test_that("Registry integrates with existing parameter validation patterns", {
  # Simulate config object construction pattern
  word_limit <- 200
  cutoff <- 0.4

  # Validate using registry
  validated_word_limit <- validate_param("word_limit", word_limit)
  validated_cutoff <- validate_param("cutoff", cutoff)

  expect_equal(validated_word_limit, 200)
  expect_equal(validated_cutoff, 0.4)
})


test_that("Registry handles all interpretation_args FA parameters", {
  fa_params <- list(
    cutoff = 0.4,
    n_emergency = 3,
    hide_low_loadings = TRUE,
    sort_loadings = FALSE
  )

  validated <- validate_params(fa_params, throw_error = TRUE)

  expect_equal(validated$cutoff, 0.4)
  expect_equal(validated$n_emergency, 3L)
  expect_equal(validated$hide_low_loadings, TRUE)
  expect_equal(validated$sort_loadings, FALSE)
})


test_that("Registry handles all llm_args parameters", {
  llm_params <- list(
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 150,
    echo = "none",
    system_prompt = NULL,
    params = NULL,
    interpretation_guidelines = NULL,
    additional_info = NULL
  )

  validated <- validate_params(llm_params, throw_error = TRUE)

  expect_equal(validated$llm_provider, "ollama")
  expect_equal(validated$llm_model, "gpt-oss:20b-cloud")
  expect_equal(validated$word_limit, 150)
  expect_equal(validated$echo, "none")
})


test_that("Registry handles all output_args parameters", {
  output_params <- list(
    format = "markdown",
    heading_level = 2,
    suppress_heading = TRUE,
    max_line_length = 100,
    silent = 1
  )

  validated <- validate_params(output_params, throw_error = TRUE)

  expect_equal(validated$format, "markdown")
  expect_equal(validated$heading_level, 2L)
  expect_equal(validated$suppress_heading, TRUE)
  expect_equal(validated$max_line_length, 100)
  expect_equal(validated$silent, 1L)
})


# ==============================================================================
# show_interpret_args() TESTS
# ==============================================================================

test_that("show_interpret_args() returns data.frame with correct structure", {
  # Capture output to suppress printing
  output <- capture.output(result <- show_interpret_args())

  expect_s3_class(result, "data.frame")
  expect_true(all(c("parameter", "default", "type", "range_or_values",
                    "config_group", "description") %in% names(result)))
})


test_that("show_interpret_args() with NULL shows common parameters only", {
  output <- capture.output(result <- show_interpret_args())

  # Should show llm_args + output_args only
  expect_true(all(result$config_group %in% c("llm_args", "output_args")))

  # Should have 8 llm_args + 5 output_args = 13 rows
  expect_equal(nrow(result), 13)

  # Should include key parameters
  expect_true("word_limit" %in% result$parameter)
  expect_true("format" %in% result$parameter)
  expect_true("silent" %in% result$parameter)

  # Should NOT include interpretation_args
  expect_false("cutoff" %in% result$parameter)
  expect_false("n_clusters" %in% result$parameter)
})


test_that("show_interpret_args() with NULL displays informative message", {
  output <- capture.output(result <- show_interpret_args())

  # Check that output contains the expected informative messages
  output_text <- paste(output, collapse = "\n")
  # Check that some output was generated (messages + parameter display)
  expect_true(length(output) > 0)
  expect_true(nchar(output_text) > 100)  # Should have substantive output
})


test_that("show_interpret_args('fa') shows FA-specific parameters", {
  output <- capture.output(result <- show_interpret_args("fa"))

  # Should include llm_args + output_args + FA interpretation_args
  expect_true(all(result$config_group %in% c("llm_args", "output_args", "interpretation_args")))

  # Should have 8 + 5 + 4 = 17 rows
  expect_equal(nrow(result), 17)

  # Should include FA-specific parameters
  expect_true("cutoff" %in% result$parameter)
  expect_true("n_emergency" %in% result$parameter)
  expect_true("hide_low_loadings" %in% result$parameter)
  expect_true("sort_loadings" %in% result$parameter)

  # Should NOT include GM-specific parameters
  expect_false("n_clusters" %in% result$parameter)
  expect_false("plot_type" %in% result$parameter)
})


test_that("show_interpret_args('gm') shows GM-specific parameters", {
  output <- capture.output(result <- show_interpret_args("gm"))

  # Should include llm_args + output_args + GM interpretation_args
  expect_true(all(result$config_group %in% c("llm_args", "output_args", "interpretation_args")))

  # Should have 8 + 5 + 7 = 20 rows
  expect_equal(nrow(result), 20)

  # Should include GM-specific parameters
  expect_true("n_clusters" %in% result$parameter)
  expect_true("covariance_type" %in% result$parameter)
  expect_true("min_cluster_size" %in% result$parameter)
  expect_true("separation_threshold" %in% result$parameter)
  expect_true("profile_variables" %in% result$parameter)
  expect_true("weight_by_uncertainty" %in% result$parameter)
  expect_true("plot_type" %in% result$parameter)

  # Should NOT include FA-specific parameters
  expect_false("cutoff" %in% result$parameter)
  expect_false("n_emergency" %in% result$parameter)
})


test_that("show_interpret_args() formats defaults correctly", {
  output <- capture.output(result <- show_interpret_args("fa"))

  # Check default formatting for different types
  word_limit_row <- result[result$parameter == "word_limit", ]
  expect_equal(word_limit_row$default, "150")

  format_row <- result[result$parameter == "format", ]
  expect_equal(format_row$default, "\"cli\"")

  cutoff_row <- result[result$parameter == "cutoff", ]
  expect_equal(cutoff_row$default, "0.3")

  hide_low_row <- result[result$parameter == "hide_low_loadings", ]
  expect_equal(hide_low_row$default, "FALSE")

  llm_model_row <- result[result$parameter == "llm_model", ]
  expect_equal(llm_model_row$default, "NULL")
})


test_that("show_interpret_args() formats ranges and allowed values correctly", {
  output <- capture.output(result <- show_interpret_args("fa"))

  # Check range formatting
  word_limit_row <- result[result$parameter == "word_limit", ]
  expect_equal(word_limit_row$range_or_values, "20-500")

  cutoff_row <- result[result$parameter == "cutoff", ]
  expect_equal(cutoff_row$range_or_values, "0-1")

  # Check allowed values formatting
  format_row <- result[result$parameter == "format", ]
  expect_equal(format_row$range_or_values, "\"cli\", \"markdown\"")

  echo_row <- result[result$parameter == "echo", ]
  expect_equal(echo_row$range_or_values, "\"none\", \"output\", \"all\"")

  # Check no range/values
  llm_model_row <- result[result$parameter == "llm_model", ]
  expect_equal(llm_model_row$range_or_values, "-")
})


test_that("show_interpret_args() errors on invalid analysis_type", {
  expect_error(
    show_interpret_args("invalid"),
    "Invalid.*analysis_type"
  )

  expect_error(
    show_interpret_args(123),
    "must be a single character string"
  )

  expect_error(
    show_interpret_args(c("fa", "gm")),
    "must be a single character string"
  )
})


test_that("show_interpret_args() warns on unimplemented model types", {
  expect_warning(
    output <- capture.output(result <- show_interpret_args("irt")),
    "not yet implemented"
  )

  expect_warning(
    output <- capture.output(result <- show_interpret_args("cdm")),
    "not yet implemented"
  )
})


test_that("show_interpret_args() produces CLI-formatted output", {
  output <- capture.output(result <- show_interpret_args("fa"))

  output_text <- paste(output, collapse = "\n")

  # Check that substantial output was generated
  expect_true(length(output) > 0)
  expect_true(nchar(output_text) > 100)

  # Check that parameter names appear in output
  expect_true(grepl("word_limit", output_text))
  expect_true(grepl("cutoff", output_text))
  expect_true(grepl("format", output_text))
})


test_that("show_interpret_args() returns invisible data.frame", {
  # Capture both output and return value
  output <- capture.output(result <- show_interpret_args())

  # The function should print output
  expect_true(length(output) > 0)

  # But also return a data.frame
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})
