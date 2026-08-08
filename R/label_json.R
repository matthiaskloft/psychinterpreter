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

  # Tier 1: strict JSON, plus structural recovery of near-miss shapes.
  cleaned <- clean_json_response(response)
  attempt <- try_parse_json_with_error(cleaned)
  parsed <- attempt$value

  if (!is.null(parsed) && is.list(parsed)) {
    records <- coerce_label_records(parsed, variable_info)
    if (!is.null(records) && validate_label_structure(records, variable_info)) {
      # The LLM chooses the order; downstream code pairs records positionally
      # with variable_info, so restore the caller's order before returning.
      return(label_parse_result(
        order_labels(records, variable_info), "parsed", NULL
      ))
    }
  }

  parse_error <- attempt$error %||%
    "response did not match the expected label schema"

  # Tier 2: pattern-based extraction. This tier scrapes *prose*, so it must
  # never see text that already parsed as JSON: matching structural syntax
  # returns key names and punctuation as labels. A response that parsed but
  # could not be recovered above goes straight to defaults instead.
  if (is.null(parsed)) {
    labels <- extract_labels_fallback(response, variable_info)
    if (!is.null(labels) && isTRUE(attr(labels, "any_matched"))) {
      cli::cli_warn(c(
        "Could not parse the LLM response as JSON; labels were recovered by pattern matching.",
        "i" = "Check {.code x$labels_formatted}; see {.code x$metadata$parse_error}."
      ))
      return(label_parse_result(labels, "pattern_extracted", parse_error))
    }
  }

  # Tier 3: derive labels from the descriptions we already hold.
  # create_default_labels() derives labels from variable_info$description via
  # simplify_description(), not from the variable names.
  cli::cli_warn(c(
    "Could not parse the LLM response; labels were derived from the variable descriptions.",
    "i" = "See {.code x$metadata$parse_error} for why parsing failed."
  ))
  label_parse_result(create_default_labels(variable_info),
                     "default_fallback", parse_error)
}

#' Recover Label Records From Near-Miss JSON Shapes
#'
#' The prompt asks for an array of `variable`/`label` objects, but models
#' deviate in a small number of predictable ways. Recovering these structurally
#' is safe; handing them to the prose scraper is not.
#'
#' Handles: the requested array; an array wrapped in a single container key
#' (`{"labels": [...]}`); an object keyed by variable name
#' (`{"v1": "Tiredness"}`); and records whose `label` is a scalar number or
#' boolean rather than a string.
#'
#' @param parsed List. Parsed JSON
#' @param variable_info Data frame. Original variables
#' @return List of records, or NULL if no known shape matches
#' @keywords internal
coerce_label_records <- function(parsed, variable_info) {
  expected <- as.character(variable_info$variable)

  # {"labels": [...]} - unwrap a single container key holding a list.
  if (!is.null(names(parsed)) && length(parsed) == 1L && is.list(parsed[[1]]) &&
      is.null(names(parsed[[1]]))) {
    parsed <- parsed[[1]]
  }

  # {"v1": "Tiredness", "v2": "Alertness"} - an object keyed by variable name.
  if (!is.null(names(parsed)) && setequal(names(parsed), expected) &&
      all(vapply(parsed, function(x) is.atomic(x) && length(x) == 1L, logical(1)))) {
    return(lapply(names(parsed), function(nm) {
      list(variable = nm, label = as_label_string(parsed[[nm]]))
    }))
  }

  if (!is.list(parsed) || !is.null(names(parsed))) {
    return(NULL)
  }

  # The requested shape, with scalar labels coerced to character.
  lapply(parsed, function(item) {
    if (!is.list(item)) {
      return(item)
    }
    if (!is.null(item$label)) {
      item$label <- as_label_string(item$label)
    }
    if (!is.null(item$variable)) {
      item$variable <- as_label_string(item$variable)
    }
    item
  })
}

#' Coerce a Scalar JSON Value to a Label String
#'
#' @param x Value from parsed JSON
#' @return Character scalar, or `x` unchanged if it is not a usable scalar
#' @keywords internal
as_label_string <- function(x) {
  if (is.character(x) && length(x) == 1L) {
    return(x)
  }
  if (is.atomic(x) && length(x) == 1L && !is.na(x)) {
    return(as.character(x))
  }
  x
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

#' Flatten Label Records Into a Two-Column Data Frame
#'
#' Defence in depth rather than a fix for an observed failure: the tiers above
#' currently guarantee well-formed records, so no LLM response is known to
#' reach here with a field missing. `vapply()` is used anyway because the
#' previous `sapply()` would have degraded silently - returning a list, and so
#' a list-column - if that guarantee were ever weakened.
#'
#' Any record that still lacks a usable label falls back to the description
#' already held in `variable_info`, rather than carrying NA into formatting.
#'
#' @param records List of label records
#' @param variable_info Data frame. Original variables
#' @return Data frame with character columns `variable` and `label`
#' @keywords internal
label_records_to_df <- function(records, variable_info) {
  record_field <- function(field) {
    vapply(
      records,
      function(x) {
        value <- x[[field]]
        if (is_nonempty_string(value)) as.character(value) else NA_character_
      },
      character(1)
    )
  }

  out <- data.frame(
    variable = record_field("variable"),
    label = record_field("label"),
    stringsAsFactors = FALSE
  )

  missing_variable <- is.na(out$variable)
  if (any(missing_variable)) {
    out$variable[missing_variable] <-
      as.character(variable_info$variable[missing_variable])
  }

  missing_label <- is.na(out$label)
  if (any(missing_label)) {
    out$label[missing_label] <- vapply(
      which(missing_label),
      function(i) simplify_description(variable_info$description[i]),
      character(1)
    )
  }

  out
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