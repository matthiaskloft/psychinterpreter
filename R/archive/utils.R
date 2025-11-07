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

# ==============================================================================
# GLOBAL VARIABLES
# ==============================================================================

# Declare global variables to avoid R CMD check NOTEs for NSE in dplyr
# These are column names used in tidyverse pipelines
utils::globalVariables(c("variable", "description", "loading", "loading_num"))