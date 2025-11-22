#' Label Response Parser Framework
#'
#' S3 methods for parsing LLM responses for variable labeling.
#'
#' @name label_parser
#' @keywords internal
NULL

#' Parse Label Response from LLM
#'
#' @param response Character. Raw LLM response
#' @param variable_info Data frame. Original variable information
#' @param ... Additional arguments
#'
#' @return List with parsed labels
#' @export
#' @keywords internal
parse_label_response <- function(response, variable_info, ...) {

  # Try JSON parsing first
  cleaned <- clean_json_response(response)
  parsed <- try_parse_json(cleaned)

  if (!is.null(parsed) && is.list(parsed)) {
    # Validate structure
    if (validate_label_structure(parsed, variable_info)) {
      return(parsed)
    }
  }

  # Fallback: Pattern-based extraction
  labels <- extract_labels_fallback(response, variable_info)

  if (!is.null(labels)) {
    return(labels)
  }

  # Last resort: Create default labels
  cli::cli_warn("Could not parse LLM response, using variable names as labels")
  return(create_default_labels(variable_info))
}

#' Validate Label Structure
#'
#' @param parsed List. Parsed JSON response
#' @param variable_info Data frame. Original variables
#'
#' @return Logical. TRUE if valid structure
#' @keywords internal
validate_label_structure <- function(parsed, variable_info) {

  # Check if it's a list/array
  if (!is.list(parsed)) {
    return(FALSE)
  }

  # Check each element has required fields
  for (item in parsed) {
    if (!is.list(item) || !all(c("variable", "label") %in% names(item))) {
      return(FALSE)
    }
  }

  # Check all variables are present
  parsed_vars <- sapply(parsed, function(x) x$variable)
  expected_vars <- variable_info$variable

  if (!all(expected_vars %in% parsed_vars)) {
    cli::cli_warn("Not all variables found in LLM response")
    return(FALSE)
  }

  return(TRUE)
}

#' Extract Labels Using Fallback Pattern Matching
#'
#' @param response Character. Raw response text
#' @param variable_info Data frame. Original variables
#'
#' @return List or NULL. Extracted labels
#' @keywords internal
extract_labels_fallback <- function(response, variable_info) {

  labels <- list()

  for (i in seq_len(nrow(variable_info))) {
    var <- variable_info$variable[i]

    # Try multiple patterns
    patterns <- c(
      paste0('"', var, '"\\s*:\\s*"([^"]+)"'),  # JSON-like
      paste0(var, '\\s*[=:]\\s*"([^"]+)"'),      # Assignment-like
      paste0(var, '\\s*[=:]\\s*([^,\\n]+)'),     # Without quotes
      paste0('\\b', var, '\\b.*?label.*?["\']([^"\']+)["\']')  # Natural language
    )

    label_found <- FALSE
    for (pattern in patterns) {
      matches <- regmatches(response, regexec(pattern, response, ignore.case = TRUE))
      if (length(matches[[1]]) > 1) {
        labels[[length(labels) + 1]] <- list(
          variable = var,
          label = trimws(matches[[1]][2])
        )
        label_found <- TRUE
        break
      }
    }

    if (!label_found) {
      # Use a simplified version of the description
      labels[[length(labels) + 1]] <- list(
        variable = var,
        label = simplify_description(variable_info$description[i])
      )
    }
  }

  return(labels)
}

#' Create Default Labels
#'
#' @param variable_info Data frame. Variable information
#'
#' @return List. Default label structure
#' @keywords internal
create_default_labels <- function(variable_info) {
  labels <- list()

  for (i in seq_len(nrow(variable_info))) {
    labels[[i]] <- list(
      variable = variable_info$variable[i],
      label = simplify_description(variable_info$description[i])
    )
  }

  return(labels)
}

#' Simplify Description to Label
#'
#' Basic heuristic to create a label from a description.
#'
#' @param description Character. Variable description
#'
#' @return Character. Simplified label
#' @keywords internal
simplify_description <- function(description) {
  if (is.na(description) || nchar(description) == 0) {
    return("Variable")
  }

  # Remove question marks and common question starters
  simplified <- gsub("^(how |what |when |where |why |which |do you |does |is |are )","",
                     tolower(description))
  simplified <- gsub("\\?", "", simplified)

  # Take first few words
  words <- strsplit(trimws(simplified), "\\s+")[[1]]
  label <- paste(head(words, 3), collapse = " ")

  # Capitalize first letter
  label <- paste0(toupper(substr(label, 1, 1)), substr(label, 2, nchar(label)))

  return(label)
}