# ==============================================================================
# S3 GENERICS: LIST VALIDATION
# ==============================================================================
#
# Model-specific validation and extraction of data from structured lists.
# Each model type defines what components are required and how to extract them.
#
# This enables interpret() to accept structured lists for any model type:
#   interpret(fit_results = list(loadings = ..., factor_cor_mat = ...))
#   interpret(fit_results = list(posterior = ..., means = ...))  # GM
#   interpret(fit_results = list(item_params = ..., ability = ...))  # IRT
#

#' Validate and Extract Structured List Components (S3 Generic)
#'
#' Model-specific validation and extraction of data from structured lists.
#' Each model type defines what components are required and how to extract them.
#'
#' @param model_type Character. Model type identifier ("fa", "gm", "irt", "cdm")
#' @param fit_results_list List. Structured list with model-specific components
#'
#' @return List containing extracted and validated components (model-specific structure)
#' @export
#' @keywords internal
validate_list_structure <- function(model_type, fit_results_list) {
  # Create dispatch object with model_type class
  dispatch_obj <- structure(
    list(),
    class = c(model_type, "list_validator")
  )

  UseMethod("validate_list_structure", dispatch_obj)
}


#' Default Method for validate_list_structure
#'
#' Returns an error for unsupported model types.
#'
#' @param model_type Dispatch object with model type class
#' @param fit_results_list List. Structured list
#'
#' @return Never returns - always errors
#' @export
#' @keywords internal
validate_list_structure.default <- function(model_type, fit_results_list) {
  model_class <- class(model_type)[1]

  cli::cli_abort(
    c(
      "No list validator for model type: {.val {model_class}}",
      "i" = "Available types: fa, gm, irt, cdm",
      "i" = "Implement validate_list_structure.{model_class}() to add support"
    )
  )
}


#' Validate FA Structured List (S3 Method)
#'
#' Extracts and validates FA-specific list components.
#' Required components: loadings
#' Optional components: factor_cor_mat or Phi
#'
#' @param model_type Character. Should be "fa"
#' @param fit_results_list List. Must contain 'loadings' component
#'
#' @return List with components: loadings, factor_cor_mat
#' @export
#' @keywords internal
validate_list_structure.fa <- function(model_type, fit_results_list) {
  # Check that loadings is present (required)
  if (!"loadings" %in% names(fit_results_list)) {
    cli::cli_abort(
      c(
        "{.var fit_results} list must contain a 'loadings' component",
        "x" = "Current components: {.field {names(fit_results_list)}}",
        "i" = "Minimum required structure: list(loadings = matrix(...))",
        "i" = "Optional components: factor_cor_mat"
      )
    )
  }

  # Extract loadings
  loadings <- fit_results_list$loadings

  # Validate loadings is a matrix or data.frame
  if (!is.matrix(loadings) && !is.data.frame(loadings)) {
    cli::cli_abort(
      c(
        "{.var loadings} component must be a matrix or data.frame",
        "x" = "You provided: {.cls {class(loadings)}}",
        "i" = "Convert to matrix or data.frame before passing to interpret()"
      )
    )
  }

  # Extract factor correlation matrix (optional)
  # Accept both "factor_cor_mat" and "Phi" (psych::fa uses "Phi")
  factor_cor_mat <- NULL
  if ("factor_cor_mat" %in% names(fit_results_list)) {
    factor_cor_mat <- fit_results_list$factor_cor_mat
  } else if ("Phi" %in% names(fit_results_list)) {
    factor_cor_mat <- fit_results_list$Phi
  }

  # Validate and convert factor_cor_mat if provided
  if (!is.null(factor_cor_mat)) {
    if (!is.matrix(factor_cor_mat) && !is.data.frame(factor_cor_mat)) {
      cli::cli_abort(
        c(
          "Factor correlation matrix must be a matrix or data.frame",
          "x" = "You provided: {.cls {class(factor_cor_mat)}}",
          "i" = "Use matrix() or data.frame() to create a proper correlation matrix"
        )
      )
    }

    # Convert data.frame to matrix if needed
    if (is.data.frame(factor_cor_mat)) {
      factor_cor_mat <- as.matrix(factor_cor_mat)
    }
  }

  # Warn about unrecognized components
  # Accept both "factor_cor_mat" and "Phi" (psych::fa uses "Phi")
  recognized_components <- c("loadings", "factor_cor_mat", "Phi")
  unrecognized <- setdiff(names(fit_results_list), recognized_components)

  if (length(unrecognized) > 0) {
    cli::cli_warn(
      c(
        "!" = "Unrecognized components in fit_results list will be ignored",
        "i" = "Unrecognized: {.field {unrecognized}}",
        "i" = "Recognized components: {.field {recognized_components}}",
        "i" = "Note: Use {.arg additional_info} parameter for contextual information, not fit_results list"
      )
    )
  }

  # Return extracted components
  list(
    loadings = loadings,
    factor_cor_mat = factor_cor_mat
  )
}
