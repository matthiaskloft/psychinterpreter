#' Model Data Builder Framework
#'
#' S3 generic functions for extracting and preparing model-specific data from
#' various fitted model objects. This is the first step in the interpretation
#' pipeline, converting raw model outputs into a standardized format.
#'
#' @name model_data
#' @keywords internal
NULL

#' Build Model Data (S3 Generic)
#'
#' Extracts and validates model-specific data from fitted model objects.
#' This includes loadings, factor correlations, fit indices, and other
#' model-specific information needed for interpretation.
#'
#' @param fit_results Fitted model object (e.g., psych::fa, lavaan::cfa, list with loadings)
#' @param model_type Character. Model type ("fa", "gm", "irt", "cdm"). Required for list inputs.
#' @param interpretation_args Interpretation configuration object from interpretation_args() or NULL
#' @param ... Additional arguments passed to model-specific methods, including variable_info
#'   (data frame with 'variable' and 'description' columns, required for FA)
#'
#' @return List containing standardized model data:
#'   \item{model_type}{Character. Model type identifier}
#'   \item{loadings}{Data frame. Factor loadings with 'variable' column}
#'   \item{factor_names}{Character vector. Factor names}
#'   \item{n_factors}{Integer. Number of factors}
#'   \item{n_variables}{Integer. Number of variables}
#'   \item{...}{Additional model-specific data}
#'
#' @export
#' @keywords internal
build_model_data <- function(fit_results, model_type = NULL, interpretation_args = NULL, ...) {
  UseMethod("build_model_data")
}

#' Default method for build_model_data
#'
#' @export
#' @keywords internal
build_model_data.default <- function(fit_results, model_type = NULL, interpretation_args = NULL, ...) {
  # Get the class name
  model_class <- class(fit_results)[1]

  cli::cli_abort(
    c(
      "No model data builder for object of class: {.val {model_class}}",
      "i" = "Supported types: fa, psych, principal, lavaan, SingleGroupClass (mirt), or list",
      "i" = "For list input, provide model_type parameter (e.g., model_type = 'fa')",
      "i" = "Implement build_model_data.{model_class}() to add support"
    )
  )
}
