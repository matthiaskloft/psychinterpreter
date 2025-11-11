# Package-level constants
#
# This file contains constants used throughout the package to ensure consistency
# and make it easier to add new model types.

#' Valid Model Types
#'
#' Vector of valid model type identifiers supported by the package.
#' When implementing a new model type, add it to this vector.
#'
#' Current types:
#' - "fa": Factor Analysis
#' - "gm": Gaussian Mixture (not yet implemented)
#' - "irt": Item Response Theory (not yet implemented)
#' - "cdm": Cognitive Diagnostic Models (not yet implemented)
#'
#' @keywords internal
#' @noRd
VALID_MODEL_TYPES <- c("fa")  # , "gm", "irt", "cdm")  # Uncomment when implemented


#' Validate Model Type
#'
#' Internal helper to validate model_type parameter against VALID_MODEL_TYPES.
#' Provides clear error messages when invalid type is provided.
#'
#' @param model_type Character string representing the model type
#' @param allow_null Logical. If TRUE, NULL values are allowed (default: FALSE)
#'
#' @return Invisibly returns the validated model_type
#' @keywords internal
#' @noRd
validate_model_type <- function(model_type, allow_null = FALSE) {
  # Allow NULL if specified
  if (allow_null && is.null(model_type)) {
    return(invisible(NULL))
  }

  # Check for NULL when not allowed
  if (is.null(model_type)) {
    cli::cli_abort(c(
      "x" = "{.var model_type} cannot be NULL",
      "i" = "Valid types: {.val {VALID_MODEL_TYPES}}"
    ))
  }

  # Check if valid
  if (!model_type %in% VALID_MODEL_TYPES) {
    cli::cli_abort(c(
      "x" = "Invalid model_type: {.val {model_type}}",
      "i" = "Valid types: {.val {VALID_MODEL_TYPES}}",
      "i" = "Only 'fa' (factor analysis) is currently fully implemented"
    ))
  }

  invisible(model_type)
}
