#' Factor Analysis JSON Parsing Methods
#'
#' S3 methods for parsing, validating, and extracting FA interpretation results
#' from LLM JSON responses. Implements the json_parser generics for FA.
#'
#' @name fa_json
#' @keywords internal
NULL

#' Validate Parsed JSON Result for Factor Analysis
#'
#' Checks that parsed JSON contains required fields and factor names.
#'
#' @param parsed List. Parsed JSON object
#' @param analysis_type Character. "fa"
#' @param analysis_data List. Contains factor_cols (factor names) and factor_summaries
#' @param ... Additional arguments (unused)
#'
#' @return List with component_summaries and suggested_names, or NULL if invalid
#' @export
#' @keywords internal
validate_parsed_result.fa <- function(parsed, analysis_type, analysis_data, ...) {
  factor_cols <- analysis_data$factor_cols
  factor_summaries <- analysis_data$factor_summaries

  # Check if parsed is a list and has factor names as keys
  if (!is.list(parsed) || length(parsed) == 0) {
    return(NULL)
  }

  # Check if at least some expected factor names are present
  matched_factors <- intersect(names(parsed), factor_cols)
  if (length(matched_factors) == 0) {
    return(NULL)
  }

  # Extract results for each factor
  suggested_names <- list()

  for (factor_name in factor_cols) {
    # Check if factor is undefined (n_emergency = 0 and no significant loadings)
    # Note: If emergency rule was used, the factor is NOT undefined
    is_undefined <- nrow(factor_summaries[[factor_name]]$variables) == 0 &&
                    !isTRUE(factor_summaries[[factor_name]]$used_emergency_rule)

    if (is_undefined) {
      # For undefined factors, use special values
      suggested_names[[factor_name]] <- "undefined"
      factor_summaries[[factor_name]]$llm_interpretation <- "NA"
    } else if (factor_name %in% names(parsed)) {
      factor_data <- parsed[[factor_name]]

      # Extract name
      suggested_name <- if (!is.null(factor_data$name) &&
                            !is.na(factor_data$name) &&
                            nchar(trimws(factor_data$name)) > 0) {
        name_text <- trimws(factor_data$name)
        # Add (n.s.) suffix if emergency rule was used
        add_emergency_suffix(
          name_text,
          factor_summaries[[factor_name]]$used_emergency_rule
        )
      } else {
        paste("Factor", which(factor_cols == factor_name))
      }

      # Extract interpretation
      interpretation <- if (!is.null(factor_data$interpretation) &&
                            !is.na(factor_data$interpretation) &&
                            nchar(trimws(factor_data$interpretation)) > 0) {
        trimws(factor_data$interpretation)
      } else {
        "Unable to generate interpretation"
      }

      # Store results
      suggested_names[[factor_name]] <- suggested_name
      factor_summaries[[factor_name]]$llm_interpretation <- interpretation

      # Check word count (optional - for consistency with original code)
      # Note: This requires access to count_words() from utils
      # We'll handle this in the calling code
    } else {
      # Factor missing from response
      suggested_names[[factor_name]] <- paste("Factor", which(factor_cols == factor_name))
      factor_summaries[[factor_name]]$llm_interpretation <- "Missing from LLM response"
    }
  }

  return(list(
    component_summaries = factor_summaries,
    suggested_names = suggested_names
  ))
}

#' Extract Factor Analysis Results by Pattern
#'
#' Fallback extraction when JSON parsing fails. Uses regex patterns to
#' extract factor names and interpretations from raw LLM response.
#'
#' @param response Character. Raw LLM response
#' @param analysis_type Character. "fa"
#' @param analysis_data List. Contains factor_cols and factor_summaries
#' @param ... Additional arguments (unused)
#'
#' @return List with component_summaries and suggested_names, or NULL if extraction failed
#' @export
#' @keywords internal
extract_by_pattern.fa <- function(response, analysis_type, analysis_data, ...) {
  factor_cols <- analysis_data$factor_cols
  factor_summaries <- analysis_data$factor_summaries

  suggested_names <- list()
  extraction_successful <- FALSE

  # Try to extract factor information using patterns
  # Look for factor names as keys with nested objects
  for (i in seq_along(factor_cols)) {
    factor_name <- factor_cols[i]

    # Pattern: Look for "FactorName": { "name": "...", "interpretation": "..." }
    pattern <- paste0(
      '"',
      factor_name,
      '"\\s*:\\s*\\{[^{}]*"name"[^{}]*"interpretation"[^{}]*\\}'
    )
    match <- regexpr(pattern, response, perl = TRUE)

    if (match[1] > 0) {
      # Extract the matched factor object
      factor_text <- regmatches(response, match)

      # Try to parse this individual factor
      parsed_factor <- tryCatch({
        # Extract just the object part (everything after the factor name)
        object_match <- regexpr("\\{[^{}]*\\}", factor_text, perl = TRUE)
        if (object_match[1] > 0) {
          object_text <- regmatches(factor_text, object_match)
          jsonlite::fromJSON(object_text)
        } else {
          NULL
        }
      }, error = function(e) NULL)

      if (!is.null(parsed_factor) && is.list(parsed_factor)) {
        # Successfully parsed individual factor
        extraction_successful <- TRUE

        suggested_names[[factor_name]] <- if (!is.null(parsed_factor$name)) {
          name_text <- trimws(parsed_factor$name)
          # Add (n.s.) suffix if emergency rule was used
          add_emergency_suffix(
            name_text,
            factor_summaries[[factor_name]]$used_emergency_rule
          )
        } else {
          paste("Factor", i)
        }

        interpretation <- if (!is.null(parsed_factor$interpretation)) {
          trimws(parsed_factor$interpretation)
        } else {
          "Unable to parse interpretation"
        }

        factor_summaries[[factor_name]]$llm_interpretation <- interpretation
      } else {
        # Parsing failed for this factor
        suggested_names[[factor_name]] <- paste("Factor", i)
        factor_summaries[[factor_name]]$llm_interpretation <- "Unable to extract from response"
      }
    } else {
      # No match found for this factor
      suggested_names[[factor_name]] <- paste("Factor", i)
      factor_summaries[[factor_name]]$llm_interpretation <- "Not found in response"
    }
  }

  if (extraction_successful) {
    return(list(
      component_summaries = factor_summaries,
      suggested_names = suggested_names
    ))
  } else {
    return(NULL)
  }
}

#' Create Default Result for Factor Analysis
#'
#' Creates default values when all parsing methods fail.
#'
#' @param analysis_type Character. "fa"
#' @param ... Additional arguments including analysis_data
#'
#' @return List with component_summaries and suggested_names
#' @export
#' @keywords internal
create_default_result.fa <- function(analysis_type, ...) {
  # Extract analysis_data from ...
  dots <- list(...)
  analysis_data <- dots$analysis_data

  if (is.null(analysis_data)) {
    cli::cli_abort("analysis_data is required for FA default results")
  }

  factor_cols <- analysis_data$factor_cols
  factor_summaries <- analysis_data$factor_summaries

  suggested_names <- list()

  # Set defaults for all factors
  for (i in seq_along(factor_cols)) {
    factor_name <- factor_cols[i]

    # Check if already set (e.g., from undefined factors with n_emergency = 0)
    if (is.null(suggested_names[[factor_name]])) {
      suggested_names[[factor_name]] <- paste("Factor", i)
    }

    if (is.null(factor_summaries[[factor_name]]$llm_interpretation)) {
      factor_summaries[[factor_name]]$llm_interpretation <-
        "Unable to generate interpretation due to LLM error"
    }
  }

  return(list(
    component_summaries = factor_summaries,
    suggested_names = suggested_names
  ))
}
