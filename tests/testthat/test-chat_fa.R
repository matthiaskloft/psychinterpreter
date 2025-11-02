test_that("chat_fa creates valid chat session object", {
  skip_if_no_llm()

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

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

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  chat <- chat_fa(provider, model)
  expect_true(is.chat_fa(chat))

  # Test with non-chat_fa objects
  expect_false(is.chat_fa(list()))
  expect_false(is.chat_fa(NULL))
  expect_false(is.chat_fa("not a chat"))
})

test_that("reset.chat_fa resets session state", {
  skip_if_no_llm()

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  chat <- chat_fa(provider, model)

  # Simulate some usage
  chat$n_interpretations <- 5
  chat$total_input_tokens <- 1000
  chat$total_output_tokens <- 500

  # Reset - returns a NEW object
  chat_reset <- reset.chat_fa(chat)

  # Check that counters are reset in the new object
  expect_equal(chat_reset$n_interpretations, 0)
  expect_equal(chat_reset$total_input_tokens, 0)
  expect_equal(chat_reset$total_output_tokens, 0)

  # Check that original creation time is preserved
  expect_equal(chat_reset$created_at, chat$created_at)
})

test_that("print.chat_fa displays session info", {
  skip_if_no_llm()

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  chat <- chat_fa(provider, model)

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

test_that("chat_fa handles invalid provider gracefully", {
  expect_error(
    chat_fa("invalid_provider", "model"),
    class = "rlang_error"
  )
})
