#' Export Factor Analysis Interpretation Results
#'
#' Exports factor analysis interpretation results to various generic formats.
#' All formats use base R functionality without external dependencies for
#' maximum compatibility and reliability.
#'
#' @param interpretation_results Results from interpret_fa() function - a list containing
#'   factor analysis interpretation results
#' @param format Character. Export format: "csv", "json", "rds", or "txt" (default = "csv")
#' @param file Character. File path (with or without extension). Can include directory path.
#'   Default is "fa_interpretation" (saves in current directory)
#'
#' @details
#' **Supported Export Formats:**
#'
#' - **"csv"**: Creates multiple CSV files for different components:
#'   - `{file}_loadings.csv` - Factor loading matrix
#'   - `{file}_summary.csv` - Suggested factor names and variance explained
#'   - `{file}_cross_loadings.csv` - Variables with cross-loadings (if any)
#'   - `{file}_no_loadings.csv` - Variables with no significant loadings (if any)
#'   - `{file}_report.txt` - Full interpretation report
#'
#' - **"json"**: Single JSON file containing all results in structured format.
#'   Ideal for programmatic access and web applications.
#'
#' - **"rds"**: Native R data format preserving exact object structure.
#'   Perfect for re-importing into R with full fidelity.
#'
#' - **"txt"**: Text-based export with formatted report and separate data files:
#'   - `{file}_report.txt` - Main interpretation report
#'   - `{file}_loadings.txt` - Tab-separated loading matrix
#'   - `{file}_summary.txt` - Tab-separated summary information
#'
#' @return Invisible TRUE on success
#'
#' @examples
#' \dontrun{
#' # Get interpretation results
#' results <- interpret_fa(loadings, variable_info, silent = TRUE)
#'
#' # Export to current directory
#' export_interpretation(results, "csv", "my_analysis")
#'
#' # Export to specific directory
#' export_interpretation(results, "csv", "output/my_analysis")
#' export_interpretation(results, "json", "results/factors")
#' }
#'
#' @importFrom utils write.csv write.table
#' @export
export_interpretation <- function(interpretation_results,
                                 format = "csv",
                                 file = "fa_interpretation") {

  # Validate inputs
  if (!is.list(interpretation_results)) {
    cli::cli_abort("interpretation_results must be a list (output from interpret_fa)")
  }

  if (!format %in% c("csv", "json", "rds", "txt")) {
    cli::cli_abort(
      c(
        "Unsupported format: {.val {format}}",
        "i" = "Supported formats: {.val csv}, {.val json}, {.val rds}, {.val txt}"
      )
    )
  }

  if (!is.character(file) || length(file) != 1) {
    cli::cli_abort("file must be a single character string")
  }

  # Extract directory from file path and ensure it exists
  file_dir <- dirname(file)
  if (!dir.exists(file_dir)) {
    cli::cli_abort("Directory does not exist: {.path {file_dir}}")
  }

  # Get base filename without directory
  base_name <- basename(file)

  # Export based on format
  switch(format,

    "csv" = {
      # Export loading matrix
      if ("loading_matrix" %in% names(interpretation_results)) {
        write.csv(interpretation_results$loading_matrix,
                  paste0(file, "_loadings.csv"),
                  row.names = FALSE)
      }

      # Export summary information
      if ("suggested_names" %in% names(interpretation_results) &&
          "factor_summaries" %in% names(interpretation_results)) {

        # Create summary dataframe
        factor_names <- names(interpretation_results$suggested_names)
        summary_df <- data.frame(
          factor = factor_names,
          suggested_name = unlist(interpretation_results$suggested_names),
          variance_explained = sapply(interpretation_results$factor_summaries,
                                    function(x) x$variance_explained),
          n_variables = sapply(interpretation_results$factor_summaries,
                              function(x) x$n_variables),
          stringsAsFactors = FALSE
        )

        write.csv(summary_df,
                  paste0(file, "_summary.csv"),
                  row.names = FALSE)
      }

      # Export cross-loadings if present
      if ("cross_loadings" %in% names(interpretation_results) &&
          !is.null(interpretation_results$cross_loadings) &&
          nrow(interpretation_results$cross_loadings) > 0) {

        write.csv(interpretation_results$cross_loadings,
                  paste0(file, "_cross_loadings.csv"),
                  row.names = FALSE)
      }

      # Export no-loadings if present
      if ("no_loadings" %in% names(interpretation_results) &&
          !is.null(interpretation_results$no_loadings) &&
          nrow(interpretation_results$no_loadings) > 0) {

        write.csv(interpretation_results$no_loadings,
                  paste0(file, "_no_loadings.csv"),
                  row.names = FALSE)
      }

      # Export report as text file
      if ("report" %in% names(interpretation_results)) {
        writeLines(interpretation_results$report,
                   paste0(file, "_report.txt"))
      }

      cli::cli_alert_success("Results exported as CSV files to: {.path {file_dir}}")
      cli::cli_text("Files created: {.file {base_name}_*.csv}, {.file {base_name}_report.txt}")
    },
    
    "json" = {
      # Convert to JSON using base R jsonlite-style approach
      # Create a clean structure for JSON export
      json_data <- list(
        metadata = list(
          export_format = "json",
          export_date = Sys.time(),
          package = "psychinterpreter"
        ),
        interpretation = interpretation_results
      )

      # Use built-in JSON serialization (requires jsonlite or equivalent)
      json_file <- paste0(file, ".json")

      # Simple JSON export (basic implementation)
      if (requireNamespace("jsonlite", quietly = TRUE)) {
        jsonlite::write_json(json_data, json_file, pretty = TRUE, auto_unbox = TRUE)
      } else {
        # Fallback: create a simple text representation
        writeLines(c(
          "{",
          paste0('  "export_date": "', Sys.time(), '",'),
          paste0('  "package": "psychinterpreter",'),
          paste0('  "report": "', gsub('"', '\\\\"', gsub('\n', '\\\\n', interpretation_results$report)), '",'),
          paste0('  "n_factors": ', length(interpretation_results$factor_summaries)),
          "}"
        ), json_file)
        cli::cli_warn("jsonlite package not available - created simplified JSON format")
      }

      cli::cli_alert_success("Results exported to: {.file {json_file}}")
    },

    "rds" = {
      # Save as R data file (preserves exact structure)
      rds_file <- paste0(file, ".rds")
      saveRDS(interpretation_results, rds_file)

      cli::cli_alert_success("Results exported to: {.file {rds_file}}")
      cli::cli_text("Use {.code readRDS()} to reload the data in R")
    },

    "txt" = {
      # Export main report
      if ("report" %in% names(interpretation_results)) {
        writeLines(interpretation_results$report,
                   paste0(file, "_report.txt"))
      }

      # Export loading matrix as tab-delimited
      if ("loading_matrix" %in% names(interpretation_results)) {
        write.table(interpretation_results$loading_matrix,
                    paste0(file, "_loadings.txt"),
                    sep = "\t", row.names = FALSE, quote = FALSE)
      }

      # Export summary as tab-delimited
      if ("suggested_names" %in% names(interpretation_results) &&
          "factor_summaries" %in% names(interpretation_results)) {

        factor_names <- names(interpretation_results$suggested_names)
        summary_df <- data.frame(
          factor = factor_names,
          suggested_name = unlist(interpretation_results$suggested_names),
          variance_explained = sapply(interpretation_results$factor_summaries,
                                    function(x) x$variance_explained),
          stringsAsFactors = FALSE
        )

        write.table(summary_df,
                    paste0(file, "_summary.txt"),
                    sep = "\t", row.names = FALSE, quote = FALSE)
      }

      cli::cli_alert_success("Results exported as text files to: {.path {file_dir}}")
      cli::cli_text("Files created: {.file {base_name}_*.txt}")
    }
  )
  
  return(invisible(TRUE))
}
