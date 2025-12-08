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
#' @param verbosity Integer. Controls output verbosity:
#'   - 0: Suppress success message
#'   - 1: Suppress success message (same as 0 for this function)
#'   - 2: Show success message (default)
#'
#' @return Invisible TRUE on success
#'
#' @details
#' This is an S3 generic function. Model-specific export methods are implemented as:
#' - `export_interpretation.fa_interpretation()` for factor analysis
#' - `export_interpretation.gm_interpretation()` for gaussian mixture
#' - Future: `export_interpretation.irt_interpretation()` for IRT
#' - Future: `export_interpretation.cdm_interpretation()` for CDM
#'
#' @seealso [interpret()] for generating interpretations
#'
#' @examples
#' \dontrun{
#' # Run interpretation
#' fa_result <- psych::fa(data, nfactors = 3)
#' var_info <- data.frame(variable = names(data), description = paste("Variable", names(data)))
#' interpretation <- interpret(fa_result, variable_info = var_info,
#'                            llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")
#'
#' # Export to text file
#' export_interpretation(interpretation, format = "txt", file = "results")
#'
#' # Export to markdown file
#' export_interpretation(interpretation, format = "md", file = "results")
#'
#' # Export to specific directory
#' export_interpretation(interpretation, format = "md", file = "output/analysis_results")
#' }
#'
#' @export
export_interpretation <- function(interpretation_results,
                                 format = "txt",
                                 file = "interpretation",
                                 verbosity = 2) {
  UseMethod("export_interpretation")
}

#' Default Export Method
#'
#' Throws an error when no model-specific export method is found. This ensures
#' all supported model types have explicit export implementations.
#'
#' @param interpretation_results Interpretation results object
#' @param format Character. Export format ("txt" or "md")
#' @param file Character. File path with or without extension
#' @param verbosity Integer. Output verbosity control
#'
#' @return Does not return (throws error)
#' @export
#' @keywords internal
export_interpretation.default <- function(interpretation_results,
                                         format = "txt",
                                         file = "interpretation",
                                         verbosity = 2) {
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

  # Try to extract analysis_type
  analysis_type <- interpretation_results$analysis_type %||% "unknown"

  cli::cli_abort(
    c(
      "No export method for model type: {.val {analysis_type}}",
      "i" = "Available types: fa, gm",
      "i" = "Implement export_interpretation.{analysis_type}_interpretation() in R/models/{analysis_type}/"
    )
  )
}
