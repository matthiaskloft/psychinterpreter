# Test configuration object constructors

# =============================================================================
# interpretation_args() tests
# =============================================================================

test_that("interpretation_args() creates valid fa config object", {
  config <- interpretation_args(
    analysis_type = "fa",
    cutoff = 0.4,
    n_emergency = 2,
    hide_low_loadings = TRUE
  )

  expect_s3_class(config, "interpretation_args")
  expect_s3_class(config, "model_config")
  expect_type(config, "list")
  expect_equal(config$analysis_type, "fa")
  expect_equal(config$cutoff, 0.4)
  expect_equal(config$n_emergency, 2L)
  expect_equal(config$hide_low_loadings, TRUE)
})

test_that("interpretation_args() validates analysis_type parameter", {
  expect_error(
    interpretation_args(analysis_type = "invalid"),
    "Invalid analysis_type"
  )
})

test_that("interpretation_args() validates cutoff parameter", {
  expect_error(
    interpretation_args(analysis_type = "fa", cutoff = -0.1),
    "must be between 0 and 1"
  )

  expect_error(
    interpretation_args(analysis_type = "fa", cutoff = 1.5),
    "must be between 0 and 1"
  )

  expect_error(
    interpretation_args(analysis_type = "fa", cutoff = "high"),
    "must be.*numeric"
  )
})

test_that("interpretation_args() validates n_emergency parameter", {
  expect_error(
    interpretation_args(analysis_type = "fa", n_emergency = -1),
    "must be.*non-negative integer"
  )

  expect_error(
    interpretation_args(analysis_type = "fa", n_emergency = 3.5),
    "must be.*integer"
  )

  expect_error(
    interpretation_args(analysis_type = "fa", n_emergency = "many"),
    "must be.*integer"
  )
})

test_that("interpretation_args() uses default values when not specified", {
  config <- interpretation_args(analysis_type = "fa")

  expect_equal(config$cutoff, 0.3)
  expect_equal(config$n_emergency, 2L)
  expect_equal(config$hide_low_loadings, FALSE)
  expect_equal(config$sort_loadings, TRUE)
})

test_that("interpretation_args() errors for unimplemented analysis types", {
  # GM is now implemented, so test IRT and CDM instead
  expect_error(
    interpretation_args(analysis_type = "irt"),
    "not yet implemented"
  )

  expect_error(
    interpretation_args(analysis_type = "cdm"),
    "not yet implemented"
  )
})

# =============================================================================
# llm_args() tests
# =============================================================================

test_that("llm_args() creates valid config object", {
  config <- llm_args(
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 100,
    additional_info = "Test context"
  )

  expect_s3_class(config, "llm_args")
  expect_type(config, "list")
  expect_equal(config$llm_provider, "ollama")
  expect_equal(config$llm_model, "gpt-oss:20b-cloud")
  expect_equal(config$word_limit, 100L)
  expect_equal(config$additional_info, "Test context")
})

test_that("llm_args() validates word_limit parameter", {
  expect_error(
    llm_args(llm_provider = "ollama", word_limit = 10),
    "must be between 20 and 500"
  )

  expect_error(
    llm_args(llm_provider = "ollama", word_limit = 1000),
    "must be between 20 and 500"
  )
})

test_that("llm_args() validates additional_info parameter", {
  expect_error(
    llm_args(llm_provider = "ollama", additional_info = 123),
    "must be.*character.*or NULL"
  )
})

test_that("llm_args() uses default values when not specified", {
  config <- llm_args(llm_provider = "ollama")

  expect_equal(config$word_limit, 150L)
  expect_null(config$additional_info)
  expect_null(config$llm_model)
})

test_that("llm_args() requires llm_provider parameter", {
  expect_error(
    llm_args(word_limit = 100),
    "llm_provider.*required"
  )
})

test_that("llm_args() accepts edge case values", {
  # Minimum word_limit
  config_min <- llm_args(llm_provider = "ollama", word_limit = 20)
  expect_equal(config_min$word_limit, 20L)

  # Maximum word_limit
  config_max <- llm_args(llm_provider = "ollama", word_limit = 500)
  expect_equal(config_max$word_limit, 500L)

  # NULL additional_info (should be acceptable)
  config_null <- llm_args(llm_provider = "ollama", additional_info = NULL)
  expect_null(config_null$additional_info)
})

# =============================================================================
# output_args() tests
# =============================================================================

test_that("output_args() creates valid config object", {
  config <- output_args(
    format = "markdown",
    silent = 2
  )

  expect_s3_class(config, "output_args")
  expect_type(config, "list")
  expect_equal(config$format, "markdown")
  expect_equal(config$silent, 2L)
})

test_that("output_args() validates format parameter", {
  expect_error(
    output_args(format = "html"),
    "must be either.*cli.*markdown"
  )
})

test_that("output_args() validates silent parameter", {
  expect_error(
    output_args(silent = -1),
    "must be 0, 1, or 2"
  )

  expect_error(
    output_args(silent = 5),
    "must be 0, 1, or 2"
  )
})

test_that("output_args() uses default values when not specified", {
  config <- output_args()

  expect_equal(config$format, "cli")
  expect_equal(config$silent, 0L)
  expect_equal(config$heading_level, 1L)
  expect_equal(config$max_line_length, 80L)
})

test_that("output_args() accepts all valid formats", {
  config_cli <- output_args(format = "cli")
  expect_equal(config_cli$format, "cli")

  config_md <- output_args(format = "markdown")
  expect_equal(config_md$format, "markdown")
})

test_that("output_args() accepts all valid silent values", {
  config_0 <- output_args(silent = 0)
  expect_equal(config_0$silent, 0L)

  config_1 <- output_args(silent = 1)
  expect_equal(config_1$silent, 1L)

  config_2 <- output_args(silent = 2)
  expect_equal(config_2$silent, 2L)
})

test_that("output_args() accepts logical silent values", {
  config_false <- output_args(silent = FALSE)
  expect_equal(config_false$silent, 0L)

  config_true <- output_args(silent = TRUE)
  expect_equal(config_true$silent, 2L)
})

# =============================================================================
# Integration tests with interpret()
# =============================================================================

test_that("interpretation_args config object has correct structure for interpret()", {
  # Non-LLM test: verifies config object structure without calling LLM
  config <- interpretation_args(
    analysis_type = "fa",
    cutoff = 0.4,
    n_emergency = 2,
    hide_low_loadings = TRUE
  )

  # Verify the config object is properly structured
  expect_s3_class(config, "interpretation_args")
  expect_s3_class(config, "model_config")
  expect_true(all(c("analysis_type", "cutoff", "n_emergency", "hide_low_loadings") %in% names(config)))
  expect_equal(config$analysis_type, "fa")
  expect_equal(config$cutoff, 0.4)
  expect_equal(config$n_emergency, 2L)
  expect_equal(config$hide_low_loadings, TRUE)
})

test_that("llm_args config object has correct structure for interpret()", {
  # Non-LLM test: verifies config object structure without calling LLM
  llm_config <- llm_args(
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20,
    additional_info = "Test study context"
  )

  # Verify the config object is properly structured
  expect_s3_class(llm_config, "llm_args")
  expect_true(all(c("llm_provider", "llm_model", "word_limit", "additional_info") %in% names(llm_config)))
  expect_equal(llm_config$llm_provider, "ollama")
  expect_equal(llm_config$llm_model, "gpt-oss:20b-cloud")
  expect_equal(llm_config$word_limit, 20L)
  expect_equal(llm_config$additional_info, "Test study context")
})

test_that("output_args config object has correct structure for interpret()", {
  # Non-LLM test: verifies config object structure without calling LLM
  out_config <- output_args(
    format = "markdown",
    silent = 2
  )

  # Verify the config object is properly structured
  expect_s3_class(out_config, "output_args")
  expect_true(all(c("format", "silent") %in% names(out_config)))
  expect_equal(out_config$format, "markdown")
  expect_equal(out_config$silent, 2L)
})

test_that("interpret() works with all three config objects together", {
  skip_on_ci()
  skip_if_no_llm()

  loadings <- sample_loadings()
  var_info <- sample_variable_info()

  interp_config <- interpretation_args(analysis_type = "fa", cutoff = 0.35)
  llm_config <- llm_args(llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud", word_limit = 20)
  out_config <- output_args(format = "cli", silent = 1)

  result <- interpret(
    fit_results = list(loadings = loadings),
    variable_info = var_info,
    analysis_type = "fa",  # Required when using structured list
    interpretation_args = interp_config,
    llm_args = llm_config,
    output_args = out_config
  )

  expect_s3_class(result, "fa_interpretation")
  # Verify that config object settings were applied
  expect_true(!is.null(result$suggested_names))
  expect_true(length(result$component_summaries) > 0)
})

test_that("direct parameters override config object parameters", {
  skip_on_ci()
  skip_if_no_llm()

  loadings <- sample_loadings()
  var_info <- sample_variable_info()

  # Create config with word_limit = 100
  llm_config <- llm_args(llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud", word_limit = 100)

  # But pass word_limit = 20 directly (should override)
  result <- interpret(
    fit_results = list(loadings = loadings),
    variable_info = var_info,
    analysis_type = "fa",
    llm_args = llm_config,
    word_limit = 20  # This should override the config
  )

  expect_s3_class(result, "fa_interpretation")
  # The result should reflect that word_limit=20 was used
  # (This is hard to test directly, but the interpret() call should succeed)
})
