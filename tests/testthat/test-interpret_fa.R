test_that("interpret_fa validates input parameters", {
  loadings <- sample_loadings()
  var_info <- sample_variable_info()

  # Test invalid cutoff
  expect_error(
    interpret_fa(loadings, var_info, cutoff = -0.1),
    "must be between 0 and 1"
  )

  expect_error(
    interpret_fa(loadings, var_info, cutoff = 1.5),
    "must be between 0 and 1"
  )

  # Test invalid n_emergency
  expect_error(
    interpret_fa(loadings, var_info, n_emergency = 0),
    "must be a positive integer"
  )

  # Test invalid output_format
  expect_error(
    interpret_fa(loadings, var_info, output_format = "invalid"),
    "must be either"
  )

  # Test invalid heading_level
  expect_error(
    interpret_fa(loadings, var_info, heading_level = 0),
    "between 1 and 6"
  )

  expect_error(
    interpret_fa(loadings, var_info, heading_level = 7),
    "between 1 and 6"
  )
})

test_that("interpret_fa validates loadings structure", {
  var_info <- sample_variable_info()

  # Missing variable column
  bad_loadings <- data.frame(
    ML1 = c(0.8, 0.7),
    ML2 = c(0.1, 0.15)
  )

  expect_error(
    interpret_fa(bad_loadings, var_info),
    'No variables from.*found in'
  )

  # No factor columns
  only_vars <- data.frame(variable = c("var1", "var2"))

  expect_error(
    interpret_fa(only_vars, var_info),
    "must contain at least one factor"
  )
})

test_that("interpret_fa validates variable_info structure", {
  loadings <- sample_loadings()

  # Missing required columns
  bad_var_info <- data.frame(
    var = c("var1", "var2")
  )

  expect_error(
    interpret_fa(loadings, bad_var_info),
    'must contain a variable column'
  )
})

test_that("interpret_fa validates chat_session parameter", {
  skip_if_no_llm()

  loadings <- sample_loadings()
  var_info <- sample_variable_info()

  # Test with invalid chat_session
  expect_error(
    interpret_fa(loadings, var_info, chat_session = "not a chat_fa"),
    "chat_session must be a chat_fa object"
  )

  expect_error(
    interpret_fa(loadings, var_info, chat_session = list()),
    "chat_session must be a chat_fa object"
  )
})

test_that("interpret_fa warns when chat_session overrides provider/model", {
  skip_if_no_llm()

  loadings <- sample_loadings()
  var_info <- sample_variable_info()

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  chat <- chat_fa(provider, model)

  # Should inform user that chat_session overrides provider/model
  expect_message(
    interpret_fa(loadings, var_info,
                chat_session = chat,
                llm_provider = "different_provider",
                silent = FALSE),
    "overrides"
  )
})

test_that("interpret_fa handles emergency rule for weak factors", {
  skip_if_no_llm()

  # Create loadings where one factor has no loadings above cutoff
  weak_loadings <- data.frame(
    variable = c("var1", "var2", "var3"),
    ML1 = c(0.8, 0.7, 0.6),
    ML2 = c(0.05, 0.03, 0.02)  # All below typical cutoff
  )

  var_info <- data.frame(
    variable = c("var1", "var2", "var3"),
    description = c("Variable 1", "Variable 2", "Variable 3")
  )

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  # Should apply emergency rule for ML2
  result <- interpret_fa(weak_loadings, var_info,
                        cutoff = 0.3,
                        n_emergency = 2,
                        llm_provider = provider,
                        llm_model = model,
                        silent = TRUE)

  # Check that result includes ML2 despite low loadings
  expect_true("ML2" %in% names(result$factor_summaries))

  # Check that the summary indicates emergency rule was used
  ml2_summary <- result$factor_summaries$ML2$summary
  expect_true(grepl("WARNING", ml2_summary))
})

test_that("interpret_fa returns expected structure", {
  skip_if_no_llm()

  loadings <- sample_loadings()
  var_info <- sample_variable_info()

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  result <- interpret_fa(loadings, var_info,
                        llm_provider = provider,
                        llm_model = model,
                        silent = TRUE)

  # Check main structure
  expect_s3_class(result, "fa_interpretation")
  expect_type(result$suggested_names, "list")
  expect_type(result$factor_summaries, "list")
  expect_type(result$report, "character")

  # Check that all factors are present
  factor_names <- setdiff(names(loadings), "variable")
  expect_true(all(factor_names %in% names(result$suggested_names)))
  expect_true(all(factor_names %in% names(result$factor_summaries)))

  # Check token tracking
  expect_true("run_tokens" %in% names(result))
  expect_type(result$run_tokens, "list")
})

test_that("leading zeros are removed consistently for negative numbers", {
  skip_if_no_llm()

  # Create loadings with negative values
  neg_loadings <- data.frame(
    variable = c("var1", "var2", "var3"),
    ML1 = c(0.8, -0.456, 0.123),
    ML2 = c(-0.789, 0.654, -0.321)
  )

  var_info <- data.frame(
    variable = c("var1", "var2", "var3"),
    description = c("Variable 1", "Variable 2", "Variable 3")
  )

  provider <- "ollama"
  model <- "gpt-oss:20b-cloud"

  result <- interpret_fa(neg_loadings, var_info,
                        llm_provider = provider,
                        llm_model = model,
                        silent = TRUE)

  # Check that loading matrix doesn't have "-0." patterns
  if (!is.null(result$loading_matrix)) {
    loading_str <- paste(result$loading_matrix, collapse = " ")
    # Should have "-.XXX" not "-0.XXX" for negative values
    expect_false(grepl("-0\\.[0-9]", loading_str))
  }
})
