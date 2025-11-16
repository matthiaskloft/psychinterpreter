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

  if (!is.character(file) || length(file) != 1) {
    cli::cli_abort("file must be a single character string")
  }

  # Get format configuration using dispatch table
  format_config <- get_export_format_config(format)

  # Process file path
  output_file <- process_export_file_path(file, format_config$extension)

  # Extract directory from file path and ensure it exists
  file_dir <- dirname(output_file)
  if (file_dir != "." && !dir.exists(file_dir)) {
    cli::cli_abort("Directory does not exist: {.path {file_dir}}")
  }

  # Build report
  report <- build_fa_report(
    interpretation_results,
    n_factors = length(interpretation_results$component_summaries),
    output_format = format_config$output_format,
    cutoff = interpretation_results$analysis_data$cutoff,
    suppress_heading = FALSE,
    heading_level = 1
  )

  # Apply format-specific post-processing
  report <- apply_export_format(report, format_config)

  # Write report to file
  # Use cat() to properly interpret escape sequences like \n
  cat(report, file = output_file, sep = "")

  if (silent == 0) {
    cli::cli_alert_success("Report exported to: {.file {output_file}}")
  }

  invisible(TRUE)
}

#' Export Format Dispatch Table
#'
#' Centralized configuration for supported export formats.
#' Maps format names to their properties (extension, output format, post-processor).
#'
#' @return A list of format configurations, each containing:
#'   - `extension`: File extension including the dot (e.g., ".txt")
#'   - `output_format`: Format name for report builder (e.g., "cli")
#'   - `post_processor`: Function to apply format-specific transformations
#'
#' @keywords internal
export_format_dispatch_table <- function() {
  list(
    txt = list(
      extension = ".txt",
      output_format = "cli",
      post_processor = function(report) cli::ansi_strip(report),
      supported_formats = c("txt")
    ),
    md = list(
      extension = ".md",
      output_format = "markdown",
      post_processor = function(report) report,  # No transformation for markdown
      supported_formats = c("md")
    )
  )
}

#' Get Export Format Configuration
#'
#' Retrieves configuration for a specific export format from the dispatch table.
#' Validates that the format is supported and returns its configuration.
#'
#' @param format Character. The export format name (e.g., "txt", "md")
#'
#' @return A list containing the format configuration
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' config <- get_export_format_config("txt")
#' # Returns list with extension=".txt", output_format="cli", post_processor=function
#' }
get_export_format_config <- function(format) {
  # Get dispatch table
  dispatch_table <- export_format_dispatch_table()

  # Validate format exists in dispatch table
  if (!format %in% names(dispatch_table)) {
    supported <- paste(names(dispatch_table), collapse = ", ")
    cli::cli_abort(
      c(
        "Unsupported format: {.val {format}}",
        "i" = "Supported formats: {.val {supported}}"
      )
    )
  }

  # Return configuration for requested format
  dispatch_table[[format]]
}

#' Process Export File Path
#'
#' Intelligently handles file extension management for export files.
#' Adds the correct extension if missing, and replaces incorrect extensions.
#'
#' @param file Character. Original file path
#' @param expected_extension Character. The extension that should be used (e.g., ".txt")
#'
#' @return Character. The processed file path with correct extension
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # Add extension if missing
#' process_export_file_path("report", ".txt")     # Returns "report.txt"
#'
#' # Keep correct extension
#' process_export_file_path("report.txt", ".txt") # Returns "report.txt"
#'
#' # Replace incorrect extension
#' process_export_file_path("report.md", ".txt")  # Returns "report.txt"
#' }
process_export_file_path <- function(file, expected_extension) {
  # Get current file extension
  current_ext <- tolower(tools::file_ext(file))

  # Normalize expected extension (ensure it starts with ".")
  if (!startsWith(expected_extension, ".")) {
    expected_extension <- paste0(".", expected_extension)
  }

  # Check if file already has correct extension
  if (current_ext == "" || paste0(".", current_ext) != expected_extension) {
    # Remove any existing extension and add the correct one
    file_base <- tools::file_path_sans_ext(file)
    output_file <- paste0(file_base, expected_extension)
  } else {
    # User already provided correct extension
    output_file <- file
  }

  output_file
}

#' Apply Export Format Transformations
#'
#' Applies format-specific post-processing to a report.
#' Uses the post-processor function from the format configuration.
#'
#' @param report Character. The report text to process
#' @param format_config List. Format configuration from dispatch table
#'
#' @return Character. The processed report
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' config <- get_export_format_config("txt")
#' processed <- apply_export_format("Report with ANSI codes", config)
#' }
apply_export_format <- function(report, format_config) {
  # Ensure format_config has a post_processor function
  if (!is.function(format_config$post_processor)) {
    cli::cli_warn("Format config missing post_processor, returning report unchanged")
    return(report)
  }

  # Apply format-specific transformation
  format_config$post_processor(report)
}
