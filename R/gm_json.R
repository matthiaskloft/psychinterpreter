# ===================================================================
# FILE: gm_json.R
# PURPOSE: JSON parsing and validation for Gaussian Mixture Model interpretations
# ===================================================================

#' Validate Parsed JSON Result for Gaussian Mixture Models
#'
#' Checks if the parsed JSON contains the expected cluster interpretation structure.
#'
#' @param parsed List from JSON parsing
#' @param analysis_type Character. Type of analysis ("gm")
#' @param analysis_data Standardized GM analysis data
#' @param ... Additional arguments (currently unused)
#' @return A list with two components: \code{component_summaries} (named list of cluster interpretations) and \code{suggested_names} (named list of cluster labels), or NULL if validation fails
#' @export
#' @keywords internal
validate_parsed_result.gm <- function(parsed, analysis_type, analysis_data, ...) {
  # Check if it's a list
  if (!is.list(parsed)) {
    return(NULL)
  }

  # Check for expected cluster keys
  expected_keys <- analysis_data$cluster_names

  # Allow for some flexibility in key names
  actual_keys <- names(parsed)

  # Check if we have the right number of clusters
  if (length(actual_keys) != analysis_data$n_clusters) {
    return(NULL)
  }

  # Check if keys match expected pattern
  for (k in seq_len(analysis_data$n_clusters)) {
    expected_key <- expected_keys[k]

    # Check for exact match or close match
    if (!expected_key %in% actual_keys) {
      # Also check for variations like "cluster_1", "Cluster1", etc.
      pattern <- paste0("(?i)cluster[_\\s]*", k)
      if (!any(grepl(pattern, actual_keys))) {
        return(NULL)
      }
    }
  }

  # New structure: Each cluster should have "name" and "interpretation" fields
  component_summaries <- list()
  suggested_names <- list()

  for (key in actual_keys) {
    cluster_value <- parsed[[key]]

    # Check if it's the new structure (object with name and interpretation)
    if (is.list(cluster_value) &&
        !is.null(cluster_value$name) &&
        !is.null(cluster_value$interpretation)) {
      # New format: {"Cluster_1": {"name": "...", "interpretation": "..."}}
      suggested_names[[key]] <- as.character(cluster_value$name)
      component_summaries[[key]] <- as.character(cluster_value$interpretation)
    } else if (is.character(cluster_value) && length(cluster_value) == 1) {
      # Old format (legacy): {"Cluster_1": "interpretation"}
      # Use cluster key as name
      suggested_names[[key]] <- key
      component_summaries[[key]] <- cluster_value
    } else {
      # Invalid structure
      return(NULL)
    }
  }

  # Transform into expected format with component_summaries and suggested_names
  result <- list(
    component_summaries = component_summaries,
    suggested_names = suggested_names
  )

  return(result)
}

#' Extract Interpretations by Pattern for Gaussian Mixture Models
#'
#' Fallback extraction method using regex patterns when JSON parsing fails.
#'
#' @param response Raw text response from LLM
#' @param analysis_type Character. Analysis type ("gm")
#' @param ... Additional arguments including analysis_data
#' @return A list with two components: \code{component_summaries} (named list of cluster interpretations) and \code{suggested_names} (named list of cluster labels), or NULL if extraction fails
#' @export
#' @keywords internal
extract_by_pattern.gm <- function(response, analysis_type, ...) {
  # Extract analysis_data from ...
  dots <- list(...)
  analysis_data <- dots$analysis_data

  if (is.null(analysis_data)) {
    cli::cli_abort("analysis_data is required for GM pattern extraction")
  }

  response_text <- response
  interpretations <- list()
  names_list <- list()

  # Try different patterns for cluster interpretations with names
  # Pattern for new format: "Cluster_N": {"name": "...", "interpretation": "..."}
  name_interp_pattern <- '"Cluster[_\\s]*%d"\\s*:\\s*\\{\\s*"name"\\s*:\\s*"([^"]+)"\\s*,\\s*"interpretation"\\s*:\\s*"([^"]+)"'

  for (k in seq_len(analysis_data$n_clusters)) {
    cluster_name <- analysis_data$cluster_names[k]
    found <- FALSE

    # First try new format with name + interpretation
    pattern <- sprintf(name_interp_pattern, k)
    matches <- regmatches(
      response_text,
      regexec(pattern, response_text, ignore.case = TRUE)
    )

    if (length(matches[[1]]) >= 3) {
      # Found new format
      cluster_label <- trimws(matches[[1]][2])
      interpretation <- trimws(matches[[1]][3])

      interpretation <- gsub('\\\\n', ' ', interpretation)
      interpretation <- gsub('\\s+', ' ', interpretation)

      if (nchar(interpretation) > 10 && nchar(cluster_label) > 0) {
        names_list[[cluster_name]] <- cluster_label
        interpretations[[cluster_name]] <- interpretation
        found <- TRUE
      }
    }

    # If not found, try old patterns (just interpretation, no name)
    if (!found) {
      old_patterns <- c(
        # Pattern 1: "Cluster_N": "interpretation"
        '"Cluster[_\\s]*(%d)"\\s*:\\s*"([^"]+)"',
        # Pattern 2: Cluster_N: interpretation (without quotes)
        'Cluster[_\\s]*(%d)\\s*:\\s*([^\n]+)',
        # Pattern 3: **Cluster N**: interpretation
        '\\*\\*Cluster[_\\s]*(%d)\\*\\*\\s*:?\\s*([^\n]+)',
        # Pattern 4: N. interpretation or N) interpretation
        '(%d)[\\.)\\s]+([^\n]+)'
      )

      for (pattern_template in old_patterns) {
        if (found) break

        pattern <- sprintf(pattern_template, k)
        matches <- regmatches(
          response_text,
          regexec(pattern, response_text, ignore.case = TRUE)
        )

        if (length(matches[[1]]) >= 3) {
          interpretation <- trimws(matches[[1]][3])
          interpretation <- gsub('^"', '', interpretation)
          interpretation <- gsub('"$', '', interpretation)
          interpretation <- gsub('\\\\n', ' ', interpretation)
          interpretation <- gsub('\\s+', ' ', interpretation)

          if (nchar(interpretation) > 10) {
            interpretations[[cluster_name]] <- interpretation
            names_list[[cluster_name]] <- cluster_name  # Use default name
            found <- TRUE
          }
        }
      }
    }

    # If still not found, try to find any mention of this cluster
    if (!found) {
      cluster_pattern <- paste0("(?i)cluster[_\\s]*", k, "[^.]+\\.")
      matches <- regmatches(
        response_text,
        gregexpr(cluster_pattern, response_text)
      )

      if (length(matches[[1]]) > 0) {
        interpretation <- trimws(matches[[1]][1])
        interpretation <- gsub(
          paste0("(?i)^cluster[_\\s]*", k, "[:\\s]*"),
          "",
          interpretation
        )
        interpretations[[cluster_name]] <- interpretation
        names_list[[cluster_name]] <- cluster_name  # Use default name
      }
    }
  }

  # Return NULL if we couldn't extract all clusters
  if (length(interpretations) != analysis_data$n_clusters) {
    missing_clusters <- setdiff(
      analysis_data$cluster_names,
      names(interpretations)
    )

    # If we got most clusters, fill missing with default
    if (length(interpretations) >= analysis_data$n_clusters * 0.5) {
      for (cluster_name in missing_clusters) {
        interpretations[[cluster_name]] <- "Unable to extract interpretation for this cluster."
        names_list[[cluster_name]] <- cluster_name
      }
    } else {
      return(NULL)
    }
  }

  # Return in expected format with component_summaries and suggested_names
  result <- list(
    component_summaries = interpretations,
    suggested_names = names_list
  )

  return(result)
}

#' Create Default Result for Gaussian Mixture Models
#'
#' Generates default interpretations when parsing completely fails.
#'
#' @param analysis_type Character. Analysis type ("gm")
#' @param ... Additional arguments including analysis_data
#' @return A list with two components: \code{component_summaries} (named list of default cluster interpretations) and \code{suggested_names} (named list of cluster names)
#' @export
#' @keywords internal
create_default_result.gm <- function(analysis_type, ...) {
  # Extract analysis_data from ...
  dots <- list(...)
  analysis_data <- dots$analysis_data

  if (is.null(analysis_data)) {
    cli::cli_abort("analysis_data is required for GM default results")
  }
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

  # Return in expected format with component_summaries and suggested_names
  formatted_result <- list(
    component_summaries = result,
    suggested_names = names(result)
  )

  return(formatted_result)
}

#' Parse GM Interpretation Response
#'
#' High-level function that orchestrates JSON parsing with fallback strategies.
#'
#' @param response_text Raw text response from LLM
#' @param analysis_data Standardized GM analysis data
#' @return A list with two components: \code{component_summaries} (named list of cluster interpretations) and \code{suggested_names} (named list of cluster labels)
#' @keywords internal
parse_gm_response <- function(response_text, analysis_data) {
  # Try standard JSON parsing first
  parsed_result <- parse_llm_response(
    response = response_text,
    analysis_type = "gm",
    analysis_data = analysis_data
  )

  # If that worked and passed validation, return it
  if (!is.null(parsed_result) && validate_parsed_result.gm(parsed_result, "gm", analysis_data)) {
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