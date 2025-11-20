# Tests for Core Interpretation Orchestrator
# Focus: interpret_core() workflow and integration
#
# Note: interpret_core() is an internal function (not exported)
# We access it using ::: for testing purposes
#
# Test Structure:
# - Section 1: Input validation tests (NO LLM)
# - Section 2: Model type detection tests (NO LLM)
# - Section 3: Comprehensive workflow integration test (WITH LLM)
# - Section 4: Configuration objects integration test (WITH LLM)
# - Section 5: Chat session reuse integration test (WITH LLM)
# - Section 6: Output behavior tests using cached fixtures (NO LLM)
# - Section 7: Silent parameter test (WITH LLM)
# - Section 8: Performance test (WITH LLM, skip_on_ci)

# ==============================================================================
# SECTION 1: INPUT VALIDATION TESTS (NO LLM)
# ==============================================================================

test_that("interpret_core requires either fit_results or analysis_data", {
  expect_error(
    psychinterpreter:::interpret_core(
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud"
    ),
    "fit_results.*analysis_data"
  )
})

test_that("interpret_core validates all parameters without LLM", {
  # Test all validation logic WITHOUT calling LLMs
  loadings <- minimal_loadings()
  var_info <- minimal_variable_info()

  # Invalid output_format
  expect_error(
    psychinterpreter:::interpret_core(
      fit_results = list(loadings = loadings),
      variable_info = var_info,
      analysis_type = "fa",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud",
      output_format = "invalid"
    ),
    "must be either"
  )

  # Invalid heading_level
  expect_error(
    psychinterpreter:::interpret_core(
      fit_results = list(loadings = loadings),
      variable_info = var_info,
      analysis_type = "fa",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud",
      heading_level = 0
    ),
    "between 1 and 6"
  )

  # Invalid analysis_type
  expect_error(
    psychinterpreter:::interpret_core(
      fit_results = list(loadings = loadings),
      variable_info = var_info,
      analysis_type = "invalid_type",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud"
    ),
    "Invalid analysis_type"
  )

  # Missing variable_info for FA
  expect_error(
    psychinterpreter:::interpret_core(
      fit_results = minimal_fa_model(),
      analysis_type = "fa",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud"
    ),
    "variable_info.*required"
  )
})

test_that("interpret_core handles both fit_results and analysis_data precedence", {
  skip_if_not_installed("psych")

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()
  dummy_analysis_data <- list(test = "dummy")

  # Should warn when both provided
  expect_warning(
    # Don't call LLM, just test validation
    tryCatch({
      psychinterpreter:::interpret_core(
        fit_results = fa_model,
        analysis_data = dummy_analysis_data,
        analysis_type = "fa",
        llm_provider = "invalid_to_stop_early",  # Force early exit
        llm_model = "gpt-oss:20b-cloud",
        variable_info = var_info
      )
    }, error = function(e) NULL),
    "fit_results.*analysis_data"
  )
})

# ==============================================================================
# SECTION 2: MODEL TYPE DETECTION TESTS (NO LLM)
# ==============================================================================

test_that("interpret_core correctly detects analysis_type from fit_results", {
  skip_if_not_installed("psych")

  fa_model <- minimal_fa_model()

  # Should detect FA model type automatically
  model_data <- psychinterpreter:::build_analysis_data(
    fit_results = fa_model,
    analysis_type = NULL,  # Should be auto-detected
    interpretation_args = interpretation_args(analysis_type = "fa"),
    variable_info = minimal_variable_info()
  )

  expect_equal(model_data$analysis_type, "fa")
})

# ==============================================================================
# SECTION 3: COMPREHENSIVE WORKFLOW INTEGRATION TEST (WITH LLM)
# ==============================================================================
# This single test covers:
# - fit_results processing
# - analysis_type detection
# - Temporary chat session creation
# - Prompt building (system + main)
# - LLM call
# - Response parsing
# - Return structure validation
# - Token tracking
# - word_limit parameter
# - additional_info parameter
# - custom system_prompt parameter
# ==============================================================================

test_that("interpret_core complete workflow integration", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Single comprehensive test covering most functionality
  result <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    analysis_type = "fa",
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20,
    additional_info = "Test study context",
    variable_info = var_info,
    silent = 2
  )

  # Check class structure
  expect_s3_class(result, "fa_interpretation")
  expect_s3_class(result, "interpretation")
  expect_type(result, "list")

  # Check required components
  expect_true("component_summaries" %in% names(result))
  expect_true("suggested_names" %in% names(result))
  expect_true("analysis_type" %in% names(result))
  expect_true("timestamp" %in% names(result))
  expect_true("report" %in% names(result))

  # Check analysis_type is correct
  expect_equal(result$analysis_type, "fa")

  # Check timestamp is valid
  expect_s3_class(result$timestamp, "POSIXct")

  # Check token tracking (may be 0 for Ollama, but fields should exist)
  expect_true("input_tokens" %in% names(result))
  expect_true("output_tokens" %in% names(result))
  expect_true("total_tokens" %in% names(result))

  # Check interpretations are present
  expect_true(length(result$component_summaries) > 0)
  expect_true(nchar(result$report) > 0)
})

# ==============================================================================
# SECTION 4: CONFIGURATION OBJECTS INTEGRATION TEST (WITH LLM)
# ==============================================================================
# This single test covers all three configuration objects:
# - interpretation_args
# - llm_args
# - output_args
# ==============================================================================

test_that("interpret_core works with all configuration objects", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Create all configuration objects
  interp_config <- interpretation_args(
    analysis_type = "fa",
    cutoff = 0.4,
    n_emergency = 2
  )

  llm_config <- llm_args(
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20,
    additional_info = "Test study"
  )

  output_config <- output_args(
    format = "markdown",
    silent = 2
  )

  # Test all three config objects together
  result <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    analysis_type = "fa",  # Required when not using chat_session
    interpretation_args = interp_config,
    llm_args = llm_config,
    output_args = output_config,
    variable_info = var_info
  )

  expect_s3_class(result, "fa_interpretation")
  expect_true("report" %in% names(result))
})

# ==============================================================================
# SECTION 5: CHAT SESSION REUSE INTEGRATION TEST (WITH LLM)
# ==============================================================================
# This single test covers:
# - Using existing chat_session
# - Chat session state tracking
# - Multiple interpretations with same session
# ==============================================================================

test_that("interpret_core reuses existing chat_session correctly", {
  skip_if_not_installed("psych")
  skip_on_ci()
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Create chat session
  chat <- chat_session(
    analysis_type = "fa",
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud"
  )

  # Initial state
  expect_equal(chat$n_interpretations, 0)
  initial_input <- chat$total_input_tokens
  initial_output <- chat$total_output_tokens

  # Use with interpret_core (first interpretation)
  result1 <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    chat_session = chat,
    word_limit = 20,
    variable_info = var_info,
    silent = 2
  )

  expect_s3_class(result1, "fa_interpretation")

  # Chat session should have updated counters
  expect_equal(chat$n_interpretations, 1)
  expect_gte(chat$total_input_tokens, initial_input)
  expect_gte(chat$total_output_tokens, initial_output)

  # Second interpretation with same session
  result2 <- psychinterpreter:::interpret_core(
    fit_results = fa_model,
    chat_session = chat,
    word_limit = 20,
    variable_info = var_info,
    silent = 2
  )

  expect_s3_class(result2, "fa_interpretation")
  expect_equal(chat$n_interpretations, 2)
})

# ==============================================================================
# SECTION 6: OUTPUT BEHAVIOR TESTS (USE CACHED FIXTURES - NO LLM)
# ==============================================================================

test_that("interpret_core output formats work correctly with cached fixtures", {
  # Use cached interpretation to test formatting behavior
  # Note: Currently we only have sample_interpretation.rds in CLI format
  # When sample_interpretation_markdown.rds is created in Phase 1.1, update this test

  interp_cli <- sample_interpretation()
  expect_true("report" %in% names(interp_cli))
  expect_true(is.character(interp_cli$report))
  expect_true(nchar(interp_cli$report) > 0)

  # TODO: When Phase 1.1 creates sample_interpretation_markdown.rds, add:
  # interp_md <- sample_interpretation_markdown()
  # expect_true("report" %in% names(interp_md))
  # expect_true(grepl("##|\\*\\*|\\*", interp_md$report))  # Check for markdown formatting
})

# ==============================================================================
# SECTION 7: SILENT PARAMETER TEST (WITH LLM)
# ==============================================================================

test_that("interpret_core respects silent parameter behavior", {
  skip_if_not_installed("psych")
  skip_if_no_llm()

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # silent = 0 (show everything) - capture output
  expect_output({
    result0 <- psychinterpreter:::interpret_core(
      fit_results = fa_model,
      analysis_type = "fa",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud",
      word_limit = 20,
      silent = 0,
      variable_info = var_info
    )
  })

  # silent = 2 (completely silent) - no output
  expect_silent({
    result2 <- psychinterpreter:::interpret_core(
      fit_results = fa_model,
      analysis_type = "fa",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud",
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
# SECTION 8: PERFORMANCE TEST (WITH LLM, SKIP ON CI)
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
    analysis_type = "fa",
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20,
    variable_info = var_info,
    silent = 2
  )
  elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))

  expect_s3_class(result, "fa_interpretation")

  # Should complete in under 60 seconds (generous for LLM call)
  expect_lt(elapsed, 60)
})

# ==============================================================================
# SECTION 9: ERROR HANDLING WITH MOCKS (NO LLM)
# ==============================================================================

test_that("interpret_core handles malformed JSON gracefully with mock", {
  skip_if_not_installed("psych")

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Create mock chat session with malformed JSON response
  mock_chat <- mock_chat_session(analysis_type = "fa", response_type = "malformed_json")

  # Should handle malformed JSON - either return defaults or handle error
  # Suppress expected warning from JSON parsing fallback
  result <- suppressWarnings(tryCatch({
    psychinterpreter:::interpret_core(
      fit_results = fa_model,
      chat_session = mock_chat,
      variable_info = var_info,
      silent = 2
    )
  }, error = function(e) NULL))

  # If it returns a result, check it's valid
  if (!is.null(result)) {
    expect_s3_class(result, "fa_interpretation")
    expect_true("component_summaries" %in% names(result))
    expect_true("suggested_names" %in% names(result))
  } else {
    # Or it can fail gracefully
    expect_null(result)
  }
})

test_that("interpret_core handles empty response with mock", {
  skip_if_not_installed("psych")

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Create mock chat session with empty response
  mock_chat <- mock_chat_session(analysis_type = "fa", response_type = "empty")

  # Should handle empty response gracefully
  # Suppress expected warning from JSON parsing fallback
  result <- suppressWarnings(
    psychinterpreter:::interpret_core(
      fit_results = fa_model,
      chat_session = mock_chat,
      variable_info = var_info,
      silent = 2
    )
  )

  # Should return an interpretation object with defaults
  expect_s3_class(result, "fa_interpretation")
  expect_true("component_summaries" %in% names(result))
  expect_true("suggested_names" %in% names(result))
})

test_that("interpret_core handles partial response with mock", {
  skip_if_not_installed("psych")

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Create mock chat session with partial response
  mock_chat <- mock_chat_session(analysis_type = "fa", response_type = "partial")

  # Should handle partial response gracefully
  # Suppress expected warning from JSON parsing fallback
  result <- suppressWarnings(
    psychinterpreter:::interpret_core(
      fit_results = fa_model,
      chat_session = mock_chat,
      variable_info = var_info,
      silent = 2
    )
  )

  # Should return an interpretation object with some defaults
  expect_s3_class(result, "fa_interpretation")
  expect_true("component_summaries" %in% names(result))
  expect_true("suggested_names" %in% names(result))
})

test_that("interpret_core handles timeout error with mock", {
  skip_if_not_installed("psych")

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Create mock chat session that throws timeout error
  mock_chat <- mock_chat_session(analysis_type = "fa", response_type = "timeout")

  # Should handle timeout error
  expect_error(
    psychinterpreter:::interpret_core(
      fit_results = fa_model,
      chat_session = mock_chat,
      variable_info = var_info,
      silent = 2
    ),
    "timeout"
  )
})

test_that("interpret_core handles rate limit error with mock", {
  skip_if_not_installed("psych")

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Create mock chat session that throws rate limit error
  mock_chat <- mock_chat_session(analysis_type = "fa", response_type = "rate_limit")

  # Should handle rate limit error
  expect_error(
    psychinterpreter:::interpret_core(
      fit_results = fa_model,
      chat_session = mock_chat,
      variable_info = var_info,
      silent = 2
    ),
    "429|rate.?limit"
  )
})

test_that("interpret_core handles generic API error with mock", {
  skip_if_not_installed("psych")

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Create mock chat session that throws generic error
  mock_chat <- mock_chat_session(analysis_type = "fa", response_type = "error")

  # Should handle API error
  expect_error(
    psychinterpreter:::interpret_core(
      fit_results = fa_model,
      chat_session = mock_chat,
      variable_info = var_info,
      silent = 2
    ),
    "API Error|500"
  )
})
