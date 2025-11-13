# Tests for FA Prompt Builder Methods
# Focus: build_system_prompt() and build_main_prompt() with model_type = "fa"

# ==============================================================================
# SETUP: Create Mock Data
# ==============================================================================

create_mock_prompt_data <- function() {
  list(
    loadings_df = data.frame(
      variable = c("var1", "var2", "var3"),
      MR1 = c(0.8, 0.7, 0.1),
      MR2 = c(0.1, 0.2, 0.9),
      stringsAsFactors = FALSE
    ),
    factor_summaries = list(
      MR1 = list(
        variables = data.frame(
          variable = c("var1", "var2"),
          loading = c(0.8, 0.7),
          stringsAsFactors = FALSE
        ),
        used_emergency_rule = FALSE
      ),
      MR2 = list(
        variables = data.frame(
          variable = "var3",
          loading = 0.9,
          stringsAsFactors = FALSE
        ),
        used_emergency_rule = FALSE
      )
    ),
    factor_cols = c("MR1", "MR2"),
    n_factors = 2,
    n_variables = 3,
    cutoff = 0.3,
    n_emergency = 2,
    hide_low_loadings = FALSE,
    factor_cor_mat = NULL
  )
}

create_mock_variable_info <- function() {
  data.frame(
    variable = c("var1", "var2", "var3"),
    description = c("Variable 1 description", "Variable 2 description", "Variable 3 description"),
    stringsAsFactors = FALSE
  )
}

# ==============================================================================
# BUILD_SYSTEM_PROMPT.FA() TESTS
# ==============================================================================

test_that("build_system_prompt (FA)returns character string", {
  model_type <- structure("fa", class = "fa")

  result <- build_system_prompt(model_type, word_limit = 100)

  expect_type(result, "character")
  expect_length(result, 1)
  expect_gt(nchar(result), 0)
})

test_that("build_system_prompt (FA)includes required sections", {
  model_type <- structure("fa", class = "fa")

  result <- build_system_prompt(model_type, word_limit = 100)

  # Check for key sections
  expect_match(result, "ROLE", ignore.case = TRUE)
  expect_match(result, "TASK", ignore.case = TRUE)
  expect_match(result, "KEY DEFINITIONS", ignore.case = TRUE)
})

test_that("build_system_prompt (FA)includes key FA concepts", {
  model_type <- structure("fa", class = "fa")

  result <- build_system_prompt(model_type, word_limit = 100)

  # Check for important FA terminology
  expect_match(result, "Loading", ignore.case = TRUE)
  expect_match(result, "Convergent validity", ignore.case = TRUE)
  expect_match(result, "Discriminant validity", ignore.case = TRUE)
  expect_match(result, "Factor correlation", ignore.case = TRUE)
  expect_match(result, "Emergency rule", ignore.case = TRUE)
})

test_that("build_system_prompt (FA)mentions psychometrician role", {
  model_type <- structure("fa", class = "fa")

  result <- build_system_prompt(model_type)

  expect_match(result, "psychometrician", ignore.case = TRUE)
  expect_match(result, "expert", ignore.case = TRUE)
})

test_that("build_system_prompt (FA)handles different word limits", {
  model_type <- structure("fa", class = "fa")

  result1 <- build_system_prompt(model_type, word_limit = 50)
  result2 <- build_system_prompt(model_type, word_limit = 200)

  # System prompt should be same regardless of word limit
  # (word limit affects instructions in main prompt, not system prompt)
  expect_equal(result1, result2)
})

test_that("build_system_prompt (FA)works with minimal arguments", {
  model_type <- structure("fa", class = "fa")

  # Should work with just model_type
  expect_no_error({
    result <- build_system_prompt(model_type)
  })
})

# ==============================================================================
# BUILD_MAIN_PROMPT.FA() TESTS
# ==============================================================================

test_that("build_main_prompt (FA)returns character string with valid inputs", {
  model_type <- structure("fa", class = "fa")
  model_data <- create_mock_prompt_data()
  var_info <- create_mock_variable_info()

  result <- build_main_prompt(
    model_type,
    model_data,
    word_limit = 100,
    variable_info = var_info
  )

  expect_type(result, "character")
  expect_length(result, 1)
  expect_gt(nchar(result), 0)
})

test_that("build_main_prompt (FA)requires variable_info", {
  model_type <- structure("fa", class = "fa")
  model_data <- create_mock_prompt_data()

  expect_error(
    build_main_prompt(model_type, model_data, word_limit = 100),
    "variable_info.*required"
  )
})

test_that("build_main_prompt (FA)includes factor loadings table", {
  model_type <- structure("fa", class = "fa")
  model_data <- create_mock_prompt_data()
  var_info <- create_mock_variable_info()

  result <- build_main_prompt(
    model_type,
    model_data,
    word_limit = 100,
    variable_info = var_info
  )

  # Should mention factors
  expect_match(result, "MR1", fixed = TRUE)
  expect_match(result, "MR2", fixed = TRUE)

  # Should mention variables
  expect_match(result, "var1", fixed = TRUE)
  expect_match(result, "var2", fixed = TRUE)
  expect_match(result, "var3", fixed = TRUE)
})

test_that("build_main_prompt (FA)includes variable descriptions", {
  model_type <- structure("fa", class = "fa")
  model_data <- create_mock_prompt_data()
  var_info <- create_mock_variable_info()

  result <- build_main_prompt(
    model_type,
    model_data,
    word_limit = 100,
    variable_info = var_info
  )

  # Should include variable descriptions
  expect_match(result, "Variable 1 description", fixed = TRUE)
  expect_match(result, "Variable 2 description", fixed = TRUE)
  expect_match(result, "Variable 3 description", fixed = TRUE)
})

test_that("build_main_prompt (FA)mentions word limit", {
  model_type <- structure("fa", class = "fa")
  model_data <- create_mock_prompt_data()
  var_info <- create_mock_variable_info()

  result <- build_main_prompt(
    model_type,
    model_data,
    word_limit = 150,
    variable_info = var_info
  )

  # Should mention the word limit
  expect_match(result, "150")
})

test_that("build_main_prompt (FA)includes cutoff information", {
  model_type <- structure("fa", class = "fa")
  model_data <- create_mock_prompt_data()
  var_info <- create_mock_variable_info()

  result <- build_main_prompt(
    model_type,
    model_data,
    word_limit = 100,
    variable_info = var_info
  )

  # Should mention cutoff value
  expect_match(result, "0\\.3")
})

test_that("build_main_prompt (FA)handles additional_info parameter", {
  model_type <- structure("fa", class = "fa")
  model_data <- create_mock_prompt_data()
  var_info <- create_mock_variable_info()

  result_without <- build_main_prompt(
    model_type,
    model_data,
    word_limit = 100,
    variable_info = var_info,
    additional_info = NULL
  )

  result_with <- build_main_prompt(
    model_type,
    model_data,
    word_limit = 100,
    variable_info = var_info,
    additional_info = "This is a personality study"
  )

  # With additional info should be longer
  expect_gt(nchar(result_with), nchar(result_without))
  expect_match(result_with, "personality study", ignore.case = TRUE)
})

test_that("build_main_prompt (FA)handles factor correlations when present", {
  model_type <- structure("fa", class = "fa")
  model_data <- create_mock_prompt_data()
  model_data$factor_cor_mat <- matrix(
    c(1.0, 0.3, 0.3, 1.0),
    nrow = 2,
    dimnames = list(c("MR1", "MR2"), c("MR1", "MR2"))
  )
  var_info <- create_mock_variable_info()

  result <- build_main_prompt(
    model_type,
    model_data,
    word_limit = 100,
    variable_info = var_info
  )

  # Should mention factor correlations
  expect_match(result, "correlation", ignore.case = TRUE)
})

test_that("build_main_prompt (FA)handles orthogonal factors (no correlation matrix)", {
  model_type <- structure("fa", class = "fa")
  model_data <- create_mock_prompt_data()
  model_data$factor_cor_mat <- NULL  # Orthogonal rotation
  var_info <- create_mock_variable_info()

  result <- build_main_prompt(
    model_type,
    model_data,
    word_limit = 100,
    variable_info = var_info
  )

  # Should still work without factor correlations
  expect_type(result, "character")
  expect_gt(nchar(result), 0)
})

test_that("build_main_prompt (FA)respects hide_low_loadings parameter", {
  model_type <- structure("fa", class = "fa")

  # Create data with low loadings
  model_data_show <- create_mock_prompt_data()
  model_data_show$hide_low_loadings <- FALSE

  model_data_hide <- create_mock_prompt_data()
  model_data_hide$hide_low_loadings <- TRUE

  var_info <- create_mock_variable_info()

  result_show <- build_main_prompt(
    model_type,
    model_data_show,
    word_limit = 100,
    variable_info = var_info
  )

  result_hide <- build_main_prompt(
    model_type,
    model_data_hide,
    word_limit = 100,
    variable_info = var_info
  )

  # Hidden version should be shorter (fewer loadings displayed)
  expect_lt(nchar(result_hide), nchar(result_show))
})

test_that("build_main_prompt (FA)mentions emergency rule when n_emergency > 0", {
  model_type <- structure("fa", class = "fa")
  model_data <- create_mock_prompt_data()
  model_data$n_emergency <- 3
  var_info <- create_mock_variable_info()

  result <- build_main_prompt(
    model_type,
    model_data,
    word_limit = 100,
    variable_info = var_info
  )

  # Should mention emergency rule
  expect_match(result, "emergency", ignore.case = TRUE)
  expect_match(result, "3")
})

test_that("build_main_prompt (FA)handles n_emergency = 0", {
  model_type <- structure("fa", class = "fa")
  model_data <- create_mock_prompt_data()
  model_data$n_emergency <- 0
  var_info <- create_mock_variable_info()

  result <- build_main_prompt(
    model_type,
    model_data,
    word_limit = 100,
    variable_info = var_info
  )

  # Should mention undefined factors
  expect_match(result, "undefined", ignore.case = TRUE)
})

test_that("build_main_prompt (FA)requests JSON output format", {
  model_type <- structure("fa", class = "fa")
  model_data <- create_mock_prompt_data()
  var_info <- create_mock_variable_info()

  result <- build_main_prompt(
    model_type,
    model_data,
    word_limit = 100,
    variable_info = var_info
  )

  # Should request JSON format
  expect_match(result, "JSON", ignore.case = TRUE)
})

# ==============================================================================
# INTEGRATION TESTS WITH REAL MODEL DATA
# ==============================================================================

test_that("Prompt builders work with real FA model data", {
  skip_if_not_installed("psych")

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Build real model data
  model_data <- psychinterpreter:::build_model_data.fa(
    fa_model,
    model_type = "fa",
    interpretation_args = interpretation_args(model_type = "fa"),
    variable_info = var_info
  )

  model_type <- structure("fa", class = "fa")

  # Test system prompt
  system_prompt <- build_system_prompt(model_type, word_limit = 100)
  expect_type(system_prompt, "character")
  expect_gt(nchar(system_prompt), 100)

  # Test main prompt
  main_prompt <- build_main_prompt(
    model_type,
    model_data,
    word_limit = 100,
    variable_info = var_info
  )
  expect_type(main_prompt, "character")
  expect_gt(nchar(main_prompt), 200)
})

test_that("Prompts include all required information for LLM", {
  skip_if_not_installed("psych")

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  model_data <- psychinterpreter:::build_model_data.fa(
    fa_model,
    model_type = "fa",
    interpretation_args = interpretation_args(model_type = "fa"),
    variable_info = var_info
  )

  model_type <- structure("fa", class = "fa")

  system_prompt <- build_system_prompt(model_type)
  main_prompt <- build_main_prompt(
    model_type,
    model_data,
    word_limit = 100,
    variable_info = var_info
  )

  # System prompt should define key concepts
  expect_match(system_prompt, "Loading")
  expect_match(system_prompt, "convergent", ignore.case = TRUE)

  # Main prompt should have data and instructions
  expect_match(main_prompt, "JSON")
  expect_match(main_prompt, "interpretation")

  # Both should be substantial
  expect_gt(nchar(system_prompt), 300)
  expect_gt(nchar(main_prompt), 300)
})

test_that("Prompt builders handle edge cases gracefully", {
  model_type <- structure("fa", class = "fa")

  # Single factor
  model_data_single <- create_mock_prompt_data()
  model_data_single$n_factors <- 1
  model_data_single$factor_cols <- "MR1"
  model_data_single$factor_summaries <- model_data_single$factor_summaries[1]
  model_data_single$loadings_df <- model_data_single$loadings_df[, c("variable", "MR1")]

  var_info <- create_mock_variable_info()

  result_single <- build_main_prompt(
    model_type,
    model_data_single,
    word_limit = 100,
    variable_info = var_info
  )

  expect_type(result_single, "character")
  expect_gt(nchar(result_single), 0)
})

test_that("Prompt consistency: same inputs produce same outputs", {
  model_type <- structure("fa", class = "fa")
  model_data <- create_mock_prompt_data()
  var_info <- create_mock_variable_info()

  result1 <- build_main_prompt(
    model_type,
    model_data,
    word_limit = 100,
    variable_info = var_info
  )

  result2 <- build_main_prompt(
    model_type,
    model_data,
    word_limit = 100,
    variable_info = var_info
  )

  expect_equal(result1, result2)
})
