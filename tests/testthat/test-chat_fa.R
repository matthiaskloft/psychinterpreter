test_that("chat_session creates valid FA chat session object", {
  skip_if_no_llm()

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  # Use modern chat_session() API
  chat <- chat_session(model_type = "fa", provider = provider, model = model)

  # Check structure - new class names
  expect_s3_class(chat, "fa_chat_session")
  expect_s3_class(chat, "chat_session")
  expect_true(is.chat_session(chat))

  # Check fields
  expect_true(!is.null(chat$chat))
  expect_equal(chat$model_type, "fa")
  expect_equal(chat$n_interpretations, 0)
  # Token counters should initialize to zero
  if ("total_input_tokens" %in% ls(envir = chat)) {
    expect_equal(chat$total_input_tokens, 0)
    expect_equal(chat$total_output_tokens, 0)
  }
})

test_that("is.chat_session correctly identifies chat_session objects", {
  skip_if_no_llm()

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  # Use modern API
  chat <- chat_session(model_type = "fa", provider = provider, model = model)
  expect_true(is.chat_session(chat))

  # Test with non-chat_session objects
  expect_false(is.chat_session(list()))
  expect_false(is.chat_session(NULL))
  expect_false(is.chat_session("not a chat"))
})

test_that("reset.chat_session resets session state", {
  skip_if_no_llm()

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  # Use modern API
  chat <- chat_session(model_type = "fa", provider = provider, model = model)

  # Simulate some usage
  chat$n_interpretations <- 5
  # Only simulate token counters if the fields exist
  if ("total_input_tokens" %in% ls(envir = chat)) {
    chat$total_input_tokens <- 1000
    chat$total_output_tokens <- 500
  }

  # Reset - returns a NEW object (use modern function)
  chat_reset <- reset.chat_session(chat)

  # Check that counters are reset in the new object
  expect_equal(chat_reset$n_interpretations, 0)
  if ("total_input_tokens" %in% ls(envir = chat_reset)) {
    expect_equal(chat_reset$total_input_tokens, 0)
    expect_equal(chat_reset$total_output_tokens, 0)
  }

  # Check that original creation time is preserved
  expect_equal(chat_reset$created_at, chat$created_at)
})

test_that("print.chat_session displays session info", {
  skip_if_no_llm()

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  # Use modern API
  chat <- chat_session(model_type = "fa", provider = provider, model = model)

  # Capture both stdout and stderr since cli may output to either
  output <- capture.output(print(chat), type = "output")
  message_output <- capture.output(print(chat), type = "message")

  # Combine outputs
  all_output <- c(output, message_output)
  combined <- paste(all_output, collapse = "\n")

  # Check that output contains expected information
  expect_true(grepl("Chat Session", combined, ignore.case = TRUE))
  expect_true(grepl("Provider", combined, ignore.case = TRUE))
  expect_true(grepl("ollama", combined, ignore.case = TRUE))
})

test_that("chat_session handles invalid provider gracefully", {
  skip_if_no_llm()

  expect_error(
    chat_session(model_type = "fa", provider = "invalid_provider", model = "model"),
    class = "rlang_error"
  )
})

# ==============================================================================
# Legacy API Tests (chat_fa - deprecated but still supported)
# ==============================================================================

test_that("chat_fa backward compatibility (deprecated)", {
  skip_if_no_llm()

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  # Suppress deprecation warnings for this test
  suppressWarnings({
    chat <- chat_fa(provider, model)

    # Old class name should still work via backward compatibility
    expect_true(is.chat_session(chat))
    expect_true(is.chat_fa(chat))  # Should still return TRUE for FA sessions
    expect_equal(chat$model_type, "fa")
  })
})
