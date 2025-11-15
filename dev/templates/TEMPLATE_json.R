# Template for {MODEL}_json.R
# Replace all instances of {MODEL}, {model}, {COMPONENT}, etc. with your values

#' Validate parsed JSON for {MODEL} results
#'
#' Checks if the parsed LLM response has the correct structure for {MODEL}
#' interpretation, including expected {COMPONENT_LOWER} identifiers and value types.
#'
#' @param parsed_result Parsed JSON object (list)
#' @param analysis_data Analysis data from build_analysis_data.{CLASS}()
#' @param ... Additional arguments (ignored)
#'
#' @return Logical - TRUE if valid structure, FALSE otherwise
#' @export
#'
#' @examples
#' \dontrun{
#' # Valid structure
#' result <- list(
#'   {COMPONENT}_1 = "Interpretation 1",
#'   {COMPONENT}_2 = "Interpretation 2"
#' )
#' validate_parsed_result(result, analysis_data, analysis_type = "{model}")
#' # Returns: TRUE
#'
#' # Invalid structure (missing keys)
#' result <- list(foo = "bar")
#' validate_parsed_result(result, analysis_data, analysis_type = "{model}")
#' # Returns: FALSE
#' }
validate_parsed_result.{model} <- function(parsed_result, analysis_data, ...) {

  # Pattern from fa_json.R:22-94

  # ============================================================================
  # Check 1: Is it a list?
  # ============================================================================

  if (!is.list(parsed_result)) {
    return(FALSE)
  }

  # ============================================================================
  # Check 2: Does it have keys?
  # ============================================================================

  actual_keys <- names(parsed_result)

  if (length(actual_keys) == 0) {
    return(FALSE)
  }

  # ============================================================================
  # Check 3: Are all values character strings?
  # ============================================================================

  all_char <- all(vapply(parsed_result, is.character, logical(1)))

  if (!all_char) {
    return(FALSE)
  }

  # ============================================================================
  # Check 4: Are keys valid {COMPONENT} identifiers?
  # ============================================================================

  # Generate expected keys from analysis_data
  n_components <- analysis_data$n_components
  expected_keys <- paste0("{COMPONENT}_", seq_len(n_components))

  # All actual keys should be in expected keys
  valid_keys <- all(actual_keys %in% expected_keys)

  if (!valid_keys) {
    # Optional: Log which keys are invalid for debugging
    invalid_keys <- setdiff(actual_keys, expected_keys)
    if (length(invalid_keys) > 0) {
      cli::cli_inform(c(
        "i" = "JSON contains unexpected keys: {paste(invalid_keys, collapse = ', ')}",
        "i" = "Expected keys: {paste(expected_keys, collapse = ', ')}"
      ))
    }
    return(FALSE)
  }

  # ============================================================================
  # Check 5: Are there enough keys?
  # ============================================================================

  # Require at least 50% of expected keys (allows for partial responses)
  min_required <- ceiling(n_components * 0.5)

  if (length(actual_keys) < min_required) {
    cli::cli_inform(c(
      "i" = "JSON has too few {COMPONENT_LOWER}s: {length(actual_keys)} of {n_components}",
      "i" = "Minimum required: {min_required}"
    ))
    return(FALSE)
  }

  # ============================================================================
  # Check 6: Model-specific validation (optional)
  # ============================================================================

  # Add any additional model-specific checks here

  # Example: Check interpretation length
  # for (key in actual_keys) {
  #   interp <- parsed_result[[key]]
  #   word_count <- length(strsplit(interp, "\\s+")[[1]])
  #   if (word_count > word_limit * 1.5) {  # Allow 50% overflow
  #     cli::cli_inform(c(
  #       "i" = "{key} interpretation exceeds word limit: {word_count} words"
  #     ))
  #   }
  # }

  # All checks passed
  TRUE
}


#' Extract {MODEL} interpretations using pattern matching
#'
#' Fallback method to extract interpretations from LLM response when JSON parsing
#' fails. Uses regex patterns to find "{COMPONENT}_X": "interpretation" pairs.
#'
#' @param response Raw LLM response string
#' @param analysis_data Analysis data from build_analysis_data.{CLASS}()
#' @param ... Additional arguments (ignored)
#'
#' @return List with extracted interpretations, or NULL if extraction failed
#' @export
#'
#' @examples
#' \dontrun{
#' # Malformed JSON response
#' response <- 'Here are results: {"{COMPONENT}_1": "Interp 1", "{COMPONENT}_2": "Interp 2"'
#'
#' # Extract using patterns
#' result <- extract_by_pattern(response, analysis_data, analysis_type = "{model}")
#' # Returns: list({COMPONENT}_1 = "Interp 1", {COMPONENT}_2 = "Interp 2")
#' }
extract_by_pattern.{model} <- function(response, analysis_data, ...) {

  # Pattern from fa_json.R:130-208

  # ============================================================================
  # Get expected component identifiers
  # ============================================================================

  n_components <- analysis_data$n_components
  expected_keys <- paste0("{COMPONENT}_", seq_len(n_components))

  # ============================================================================
  # Try to extract using regex patterns
  # ============================================================================

  result <- list()

  # Pattern 1: "{COMPONENT}_X": "interpretation text"
  for (key in expected_keys) {
    # Match: "key": "value" (handles escaped quotes in value)
    pattern <- sprintf('"%s"\\s*:\\s*"([^"]+)"', key)
    match <- regmatches(response, regexec(pattern, response))[[1]]

    if (length(match) > 1) {
      result[[key]] <- match[2]
    }
  }

  # ============================================================================
  # Pattern 2: Alternative formats (if Pattern 1 fails)
  # ============================================================================

  # If we didn't find enough matches, try alternative patterns
  if (length(result) < ceiling(n_components * 0.5)) {

    # Try with single quotes: '{COMPONENT}_X': 'interpretation'
    for (key in expected_keys) {
      if (!key %in% names(result)) {  # Don't overwrite existing matches
        pattern <- sprintf("'%s'\\s*:\\s*'([^']+)'", key)
        match <- regmatches(response, regexec(pattern, response))[[1]]

        if (length(match) > 1) {
          result[[key]] <- match[2]
        }
      }
    }

    # Try without quotes: {COMPONENT}_X: interpretation text (until newline or comma)
    for (key in expected_keys) {
      if (!key %in% names(result)) {
        pattern <- sprintf("%s\\s*:\\s*([^,\n]+)", key)
        match <- regmatches(response, regexec(pattern, response))[[1]]

        if (length(match) > 1) {
          # Clean up the extracted text
          interpretation <- trimws(match[2])
          interpretation <- gsub('^["\']|["\']$', '', interpretation)  # Remove quotes
          result[[key]] <- interpretation
        }
      }
    }
  }

  # ============================================================================
  # Return NULL if extraction failed
  # ============================================================================

  # Require at least 50% of expected keys
  min_required <- ceiling(n_components * 0.5)

  if (length(result) < min_required) {
    cli::cli_warn(c(
      "x" = "Pattern extraction found only {length(result)} of {n_components} {COMPONENT_LOWER}s",
      "i" = "Minimum required: {min_required}",
      "i" = "Falling back to default values"
    ))
    return(NULL)
  }

  # Log success
  cli::cli_inform(c(
    "v" = "Extracted {length(result)} of {n_components} {COMPONENT_LOWER}s using pattern matching"
  ))

  result
}


#' Create default {MODEL} interpretation
#'
#' Generates default "Unable to interpret" messages when all parsing methods fail.
#' Used as last resort to ensure the function returns a valid structure.
#'
#' @param analysis_data Analysis data from build_analysis_data.{CLASS}()
#' @param ... Additional arguments (ignored)
#'
#' @return List with default interpretations for all {COMPONENT_LOWER}s
#' @export
#'
#' @examples
#' \dontrun{
#' # Create default result
#' result <- create_default_result(analysis_data, analysis_type = "{model}")
#'
#' # Returns:
#' # list(
#' #   {COMPONENT}_1 = "Unable to generate interpretation...",
#' #   {COMPONENT}_2 = "Unable to generate interpretation...",
#' #   ...
#' # )
#' }
create_default_result.{model} <- function(analysis_data, ...) {

  # Pattern from fa_json.R:210-226

  # ============================================================================
  # Get component identifiers
  # ============================================================================

  n_components <- analysis_data$n_components
  component_ids <- paste0("{COMPONENT}_", seq_len(n_components))

  # ============================================================================
  # Create default interpretations
  # ============================================================================

  result <- list()

  for (id in component_ids) {
    result[[id]] <- paste0(
      "Unable to generate interpretation for ", id, " due to LLM response parsing errors. ",
      "Please review the raw LLM response using echo = 'all' for debugging."
    )
  }

  # ============================================================================
  # Log warning
  # ============================================================================

  cli::cli_warn(c(
    "x" = "All JSON parsing methods failed",
    "i" = "Returning default 'Unable to interpret' messages",
    "i" = "Use echo = 'all' to see the raw LLM response for debugging"
  ))

  result
}


# ==============================================================================
# Helper Functions (optional)
# ==============================================================================

# Add any helper functions for JSON processing

# Example: Clean interpretation text
# #' @keywords internal
# #' @noRd
# clean_interpretation_text <- function(text) {
#   # Remove extra whitespace
#   text <- trimws(text)
#   # Remove newlines
#   text <- gsub("\n", " ", text)
#   # Collapse multiple spaces
#   text <- gsub("\\s+", " ", text)
#   text
# }
