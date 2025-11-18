# Mock LLM Helper Functions
# Enables testing of error scenarios and edge cases without actual LLM calls
# Part of Phase 2 Test Optimization (2.1)

# Mock Provider S4 Class
# Define a simple S4 class to mock provider objects
setClass("MockProvider", slots = c(name = "character"))

#' Create mock LLM response
#'
#' @param response_type Type of response: "success", "malformed_json", "error", "timeout", "partial", "empty"
#' @param content Optional custom content
#' @param ... Additional parameters
#' @return List mimicking ellmer chat response structure
#' @noRd
mock_llm_response <- function(response_type = "success", content = NULL, ...) {
  # Dispatch table for response generators
  response_generators <- list(
    "success" = function(content) {
      list(
        content = content %||% '{
          "suggested_names": {
            "F1": "Test Factor 1",
            "F2": "Test Factor 2"
          },
          "component_summaries": {
            "F1": {
              "llm_interpretation": "This factor represents test construct 1.",
              "variables": [
                {"variable": "v1", "loading": 0.85, "description": "Variable 1"},
                {"variable": "v2", "loading": 0.75, "description": "Variable 2"}
              ],
              "used_emergency_rule": false
            },
            "F2": {
              "llm_interpretation": "This factor represents test construct 2.",
              "variables": [
                {"variable": "v3", "loading": 0.70, "description": "Variable 3"}
              ],
              "used_emergency_rule": false
            }
          }
        }',
        input_tokens = 100,
        output_tokens = 50
      )
    },
    "malformed_json" = function(content) {
      list(
        content = content %||% '{suggested_names": {"F1": "Test Factor"}',  # Missing opening brace
        input_tokens = 100,
        output_tokens = 20
      )
    },
    "partial" = function(content) {
      list(
        content = content %||% '{
          "suggested_names": {
            "F1": "Test Factor"
          }
        }',  # Missing component_summaries
        input_tokens = 100,
        output_tokens = 30
      )
    },
    "empty" = function(content) {
      list(
        content = content %||% '{}',
        input_tokens = 100,
        output_tokens = 5
      )
    },
    "error" = function(content) {
      stop("API Error: 500 Internal Server Error")
    },
    "timeout" = function(content) {
      stop("Request timeout after 30 seconds")
    },
    "rate_limit" = function(content) {
      stop("API Error: 429 Too Many Requests")
    },
    "unicode" = function(content) {
      list(
        content = content %||% '{
          "MR1": {
            "name": "Extraversion 😊 - High sociability and energy",
            "interpretation": "This factor captures outgoing 😊 social behavior with émotions positives."
          },
          "MR2": {
            "name": "Conscientiousness 📋 - Organisation et diligence",
            "interpretation": "Conscientiousness involves self-discipline and organisation 📋."
          }
        }',
        input_tokens = 100,
        output_tokens = 60
      )
    },
    "very_long" = function(content) {
      long_text <- paste(rep("Very detailed interpretation with lots of words. ", 500), collapse = "")
      long_text2 <- paste(rep("Another very long interpretation here. ", 500), collapse = "")
      list(
        content = content %||% paste0('{
          "MR1": {
            "name": "Test Factor 1",
            "interpretation": "', long_text, '"
          },
          "MR2": {
            "name": "Test Factor 2",
            "interpretation": "', long_text2, '"
          }
        }'),
        input_tokens = 100,
        output_tokens = 5000
      )
    },
    "html_artifacts" = function(content) {
      list(
        content = content %||% '```json
{
  "MR1": {
    "name": "Extraversion",
    "interpretation": "This factor represents high sociability"
  },
  "MR2": {
    "name": "Conscientiousness",
    "interpretation": "This factor represents high organization"
  }
}
```',
        input_tokens = 100,
        output_tokens = 50
      )
    },
    "provider_error_openai" = function(content) {
      stop(structure(
        list(
          message = "Rate limit exceeded",
          error = list(
            message = "Rate limit exceeded",
            type = "rate_limit_error",
            param = NULL,
            code = "rate_limit_exceeded"
          )
        ),
        class = c("openai_error", "error", "condition")
      ))
    },
    "provider_error_anthropic" = function(content) {
      stop(structure(
        list(
          message = "Rate limit exceeded. Please try again later.",
          error = list(
            type = "rate_limit_error",
            message = "Rate limit exceeded. Please try again later."
          )
        ),
        class = c("anthropic_error", "error", "condition")
      ))
    }
  )

  # Look up response type in dispatch table
  if (!response_type %in% names(response_generators)) {
    stop("Unknown response_type: ", response_type)
  }

  # Call the appropriate generator function
  response_generators[[response_type]](content)
}

#' Create mock chat object
#'
#' @param response_type Type of response for chat method
#' @param ... Additional parameters passed to mock_llm_response
#' @return Mock chat object compatible with ellmer::chat
#' @noRd
mock_chat <- function(response_type = "success", ...) {
  # Store response type for later use
  stored_response_type <- response_type
  stored_dots <- list(...)

  chat_obj <- list(
    chat = function(prompt, echo = "none", ...) {
      mock_llm_response(stored_response_type, ...)
    },
    get_turns = function() list(),
    extract_data = function(...) list(),
    get_tokens = function() {
      # Return mock token data frame
      data.frame(
        role = c("user", "assistant"),
        tokens = c(100, 50),
        stringsAsFactors = FALSE
      )
    },
    get_provider = function() {
      # Return S4 mock provider object
      new("MockProvider", name = "mock")
    },
    get_model = function() {
      "mock-model"
    },
    clone = function() {
      # Return a clone of the chat object
      mock_chat_clone <- list(
        chat = function(prompt, echo = "none", ...) {
          mock_llm_response(stored_response_type, ...)
        },
        get_turns = function() list(),
        extract_data = function(...) list(),
        get_tokens = function() {
          # Return mock token data frame
          data.frame(
            role = c("user", "assistant"),
            tokens = c(100, 50),
            stringsAsFactors = FALSE
          )
        },
        get_provider = function() {
          # Return S4 mock provider object
          new("MockProvider", name = "mock")
        },
        get_model = function() {
          "mock-model"
        },
        set_turns = function(turns) {
          # Return self for chaining
          mock_chat_clone
        }
      )
      mock_chat_clone
    }
  )
  chat_obj
}

#' Create mock chat_session for testing
#'
#' @param analysis_type Analysis type (default "fa")
#' @param response_type Type of LLM response (default "success")
#' @param ... Additional parameters
#' @return Mock chat_session object
#' @noRd
mock_chat_session <- function(analysis_type = "fa", response_type = "success", ...) {
  structure(
    list(
      chat = mock_chat(response_type, ...),
      analysis_type = analysis_type,
      n_interpretations = 0,
      total_input_tokens = 0,
      total_output_tokens = 0,
      llm_provider = "mock",
      llm_model = "mock-model",
      created_at = Sys.time()
    ),
    class = c(paste0(analysis_type, "_chat_session"), "chat_session")
  )
}

#' Test JSON parsing with various error scenarios
#'
#' Helper function to test the multi-tier JSON parsing fallback system
#'
#' @param scenario One of "valid", "malformed", "partial", "empty"
#' @return Parsed result from parse_llm_response
#' @noRd
#'
#' @examples
#' \dontrun{
#' # Test malformed JSON handling
#' result <- test_json_parsing("malformed")
#' expect_true(inherits(result, "list"))
#' }
test_json_parsing <- function(scenario = c("valid", "malformed", "partial", "empty")) {
  scenario <- match.arg(scenario)

  # Dispatch table for JSON scenarios
  json_scenarios <- list(
    "valid" = '{
      "suggested_names": {"F1": "Factor 1", "F2": "Factor 2"},
      "component_summaries": {
        "F1": {
          "llm_interpretation": "Summary 1",
          "variables": [{"variable": "v1", "loading": 0.85, "description": "Var 1"}],
          "used_emergency_rule": false
        },
        "F2": {
          "llm_interpretation": "Summary 2",
          "variables": [{"variable": "v2", "loading": 0.75, "description": "Var 2"}],
          "used_emergency_rule": false
        }
      }
    }',
    "malformed" = '{suggested_names": {"F1": "Factor 1"}',  # Missing opening brace
    "partial" = '{"suggested_names": {"F1": "Factor 1"}}',  # Missing component_summaries
    "empty" = '{}'
  )

  # Look up scenario in dispatch table
  if (!scenario %in% names(json_scenarios)) {
    stop("Unknown scenario: ", scenario)
  }

  response_content <- json_scenarios[[scenario]]

  # Attempt to parse (should use fallback mechanisms)
  psychinterpreter:::parse_llm_response(
    response = list(content = response_content),
    analysis_type = "fa",
    factor_names = c("F1", "F2")
  )
}

#' Create mock FA model object
#'
#' Creates a minimal mock FA object that mimics psych::fa() structure
#' Useful for testing extraction and validation logic
#'
#' @param n_factors Number of factors (default 2)
#' @param n_vars Number of variables (default 3)
#' @return Mock FA object with minimal structure
#' @noRd
mock_fa_model <- function(n_factors = 2, n_vars = 3) {
  # Create loadings matrix
  loadings_matrix <- matrix(
    runif(n_vars * n_factors, -0.9, 0.9),
    nrow = n_vars,
    ncol = n_factors,
    dimnames = list(
      paste0("v", 1:n_vars),
      paste0("F", 1:n_factors)
    )
  )

  # Add class for loadings
  class(loadings_matrix) <- c("loadings", "matrix")

  # Create minimal fa object structure
  structure(
    list(
      loadings = loadings_matrix,
      Phi = diag(n_factors),  # Orthogonal rotation
      factors = n_factors,
      n.obs = 100,
      communality = runif(n_vars, 0.3, 0.9),
      uniquenesses = runif(n_vars, 0.1, 0.7),
      fit = list(
        TLI = 0.95,
        RMSEA = c(RMSEA = 0.05, lower = 0.03, upper = 0.07),
        BIC = -50
      )
    ),
    class = c("fa", "psych")
  )
}

#' Create mock interpretation result
#'
#' Creates a complete mock interpretation object for testing
#' Mimics the structure returned by interpret()
#'
#' @param analysis_type Analysis type (default "fa")
#' @param n_factors Number of factors (default 2)
#' @param output_format Output format (default "text")
#' @return Mock interpretation object
#' @noRd
mock_interpretation <- function(analysis_type = "fa", n_factors = 2, output_format = "text") {
  # Create component summaries
  component_summaries <- lapply(1:n_factors, function(i) {
    list(
      llm_interpretation = paste("Mock interpretation for Factor", i),
      variables = data.frame(
        variable = paste0("v", i),
        loading = 0.8,
        description = paste("Variable", i),
        stringsAsFactors = FALSE
      ),
      used_emergency_rule = FALSE
    )
  })
  names(component_summaries) <- paste0("F", 1:n_factors)

  # Create suggested names
  suggested_names <- setNames(
    paste("Mock Factor", 1:n_factors),
    paste0("F", 1:n_factors)
  )

  # Create mock report
  report <- paste(
    "Mock Factor Analysis Interpretation",
    "",
    paste0("Factor ", 1:n_factors, ": ", suggested_names, collapse = "\n"),
    sep = "\n"
  )

  structure(
    list(
      component_summaries = component_summaries,
      suggested_names = suggested_names,
      analysis_type = analysis_type,
      timestamp = Sys.time(),
      report = report,
      input_tokens = 100,
      output_tokens = 50,
      total_tokens = 150,
      llm_provider = "mock",
      llm_model = "mock-model",
      output_format = output_format
    ),
    class = c(paste0(analysis_type, "_interpretation"), "interpretation")
  )
}
