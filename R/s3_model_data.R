#' Model Data Builder Framework
#'
#' S3 generic functions for extracting and preparing model-specific data from
#' various fitted model objects. This is the first step in the interpretation
#' pipeline, converting raw model outputs into a standardized format.
#'
#' @name analysis_data
#' @keywords internal
NULL

#' Build Analysis Data (S3 Generic)
#'
#' Extracts and validates model-specific data from fitted model objects.
#' This includes loadings, factor correlations, fit indices, and other
#' model-specific information needed for interpretation.
#'
#' @param fit_results Fitted model object (e.g., psych::fa, lavaan::cfa, list with loadings)
#' @param analysis_type Character. Model type ("fa", "gm", "irt", "cdm"). Required for list inputs.
#' @param interpretation_args Interpretation configuration object from interpretation_args() or NULL
#' @param ... Additional arguments passed to model-specific methods, including variable_info
#'   (data frame with 'variable' and 'description' columns, required for FA)
#'
#' @return List containing standardized model data:
#'   \item{analysis_type}{Character. Model type identifier}
#'   \item{loadings}{Data frame. Factor loadings with 'variable' column}
#'   \item{factor_names}{Character vector. Factor names}
#'   \item{n_factors}{Integer. Number of factors}
#'   \item{n_variables}{Integer. Number of variables}
#'   \item{...}{Additional model-specific data}
#'
#' @export
#' @keywords internal
build_analysis_data <- function(fit_results, analysis_type = NULL, interpretation_args = NULL, ...) {
  UseMethod("build_analysis_data")
}

#' Default method for build_analysis_data
#'
#' Throws an informative error for unsupported model types.
#'
#' @inheritParams build_analysis_data
#' @export
#' @keywords internal
build_analysis_data.default <- function(fit_results, analysis_type = NULL, interpretation_args = NULL, ...) {
  # Get the class name
  model_class <- class(fit_results)[1]

  cli::cli_abort(
    c(
      "No model data builder for object of class: {.val {model_class}}",
      "i" = "Supported types: fa, psych, principal, lavaan, SingleGroupClass (mirt), Mclust, or list",
      "i" = "For list input, provide analysis_type parameter (e.g., analysis_type = 'fa')",
      "i" = "Implement build_analysis_data.{model_class}() in R/{model_class}_model_data.R to add support"
    )
  )
}


#' Build Structured List for Interpretation
#'
#' S3 generic to build structured list from extracted components.
#' Called when user provides structured list input to interpret().
#'
#' @param x Extracted data (e.g., loadings matrix)
#' @param analysis_type Character. Analysis type identifier
#' @param ... Additional analysis-specific arguments
#'
#' @return Structured list for interpret_core()
#' @export
#' @keywords internal
build_structured_list <- function(x, analysis_type, ...) {
  UseMethod("build_structured_list", structure(list(), class = analysis_type))
}

#' Default method for build_structured_list
#'
#' Throws an error for unsupported analysis types.
#'
#' @inheritParams build_structured_list
#' @export
#' @keywords internal
build_structured_list.default <- function(x, analysis_type, ...) {
  cli::cli_abort(
    c(
      "{analysis_type} interpretation not yet implemented",
      "i" = "Currently supported: 'fa' (factor analysis), 'gm' (Gaussian mixture)"
    )
  )
}
