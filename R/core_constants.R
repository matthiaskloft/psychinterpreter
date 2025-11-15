# Package-level constants
#
# This file contains constants used throughout the package to ensure consistency
# and make it easier to add new model types.

#' Valid Analysis Types
#'
#' Vector of valid analysis type identifiers supported by the package.
#' When implementing a new analysis type, add it to this vector.
#'
#' Current types:
#' - "fa": Factor Analysis
#' - "gm": Gaussian Mixture (not yet implemented)
#' - "irt": Item Response Theory (not yet implemented)
#' - "cdm": Cognitive Diagnostic Models (not yet implemented)
#'
#' @keywords internal
#' @noRd
VALID_ANALYSIS_TYPES <- c("fa", "gm", "irt", "cdm")

# Analysis types with full implementation
IMPLEMENTED_ANALYSIS_TYPES <- c("fa")


#' Validate Analysis Type
#'
#' Internal helper to validate analysis_type parameter against VALID_ANALYSIS_TYPES.
#' Provides clear error messages when invalid type is provided.
#'
#' @param analysis_type Character string representing the analysis type
#' @param allow_null Logical. If TRUE, NULL values are allowed (default: FALSE)
#'
#' @return Invisibly returns the validated analysis_type
#' @keywords internal
#' @noRd
validate_analysis_type <- function(analysis_type, allow_null = FALSE) {
  # Allow NULL if specified
  if (allow_null && is.null(analysis_type)) {
    return(invisible(NULL))
  }

  # Check for NULL when not allowed
  if (is.null(analysis_type)) {
    cli::cli_abort(c(
      "x" = "{.var analysis_type} cannot be NULL",
      "i" = "Valid types: {.val {VALID_ANALYSIS_TYPES}}"
    ))
  }

  # Check if valid
  if (!analysis_type %in% VALID_ANALYSIS_TYPES) {
    cli::cli_abort(c(
      "x" = "Invalid analysis_type: {.val {analysis_type}}",
      "i" = "Valid types: {.val {VALID_ANALYSIS_TYPES}}",
      "i" = "Only 'fa' (factor analysis) is currently fully implemented"
    ))
  }

  # Check if implemented
  if (!analysis_type %in% IMPLEMENTED_ANALYSIS_TYPES) {
    cli::cli_abort(c(
      "x" = "Analysis type '{analysis_type}' is not yet implemented",
      "i" = "Currently only 'fa' (factor analysis) is fully supported",
      "i" = "Implementation for '{analysis_type}' is planned for a future release"
    ))
  }

  invisible(analysis_type)
}
