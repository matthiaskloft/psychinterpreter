# ==============================================================================
# CHAT SESSION LIFECYCLE TEST (WITH LLM - CONSOLIDATED)
# ==============================================================================

test_that("chat_session complete lifecycle (create, use, reset)", {
  skip_on_ci()
  skip_if_no_llm()

  llm_provider <- "ollama"
  llm_model <- "gpt-oss:20b-cloud"

  # === CREATION ===
  chat <- chat_session(
    analysis_type = "fa",
    llm_provider = llm_provider,
    llm_model = llm_model
  )

  # Check structure
  expect_s3_class(chat, "fa_chat_session")
  expect_s3_class(chat, "chat_session")
  expect_true(is.chat_session(chat))
  expect_true(!is.null(chat$chat))
  expect_equal(chat$analysis_type, "fa")
  expect_equal(chat$n_interpretations, 0)
  expect_equal(chat$total_input_tokens, 0)
  expect_equal(chat$total_output_tokens, 0)

  # === USAGE ===
  loadings <- minimal_loadings()
  var_info <- minimal_variable_info()

  result <- interpret(
    chat_session = chat,
    fit_results = list(loadings = loadings),
    variable_info = var_info,
    word_limit = 20,
    silent = 2
  )

  # Check that result is valid
  expect_s3_class(result, "fa_interpretation")
  expect_s3_class(result, "interpretation")

  # Check that session was updated
  expect_equal(chat$n_interpretations, 1)
  expect_gte(chat$total_input_tokens, 0)
  expect_gte(chat$total_output_tokens, 0)

  # === RESET ===
  original_created_at <- chat$created_at

  # Manually set some values to simulate usage
  chat$n_interpretations <- 5
  chat$total_input_tokens <- 1000
  chat$total_output_tokens <- 500

  chat_reset <- reset.chat_session(chat)

  # Check that counters are reset
  expect_equal(chat_reset$n_interpretations, 0)
  expect_equal(chat_reset$total_input_tokens, 0)
  expect_equal(chat_reset$total_output_tokens, 0)

  # Check that creation time is preserved
  expect_equal(chat_reset$created_at, original_created_at)

  # Check that analysis_type is preserved
  expect_equal(chat_reset$analysis_type, "fa")
  expect_s3_class(chat_reset, "fa_chat_session")
  expect_s3_class(chat_reset, "chat_session")
})

# ==============================================================================
# OBJECT VALIDATION TESTS (MINIMAL LLM - STRUCTURE ONLY)
# ==============================================================================

test_that("is.chat_session and print method work correctly", {
  skip_if_no_llm()

  llm_provider <- "ollama"
  llm_model <- "gpt-oss:20b-cloud"

  chat <- chat_session(
    analysis_type = "fa",
    llm_provider = llm_provider,
    llm_model = llm_model
  )

  # Test is.chat_session
  expect_true(is.chat_session(chat))

  # Test with non-chat_session objects
  expect_false(is.chat_session(list()))
  expect_false(is.chat_session(NULL))
  expect_false(is.chat_session("not a chat"))

  # Test print method
  output <- capture.output(print(chat), type = "output")
  message_output <- capture.output(print(chat), type = "message")
  all_output <- c(output, message_output)
  combined <- paste(all_output, collapse = "\n")

  # Check expected information
  expect_true(grepl("Chat Session", combined, ignore.case = TRUE))
  expect_true(grepl("Provider", combined, ignore.case = TRUE))
  expect_true(grepl("ollama", combined, ignore.case = TRUE))
})

# ==============================================================================
# ERROR HANDLING TESTS (NO LLM - VALIDATION ONLY)
# ==============================================================================

test_that("chat_session handles invalid provider gracefully", {
  # No skip_if_no_llm() - this should error before trying to create session
  expect_error(
    chat_session(
      analysis_type = "fa",
      llm_provider = "invalid_provider",
      llm_model = "llm_model"
    ),
    class = "rlang_error"
  )
})

test_that("chat_session validates analysis_type parameter", {
  skip_if_no_llm()

  expect_error(
    chat_session(
      analysis_type = "invalid_type",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud"
    ),
    "analysis_type"
  )
})

# ==============================================================================
# TOKEN EFFICIENCY TEST (WITH LLM)
# ==============================================================================

test_that("chat_session saves tokens across multiple interpretations", {
  skip_on_ci()
  skip_if_no_llm()

  llm_provider <- "ollama"
  llm_model <- "gpt-oss:20b-cloud"

  # Create session
  chat <- chat_session(
    analysis_type = "fa",
    llm_provider = llm_provider,
    llm_model = llm_model
  )

  loadings <- minimal_loadings()
  var_info <- minimal_variable_info()

  # First interpretation
  result1 <- interpret(
    chat_session = chat,
    fit_results = list(loadings = loadings),
    variable_info = var_info,
    word_limit = 20,
    silent = 2
  )

  tokens_after_first <- chat$total_input_tokens + chat$total_output_tokens

  # Second interpretation
  result2 <- interpret(
    chat_session = chat,
    fit_results = list(loadings = loadings),
    variable_info = var_info,
    word_limit = 20,
    silent = 2
  )

  tokens_after_second <- chat$total_input_tokens + chat$total_output_tokens

  # Check both interpretations succeeded
  expect_s3_class(result1, "fa_interpretation")
  expect_s3_class(result2, "fa_interpretation")

  # Check token tracking (values may be 0 for Ollama, but fields should exist)
  expect_true(is.numeric(chat$total_input_tokens))
  expect_true(is.numeric(chat$total_output_tokens))
  expect_equal(chat$n_interpretations, 2)

  # Verify tokens are cumulative (even if 0 for Ollama)
  expect_gte(tokens_after_second, tokens_after_first)
})
