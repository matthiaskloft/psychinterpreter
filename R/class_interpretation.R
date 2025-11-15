#' Base Interpretation Class Structure
#'
#' Defines the base `interpretation` class and related S3 methods.
#' Model-specific interpretation classes (fa_interpretation, gm_interpretation, etc.)
#' inherit from this base class.
#'
#' @details
#' All model-specific interpretation classes should inherit from this base class.
#' Common fields across all interpretation types:
#' \itemize{
#'   \item analysis_type: Character. Type of analysis ("fa", "gm", "irt", "cdm")
#'   \item component_summaries: List. Summaries of factors/clusters/items/attributes
#'   \item suggested_names: List. LLM-generated names for components
#'   \item interpretations: List. LLM-generated interpretations
#'   \item llm_info: List. Provider, model, and token information
#'   \item chat: Chat session object
#'   \item fit_summary: List. Fit-specific summary information
#'   \item report: Character. Formatted text report
#'   \item elapsed_time: Numeric. Processing time in seconds
#'   \item params: List. Analysis parameters
#' }
#'
#' @name interpretation
#' @keywords internal
NULL

#' Check if object is an interpretation
#'
#' @param x Object to test
#' @return Logical indicating if x is an interpretation object
#' @export
is.interpretation <- function(x) {
  inherits(x, "interpretation")
}

#' Generic print method for interpretation objects
#'
#' Model-specific print methods should be defined as print.\{model_type\}_interpretation
#' and can call this base method via NextMethod() or implement their own.
#'
#' @param x An interpretation object
#' @param ... Additional arguments passed to model-specific methods
#' @export
print.interpretation <- function(x, ...) {
  # Default print: just show the report
  if (!is.null(x$report) && nchar(x$report) > 0) {
    cat(x$report, "\n")
  } else {
    # Fallback if no report
    analysis_type_names <- c(
      fa = "Factor Analysis",
      gm = "Gaussian Mixture",
      irt = "Item Response Theory",
      cdm = "Cognitive Diagnosis"
    )
    model_name <- analysis_type_names[x$analysis_type] %||% x$analysis_type

    cat(model_name, "Interpretation\n")
    cat("Components:", length(x$suggested_names), "\n")
    cat("LLM:", x$llm_info$llm_provider %||% "unknown", "/", x$llm_info$llm_model %||% "unknown", "\n")
  }

  invisible(x)
}

#' Generic plot method for interpretation objects
#'
#' Delegates to model-specific plot methods.
#'
#' @param x An interpretation object
#' @param ... Additional arguments passed to model-specific methods
#' @export
#' @method plot interpretation
plot.interpretation <- function(x, ...) {
  # Check if there's a specific method for this interpretation type
  # If not, provide informative error
  analysis_type <- x$analysis_type

  cli::cli_abort(
    c(
      "No plot method for analysis type: {.val {analysis_type}}",
      "i" = "Implement plot.{analysis_type}_interpretation()"
    )
  )
}
