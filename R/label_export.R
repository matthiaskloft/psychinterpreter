#' Export Variable Labels
#'
#' Functions for exporting variable labels to various formats.
#'
#' @name label_export
#' @keywords internal
NULL

#' Export Variable Labels
#'
#' Export variable labels to various formats (CSV, CSV2, TXT, or Excel).
#'
#' @param labels variable_labels object or data frame
#' @param file Character. Output file path. Format is auto-detected from extension
#'   (.csv, .txt, .xlsx) unless format parameter is specified.
#' @param format Character or NULL. Export format: "csv" (comma-separated),
#'   "csv2" (semicolon-separated), "txt" (tab-separated), or "xlsx" (Excel).
#'   If NULL, format is auto-detected from file extension.
#'
#' @return Invisible NULL
#' @export
#'
#' @examples
#' \dontrun{
#' # Export labels to CSV (comma-separated, auto-detected)
#' labels <- label_variables(variable_info, llm_provider = "ollama")
#' export_labels(labels, "variable_labels.csv")
#'
#' # Export to CSV2 (semicolon-separated, common in Europe)
#' export_labels(labels, "variable_labels.csv", format = "csv2")
#'
#' # Export to TXT (tab-separated)
#' export_labels(labels, "variable_labels.txt")
#'
#' # Export to Excel
#' export_labels(labels, "variable_labels.xlsx")
#'
#' # Explicitly specify format
#' export_labels(labels, "myfile.dat", format = "csv")
#' }
export_labels <- function(labels, file, format = NULL) {

  # Extract data frame if variable_labels object
  if (inherits(labels, "variable_labels")) {
    df <- labels$labels_formatted
  } else if (is.data.frame(labels)) {
    df <- labels
  } else {
    cli::cli_abort("labels must be a variable_labels object or data frame")
  }

  # Auto-detect format from file extension if not specified
  if (is.null(format)) {
    if (grepl("\\.csv$", file, ignore.case = TRUE)) {
      format <- "csv"
    } else if (grepl("\\.txt$", file, ignore.case = TRUE)) {
      format <- "txt"
    } else if (grepl("\\.xlsx?$", file, ignore.case = TRUE)) {
      format <- "xlsx"
    } else {
      cli::cli_abort(
        c(
          "Cannot auto-detect format from file extension",
          "i" = "Please specify format parameter or use extension: .csv, .txt, or .xlsx"
        )
      )
    }
  }

  # Normalize format
  format <- tolower(format)

  # Export based on format
  if (format == "csv") {
    utils::write.csv(df, file, row.names = FALSE)
    cli::cli_alert_success("Labels exported to {.file {file}} (CSV format)")

  } else if (format == "csv2") {
    utils::write.csv2(df, file, row.names = FALSE)
    cli::cli_alert_success("Labels exported to {.file {file}} (CSV2 format - semicolon separator)")

  } else if (format == "txt") {
    utils::write.table(df, file, row.names = FALSE, sep = "\t", quote = FALSE)
    cli::cli_alert_success("Labels exported to {.file {file}} (TXT format - tab separator)")

  } else if (format == "xlsx") {
    if (requireNamespace("openxlsx", quietly = TRUE)) {
      openxlsx::write.xlsx(df, file)
      cli::cli_alert_success("Labels exported to {.file {file}} (Excel format)")
    } else {
      cli::cli_abort("Package {.pkg openxlsx} required for Excel export")
    }

  } else {
    cli::cli_abort("Format must be one of: 'csv', 'csv2', 'txt', or 'xlsx'")
  }

  invisible(NULL)
}

#' Import Variable Labels
#'
#' Import variable labels from CSV, CSV2, TXT, or Excel format.
#'
#' @param file Character. Input file path
#' @param format Character or NULL. Import format: "csv", "csv2", "txt", or "xlsx".
#'   Auto-detected from file extension if NULL.
#'
#' @return Data frame with 'variable' and 'label' columns
#' @export
#'
#' @examples
#' \dontrun{
#' # Import from CSV (auto-detected)
#' labels_df <- import_labels("variable_labels.csv")
#'
#' # Import from CSV2 (semicolon-separated)
#' labels_df <- import_labels("variable_labels.csv", format = "csv2")
#'
#' # Import from TXT (tab-separated)
#' labels_df <- import_labels("variable_labels.txt")
#'
#' # Import from Excel
#' labels_df <- import_labels("variable_labels.xlsx")
#' }
import_labels <- function(file, format = NULL) {

  # Auto-detect format if not specified
  if (is.null(format)) {
    if (grepl("\\.csv$", file, ignore.case = TRUE)) {
      format <- "csv"
    } else if (grepl("\\.txt$", file, ignore.case = TRUE)) {
      format <- "txt"
    } else if (grepl("\\.xlsx?$", file, ignore.case = TRUE)) {
      format <- "xlsx"
    } else {
      cli::cli_abort(
        c(
          "Cannot determine file format from extension",
          "i" = "Please specify format: 'csv', 'csv2', 'txt', or 'xlsx'"
        )
      )
    }
  }

  # Normalize format
  format <- tolower(format)

  # Import based on format
  if (format == "csv") {
    df <- utils::read.csv(file, stringsAsFactors = FALSE)
  } else if (format == "csv2") {
    df <- utils::read.csv2(file, stringsAsFactors = FALSE)
  } else if (format == "txt") {
    df <- utils::read.table(file, header = TRUE, sep = "\t", stringsAsFactors = FALSE)
  } else if (format == "xlsx") {
    if (requireNamespace("openxlsx", quietly = TRUE)) {
      df <- openxlsx::read.xlsx(file)
    } else {
      cli::cli_abort("Package {.pkg openxlsx} required for Excel import")
    }
  } else {
    cli::cli_abort("Format must be one of: 'csv', 'csv2', 'txt', or 'xlsx'")
  }

  # Validate structure
  if (!all(c("variable", "label") %in% names(df))) {
    cli::cli_abort(
      c(
        "Imported file must contain 'variable' and 'label' columns",
        "x" = "Found columns: {.val {names(df)}}"
      )
    )
  }

  return(df)
}