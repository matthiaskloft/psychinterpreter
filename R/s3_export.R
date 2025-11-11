#' Export Interpretation Report (S3 Generic)
#'
#' Exports interpretation reports to text or markdown files.
#' File extension is automatically added if not provided by the user.
#'
#' @param interpretation_results Interpretation results object from interpret()
#' @param format Character. Export format: "txt" for plain text or "md" for markdown
#'   (default = "txt")
#' @param file Character. File path with or without extension. The appropriate extension
#'   (.txt or .md) will be added automatically if missing. Can include directory path.
#'   Default is "interpretation"
#' @param silent Integer or logical. Controls output verbosity:
#'   - 0 or FALSE: Show success message (default)
#'   - 1: Suppress success message (same as 2 for this function)
#'   - 2 or TRUE: Suppress success message
#'
#' @return Invisible TRUE on success
#'
#' @details
#' This is an S3 generic function. Model-specific export methods are implemented as:
#' - `export_interpretation.fa_interpretation()` for factor analysis
#' - Future: `export_interpretation.gm_interpretation()` for gaussian mixture
#' - Future: `export_interpretation.irt_interpretation()` for IRT
#' - Future: `export_interpretation.cdm_interpretation()` for CDM
#'
#' @export
export_interpretation <- function(interpretation_results,
                                 format = "txt",
                                 file = "interpretation",
                                 silent = 0) {
  UseMethod("export_interpretation")
}

#' Default Export Method
#'
#' @export
#' @keywords internal
export_interpretation.default <- function(interpretation_results,
                                         format = "txt",
                                         file = "interpretation",
                                         silent = 0) {
  # Validate input is a list first
  if (!is.list(interpretation_results)) {
    cli::cli_abort(
      c(
        "interpretation_results must be a list",
        "x" = "You supplied: {.type {interpretation_results}}"
      )
    )
  }

  # Validate format
  if (!format %in% c("txt", "md")) {
    cli::cli_abort(
      c(
        "Unsupported format: {.val {format}}",
        "i" = "Supported formats: 'txt', 'md'"
      )
    )
  }

  # Validate file parameter
  if (!is.character(file) || length(file) != 1) {
    cli::cli_abort(
      c(
        "file must be a single character string",
        "x" = "You supplied: {.type {file}}"
      )
    )
  }

  # Try to extract model_type
  model_type <- interpretation_results$model_type %||% "unknown"

  cli::cli_abort(
    c(
      "No export method for model type: {.val {model_type}}",
      "i" = "Available types: fa",
      "i" = "Implement export_interpretation.{model_type}_interpretation() in R/models/{model_type}/"
    )
  )
}
