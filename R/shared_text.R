#' Count Words in Text
#'
#' Internal helper function to count the number of words in a text string.
#' Used for monitoring LLM response length and ensuring output meets
#' specified word limits.
#'
#' @param text Character string to count words in
#'
#' @return Integer. Number of words in the text
#'
#' @keywords internal
count_words <- function(text) {
  if (is.null(text) || is.na(text) || nchar(text) == 0) {
    return(0)
  }
  
  # Split into words and count
  words <- strsplit(trimws(text), "\\s+")[[1]]
  # Remove empty strings that might result from multiple spaces
  words <- words[words != ""]
  return(length(words))
}

#' Wrap Text to Specified Line Length
#'
#' Internal helper function to wrap text at word boundaries while preserving
#' existing formatting like headers, separators, and indentation. Used for
#' console output formatting to ensure readable display across different
#' terminal widths.
#'
#' @param text Character string to wrap
#' @param max_length Integer. Maximum line length (default = 80)
#'
#' @return Character string with wrapped lines
#'
#' @keywords internal
wrap_text <- function(text, max_length = 80) {
  if (is.null(text) || is.na(text) || nchar(text) == 0) {
    return(text)
  }
  
  # Split text into lines to preserve existing formatting
  lines <- strsplit(text, "\n")[[1]]
  wrapped_lines <- character()
  
  for (line in lines) {
    # Check if this is a header line (contains === or ---)
    if (grepl("^[=\\-]{3,}$", trimws(line))) {
      wrapped_lines <- c(wrapped_lines, line)
      next
    }
    
    # Check if this is an empty line or very short line
    if (nchar(line) <= max_length || nchar(trimws(line)) == 0) {
      wrapped_lines <- c(wrapped_lines, line)
      next
    }
    
    # Detect indentation
    leading_spaces <- sub("^(\\s*).*", "\\1", line)
    content <- sub("^\\s*", "", line)
    
    # Split content into words
    words <- strsplit(content, "\\s+")[[1]]
    
    if (length(words) == 0) {
      wrapped_lines <- c(wrapped_lines, line)
      next
    }
    
    # Build wrapped lines
    current_line <- leading_spaces
    
    for (word in words) {
      # Check if adding this word would exceed the limit
      test_line <- if (nchar(current_line) == nchar(leading_spaces)) {
        paste0(current_line, word)
      } else {
        paste0(current_line, " ", word)
      }
      
      if (nchar(test_line) <= max_length) {
        current_line <- test_line
      } else {
        # Start new line
        if (nchar(current_line) > nchar(leading_spaces)) {
          wrapped_lines <- c(wrapped_lines, current_line)
        }
        current_line <- paste0(leading_spaces, word)
      }
    }
    
    # Add the last line if it has content
    if (nchar(current_line) > nchar(leading_spaces)) {
      wrapped_lines <- c(wrapped_lines, current_line)
    }
  }
  
  return(paste(wrapped_lines, collapse = "\n"))
}

#' Format Loading Value with Consistent Precision
#'
#' Formats numeric loading values with consistent precision and removes leading
#' zeros for compact display. This is the standard format used throughout the
#' package for displaying factor loadings in prompts, reports, and diagnostics.
#'
#' @param x Numeric value(s) to format. Can be a single value or vector.
#' @param digits Integer. Number of decimal places (default = 3)
#'
#' @return Character string(s) with formatted values
#'
#' @details
#' Formatting rules:
#' - Positive values: 0.456 → ".456"
#' - Negative values: -0.456 → "-.456"
#' - Preserves sign and removes leading zero
#' - Consistent decimal precision
#'
#' @examples
#' \dontrun{
#' format_loading(0.456)      # ".456"
#' format_loading(-0.456)     # "-.456"
#' format_loading(0.7, 2)     # ".70"
#' format_loading(c(0.3, -0.5))  # c(".300", "-.500")
#' }
#'
#' @keywords internal
format_loading <- function(x, digits = 3) {
  sub("^(-?)0\\.", "\\1.", sprintf(paste0("%.", digits, "f"), x))
}

#' Normalize Token Count to Valid Numeric Value
#'
#' Ensures token count values are always valid numeric scalars, handling NULL,
#' NA, and empty values gracefully. Used for robust token tracking across
#' different LLM providers that may not consistently report token counts.
#'
#' @param value Raw token count value (may be NULL, NA, numeric(0), etc.)
#'
#' @return Numeric scalar. Returns 0.0 if input is invalid, otherwise the
#'   numeric value.
#'
#' @details
#' Some LLM providers (e.g., Ollama) do not support token tracking and may
#' return NULL or 0. This function ensures consistent handling across providers
#' by normalizing all invalid values to 0.0.
#'
#' @examples
#' \dontrun{
#' normalize_token_count(100)        # 100
#' normalize_token_count(NULL)       # 0
#' normalize_token_count(NA)         # 0
#' normalize_token_count(numeric(0)) # 0
#' }
#'
#' @keywords internal
normalize_token_count <- function(value) {
  if (length(value) == 0 || is.na(value) || is.null(value)) {
    return(0.0)
  }
  as.numeric(value)
}

#' Add Emergency Rule Suffix to Factor Name
#'
#' Adds the "(n.s.)" suffix to factor names when the emergency rule was used
#' (i.e., factor has no loadings above cutoff, but top N loadings were used
#' instead of marking it as undefined).
#'
#' @param name Character. Factor name from LLM
#' @param used_emergency_rule Logical. Whether emergency rule was applied
#'
#' @return Character. Name with "(n.s.)" suffix if emergency rule was used,
#'   otherwise unchanged. Special values like "NA", "na", "N/A", "n/a" are
#'   not modified even if emergency rule was used.
#'
#' @details
#' The "(n.s.)" suffix stands for "not significant" and indicates that the
#' factor was interpreted based on loadings below the specified cutoff threshold.
#'
#' Special handling for undefined factor names:
#' - "NA", "na", "N/A", "n/a" (case-sensitive) are not modified
#' - This prevents double-labeling when factors are undefined
#'
#' @examples
#' \dontrun{
#' add_emergency_suffix("Memory", TRUE)   # "Memory (n.s.)"
#' add_emergency_suffix("Memory", FALSE)  # "Memory"
#' add_emergency_suffix("NA", TRUE)       # "NA" (no suffix)
#' add_emergency_suffix("N/A", TRUE)      # "N/A" (no suffix)
#' }
#'
#' @keywords internal
add_emergency_suffix <- function(name, used_emergency_rule) {
  # Don't add suffix if emergency rule wasn't used
  if (!isTRUE(used_emergency_rule)) {
    return(name)
  }

  # Don't add suffix to special "undefined" values
  if (grepl("^NA$|^na$|^N/A$|^n/a$", name, ignore.case = FALSE)) {
    return(name)
  }

  # Add suffix
  paste0(name, " (n.s.)")
}

# ==============================================================================
# GLOBAL VARIABLES
# ==============================================================================

# Declare global variables to avoid R CMD check NOTEs for NSE in dplyr
# These are column names used in tidyverse pipelines
utils::globalVariables(c("variable", "description", "loading", "loading_num"))