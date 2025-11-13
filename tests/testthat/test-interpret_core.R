# Tests for Core Interpretation Orchestrator
# Focus: interpret_core() workflow and integration

# Note: interpret_core() is an internal function (not exported)
# We access it using ::: for testing purposes

# ==============================================================================
# INPUT VALIDATION TESTS
# ==============================================================================

test_that("interpret_core requires either fit_results or model_data", {
  expect_error(
    psychinterpreter:::interpret_core(
      provider = "ollama",
      model = "gpt-oss:20b-cloud"
    ),
    "fit_results.*model_data"
  )
})

test_that("interpret_core prefers fit_results when both provided", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Create some dummy model_data
  dummy_model_data <- list(test = "dummy")

  # Should use fit_results and show warning
  expect_warning(
    result <- psychinterpreter:::interpret_core(
      fit_results = fa_model,
      model_data = dummy_model_data,
      model_type = "fa",
      provider = "ollama",
      model = "gpt-oss:20b-cloud",
      word_limit = 20,
      variable_info = var_info
    ),
    "fit_results.*model_data"
  )

  # Should still complete successfully
  expect_s3_class(result, "fa_interpretation")
})

# ==============================================================================
# MODEL TYPE DETECTION TESTS
# ==============================================================================

test_that("interpret_core correctly detects model_type from fit_results", {
  skip_if_not_installed("psych")

  fa_model <- minimal_fa_model()

  # Should detect FA model type automatically
  expect_no_error({
    # We just test that model_type detection works, not full LLM call
    model_data <- psychinterpreter:::build_model_data(
      fit_results = fa_model,
      model_type = NULL,  # Should be auto-detected
      interpretation_args = interpretation_args(model_type = "fa"),
      variable_info = minimal_variable_info()
    )
  })

  expect_equal(model_data$model_type, "fa")
})

# ==============================================================================
# CHAT SESSION TESTS
# ==============================================================================

test_that("interpret_core can use existing chat_session", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Create chat session
  chat <- chat_session(
    model_type = "fa",
    provider = "ollama",
    model = "gpt-oss:20b-cloud"
  )

  # Use with interpret_core
  result <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    chat_session = chat,
    word_limit = 20,
    variable_info = var_info
  )

  expect_s3_class(result, "fa_interpretation")
  expect_s3_class(result, "interpretation")

  # Chat session should have recorded interpretation count
  expect_true(chat$n_interpretations > 0)
})

test_that("interpret_core creates temporary chat_session when none provided", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # No chat_session provided, should create temporary one
  result <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    model_type = "fa",
    provider = "ollama",
    model = "gpt-oss:20b-cloud",
    word_limit = 20,
    variable_info = var_info
  )

  expect_s3_class(result, "fa_interpretation")

  # Result should include token info from temporary session
  expect_true(!is.null(result$input_tokens) || !is.null(result$output_tokens))
})

# ==============================================================================
# PROMPT BUILDING TESTS
# ==============================================================================

test_that("interpret_core uses model-specific prompts", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # The prompts are built by S3 methods - we test integration here
  result <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    model_type = "fa",
    provider = "ollama",
    model = "gpt-oss:20b-cloud",
    word_limit = 20,
    variable_info = var_info,
    echo = "none"  # Don't show prompts in test output
  )

  expect_s3_class(result, "fa_interpretation")

  # Should have interpretation content
  expect_true("component_summaries" %in% names(result))
})

test_that("interpret_core respects custom system_prompt", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  custom_prompt <- "You are a test expert. Respond with exactly: 'Test response'"

  # With custom system prompt
  result <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    model_type = "fa",
    provider = "ollama",
    model = "gpt-oss:20b-cloud",
    system_prompt = custom_prompt,
    word_limit = 20,
    variable_info = var_info
  )

  expect_s3_class(result, "fa_interpretation")
})

# ==============================================================================
# OUTPUT FORMAT TESTS
# ==============================================================================

test_that("interpret_core respects output_format parameter", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # CLI format
  result_cli <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    model_type = "fa",
    provider = "ollama",
    model = "gpt-oss:20b-cloud",
    word_limit = 20,
    output_format = "cli",
    variable_info = var_info
  )

  # Markdown format
  result_md <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    model_type = "fa",
    provider = "ollama",
    model = "gpt-oss:20b-cloud",
    word_limit = 20,
    output_format = "markdown",
    variable_info = var_info
  )

  expect_s3_class(result_cli, "fa_interpretation")
  expect_s3_class(result_md, "fa_interpretation")

  # Both should have report, but formatting may differ
  expect_true("report" %in% names(result_cli))
  expect_true("report" %in% names(result_md))
})

test_that("interpret_core respects silent parameter", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # silent = 0 (show everything) - capture output
  expect_output({
    result0 <- psychinterpreter:::interpret_core(
      fit_results = fa_model,
      model_type = "fa",
      provider = "ollama",
      model = "gpt-oss:20b-cloud",
      word_limit = 20,
      silent = 0,
      variable_info = var_info
    )
  })

  # silent = 2 (completely silent) - no output
  expect_silent({
    result2 <- psychinterpreter:::interpret_core(
      fit_results = fa_model,
      model_type = "fa",
      provider = "ollama",
      model = "gpt-oss:20b-cloud",
      word_limit = 20,
      silent = 2,
      variable_info = var_info
    )
  })

  # Both should return valid results
  expect_s3_class(result0, "fa_interpretation")
  expect_s3_class(result2, "fa_interpretation")
})

# ==============================================================================
# WORD LIMIT TESTS
# ==============================================================================

test_that("interpret_core passes word_limit to prompt builder", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Use minimum word limit
  result <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    model_type = "fa",
    provider = "ollama",
    model = "gpt-oss:20b-cloud",
    word_limit = 20,
    variable_info = var_info,
    silent = 2
  )

  expect_s3_class(result, "fa_interpretation")

  # Check that interpretations are present (LLM should respect word limit)
  expect_true(length(result$component_summaries) > 0)
})

# ==============================================================================
# ADDITIONAL_INFO PARAMETER TESTS
# ==============================================================================

test_that("interpret_core passes additional_info to prompt builder", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  result <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    model_type = "fa",
    provider = "ollama",
    model = "gpt-oss:20b-cloud",
    word_limit = 20,
    additional_info = "This is a personality study",
    variable_info = var_info,
    silent = 2
  )

  expect_s3_class(result, "fa_interpretation")
})

# ==============================================================================
# RETURN VALUE STRUCTURE TESTS
# ==============================================================================

test_that("interpret_core returns complete interpretation object", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  result <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    model_type = "fa",
    provider = "ollama",
    model = "gpt-oss:20b-cloud",
    word_limit = 20,
    variable_info = var_info,
    silent = 2
  )

  # Check class
  expect_s3_class(result, "fa_interpretation")
  expect_s3_class(result, "interpretation")
  expect_type(result, "list")

  # Check required components
  expect_true("component_summaries" %in% names(result))
  expect_true("suggested_names" %in% names(result))
  expect_true("model_type" %in% names(result))
  expect_true("timestamp" %in% names(result))

  # Check model_type is correct
  expect_equal(result$model_type, "fa")

  # Check timestamp is valid
  expect_s3_class(result$timestamp, "POSIXct")
})

test_that("interpret_core includes token usage information", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  result <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    model_type = "fa",
    provider = "ollama",
    model = "gpt-oss:20b-cloud",
    word_limit = 20,
    variable_info = var_info,
    silent = 2
  )

  # Should have token counts (may be 0 for Ollama, but fields should exist)
  expect_true("input_tokens" %in% names(result))
  expect_true("output_tokens" %in% names(result))
  expect_true("total_tokens" %in% names(result))
})

# ==============================================================================
# ERROR HANDLING TESTS
# ==============================================================================

test_that("interpret_core handles missing variable_info for FA gracefully", {
  skip_if_not_installed("psych")

  fa_model <- minimal_fa_model()

  # Should error when variable_info missing for FA
  expect_error(
    psychinterpreter:::interpret_core(
      fit_results = fa_model,
      model_type = "fa",
      provider = "ollama",
      model = "gpt-oss:20b-cloud",
      word_limit = 20
      # variable_info missing!
    ),
    "variable_info.*required"
  )
})

test_that("interpret_core handles invalid model_type", {
  skip_if_not_installed("psych")

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  expect_error(
    psychinterpreter:::interpret_core(
      fit_results = fa_model,
      model_type = "invalid_type",
      provider = "ollama",
      model = "gpt-oss:20b-cloud",
      word_limit = 20,
      variable_info = var_info
    ),
    "Invalid model_type"
  )
})

# ==============================================================================
# CONFIGURATION OBJECTS INTEGRATION TESTS
# ==============================================================================

test_that("interpret_core works with interpretation_args configuration object", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Create configuration object
  interp_config <- interpretation_args(
    model_type = "fa",
    cutoff = 0.4,
    n_emergency = 2
  )

  result <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    model_type = "fa",
    interpretation_args = interp_config,
    provider = "ollama",
    model = "gpt-oss:20b-cloud",
    word_limit = 20,
    variable_info = var_info,
    silent = 2
  )

  expect_s3_class(result, "fa_interpretation")
})

test_that("interpret_core works with llm_args configuration object", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Create LLM configuration
  llm_config <- llm_args(
    provider = "ollama",
    model = "gpt-oss:20b-cloud",
    word_limit = 20,
    additional_info = "Test study"
  )

  result <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    model_type = "fa",
    llm_args = llm_config,
    variable_info = var_info,
    silent = 2
  )

  expect_s3_class(result, "fa_interpretation")
})

test_that("interpret_core works with output_args configuration object", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Create output configuration
  output_config <- output_args(
    format = "markdown",
    silent = 2
  )

  result <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    model_type = "fa",
    output_args = output_config,
    provider = "ollama",
    model = "gpt-oss:20b-cloud",
    word_limit = 20,
    variable_info = var_info
  )

  expect_s3_class(result, "fa_interpretation")
})

# ==============================================================================
# PERFORMANCE / TIMING TESTS
# ==============================================================================

test_that("interpret_core completes in reasonable time", {
  skip_if_not_installed("psych")
  skip_if_no_llm()
  skip_on_ci()  # Skip on CI as timing may vary

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Time the execution
  start <- Sys.time()
  result <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    model_type = "fa",
    provider = "ollama",
    model = "gpt-oss:20b-cloud",
    word_limit = 20,
    variable_info = var_info,
    silent = 2
  )
  elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))

  expect_s3_class(result, "fa_interpretation")

  # Should complete in under 60 seconds (generous for LLM call)
  expect_lt(elapsed, 60)
})
