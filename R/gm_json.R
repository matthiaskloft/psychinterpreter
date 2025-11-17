# ===================================================================
# FILE: gm_json.R
# PURPOSE: JSON parsing and validation for Gaussian Mixture Model interpretations
# ===================================================================

#' Validate Parsed JSON Result for Gaussian Mixture Models
#'
#' Checks if the parsed JSON contains the expected cluster interpretation structure.
#'
#' @param parsed_result List from JSON parsing
#' @param analysis_data Standardized GM analysis data
#' @return Logical indicating whether the result is valid
#' @export
#' @keywords internal
validate_parsed_result.gm <- function(parsed_result, analysis_data) {
  # Check if it's a list
  if (!is.list(parsed_result)) {
    return(FALSE)
  }

  # Check for expected cluster keys
  expected_keys <- analysis_data$cluster_names

  # Allow for some flexibility in key names
  actual_keys <- names(parsed_result)

  # Check if we have the right number of clusters
  if (length(actual_keys) != analysis_data$n_clusters) {
    return(FALSE)
  }

  # Check if keys match expected pattern
  for (k in seq_len(analysis_data$n_clusters)) {
    expected_key <- expected_keys[k]

    # Check for exact match or close match
    if (!expected_key %in% actual_keys) {
      # Also check for variations like "cluster_1", "Cluster1", etc.
      pattern <- paste0("(?i)cluster[_\\s]*", k)
      if (!any(grepl(pattern, actual_keys))) {
        return(FALSE)
      }
    }
  }

  # Check that all values are character strings
  for (key in actual_keys) {
    if (!is.character(parsed_result[[key]]) || length(parsed_result[[key]]) != 1) {
      return(FALSE)
    }
  }

  return(TRUE)
}

#' Extract Interpretations by Pattern for Gaussian Mixture Models
#'
#' Fallback extraction method using regex patterns when JSON parsing fails.
#'
#' @param response_text Raw text response from LLM
#' @param analysis_data Standardized GM analysis data
#' @return Named list of cluster interpretations or NULL
#' @export
#' @keywords internal
extract_by_pattern.gm <- function(response_text, analysis_data) {
  interpretations <- list()

  # Try different patterns for cluster interpretations
  patterns <- c(
    # Pattern 1: "Cluster_N": "interpretation"
    '"Cluster[_\\s]*(%d)"\\s*:\\s*"([^"]+)"',
    # Pattern 2: Cluster_N: interpretation (without quotes)
    'Cluster[_\\s]*(%d)\\s*:\\s*([^\\n]+)',
    # Pattern 3: **Cluster N**: interpretation
    '\\*\\*Cluster[_\\s]*(%d)\\*\\*\\s*:?\\s*([^\\n]+)',
    # Pattern 4: N. interpretation or N) interpretation
    '(%d)[\\.)\\s]+(.+?)(?=\\d+[\\.)\\s]+|$)'
  )

  for (k in seq_len(analysis_data$n_clusters)) {
    cluster_name <- analysis_data$cluster_names[k]
    found <- FALSE

    for (pattern_template in patterns) {
      if (found) break

      # Create pattern for this cluster number
      pattern <- sprintf(pattern_template, k)

      # Try to extract
      matches <- regmatches(
        response_text,
        regexec(pattern, response_text, ignore.case = TRUE)
      )

      if (length(matches[[1]]) >= 3) {
        # Clean up the interpretation text
        interpretation <- trimws(matches[[1]][3])
        interpretation <- gsub('^"', '', interpretation)
        interpretation <- gsub('"$', '', interpretation)
        interpretation <- gsub('\\\\n', ' ', interpretation)
        interpretation <- gsub('\\s+', ' ', interpretation)

        if (nchar(interpretation) > 10) {  # Minimum meaningful length
          interpretations[[cluster_name]] <- interpretation
          found <- TRUE
        }
      }
    }

    # If still not found, try to find any mention of this cluster
    if (!found) {
      # Look for any paragraph mentioning this cluster
      cluster_pattern <- paste0(
        "(?i)cluster[_\\s]*", k, "[^.]+\\."
      )
      matches <- regmatches(
        response_text,
        gregexpr(cluster_pattern, response_text)
      )

      if (length(matches[[1]]) > 0) {
        interpretation <- trimws(matches[[1]][1])
        # Remove the cluster mention from the beginning
        interpretation <- gsub(
          paste0("(?i)^cluster[_\\s]*", k, "[:\\s]*"),
          "",
          interpretation
        )
        interpretations[[cluster_name]] <- interpretation
      }
    }
  }

  # Return NULL if we couldn't extract all clusters
  if (length(interpretations) != analysis_data$n_clusters) {
    # Try to fill in missing with a search for remaining content
    missing_clusters <- setdiff(
      analysis_data$cluster_names,
      names(interpretations)
    )

    # If we got most clusters, fill missing with default
    if (length(interpretations) >= analysis_data$n_clusters * 0.5) {
      for (cluster_name in missing_clusters) {
        interpretations[[cluster_name]] <- "Unable to extract interpretation for this cluster."
      }
    } else {
      return(NULL)
    }
  }

  return(interpretations)
}

#' Create Default Result for Gaussian Mixture Models
#'
#' Generates default interpretations when parsing completely fails.
#'
#' @param analysis_data Standardized GM analysis data
#' @return Named list with default cluster interpretations
#' @export
#' @keywords internal
create_default_result.gm <- function(analysis_data) {
  result <- list()

  for (k in seq_len(analysis_data$n_clusters)) {
    cluster_name <- analysis_data$cluster_names[k]

    # Create a basic description based on cluster size
    if (!is.null(analysis_data$proportions)) {
      size_pct <- round(analysis_data$proportions[k] * 100, 1)
      size_desc <- ifelse(
        size_pct > 40, "large",
        ifelse(size_pct > 20, "moderate-sized", "small")
      )
    } else {
      size_desc <- "distinct"
    }

    # Create a generic but informative default message
    result[[cluster_name]] <- paste0(
      "This ", size_desc, " cluster represents a distinct profile ",
      "in the data. Interpretation could not be generated automatically. ",
      "Please review the cluster means to understand its characteristics."
    )
  }

  return(result)
}

#' Parse GM Interpretation Response
#'
#' High-level function that orchestrates JSON parsing with fallback strategies.
#'
#' @param response_text Raw text response from LLM
#' @param analysis_data Standardized GM analysis data
#' @return Named list of cluster interpretations
#' @keywords internal
parse_gm_response <- function(response_text, analysis_data) {
  # Try standard JSON parsing first
  parsed_result <- parse_llm_response_with_fallback(
    response_text = response_text,
    analysis_data = analysis_data
  )

  # If that worked and passed validation, return it
  if (!is.null(parsed_result) && validate_parsed_result.gm(parsed_result, analysis_data)) {
    # Ensure keys match expected cluster names
    standardized_result <- list()
    for (k in seq_len(analysis_data$n_clusters)) {
      expected_key <- analysis_data$cluster_names[k]

      # Find matching key in parsed result
      found_key <- NULL
      for (actual_key in names(parsed_result)) {
        if (actual_key == expected_key ||
            grepl(paste0("(?i)cluster[_\\s]*", k), actual_key)) {
          found_key <- actual_key
          break
        }
      }

      if (!is.null(found_key)) {
        standardized_result[[expected_key]] <- parsed_result[[found_key]]
      }
    }

    if (length(standardized_result) == analysis_data$n_clusters) {
      return(standardized_result)
    }
  }

  # Try pattern extraction as fallback
  extracted_result <- extract_by_pattern.gm(response_text, analysis_data)

  if (!is.null(extracted_result)) {
    return(extracted_result)
  }

  # Final fallback: return default interpretations
  cli::cli_warn("Could not parse GM interpretations, using defaults")
  return(create_default_result.gm(analysis_data))
}