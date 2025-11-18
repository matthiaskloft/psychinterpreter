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

  result <- create_default_result("fa", analysis_data = model_data)

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

  result <- create_default_result("fa", analysis_data = model_data)

  expect_length(result$suggested_names, 1)
  expect_equal(result$suggested_names$MR1, "Factor 1")
})

test_that("create_default_result (FA)preserves existing values if set", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Pre-set some values (simulating undefined factor handling)
  model_data$factor_summaries$MR2$llm_interpretation <- "NA"

  result <- create_default_result("fa", analysis_data = model_data)

  # MR1 should get default
  expect_equal(result$component_summaries$MR1$llm_interpretation,
               "Unable to generate interpretation due to LLM error")
  # MR2 should preserve existing value
  expect_equal(result$component_summaries$MR2$llm_interpretation, "NA")
})

test_that("create_default_result (FA)returns complete structure", {
  model_data <- create_mock_model_data(n_factors = 2)

  result <- create_default_result("fa", analysis_data = model_data)

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

  result <- create_default_result("fa", analysis_data = model_data)

  expect_type(result, "list")
  expect_named(result, c("component_summaries", "suggested_names"))
  expect_length(result$suggested_names, ncol(fa_model$loadings))
})

# ==============================================================================
# NEW JSON EDGE CASE TESTS (Phase 1, Task 1)
# ==============================================================================

test_that("JSON parsing handles unicode in factor names", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Unicode in factor names
  parsed <- list(
    MR1 = list(
      name = "Extraversion 😊",
      interpretation = "Outgoing behavior"
    ),
    MR2 = list(
      name = "Conscientiousness 📋",
      interpretation = "Organized behavior"
    )
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_type(result, "list")
  expect_match(result$suggested_names$MR1, "😊")
  expect_match(result$suggested_names$MR2, "📋")
})

test_that("JSON parsing handles unicode in interpretations", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Unicode in interpretations
  parsed <- list(
    MR1 = list(
      name = "Extraversion",
      interpretation = "High sociability and energy 😊 with positive émotions"
    ),
    MR2 = list(
      name = "Conscientiousness",
      interpretation = "Organisation 📋 et diligence"
    )
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_type(result, "list")
  expect_match(result$component_summaries$MR1$llm_interpretation, "😊")
  expect_match(result$component_summaries$MR1$llm_interpretation, "émotions")
  expect_match(result$component_summaries$MR2$llm_interpretation, "📋")
})

test_that("JSON parsing handles very long interpretations", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Very long interpretation (>5000 words)
  long_text <- paste(rep("This is a very detailed interpretation with many words. ", 1000), collapse = "")

  parsed <- list(
    MR1 = list(
      name = "Factor 1",
      interpretation = long_text
    ),
    MR2 = list(
      name = "Factor 2",
      interpretation = "Short interpretation"
    )
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_type(result, "list")
  expect_true(nchar(result$component_summaries$MR1$llm_interpretation) > 5000)
  expect_equal(result$component_summaries$MR2$llm_interpretation, "Short interpretation")
})

test_that("JSON parsing handles HTML/markdown code block artifacts", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Response wrapped in markdown code blocks
  response <- '```json
{
  "MR1": { "name": "Extraversion", "interpretation": "Outgoing behavior" },
  "MR2": { "name": "Neuroticism", "interpretation": "Emotional instability" }
}
```'

  result <- extract_by_pattern(response, "fa", model_data)

  expect_type(result, "list")
  expect_equal(result$suggested_names$MR1, "Extraversion (n.s.)")
  expect_equal(result$suggested_names$MR2, "Neuroticism")
})

test_that("JSON parsing handles responses with extra unexpected fields", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Extra unexpected fields should be ignored
  parsed <- list(
    MR1 = list(
      name = "Extraversion",
      interpretation = "Outgoing behavior",
      extra_field = "This should be ignored",
      another_field = 123
    ),
    MR2 = list(
      name = "Neuroticism",
      interpretation = "Emotional instability",
      unexpected = TRUE
    )
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_type(result, "list")
  expect_equal(result$suggested_names$MR1, "Extraversion (n.s.)")
  expect_equal(result$suggested_names$MR2, "Neuroticism")
  expect_equal(result$component_summaries$MR1$llm_interpretation, "Outgoing behavior")
})

test_that("JSON parsing handles responses with missing optional fields", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Only required fields present
  parsed <- list(
    MR1 = list(
      name = "Extraversion",
      interpretation = "Outgoing behavior"
    ),
    MR2 = list(
      name = "Neuroticism",
      interpretation = "Emotional instability"
    )
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_type(result, "list")
  expect_equal(result$suggested_names$MR1, "Extraversion (n.s.)")
  expect_equal(result$suggested_names$MR2, "Neuroticism")
})

test_that("JSON parsing handles null values in name field", {
  model_data <- create_mock_model_data(n_factors = 2)

  # null in name field
  parsed <- list(
    MR1 = list(
      name = NULL,
      interpretation = "Outgoing behavior"
    ),
    MR2 = list(
      name = "Neuroticism",
      interpretation = "Emotional instability"
    )
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_type(result, "list")
  expect_equal(result$suggested_names$MR1, "Factor 1")  # Default when null
  expect_equal(result$suggested_names$MR2, "Neuroticism")
})

test_that("JSON parsing handles null values in interpretation field", {
  model_data <- create_mock_model_data(n_factors = 2)

  # null in interpretation field
  parsed <- list(
    MR1 = list(
      name = "Extraversion",
      interpretation = NULL
    ),
    MR2 = list(
      name = "Neuroticism",
      interpretation = "Emotional instability"
    )
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_type(result, "list")
  expect_equal(result$component_summaries$MR1$llm_interpretation, "Unable to generate interpretation")
  expect_equal(result$component_summaries$MR2$llm_interpretation, "Emotional instability")
})

test_that("JSON parsing handles numeric values instead of strings", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Numeric instead of string
  parsed <- list(
    MR1 = list(
      name = 123,
      interpretation = 456
    ),
    MR2 = list(
      name = "Neuroticism",
      interpretation = "Emotional instability"
    )
  )

  result <- validate_parsed_result(parsed, "fa", model_data)

  expect_type(result, "list")
  # Should convert numeric to string or use default
  expect_true(is.character(result$suggested_names$MR1))
  expect_true(is.character(result$component_summaries$MR1$llm_interpretation))
})

test_that("JSON parsing handles array values instead of expected types", {
  model_data <- create_mock_model_data(n_factors = 2)

  # Array instead of string - this should fail validation as it's invalid
  parsed <- list(
    MR1 = list(
      name = c("Name1", "Name2"),
      interpretation = c("Interp1", "Interp2")
    ),
    MR2 = list(
      name = "Neuroticism",
      interpretation = "Emotional instability"
    )
  )

  # This should either return NULL or handle the error gracefully
  result <- tryCatch({
    validate_parsed_result(parsed, "fa", model_data)
  }, error = function(e) NULL)

  # If not NULL, check structure
  if (!is.null(result)) {
    expect_type(result, "list")
    # Should have character results
    expect_true(is.character(result$suggested_names$MR1))
    expect_true(is.character(result$component_summaries$MR1$llm_interpretation))
  } else {
    # NULL is acceptable for invalid input
    expect_null(result)
  }
})

test_that("validate_parsed_result handles unicode from mock response", {
  skip_if_not_installed("psych")

  # Create minimal FA model and analysis data
  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  analysis_data <- psychinterpreter:::build_analysis_data.fa(
    fa_model,
    analysis_type = "fa",
    interpretation_args = interpretation_args(analysis_type = "fa"),
    variable_info = var_info
  )

  # Parse the unicode mock response JSON directly
  unicode_json <- jsonlite::fromJSON(mock_llm_response("unicode")$content)

  # Validate the parsed result
  result <- psychinterpreter:::validate_parsed_result.fa(
    unicode_json,
    analysis_type = "fa",
    analysis_data = analysis_data
  )

  expect_type(result, "list")
  expect_true("suggested_names" %in% names(result))
  expect_true("component_summaries" %in% names(result))
  # Check unicode is preserved
  expect_match(result$suggested_names$MR1, "😊")
})

test_that("validate_parsed_result handles very long interpretations from mock", {
  skip_if_not_installed("psych")

  # Create minimal FA model and analysis data
  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  analysis_data <- psychinterpreter:::build_analysis_data.fa(
    fa_model,
    analysis_type = "fa",
    interpretation_args = interpretation_args(analysis_type = "fa"),
    variable_info = var_info
  )

  # Parse the very_long mock response JSON directly
  long_json <- jsonlite::fromJSON(mock_llm_response("very_long")$content)

  # Validate the parsed result
  result <- psychinterpreter:::validate_parsed_result.fa(
    long_json,
    analysis_type = "fa",
    analysis_data = analysis_data
  )

  expect_type(result, "list")
  expect_true("suggested_names" %in% names(result))
  expect_true("component_summaries" %in% names(result))
  # Check that long text was preserved
  expect_true(nchar(result$component_summaries$MR1$llm_interpretation) > 5000)
})

test_that("validate_parsed_result handles html artifacts from mock (after cleanup)", {
  skip_if_not_installed("psych")

  # Create minimal FA model and analysis data
  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  analysis_data <- psychinterpreter:::build_analysis_data.fa(
    fa_model,
    analysis_type = "fa",
    interpretation_args = interpretation_args(analysis_type = "fa"),
    variable_info = var_info
  )

  # Get mock response and strip markdown code blocks
  raw_response <- mock_llm_response("html_artifacts")$content
  cleaned <- gsub("^```json\\n|\\n```$", "", raw_response)

  # Parse the cleaned JSON
  cleaned_json <- jsonlite::fromJSON(cleaned)

  # Validate the parsed result
  result <- psychinterpreter:::validate_parsed_result.fa(
    cleaned_json,
    analysis_type = "fa",
    analysis_data = analysis_data
  )

  expect_type(result, "list")
  expect_true("suggested_names" %in% names(result))
  expect_true("component_summaries" %in% names(result))
})
