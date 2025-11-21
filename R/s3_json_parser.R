#' Core JSON Parsing Utilities
#'
#' Generic JSON parsing functions with multi-tier fallback strategy.
#' Model-specific validation and extraction delegated to S3 methods.
#'
#' @name json_parser
#' @keywords internal
NULL

#' Clean JSON Response
#'
#' Removes common prefixes, suffixes, and formatting issues that LLMs add.
#'
#' @param response Character. Raw LLM response text
#' @return Character. Cleaned JSON string
#' @keywords internal
clean_json_response <- function(response) {
  if (is.null(response) || !is.character(response) || length(response) == 0) {
    return(NULL)
  }

  cleaned <- response

  # Try to extract JSON block if response contains extra text
  json_match <- regexpr('\\{[\\s\\S]*\\}', response)
  if (json_match > 0) {
    cleaned <- regmatches(response, json_match)
  }

  # Remove common prefixes/suffixes that LLMs might add
  cleaned <- gsub("^[^{]*", "", cleaned)  # Remove text before first {
  cleaned <- gsub("[^}]*$", "", cleaned)  # Remove text after last }

  # Fix common JSON formatting issues specific to small models
  cleaned <- gsub("\\n\\s*", " ", cleaned)  # Remove newlines and extra spaces
  cleaned <- gsub("\\s+", " ", cleaned)     # Collapse multiple spaces
  cleaned <- gsub('(\\})\\s*("\\w+")\\s*:', '\\1, \\2:', cleaned)  # Add missing commas
  cleaned <- gsub(',\\s*}', '}', cleaned)   # Remove trailing commas

  return(trimws(cleaned))
}

#' Try Parsing JSON
#'
#' Attempt to parse JSON string with error handling.
#'
#' @param json_string Character. JSON string to parse
#' @return List or NULL. Parsed JSON object or NULL if parsing failed
#' @keywords internal
try_parse_json <- function(json_string) {
  if (is.null(json_string) || !is.character(json_string) || nchar(json_string) == 0) {
    return(NULL)
  }

  tryCatch(
    {
      jsonlite::fromJSON(json_string, simplifyVector = FALSE)
    },
    error = function(e) {
      NULL
    }
  )
}

#' Parse LLM JSON Response with Multi-Tier Fallback
#'
#' Implements robust JSON parsing with multiple fallback strategies.
#' Tier 1: Try parsing cleaned JSON
#' Tier 2: Try parsing original response
#' Tier 3: Pattern-based extraction (model-specific via S3)
#' Tier 4: Default values (model-specific via S3)
#'
#' @param response Character. Raw LLM response
#' @param analysis_type Character. Model type ("fa", "gm", "irt", "cdm")
#' @param ... Additional arguments passed to model-specific methods
#' @return List. Parsed and validated result
#' @keywords internal
parse_llm_response <- function(response, analysis_type, ...) {
  if (is.null(response)) {
    cli::cli_warn("LLM returned NULL response")
    return(create_default_result(analysis_type, ...))
  }

  # Tier 1: Try cleaning and parsing
  cleaned_response <- clean_json_response(response)
  parsed <- try_parse_json(cleaned_response)

  if (!is.null(parsed) && is.list(parsed)) {
    # Validate and return (model-specific validation via S3)
    validated <- validate_parsed_result(parsed, analysis_type, ...)
    if (!is.null(validated)) {
      return(validated)
    }
  }

  # Tier 2: Try original response
  parsed <- try_parse_json(response)

  if (!is.null(parsed) && is.list(parsed)) {
    validated <- validate_parsed_result(parsed, analysis_type, ...)
    if (!is.null(validated)) {
      return(validated)
    }
  }

  # Tier 3: Pattern-based extraction (model-specific)
  cli::cli_alert_info("Standard JSON parsing failed, attempting pattern-based extraction")
  extracted <- extract_by_pattern(response, analysis_type, ...)

  if (!is.null(extracted)) {
    return(extracted)
  }

  # Tier 4: Default fallback
  cli::cli_warn(
    c(
      "All JSON parsing methods failed",
      "i" = "Consider using a larger model for better JSON generation"
    )
  )
  return(create_default_result(analysis_type, ...))
}

#' Validate Parsed Result (S3 Generic)
#'
#' Model-specific validation of parsed JSON.
#' Should return the validated result or NULL if validation fails.
#'
#' @param parsed List. Parsed JSON object
#' @param analysis_type Character. Model type
#' @param ... Additional arguments for model-specific validation, including:
#'   - \code{analysis_data}: Standardized model data (required by most implementations)
#' @return List with model-specific structure, or NULL if validation fails. Structure by model:
#'   \itemize{
#'     \item FA: list(component_summaries = character vector of length n_factors,
#'                    suggested_names = character vector of length n_factors)
#'     \item GM: list(component_summaries = character vector of length n_clusters,
#'                    suggested_names = character vector of length n_clusters)
#'   }
#'
#' @details
#' This function validates that parsed JSON contains all required fields with correct
#' types and lengths. Validation checks include:
#' \itemize{
#'   \item Presence of required fields (component_summaries, suggested_names)
#'   \item Correct data types (character vectors)
#'   \item Correct lengths (matching number of components/clusters)
#' }
#'
#' @seealso [extract_by_pattern()] for fallback extraction, [create_default_result()] for defaults
#'
#' @export
#' @keywords internal
validate_parsed_result <- function(parsed, analysis_type, ...) {
  UseMethod("validate_parsed_result", structure(list(), class = analysis_type))
}

#' Extract by Pattern (S3 Generic)
#'
#' Model-specific pattern-based extraction when JSON parsing fails.
#'
#' @param response Character. Raw LLM response
#' @param analysis_type Character. Model type
#' @param ... Additional arguments for model-specific extraction, including:
#'   - \code{analysis_data}: Standardized model data (required by most implementations)
#' @return List with model-specific structure, or NULL if extraction failed:
#'   \itemize{
#'     \item FA: list(component_summaries = character vector, suggested_names = character vector)
#'     \item GM: list(component_summaries = character vector, suggested_names = character vector)
#'   }
#'
#' @details
#' This is a fallback extraction method used when standard JSON parsing fails.
#' It uses regex patterns to extract interpretations and names from unstructured
#' LLM responses. Pattern extraction looks for common formats like:
#' \itemize{
#'   \item "Factor 1:" or "Cluster 1:" followed by text
#'   \item Quoted names or labels
#'   \item Numbered lists
#' }
#'
#' @seealso [validate_parsed_result()] for primary parsing, [create_default_result()] for final fallback
#'
#' @export
#' @keywords internal
extract_by_pattern <- function(response, analysis_type, ...) {
  UseMethod("extract_by_pattern", structure(list(), class = analysis_type))
}

#' Create Default Result (S3 Generic)
#'
#' Model-specific default result when all parsing methods fail.
#'
#' @param analysis_type Character. Model type
#' @param ... Additional arguments for model-specific defaults, including:
#'   - \code{analysis_data}: Standardized model data (required by most implementations)
#' @return List with generic default values. Structure by model:
#'   \itemize{
#'     \item FA: list(component_summaries = "Factor \{i\} interpretation unavailable" for each factor,
#'                    suggested_names = "Factor\{i\}" for each factor)
#'     \item GM: list(component_summaries = "Cluster \{i\} interpretation unavailable" for each cluster,
#'                    suggested_names = "Cluster\{i\}" for each cluster)
#'   }
#'
#' @details
#' This is the final fallback when both JSON parsing and pattern extraction fail.
#' It generates placeholder interpretations that ensure the package can still
#' return a valid result object. The defaults are intentionally generic to
#' signal to users that LLM interpretation was unsuccessful.
#'
#' Users seeing these defaults should consider:
#' \itemize{
#'   \item Using a larger/better LLM model
#'   \item Checking LLM API connectivity
#'   \item Reviewing prompt construction (echo = "all")
#' }
#'
#' @seealso [validate_parsed_result()] for primary parsing, [extract_by_pattern()] for pattern extraction
#'
#' @export
#' @keywords internal
create_default_result <- function(analysis_type, ...) {
  UseMethod("create_default_result", structure(list(), class = analysis_type))
}

#' Default method for validate_parsed_result
#'
#' Throws an error when no model-specific method is found.
#'
#' @param parsed List. Parsed JSON object
#' @param analysis_type Character. Model type
#' @param ... Additional arguments (ignored)
#'
#' @return Does not return (throws error)
#' @export
#' @keywords internal
validate_parsed_result.default <- function(parsed, analysis_type, ...) {
  cli::cli_abort(
    c(
      "No validation method for model type: {.val {analysis_type}}",
      "i" = "Currently implemented: fa, gm (irt and cdm planned)"
    )
  )
}

#' Default method for extract_by_pattern
#'
#' Throws an error when no model-specific method is found.
#'
#' @param response Character. Raw LLM response
#' @param analysis_type Character. Model type
#' @param ... Additional arguments (ignored)
#'
#' @return Does not return (throws error)
#' @export
#' @keywords internal
extract_by_pattern.default <- function(response, analysis_type, ...) {
  cli::cli_abort(
    c(
      "No pattern extraction method for model type: {.val {analysis_type}}",
      "i" = "Currently implemented: fa, gm (irt and cdm planned)"
    )
  )
}

#' Default method for create_default_result
#'
#' Throws an error when no model-specific method is found.
#'
#' @param analysis_type Character. Model type
#' @param ... Additional arguments (ignored)
#'
#' @return Does not return (throws error)
#' @export
#' @keywords internal
create_default_result.default <- function(analysis_type, ...) {
  cli::cli_abort(
    c(
      "No default result method for model type: {.val {analysis_type}}",
      "i" = "Currently implemented: fa, gm (irt and cdm planned)"
    )
  )
}
