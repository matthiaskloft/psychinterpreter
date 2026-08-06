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
#' @return List with parsed labels, carrying two attributes: `parse_status`,
#'   one of `"parsed"`, `"pattern_extracted"` or `"default_fallback"`, and
#'   `parse_error`, the reason the strict parse failed (NULL when it succeeded).
#' @export
#' @keywords internal
parse_label_response <- function(response, variable_info, ...) {

  # Tier 1: strict JSON.
  cleaned <- clean_json_response(response)
  attempt <- try_parse_json_with_error(cleaned)
  parsed <- attempt$value

  if (!is.null(parsed) && is.list(parsed) &&
      validate_label_structure(parsed, variable_info)) {
    # The LLM chooses the order; downstream code pairs records positionally
    # with variable_info, so restore the caller's order before returning.
    return(label_parse_result(
      order_labels(parsed, variable_info), "parsed", NULL
    ))
  }

  parse_error <- attempt$error %||%
    "response did not match the expected label schema"

  # Tier 2: pattern-based extraction.
  labels <- extract_labels_fallback(response, variable_info)
  if (!is.null(labels) && isTRUE(attr(labels, "any_matched"))) {
    return(label_parse_result(labels, "pattern_extracted", parse_error))
  }

  # Tier 3: derive labels from the descriptions we already hold.
  cli::cli_warn("Could not parse LLM response, using variable names as labels")
  label_parse_result(create_default_labels(variable_info),
                     "default_fallback", parse_error)
}

#' Tag a Parsed Label List With the Tier That Produced It
#'
#' @param labels List of label records
#' @param status Character. Parse tier that produced `labels`
#' @param error Character or NULL. Why the strict parse failed
#' @return `labels` with `parse_status` and `parse_error` attributes
#' @keywords internal
label_parse_result <- function(labels, status, error) {
  attr(labels, "any_matched") <- NULL
  attr(labels, "parse_status") <- status
  attr(labels, "parse_error") <- error
  labels
}

#' Reorder Label Records to Match variable_info
#'
#' @param parsed List of validated label records
#' @param variable_info Data frame. Original variables
#' @return List of records in `variable_info$variable` order
#' @keywords internal
order_labels <- function(parsed, variable_info) {
  parsed_vars <- vapply(parsed, function(x) as.character(x$variable), character(1))
  parsed[match(variable_info$variable, parsed_vars)]
}

#' Validate Label Structure
#'
#' @param parsed List. Parsed JSON response
#' @param variable_info Data frame. Original variables
#'
#' @return Logical. TRUE if valid structure
#' @keywords internal
validate_label_structure <- function(parsed, variable_info) {

  expected_vars <- as.character(variable_info$variable)

  # Must be an array of records, exactly one per expected variable. A subset
  # check would let duplicates, extras and blanks through, and the result was
  # then assembled in LLM-provided order.
  if (!is.list(parsed) || length(parsed) != length(expected_vars)) {
    return(FALSE)
  }

  for (item in parsed) {
    if (!is.list(item) || !all(c("variable", "label") %in% names(item))) {
      return(FALSE)
    }
    if (!is_nonempty_string(item$variable) || !is_nonempty_string(item$label)) {
      return(FALSE)
    }
  }

  parsed_vars <- vapply(parsed, function(x) as.character(x$variable), character(1))

  if (anyDuplicated(parsed_vars) > 0) {
    cli::cli_warn("Duplicate variables in LLM response")
    return(FALSE)
  }

  if (!setequal(parsed_vars, expected_vars)) {
    cli::cli_warn("LLM response does not label exactly the requested variables")
    return(FALSE)
  }

  return(TRUE)
}

#' Is x a Single Non-Blank Character Value?
#'
#' @param x Value to test
#' @return Logical scalar
#' @keywords internal
is_nonempty_string <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(trimws(x))
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
  any_matched <- FALSE

  for (i in seq_len(nrow(variable_info))) {
    var <- variable_info$variable[i]
    # Identifiers are literal text, not patterns: `a.b` would otherwise match
    # `axb`, and `x[1` is not a compilable pattern at all.
    var_pattern <- escape_regex(var)

    # Try multiple patterns
    patterns <- c(
      paste0('"', var_pattern, '"\\s*:\\s*"([^"]+)"'),  # JSON-like
      paste0(var_pattern, '\\s*[=:]\\s*"([^"]+)"'),      # Assignment-like
      paste0(var_pattern, '\\s*[=:]\\s*([^,\\n]+)'),     # Without quotes
      paste0('\\b', var_pattern, '\\b.*?label.*?["\']([^"\']+)["\']')  # Natural language
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
        any_matched <- TRUE
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

  # Whether any label came from the response at all, rather than every one
  # being derived from the description we already had. This is what separates
  # the "pattern_extracted" tier from "default_fallback".
  attr(labels, "any_matched") <- any_matched
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