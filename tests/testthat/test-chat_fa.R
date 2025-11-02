test_that("chat_fa creates valid chat session object", {
  skip_if_no_llm()

  # Determine which provider to use
  provider <- if (has_openai_key()) "openai" else "anthropic"
  model <- if (provider == "openai") "gpt-4o-mini" else "claude-haiku-4-5-20251001"

  chat <- chat_fa(provider, model)

  # Check structure
  expect_s3_class(chat, "chat_fa")
  expect_true(is.chat_fa(chat))

  # Check fields
  expect_true(!is.null(chat$chat))
  expect_equal(chat$n_interpretations, 0)
  expect_equal(chat$total_input_tokens, 0)
  expect_equal(chat$total_output_tokens, 0)
})

test_that("is.chat_fa correctly identifies chat_fa objects", {
  skip_if_no_llm()

  provider <- if (has_openai_key()) "openai" else "anthropic"
  model <- if (provider == "openai") "gpt-4o-mini" else "claude-haiku-4-5-20251001"

  chat <- chat_fa(provider, model)
  expect_true(is.chat_fa(chat))

  # Test with non-chat_fa objects
  expect_false(is.chat_fa(list()))
  expect_false(is.chat_fa(NULL))
  expect_false(is.chat_fa("not a chat"))
})

test_that("reset.chat_fa resets session state", {
  skip_if_no_llm()

  provider <- if (has_openai_key()) "openai" else "anthropic"
  model <- if (provider == "openai") "gpt-4o-mini" else "claude-haiku-4-5-20251001"

  chat <- chat_fa(provider, model)

  # Simulate some usage
  chat$n_interpretations <- 5
  chat$total_input_tokens <- 1000
  chat$total_output_tokens <- 500

  # Reset
  reset.chat_fa(chat)

  # Check that counters are reset
  expect_equal(chat$n_interpretations, 0)
  expect_equal(chat$total_input_tokens, 0)
  expect_equal(chat$total_output_tokens, 0)
})

test_that("print.chat_fa displays session info", {
  skip_if_no_llm()

  provider <- if (has_openai_key()) "openai" else "anthropic"
  model <- if (provider == "openai") "gpt-4o-mini" else "claude-haiku-4-5-20251001"

  chat <- chat_fa(provider, model)

  # Capture print output
  output <- capture.output(print(chat))

  # Check that output contains expected information
  expect_true(any(grepl("Factor Analysis Chat Session", output)))
  expect_true(any(grepl("Provider:", output)))
  expect_true(any(grepl("Model:", output)))
})

test_that("chat_fa handles invalid provider gracefully", {
  expect_error(
    chat_fa("invalid_provider", "model"),
    class = "rlang_error"
  )
})
