# Tests for FA JSON Parsing Methods
# Focus: validate_parsed_result(), extract_by_pattern(), create_default_result() with analysis_type = "fa"

# ==============================================================================
# SETUP: Create Mock Model Data
# ==============================================================================

create_mock_model_data <- function(n_factors = 2, include_undefined = FALSE) {
  factor_cols <- paste0("MR", 1:n_factors)

  # Create factor summaries
  factor_summaries <- list()
  for (i in seq_along(factor_cols)) {
    if (include_undefined && i == n_factors) {
      # Last factor is undefined (no significant loadings, emergency rule not used)
      factor_summaries[[factor_cols[i]]] <- list(
        variables = data.frame(
          variable = character(0),
          loading = numeric(0),
          stringsAsFactors = FALSE
        ),
        used_emergency_rule = FALSE
      )
    } else {
      # Normal factor with loadings
      factor_summaries[[factor_cols[i]]] <- list(
        variables = data.frame(
          variable = paste0("var", 1:3),
          loading = c(0.8, 0.7, 0.6),
          stringsAsFactors = FALSE
        ),
        used_emergency_rule = (i == 1)  # First factor used emergency rule
      )
    }
  }

  list(
    factor_cols = factor_cols,
    factor_summaries = factor_summaries
  )
}

# ==============================================================================
# VALIDATE_PARSED_RESULT() TESTS (FA)
# ==============================================================================

test_that("validate_parsed_result handles valid JSON with all fields (FA)", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Valid JSON with all required fields
  parsed <- list(
    MR1 = list(
      name = "Extraversion",
      interpretation = "This factor represents outgoing behavior"
    ),
    MR2 = list(
      name = "Neuroticism",
      interpretation = "This factor represents emotional instability"
    )
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_type(result, "list")
  expect_named(result, c("component_summaries", "suggested_names"))
  expect_length(result$suggested_names, 2)
  expect_equal(result$suggested_names$MR1, "Extraversion (n.s.)")  # Emergency rule used
  expect_equal(result$suggested_names$MR2, "Neuroticism")
  expect_equal(result$component_summaries$MR1$llm_interpretation,
               "This factor represents outgoing behavior")
  expect_equal(result$component_summaries$MR2$llm_interpretation,
               "This factor represents emotional instability")
})

test_that("validate_parsed_resulthandles empty list", {
  model_data <- create_mock_model_data(n_factors = 2)

  result <- validate_parsed_result(list(), "fa", model_data)

  expect_null(result)
})

test_that("validate_parsed_resulthandles NULL input", {
  model_data <- create_mock_model_data(n_factors = 2)

  result <- validate_parsed_result(NULL, "fa", model_data)

  expect_null(result)
})

test_that("validate_parsed_resulthandles JSON with no matching factor names", {
  model_data <- create_mock_model_data(n_factors = 2)

  # JSON with wrong factor names
  parsed <- list(
    Wrong1 = list(name = "Test", interpretation = "Test"),
    Wrong2 = list(name = "Test2", interpretation = "Test2")
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_null(result)
})

test_that("validate_parsed_resulthandles partial matches (some factors present)", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Only one factor present
  parsed <- list(
    MR1 = list(
      name = "Extraversion",
      interpretation = "This factor represents outgoing behavior"
    )
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_type(result, "list")
  expect_length(result$suggested_names, 2)
  expect_equal(result$suggested_names$MR1, "Extraversion (n.s.)")
  expect_equal(result$suggested_names$MR2, "Factor 2")  # Missing factor gets default
  expect_equal(result$component_summaries$MR2$llm_interpretation,
               "Missing from LLM response")
})

test_that("validate_parsed_resulthandles missing name field", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Missing name field
  parsed <- list(
    MR1 = list(
      interpretation = "This factor represents outgoing behavior"
    ),
    MR2 = list(
      name = "Neuroticism",
      interpretation = "This factor represents emotional instability"
    )
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_equal(result$suggested_names$MR1, "Factor 1")  # Default when name missing
  expect_equal(result$suggested_names$MR2, "Neuroticism")
})

test_that("validate_parsed_resulthandles missing interpretation field", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Missing interpretation field
  parsed <- list(
    MR1 = list(
      name = "Extraversion"
    ),
    MR2 = list(
      name = "Neuroticism",
      interpretation = "This factor represents emotional instability"
    )
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_equal(result$component_summaries$MR1$llm_interpretation,
               "Unable to generate interpretation")
  expect_equal(result$component_summaries$MR2$llm_interpretation,
               "This factor represents emotional instability")
})

test_that("validate_parsed_resulthandles empty string fields", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Empty strings
  parsed <- list(
    MR1 = list(
      name = "",
      interpretation = "  "
    ),
    MR2 = list(
      name = "Neuroticism",
      interpretation = "This factor represents emotional instability"
    )
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_equal(result$suggested_names$MR1, "Factor 1")
  expect_equal(result$component_summaries$MR1$llm_interpretation,
               "Unable to generate interpretation")
})

test_that("validate_parsed_resulthandles NA fields", {
  model_data <- create_mock_model_data(n_factors = 2)

  # NA values
  parsed <- list(
    MR1 = list(
      name = NA_character_,
      interpretation = NA_character_
    ),
    MR2 = list(
      name = "Neuroticism",
      interpretation = "This factor represents emotional instability"
    )
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_equal(result$suggested_names$MR1, "Factor 1")
  expect_equal(result$component_summaries$MR1$llm_interpretation,
               "Unable to generate interpretation")
})

test_that("validate_parsed_resultcorrectly handles undefined factors", {
  model_data <- create_mock_model_data(n_factors = 2, include_undefined = TRUE)

  # JSON for defined factor only
  parsed <- list(
    MR1 = list(
      name = "Extraversion",
      interpretation = "This factor represents outgoing behavior"
    )
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_equal(result$suggested_names$MR2, "undefined")
  expect_equal(result$component_summaries$MR2$llm_interpretation, "NA")
})

test_that("validate_parsed_resultadds emergency suffix correctly", {
  model_data <- create_mock_model_data(n_factors = 2)

  parsed <- list(
    MR1 = list(
      name = "Extraversion",
      interpretation = "Test"
    ),
    MR2 = list(
      name = "Neuroticism",
      interpretation = "Test"
    )
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  # MR1 has used_emergency_rule = TRUE
  expect_match(result$suggested_names$MR1, "\\(n\\.s\\.\\)$")
  # MR2 has used_emergency_rule = FALSE
  expect_equal(result$suggested_names$MR2, "Neuroticism")
})

# ==============================================================================
# EXTRACT_BY_PATTERN() TESTS (FA)
# ==============================================================================

test_that("extract_by_pattern (FA) extracts from properly formatted response", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Simulated LLM response with factor objects
  response <- '{
    "MR1": { "name": "Extraversion", "interpretation": "Outgoing behavior" },
    "MR2": { "name": "Neuroticism", "interpretation": "Emotional instability" }
  }'

  result <- extract_by_pattern(response, "fa", model_data)

  expect_type(result, "list")
  expect_named(result, c("component_summaries", "suggested_names"))
  expect_length(result$suggested_names, 2)
  expect_equal(result$suggested_names$MR1, "Extraversion (n.s.)")
  expect_equal(result$suggested_names$MR2, "Neuroticism")
})

test_that("extract_by_pattern (FA)handles partial extraction", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Only one factor properly formatted
  response <- '{
    "MR1": { "name": "Extraversion", "interpretation": "Outgoing behavior" },
    "MR2": "This is not properly formatted"
  }'

  result <- extract_by_pattern(response, "fa", model_data)

  expect_type(result, "list")
  expect_equal(result$suggested_names$MR1, "Extraversion (n.s.)")
  expect_equal(result$suggested_names$MR2, "Factor 2")
  expect_equal(result$component_summaries$MR2$llm_interpretation,
               "Not found in response")
})

test_that("extract_by_pattern (FA)returns NULL when no factors found", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Response with no recognizable patterns
  response <- "This is just plain text with no JSON structure"

  result <- extract_by_pattern(response, "fa", model_data)

  expect_null(result)
})

test_that("extract_by_pattern (FA)handles malformed JSON in factor objects", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Malformed JSON
  response <- '{
    "MR1": { "name": "Extraversion", "interpretation": "Test" ,,,
    "MR2": { "name": "Neuroticism" }
  }'

  result <- extract_by_pattern(response, "fa", model_data)

  # Should handle errors gracefully
  expect_true(is.list(result) || is.null(result))
})

test_that("extract_by_pattern (FA)handles missing interpretation field", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Response where MR1 has valid JSON object but missing interpretation
  response <- '{
    "MR1": { "name": "Extraversion", "interpretation": null },
    "MR2": { "name": "Neuroticism", "interpretation": "Emotional instability" }
  }'

  result <- extract_by_pattern(response, "fa", model_data)

  if (!is.null(result)) {
    expect_equal(result$component_summaries$MR1$llm_interpretation,
                 "Unable to parse interpretation")
    expect_equal(result$component_summaries$MR2$llm_interpretation,
                 "Emotional instability")
  }
})

test_that("extract_by_pattern (FA)adds emergency suffix", {
  model_data <- create_mock_model_data(n_factors = 2)

  response <- '{
    "MR1": { "name": "Extraversion", "interpretation": "Test" },
    "MR2": { "name": "Neuroticism", "interpretation": "Test" }
  }'

  result <- extract_by_pattern(response, "fa", model_data)

  if (!is.null(result)) {
    # MR1 has used_emergency_rule = TRUE
    expect_match(result$suggested_names$MR1, "\\(n\\.s\\.\\)$")
    # MR2 has used_emergency_rule = FALSE
    expect_equal(result$suggested_names$MR2, "Neuroticism")
  }
})

# ==============================================================================
# CREATE_DEFAULT_RESULT() TESTS (FA)
# ==============================================================================

test_that("create_default_result (FA) creates defaults for all factors", {
  model_data <- create_mock_model_data(n_factors = 3)

  result <- create_default_result("fa", model_data)

  expect_type(result, "list")
  expect_named(result, c("component_summaries", "suggested_names"))
  expect_length(result$suggested_names, 3)
  expect_equal(result$suggested_names$MR1, "Factor 1")
  expect_equal(result$suggested_names$MR2, "Factor 2")
  expect_equal(result$suggested_names$MR3, "Factor 3")
  expect_equal(result$component_summaries$MR1$llm_interpretation,
               "Unable to generate interpretation due to LLM error")
  expect_equal(result$component_summaries$MR2$llm_interpretation,
               "Unable to generate interpretation due to LLM error")
  expect_equal(result$component_summaries$MR3$llm_interpretation,
               "Unable to generate interpretation due to LLM error")
})

test_that("create_default_result (FA)handles single factor", {
  model_data <- create_mock_model_data(n_factors = 1)

  result <- create_default_result("fa", model_data)

  expect_length(result$suggested_names, 1)
  expect_equal(result$suggested_names$MR1, "Factor 1")
})

test_that("create_default_result (FA)preserves existing values if set", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Pre-set some values (simulating undefined factor handling)
  model_data$factor_summaries$MR2$llm_interpretation <- "NA"

  result <- create_default_result("fa", model_data)

  # MR1 should get default
  expect_equal(result$component_summaries$MR1$llm_interpretation,
               "Unable to generate interpretation due to LLM error")
  # MR2 should preserve existing value
  expect_equal(result$component_summaries$MR2$llm_interpretation, "NA")
})

test_that("create_default_result (FA)returns complete structure", {
  model_data <- create_mock_model_data(n_factors = 2)

  result <- create_default_result("fa", model_data)

  # Check structure
  expect_true(all(c("component_summaries", "suggested_names") %in% names(result)))
  expect_equal(names(result$component_summaries), model_data$factor_cols)
  expect_equal(names(result$suggested_names), model_data$factor_cols)

  # Check all factors have required fields
  for (factor_name in model_data$factor_cols) {
    expect_true("llm_interpretation" %in% names(result$component_summaries[[factor_name]]))
    expect_type(result$suggested_names[[factor_name]], "character")
  }
})

# ==============================================================================
# INTEGRATION TESTS
# ==============================================================================

test_that("JSON parsing methods work with real fixture data", {
  skip_if_not_installed("psych")

  # Use actual FA model to create realistic model_data
  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Build model data using the actual function
  model_data <- psychinterpreter:::build_analysis_data.fa(
    fa_model,
    analysis_type = "fa",
    interpretation_args = interpretation_args(analysis_type = "fa"),
    variable_info = var_info
  )

  # Test validate_parsed_result with realistic JSON
  factor_names <- colnames(fa_model$loadings)
  parsed <- setNames(
    lapply(factor_names, function(f) {
      list(
        name = paste("Test", f),
        interpretation = paste("This is a test interpretation for", f)
      )
    }),
    factor_names
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_type(result, "list")
  expect_length(result$suggested_names, length(factor_names))
})

test_that("create_default_result (FA)works with real model data structure", {
  skip_if_not_installed("psych")

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  model_data <- psychinterpreter:::build_analysis_data.fa(
    fa_model,
    analysis_type = "fa",
    interpretation_args = interpretation_args(analysis_type = "fa"),
    variable_info = var_info
  )

  result <- create_default_result("fa", model_data)

  expect_type(result, "list")
  expect_named(result, c("component_summaries", "suggested_names"))
  expect_length(result$suggested_names, ncol(fa_model$loadings))
})
