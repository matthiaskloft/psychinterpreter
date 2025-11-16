#' @title Factor Analysis Utility Functions
#'
#' @description
#' Internal utility functions specific to factor analysis interpretation.
#' These functions handle loading formatting and factor naming conventions
#' used throughout FA-specific methods.
#'
#' @keywords internal
#' @name fa_utils
NULL

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
