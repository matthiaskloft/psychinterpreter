#' Export Gaussian Mixture Interpretation Report
#'
#' Exports the Gaussian Mixture Model interpretation report to a text or markdown file.
#' File extension is automatically added if not provided by the user.
#'
#' @param interpretation_results GM interpretation results - a list containing
#'   Gaussian Mixture interpretation results with a 'report' element
#' @param format Character. Export format: "txt" for plain text or "md" for markdown
#'   (default = "txt")
#' @param file Character. File path with or without extension. The appropriate extension
#'   (.txt or .md) will be added automatically if missing. Can include directory path.
#'   Default is "gm_interpretation"
#' @param silent Integer or logical. Controls output verbosity:
#'   - 0 or FALSE: Show success message (default)
#'   - 1: Suppress success message (same as 2 for this function)
#'   - 2 or TRUE: Suppress success message
#'   For backward compatibility, logical values are accepted and converted to integers.
#'
#' @details
#' **Supported Export Formats:**
#'
#' - **"txt"**: Exports the report in plain text format. If the report in
#'   `interpretation_results` was generated with `output_format = "cli"`, ANSI
#'   color codes will be stripped for clean text output. Otherwise, markdown formatting may be present.
#'
#' - **"md"**: Exports the report in markdown format. If the report in
#'   `interpretation_results` was generated with `output_format = "markdown"`, it will
#'   be exported with proper markdown formatting. Otherwise, it will export the cli version.
#'
#' **File Extension Handling:**
#'
#' The function intelligently handles file extensions:
#' - If you provide `file = "my_report"`, it becomes `"my_report.txt"` or `"my_report.md"`
#' - If you provide `file = "my_report.txt"`, it stays `"my_report.txt"` for format="txt"
#' - Directory paths are preserved: `"output/report"` -> `"output/report.txt"`
#'
#' @return Invisible TRUE on success
#'
#' @examples
#' \dontrun{
#' # Get interpretation results in cli format
#' results_txt <- interpret(fit_results = gmm_model, variable_info,
#'                          output_format = "cli",
#'                          silent = TRUE)
#'
#' # Export as plain text
#' export_interpretation(results_txt, "txt", "my_analysis")
#' # Creates: my_analysis.txt
#'
#' # Get interpretation results in markdown format
#' results_md <- interpret(fit_results = gmm_model, variable_info,
#'                         output_format = "markdown",
#'                         silent = TRUE)
#'
#' # Export as markdown
#' export_interpretation(results_md, "md", "my_analysis")
#' # Creates: my_analysis.md
#' }
#'
#' @export
export_interpretation.gm_interpretation <- function(interpretation_results,
                                                   format = "txt",
                                                   file = "gm_interpretation",
                                                   silent = 0) {

  # Handle backward compatibility: Convert logical to integer
  if (is.logical(silent)) {
    silent <- ifelse(silent, 2, 0)  # FALSE -> 0, TRUE -> 2
  }

  # Validate inputs
  if (!is.list(interpretation_results)) {
    cli::cli_abort("interpretation_results must be a list (output from interpret())")
  }

  if (!is.character(file) || length(file) != 1) {
    cli::cli_abort("file must be a single character string")
  }

  # Get format configuration using dispatch table (from fa_export.R)
  format_config <- get_export_format_config(format)

  # Process file path
  output_file <- process_export_file_path(file, format_config$extension)

  # Extract directory from file path and ensure it exists
  file_dir <- dirname(output_file)
  if (file_dir != "." && !dir.exists(file_dir)) {
    cli::cli_abort("Directory does not exist: {.path {file_dir}}")
  }

  # Build report using GM-specific report builder
  report <- build_report.gm_interpretation(
    interpretation_results,
    output_format = format_config$output_format,  # Correct parameter name
    heading_level = 1
  )

  # Apply format-specific post-processing (from fa_export.R)
  report <- apply_export_format(report, format_config)

  # Write report to file
  # Use cat() to properly interpret escape sequences like \n
  cat(report, file = output_file, sep = "")

  if (silent == 0) {
    cli::cli_alert_success("Report exported to: {.file {output_file}}")
  }

  invisible(TRUE)
}
