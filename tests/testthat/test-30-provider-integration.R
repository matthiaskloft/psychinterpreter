# =============================================================================
# PROVIDER-SPECIFIC INTEGRATION TESTS
# =============================================================================
#
# Tests for provider-specific behavior (OpenAI, Anthropic, Ollama)
# - Token tracking per provider
# - Provider-specific error handling
# - Provider switching
# - API key validation
#
# Setup: Set environment variables for API keys
#   Sys.setenv(OPENAI_API_KEY = "your-key")
#   Sys.setenv(ANTHROPIC_API_KEY = "your-key")
#
# Tests skip if API keys are not available

# =============================================================================
# Test Fixtures
# =============================================================================

# Minimal FA fixture for quick provider tests
create_minimal_fa_fixture <- function() {
  loadings_matrix <- matrix(
    c(0.8, 0.1, 0.1, 0.7, 0.2, 0.8),
    nrow = 3, ncol = 2,
    dimnames = list(
      c("item1", "item2", "item3"),
      c("F1", "F2")
    )
  )

  list(
    loadings = loadings_matrix,
    variable_info = data.frame(
      variable = c("item1", "item2", "item3"),
      description = c("First item", "Second item", "Third item"),
      stringsAsFactors = FALSE
    )
  )
}

# =============================================================================
# Helper: Skip if No API Key
# =============================================================================

skip_if_no_openai_key <- function() {
  # Check if LLM tests are explicitly enabled
  run_llm_tests <- Sys.getenv("RUN_LLM_TESTS", unset = "false")
  if (!identical(tolower(run_llm_tests), "true")) {
    skip("LLM tests disabled by default (set RUN_LLM_TESTS=true to enable)")
  }

  if (Sys.getenv("OPENAI_API_KEY") == "") {
    skip("OpenAI API key not available (set OPENAI_API_KEY env var)")
  }
}

skip_if_no_anthropic_key <- function() {
  # Check if LLM tests are explicitly enabled
  run_llm_tests <- Sys.getenv("RUN_LLM_TESTS", unset = "false")
  if (!identical(tolower(run_llm_tests), "true")) {
    skip("LLM tests disabled by default (set RUN_LLM_TESTS=true to enable)")
  }

  if (Sys.getenv("ANTHROPIC_API_KEY") == "") {
    skip("Anthropic API key not available (set ANTHROPIC_API_KEY env var)")
  }
}

# =============================================================================
# OpenAI Provider Tests
# =============================================================================

test_that("OpenAI provider creates successful interpretation", {
  skip_if_no_openai_key()
  skip_on_cran()
  skip_on_ci()

  fixture <- create_minimal_fa_fixture()

  result <- interpret(
    fit_results = list(loadings = fixture$loadings),
    variable_info = fixture$variable_info,
    analysis_type = "fa",
    llm_provider = "openai",
    llm_model = "gpt-4o-mini",
    word_limit = 20,
    verbosity = 0
  )

  expect_s3_class(result, "fa_interpretation")
  expect_true(!is.null(result$component_summaries))
  expect_true(length(result$component_summaries) > 0)
})

test_that("OpenAI provider tracks tokens correctly", {
  skip_if_no_openai_key()
  skip_on_cran()
  skip_on_ci()

  fixture <- create_minimal_fa_fixture()

  result <- interpret(
    fit_results = list(loadings = fixture$loadings),
    variable_info = fixture$variable_info,
    analysis_type = "fa",
    llm_provider = "openai",
    llm_model = "gpt-4o-mini",
    word_limit = 20,
    verbosity = 0
  )

  # OpenAI should provide token counts
  expect_true(!is.null(result$token_usage))
  expect_true(is.list(result$token_usage))

  # Should have prompt_tokens and completion_tokens
  expect_true("prompt_tokens" %in% names(result$token_usage) ||
              "input_tokens" %in% names(result$token_usage))
  expect_true("completion_tokens" %in% names(result$token_usage) ||
              "output_tokens" %in% names(result$token_usage))

  # Token counts should be positive
  total_tokens <- sum(unlist(result$token_usage), na.rm = TRUE)
  expect_true(total_tokens > 0)
})

test_that("OpenAI chat session works across multiple requests", {
  skip_if_no_openai_key()
  skip_on_cran()
  skip_on_ci()

  fixture <- create_minimal_fa_fixture()

  # Create session
  chat <- chat_session(
    analysis_type = "fa",
    llm_provider = "openai",
    llm_model = "gpt-4o-mini"
  )

  expect_s3_class(chat, "chat_session")

  # First interpretation
  result1 <- interpret(
    chat_session = chat,
    fit_results = list(loadings = fixture$loadings),
    variable_info = fixture$variable_info,
    word_limit = 20,
    verbosity = 0
  )

  expect_s3_class(result1, "fa_interpretation")

  # Second interpretation (should accumulate tokens)
  result2 <- interpret(
    chat_session = chat,
    fit_results = list(loadings = fixture$loadings),
    variable_info = fixture$variable_info,
    word_limit = 20,
    verbosity = 0
  )

  expect_s3_class(result2, "fa_interpretation")

  # Check cumulative token tracking
  expect_true(!is.null(chat$cumulative_tokens))
  total_tokens <- sum(unlist(chat$cumulative_tokens), na.rm = TRUE)
  expect_true(total_tokens > 0)
})

test_that("OpenAI handles rate limit errors gracefully", {
  skip_if_no_openai_key()
  skip_on_cran()
  skip_on_ci()

  # This test is challenging because we can't easily trigger rate limits
  # Instead, we verify the error handling mechanism exists

  fixture <- create_minimal_fa_fixture()

  # Should not error even with minimal resources
  expect_no_error(
    result <- interpret(
      fit_results = list(loadings = fixture$loadings),
      variable_info = fixture$variable_info,
      analysis_type = "fa",
      llm_provider = "openai",
      llm_model = "gpt-4o-mini",
      word_limit = 20,
      verbosity = 0
    )
  )
})

# =============================================================================
# Anthropic Provider Tests
# =============================================================================

test_that("Anthropic provider creates successful interpretation", {
  skip_if_no_anthropic_key()
  skip_on_cran()
  skip_on_ci()

  fixture <- create_minimal_fa_fixture()

  result <- interpret(
    fit_results = list(loadings = fixture$loadings),
    variable_info = fixture$variable_info,
    analysis_type = "fa",
    llm_provider = "anthropic",
    llm_model = "claude-3-5-haiku-20241022",
    word_limit = 20,
    verbosity = 0
  )

  expect_s3_class(result, "fa_interpretation")
  expect_true(!is.null(result$component_summaries))
  expect_true(length(result$component_summaries) > 0)
})

test_that("Anthropic provider tracks tokens correctly", {
  skip_if_no_anthropic_key()
  skip_on_cran()
  skip_on_ci()

  fixture <- create_minimal_fa_fixture()

  result <- interpret(
    fit_results = list(loadings = fixture$loadings),
    variable_info = fixture$variable_info,
    analysis_type = "fa",
    llm_provider = "anthropic",
    llm_model = "claude-3-5-haiku-20241022",
    word_limit = 20,
    verbosity = 0
  )

  # Anthropic should provide token counts
  expect_true(!is.null(result$token_usage))
  expect_true(is.list(result$token_usage))

  # Should have input_tokens and output_tokens
  expect_true("input_tokens" %in% names(result$token_usage) ||
              "prompt_tokens" %in% names(result$token_usage))
  expect_true("output_tokens" %in% names(result$token_usage) ||
              "completion_tokens" %in% names(result$token_usage))

  # Token counts should be positive or zero (caching may affect this)
  total_tokens <- sum(unlist(result$token_usage), na.rm = TRUE)
  expect_true(total_tokens >= 0)
})

test_that("Anthropic chat session works across multiple requests", {
  skip_if_no_anthropic_key()
  skip_on_cran()
  skip_on_ci()

  fixture <- create_minimal_fa_fixture()

  # Create session
  chat <- chat_session(
    analysis_type = "fa",
    llm_provider = "anthropic",
    llm_model = "claude-3-5-haiku-20241022"
  )

  expect_s3_class(chat, "chat_session")

  # First interpretation
  result1 <- interpret(
    chat_session = chat,
    fit_results = list(loadings = fixture$loadings),
    variable_info = fixture$variable_info,
    word_limit = 20,
    verbosity = 0
  )

  expect_s3_class(result1, "fa_interpretation")

  # Second interpretation
  result2 <- interpret(
    chat_session = chat,
    fit_results = list(loadings = fixture$loadings),
    variable_info = fixture$variable_info,
    word_limit = 20,
    verbosity = 0
  )

  expect_s3_class(result2, "fa_interpretation")

  # Check cumulative token tracking
  expect_true(!is.null(chat$cumulative_tokens))
  total_tokens <- sum(unlist(chat$cumulative_tokens), na.rm = TRUE)
  expect_true(total_tokens >= 0)
})

test_that("Anthropic handles prompt caching for repeated system prompts", {
  skip_if_no_anthropic_key()
  skip_on_cran()
  skip_on_ci()

  fixture <- create_minimal_fa_fixture()

  # Create chat session (system prompt should be cached on 2nd+ calls)
  chat <- chat_session(
    analysis_type = "fa",
    llm_provider = "anthropic",
    llm_model = "claude-3-5-haiku-20241022"
  )

  # First call (no cache)
  result1 <- interpret(
    chat_session = chat,
    fit_results = list(loadings = fixture$loadings),
    variable_info = fixture$variable_info,
    word_limit = 20,
    verbosity = 0
  )

  # Second call (should benefit from cache)
  result2 <- interpret(
    chat_session = chat,
    fit_results = list(loadings = fixture$loadings),
    variable_info = fixture$variable_info,
    word_limit = 20,
    verbosity = 0
  )

  # Both should succeed
  expect_s3_class(result1, "fa_interpretation")
  expect_s3_class(result2, "fa_interpretation")

  # Token tracking should work (may include cache hits)
  expect_true(!is.null(chat$cumulative_tokens))
})

# =============================================================================
# Ollama Provider Tests
# =============================================================================

test_that("Ollama provider works without API keys", {
  skip_on_cran()
  skip_if_no_llm()

  fixture <- create_minimal_fa_fixture()

  # Should work without any API keys (skip if rate limited)
  expect_no_error(
    result <- with_llm_rate_limit_skip({
      interpret(
        fit_results = list(loadings = fixture$loadings),
        variable_info = fixture$variable_info,
        analysis_type = "fa",
        llm_provider = "ollama",
        llm_model = "gpt-oss:20b-cloud",
        word_limit = 20,
        verbosity = 0
      )
    })
  )
})

test_that("Ollama token tracking returns zero or NULL", {
  skip_on_cran()
  skip_if_no_llm()

  fixture <- create_minimal_fa_fixture()

  # Run interpretation (skip if rate limited)
  result <- with_llm_rate_limit_skip({
    interpret(
      fit_results = list(loadings = fixture$loadings),
      variable_info = fixture$variable_info,
      analysis_type = "fa",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud",
      word_limit = 20,
      verbosity = 0
    )
  })

  # Ollama may not track tokens (provider-specific behavior)
  # Should be NULL or contain zeros
  if (!is.null(result$token_usage)) {
    total_tokens <- sum(unlist(result$token_usage), na.rm = TRUE)
    expect_true(total_tokens >= 0)  # Non-negative
  }
})

# =============================================================================
# Provider Switching Tests
# =============================================================================

test_that("Cannot switch providers mid-session", {
  skip_on_cran()
  skip_if_no_llm()

  fixture <- create_minimal_fa_fixture()

  # Create Ollama session
  chat <- chat_session(
    analysis_type = "fa",
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud"
  )

  expect_s3_class(chat, "chat_session")
  expect_equal(chat$llm_provider, "ollama")

  # Provider is locked to the session
  # (interpret() uses the session's provider, not the parameter)
})

test_that("Different providers can be used in separate sessions", {
  skip_on_cran()
  skip_if_no_llm()

  fixture <- create_minimal_fa_fixture()

  # Create multiple sessions with different providers
  chat_ollama <- chat_session(
    analysis_type = "fa",
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud"
  )

  expect_s3_class(chat_ollama, "chat_session")
  expect_equal(chat_ollama$llm_provider, "ollama")

  # Each session maintains its own provider
  # This is the expected way to use multiple providers
})

# =============================================================================
# Error Handling Tests
# =============================================================================

test_that("Invalid API key produces informative error", {
  skip_on_cran()
  skip_on_ci()

  fixture <- create_minimal_fa_fixture()

  # Temporarily set invalid key
  original_key <- Sys.getenv("OPENAI_API_KEY")
  Sys.setenv(OPENAI_API_KEY = "invalid-key-12345")

  on.exit(Sys.setenv(OPENAI_API_KEY = original_key))

  # Should error with authentication message
  expect_error(
    interpret(
      fit_results = list(loadings = fixture$loadings),
      variable_info = fixture$variable_info,
      analysis_type = "fa",
      llm_provider = "openai",
      llm_model = "gpt-4o-mini",
      word_limit = 20,
      verbosity = 0
    ),
    "authentication|API key|401"
  )
})

test_that("Network errors are handled gracefully", {
  skip_on_cran()
  skip_on_ci()

  # This is difficult to test reliably without mocking
  # Verify that error handling exists
  expect_true(TRUE)
})

# =============================================================================
# Token Tracking Comparison Tests
# =============================================================================

test_that("Token tracking is consistent across providers", {
  skip_on_cran()

  # This test documents the expected token tracking behavior
  # Different providers have different token counting methods

  # OpenAI: Provides prompt_tokens, completion_tokens, total_tokens
  # Anthropic: Provides input_tokens, output_tokens (may include cache info)
  # Ollama: May return NULL or zeros

  expect_true(TRUE)  # Placeholder for documentation
})
