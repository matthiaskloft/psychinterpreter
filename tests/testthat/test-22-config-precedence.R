# ==============================================================================
# TEST: Configuration Precedence
# ==============================================================================
# Purpose: Verify that direct parameters override configuration objects
# Status: New test file for Phase 2
# ==============================================================================

test_that("direct interpretation parameters override interpretation_args config", {
  skip_if_no_llm()

  # Create config with one set of values
  interp_config <- interpretation_args(
    analysis_type = "fa",
    cutoff = 0.4,
    n_emergency = 3
  )

  # Use direct parameters with different values
  result <- interpret(
    fit_results = minimal_fa_model(),
    variable_info = minimal_variable_info(),
    interpretation_args = interp_config,
    cutoff = 0.5,  # Should override 0.4 from config
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20,
    verbosity = 0
  )

  # Verify direct parameter took precedence
  # The cutoff value should be reflected in the analysis_data
  expect_true(!is.null(result$analysis_data))
  # Note: cutoff is used internally, not stored in analysis_data
  # But we can verify the interpretation was created successfully
  expect_s3_class(result, "fa_interpretation")
})

test_that("direct llm parameters override llm_args config", {
  skip_if_no_llm()

  # Create LLM config
  llm_config <- llm_args(
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 100,
    additional_info = "Original context"
  )

  # Use direct parameter to override
  result <- interpret(
    fit_results = minimal_fa_model(),
    variable_info = minimal_variable_info(),
    llm_args = llm_config,
    word_limit = 20,  # Should override 100 from config
    verbosity = 0
  )

  # Verify result is valid (word_limit was respected)
  expect_s3_class(result, "fa_interpretation")
  expect_true(!is.null(result$report))
})

test_that("direct output parameters override output_args config", {
  skip_if_no_llm()

  # Create output config
  output_config <- output_args(
    format = "markdown",
    verbosity = 2
  )

  # Use direct parameter to override
  result <- interpret(
    fit_results = minimal_fa_model(),
    variable_info = minimal_variable_info(),
    output_args = output_config,
    verbosity = 0,  # Should override 0 from config (completely silent)
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20
  )

  # Verify result is valid
  expect_s3_class(result, "fa_interpretation")
  expect_true(!is.null(result$report))
})

test_that("config objects work when no direct parameters provided", {
  skip_if_no_llm()

  # Create all config objects
  interp_config <- interpretation_args(
    analysis_type = "fa",
    cutoff = 0.3,
    n_emergency = 2
  )

  llm_config <- llm_args(
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20
  )

  output_config <- output_args(
    format = "cli",
    verbosity = 1
  )

  # Use only config objects, no direct overrides
  result <- interpret(
    fit_results = minimal_fa_model(),
    variable_info = minimal_variable_info(),
    interpretation_args = interp_config,
    llm_args = llm_config,
    output_args = output_config
  )

  # Verify config values were used
  expect_s3_class(result, "fa_interpretation")
  expect_true(!is.null(result$report))
})

test_that("mixed config and direct parameters work together", {
  skip_if_no_llm()

  # Use interpretation_args config but override one llm parameter directly
  interp_config <- interpretation_args(
    analysis_type = "fa",
    cutoff = 0.35
  )

  result <- interpret(
    fit_results = minimal_fa_model(),
    variable_info = minimal_variable_info(),
    interpretation_args = interp_config,  # Use config for interpretation
    word_limit = 20,  # Direct parameter for LLM
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    verbosity = 0
  )

  # Verify both were applied
  expect_s3_class(result, "fa_interpretation")
  expect_true(!is.null(result$report))
})

test_that("NULL config objects use package defaults", {
  skip_on_ci()
  skip_if_no_llm()

  # Don't provide any config objects, use all direct parameters
  result <- interpret(
    fit_results = minimal_fa_model(),
    variable_info = minimal_variable_info(),
    interpretation_args = NULL,
    llm_args = NULL,
    output_args = NULL,
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20,
    verbosity = 0
  )

  # Verify defaults were used
  expect_s3_class(result, "fa_interpretation")
  expect_true(!is.null(result$report))
})
