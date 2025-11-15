#' Export Factor Analysis Interpretation Report
#'
#' Exports the factor analysis interpretation report to a text or markdown file.
#' File extension is automatically added if not provided by the user.
#'
#' @param interpretation_results FA interpretation results - a list containing
#'   factor analysis interpretation results with a 'report' element
#' @param format Character. Export format: "txt" for plain text or "md" for markdown
#'   (default = "txt")
#' @param file Character. File path with or without extension. The appropriate extension
#'   (.txt or .md) will be added automatically if missing. Can include directory path.
#'   Default is "fa_interpretation"
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
#' - Directory paths are preserved: `"output/report"` → `"output/report.txt"`
#'
#' @return Invisible TRUE on success
#'
#' @examples
#' \dontrun{
#' # Get interpretation results in cli format
#' results_txt <- interpret(fit_results, variable_info,
#'                          output_format = "cli",
#'                          silent = TRUE)
#'
#' # Export as plain text
#' export_interpretation(results_txt, "txt", "my_analysis")
#' # Creates: my_analysis.txt
#'
#' # Get interpretation results in markdown format
#' results_md <- interpret(fit_results, variable_info,
#'                         output_format = "markdown",
#'                         silent = TRUE)
#'
#' # Export as markdown
#' export_interpretation(results_md, "md", "my_analysis")
#' # Creates: my_analysis.md
#' }
#'
#' @export
export_interpretation.fa_interpretation <- function(interpretation_results,
                                                   format = "txt",
                                                   file = "fa_interpretation",
                                                   silent = 0) {

  # Handle backward compatibility: Convert logical to integer
  if (is.logical(silent)) {
    silent <- ifelse(silent, 2, 0)  # FALSE -> 0, TRUE -> 2
  }

  # Validate inputs
  if (!is.list(interpretation_results)) {
    cli::cli_abort("interpretation_results must be a list (output from interpret())")
  }

  if (!format %in% c("txt", "md")) {
    cli::cli_abort(
      c(
        "Unsupported format: {.val {format}}",
        "i" = "Supported formats: {.val txt}, {.val md}"
      )
    )
  }

  if (!is.character(file) || length(file) != 1) {
    cli::cli_abort("file must be a single character string")
  }

  # Determine correct file extension
  expected_ext <- if (format == "txt") ".txt" else ".md"

  # Check if file already has the correct extension
  current_ext <- tolower(tools::file_ext(file))

  # Add extension only if missing or different
  if (current_ext == "" || paste0(".", current_ext) != expected_ext) {
    # Remove any existing extension and add the correct one
    file_base <- tools::file_path_sans_ext(file)
    output_file <- paste0(file_base, expected_ext)
  } else {
    # User already provided correct extension
    output_file <- file
  }

  # Extract directory from file path and ensure it exists
  file_dir <- dirname(output_file)
  if (file_dir != "." && !dir.exists(file_dir)) {
    cli::cli_abort("Directory does not exist: {.path {file_dir}}")
  }

  output_format <- if (format == "txt") "cli" else "markdown"

  # Build report
  report <- build_fa_report(
    interpretation_results,
    n_factors = length(interpretation_results$component_summaries),
    output_format = output_format,
    cutoff = interpretation_results$analysis_data$cutoff,
    suppress_heading = FALSE,
    heading_level = 1
  )

  # Write report to file
  # Strip ANSI codes if exporting cli format to txt file
  if (format == "txt") {
    report <- cli::ansi_strip(report)
  }
  # Use cat() to properly interpret escape sequences like \n
  cat(report, file = output_file, sep = "")

  if (silent == 0) {
    cli::cli_alert_success("Report exported to: {.file {output_file}}")
  }

  invisible(TRUE)
}
