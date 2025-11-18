# ===================================================================
# FILE: gm_report.R
# PURPOSE: Report generation for Gaussian Mixture Model interpretations
# ===================================================================
# Note: Shared formatting functions from shared_formatting.R are automatically
# available in the package namespace.

#' Build Report Header for GM Interpretation
#'
#' Creates the header section with model metadata, LLM info, and token counts.
#'
#' @param interpretation An object of class "gm_interpretation"
#' @param output_format Output format: "cli" or "markdown"
#' @param heading_level Starting heading level for markdown (default: 1)
#' @param suppress_heading Logical. If TRUE, suppress the main heading
#' @return Character string containing the formatted header
#' @keywords internal
build_report_header_gm <- function(interpretation,
                                   output_format = "cli",
                                   heading_level = 1,
                                   suppress_heading = FALSE) {

  format <- match.arg(output_format, c("cli", "markdown"))

  # Extract data
  analysis_data <- interpretation$analysis_data
  fit_summary <- interpretation$fit_summary
  chat <- interpretation$chat
  llm_info <- interpretation$llm_info

  # Get dispatch functions
  bold_fn <- get_format_fn(format, "bold")
  main_header_fn <- get_format_fn(format, "main_header")
  token_header_fn <- get_format_fn(format, "token_header")
  token_line_fn <- get_format_fn(format, "token_line")

  # Add main heading unless suppressed
  if (!suppress_heading) {
    title <- paste0(
      "Gaussian Mixture Model Interpretation: ",
      analysis_data$n_clusters, " Clusters"
    )
    report <- main_header_fn(title, heading_level)
  } else {
    report <- ""
  }

  # Build metadata section
  report <- paste0(
    report,
    fmt_keyval(format, "Number of clusters", as.character(analysis_data$n_clusters), "gm")
  )
  report <- paste0(
    report,
    fmt_keyval(format, "Number of variables", as.character(analysis_data$n_variables), "gm")
  )
  report <- paste0(
    report,
    fmt_keyval(format, "Number of observations", as.character(analysis_data$n_observations), "gm")
  )

  # Covariance structure
  if (!is.null(analysis_data$covariance_type)) {
    cov_desc <- describe_covariance_type(analysis_data$covariance_type)
    report <- paste0(
      report,
      fmt_keyval(format, "Covariance structure", cov_desc, "gm")
    )
  }

  # Model fit
  if (!is.null(fit_summary$statistics)) {
    if (!is.null(fit_summary$statistics$bic)) {
      bic_value <- format(round(fit_summary$statistics$bic, 2), nsmall = 2)
      report <- paste0(
        report,
        fmt_keyval(format, "BIC", bic_value, "gm")
      )
    }
    if (!is.null(fit_summary$statistics$min_separation)) {
      sep_value <- format(round(fit_summary$statistics$min_separation, 3), nsmall = 3)
      report <- paste0(
        report,
        fmt_keyval(format, "Minimum cluster separation", sep_value, "gm")
      )
    }
  }

  # Handle LLM info safely
  if (!is.null(chat)) {
    llm_value <- paste(chat$llm_provider, "-", chat$llm_model %||% "default")
    report <- paste0(report, fmt_keyval(format, "LLM used", llm_value, "gm"))

    if (!is.null(interpretation$input_tokens) &&
        !is.null(interpretation$output_tokens)) {
      report <- paste0(
        report,
        token_header_fn(bold_fn),
        token_line_fn("Input", interpretation$input_tokens),
        token_line_fn("Output", interpretation$output_tokens)
      )
    }
  } else if (!is.null(llm_info)) {
    llm_value <- paste(llm_info$llm_provider, "-", llm_info$llm_model %||% "default")
    report <- paste0(report, fmt_keyval(format, "LLM used", llm_value, "gm"))
  }

  return(report)
}

#' Build Report for GM Interpretation
#'
#' Creates a formatted report from GM interpretation results.
#'
#' @param interpretation An object of class "gm_interpretation"
#' @param output_format Output format: "cli" or "markdown"
#' @param heading_level Starting heading level for markdown (default: 1)
#' @param suppress_heading Logical. If TRUE, suppress the main heading
#' @param ... Additional arguments (for S3 consistency)
#' @return Character string containing the formatted report
#' @export
#' @keywords internal
build_report.gm_interpretation <- function(
    interpretation,
    output_format = "cli",
    heading_level = 1,
    suppress_heading = FALSE,
    ...) {

  format <- match.arg(output_format, c("cli", "markdown"))

  # Extract components
  cluster_interpretations <- interpretation$component_summaries
  analysis_data <- interpretation$analysis_data
  fit_summary <- interpretation$fit_summary
  suggested_names <- interpretation$suggested_names
  elapsed_time <- interpretation$elapsed_time

  # Build report sections
  sections <- list()

  # Header section (title + model info + LLM info + tokens)
  sections$header <- build_report_header_gm(
    interpretation = interpretation,
    output_format = format,
    heading_level = heading_level,
    suppress_heading = suppress_heading
  )

  # Cluster names section (like FA's factor names section)
  sections$cluster_names <- build_cluster_names_section_gm(
    suggested_names, analysis_data, format, heading_level
  )

  # Cluster interpretations
  sections$interpretations <- build_interpretations_section_gm(
    cluster_interpretations, suggested_names, analysis_data,
    format, heading_level
  )

  # Diagnostics
  if (!is.null(fit_summary)) {
    sections$diagnostics <- build_diagnostics_section_gm(
      fit_summary, format, heading_level
    )
  }

  # Key variables per cluster
  distinguishing_vars <- find_distinguishing_variables_gm(analysis_data, top_n = 3)
  if (!is.null(distinguishing_vars)) {
    sections$key_variables <- build_key_variables_section_gm(
      distinguishing_vars, suggested_names, format, heading_level
    )
  }

  # Combine all sections
  report <- paste(sections, collapse = "\n\n")

  # Insert elapsed time after tokens or LLM info in the report
  if (!is.null(elapsed_time)) {
    if (format == "markdown") {
      # Try to insert after Tokens section, if not found try after LLM used line
      if (grepl("\\*\\*Tokens:\\*\\*", report)) {
        report <- sub(
          "(\\*\\*Tokens:\\*\\*  \n  Input: [0-9]+  \n  Output: [0-9]+  \n)",
          paste0(
            "\\1**Elapsed time:** ",
            format(elapsed_time, digits = 3),
            "  \n\n"
          ),
          report
        )
      } else {
        report <- sub(
          "(\\*\\*LLM used:\\*\\* [^\n]*  \n)",
          paste0(
            "\\1**Elapsed time:** ",
            format(elapsed_time, digits = 3),
            "  \n\n"
          ),
          report
        )
      }
    } else {
      # CLI format
      # Try to insert after Tokens section, if not found try after LLM used line
      if (grepl("Tokens:", report)) {
        report <- sub(
          "(Tokens:\n  Input: [0-9]+\n  Output: [0-9]+\n)",
          paste0(
            "\\1Elapsed time: ",
            format(elapsed_time, digits = 3),
            "\n\n"
          ),
          report
        )
      } else {
        report <- sub("(LLM used: [^\n]*\n)",
                      paste0(
                        "\\1Elapsed time: ",
                        format(elapsed_time, digits = 3),
                        "\n\n"
                      ),
                      report)
      }
    }
  }

  return(report)
}

#' Print Method for GM Interpretation Objects
#'
#' Prints the interpretation report with optional text wrapping and format control.
#'
#' @param x An object of class "gm_interpretation" (output from interpret())
#' @param max_line_length Maximum line length for text wrapping (20-300).
#'   Default: 80. Only applies to CLI format output.
#' @param output_format Output format: "cli" or "markdown". If specified and
#'   component_summaries exists, regenerates the report in the specified format.
#'   If NULL (default), uses the existing report format.
#' @param heading_level Starting heading level for markdown output (1-6).
#'   Default: 1. Only applies to markdown format.
#' @param suppress_heading Logical. If TRUE, suppresses the main heading in the report.
#'   Default: FALSE.
#' @param ... Additional arguments (currently unused, for S3 consistency)
#'
#' @return Invisibly returns NULL (called for side effect of printing)
#'
#' @details
#' The print method handles two scenarios:
#' \itemize{
#'   \item If \code{output_format} is NULL, prints the existing report stored in x$report
#'   \item If \code{output_format} is specified AND component_summaries exists,
#'         regenerates the report in the requested format using build_report.gm_interpretation()
#' }
#'
#' Text wrapping is only applied to CLI format output. Markdown output preserves
#' its original formatting without wrapping.
#'
#' @examples
#' \dontrun{
#' # Basic usage (uses existing report)
#' print(gm_result)
#'
#' # Specify output format and regenerate report
#' print(gm_result, output_format = "markdown")
#'
#' # Customize line length for CLI output
#' print(gm_result, max_line_length = 120)
#'
#' # Markdown with custom heading level
#' print(gm_result, output_format = "markdown", heading_level = 2)
#' }
#'
#' @export
print.gm_interpretation <- function(x,
                                    max_line_length = 80,
                                    output_format = NULL,
                                    heading_level = 1,
                                    suppress_heading = FALSE,
                                    ...) {
  # Validate input
  if (!inherits(x, "gm_interpretation") || !is.list(x)) {
    cli::cli_abort(
      c("Input must be a gm_interpretation object", "i" = "This should be the output from interpret()")
    )
  }

  if (!("report" %in% names(x)) &&
      !("component_summaries" %in% names(x))) {
    cli::cli_abort(
      c(
        "gm_interpretation object must contain 'report' or 'component_summaries' component",
        "i" = "This should be the output from interpret()"
      )
    )
  }

  # Validate max_line_length parameter
  if (!is.numeric(max_line_length) ||
      length(max_line_length) != 1) {
    cli::cli_abort(
      c("{.var max_line_length} must be a single numeric value", "x" = "You supplied: {.val {max_line_length}}")
    )
  }
  if (max_line_length < 20 || max_line_length > 300) {
    cli::cli_abort(
      c(
        "{.var max_line_length} must be between 20 and 300",
        "x" = "You supplied: {.val {max_line_length}}",
        "i" = "Recommended range is 80-120 characters for readability"
      )
    )
  }

  # Validate output_format if provided
  if (!is.null(output_format)) {
    if (!is.character(output_format) || length(output_format) != 1) {
      cli::cli_abort(
        c(
          "{.var output_format} must be a single character string",
          "x" = "You supplied: {.val {output_format}}"
        )
      )
    }
    if (!output_format %in% c("cli", "markdown")) {
      cli::cli_abort(
        c(
          "{.var output_format} must be either 'cli' or 'markdown'",
          "x" = "You supplied: {.val {output_format}}",
          "i" = "Supported formats: 'cli', 'markdown'"
        )
      )
    }
  }

  # Validate heading_level parameter
  if (!is.numeric(heading_level) || length(heading_level) != 1) {
    cli::cli_abort(
      c("{.var heading_level} must be a single numeric value", "x" = "You supplied: {.val {heading_level}}")
    )
  }
  if (heading_level < 1 ||
      heading_level > 6 || heading_level != as.integer(heading_level)) {
    cli::cli_abort(
      c(
        "{.var heading_level} must be an integer between 1 and 6",
        "x" = "You supplied: {.val {heading_level}}",
        "i" = "Markdown supports heading levels 1 through 6"
      )
    )
  }

  # If output_format is specified, regenerate report in that format
  if (!is.null(output_format) && "component_summaries" %in% names(x)) {
    # Regenerate report in the specified format
    report_text <- build_report.gm_interpretation(
      interpretation = x,
      output_format = output_format,
      heading_level = heading_level,
      suppress_heading = suppress_heading
    )
  } else {
    # Use existing report
    report_text <- x$report
  }

  # Wrap and print the report (only for cli format)
  if (is.null(output_format) || output_format == "cli") {
    wrapped_report <- wrap_text(report_text, max_line_length)
    cat(wrapped_report)
  } else {
    # For markdown, print without wrapping to preserve formatting
    cat(report_text)
  }

  return(invisible(NULL))
}

#' Build Cluster Names Section for GM Report
#'
#' @param suggested_names Named list of suggested cluster names
#' @param analysis_data Standardized GM analysis data
#' @param format Output format
#' @param heading_level Heading level for markdown
#' @return Character string with cluster names section
#' @keywords internal
build_cluster_names_section_gm <- function(suggested_names, analysis_data, format, heading_level) {
  # Get dispatch functions
  section_header_fn <- get_format_fn(format, "section_header", "gm")
  cluster_name_item_fn <- get_format_fn(format, "cluster_name_item", "gm")

  # Build section header
  section <- section_header_fn(heading_level + 1, "Suggested Cluster Names")

  # Add each cluster name
  for (k in seq_len(analysis_data$n_clusters)) {
    cluster_name <- analysis_data$cluster_names[k]
    size_pct <- round(analysis_data$proportions[k] * 100, 1)
    suggested_name <- suggested_names[[cluster_name]]

    section <- paste0(
      section,
      cluster_name_item_fn(k, size_pct, suggested_name)
    )
  }

  # Add trailing newline
  section <- paste0(section, "\n")

  return(section)
}

#' Build Interpretations Section for GM Report
#'
#' @param cluster_interpretations Named list of cluster interpretations
#' @param suggested_names Named list of suggested cluster names
#' @param analysis_data Standardized GM analysis data
#' @param format Output format
#' @param heading_level Heading level for markdown
#' @return Character string with interpretations section
#' @keywords internal
build_interpretations_section_gm <- function(
    cluster_interpretations,
    suggested_names,
    analysis_data,
    format,
    heading_level) {

  # Get dispatch functions
  section_header_fn <- get_format_fn(format, "section_header", "gm")
  cluster_header_fn <- get_format_fn(format, "cluster_header", "gm")
  cluster_separator_fn <- get_format_fn(format, "cluster_separator", "gm")

  # Build section header
  section <- section_header_fn(heading_level + 1, "Cluster Interpretations")

  # Add each cluster interpretation
  for (k in seq_len(analysis_data$n_clusters)) {
    cluster_name <- analysis_data$cluster_names[k]

    # Get size information
    if (!is.null(analysis_data$proportions)) {
      n_obs <- round(analysis_data$proportions[k] * analysis_data$n_observations)
      size_pct <- round(analysis_data$proportions[k] * 100, 1)
      size_text <- paste0(" (n=", n_obs, ", ", size_pct, "%)")
    } else {
      size_text <- ""
    }

    # Get suggested name if available
    suggested_name <- NULL
    if (!is.null(suggested_names) && cluster_name %in% names(suggested_names)) {
      suggested_name <- suggested_names[[cluster_name]]
    }

    # Add cluster header
    section <- paste0(
      section,
      cluster_header_fn(k, cluster_name, suggested_name, size_text, heading_level + 2)
    )

    # Add cluster statistics (if available)
    if (!is.null(analysis_data$uncertainty) &&
        cluster_name %in% names(analysis_data$uncertainty) &&
        !is.null(analysis_data$uncertainty[[cluster_name]])) {
      avg_uncertainty <- mean(analysis_data$uncertainty[[cluster_name]], na.rm = TRUE)
      if (format == "markdown") {
        section <- paste0(
          section,
          "**Average assignment uncertainty:** ", round(avg_uncertainty, 3), "  \n\n"
        )
      } else {
        section <- paste0(
          section,
          "  Average assignment uncertainty: ", round(avg_uncertainty, 3), "\n\n"
        )
      }
    }

    # Get interpretation
    interpretation_text <- cluster_interpretations[[cluster_name]]

    # Add interpretation text
    if (format == "markdown") {
      section <- paste0(section, interpretation_text, "\n\n")
    } else {
      section <- paste0(section, "  ", interpretation_text, "\n\n")
    }

    # Add separator
    section <- paste0(section, cluster_separator_fn)
  }

  return(section)
}

#' Build Diagnostics Section for GM Report
#'
#' @param fit_summary Diagnostic information
#' @param format Output format
#' @param heading_level Heading level for markdown
#' @return Character string with diagnostics section
#' @keywords internal
build_diagnostics_section_gm <- function(fit_summary, format, heading_level) {
  # Skip if no warnings or notes
  if (length(fit_summary$warnings) == 0 && length(fit_summary$notes) == 0) {
    return("")
  }

  # Get dispatch functions
  section_header_fn <- get_format_fn(format, "section_header", "gm")
  diagnostic_warning_fn <- get_format_fn(format, "diagnostic_warning", "gm")
  diagnostic_note_fn <- get_format_fn(format, "diagnostic_note", "gm")
  bold_fn <- get_format_fn(format, "bold", "gm")

  # Build section header
  section <- section_header_fn(heading_level + 1, "Diagnostics")

  # Add warnings
  if (length(fit_summary$warnings) > 0) {
    if (format == "markdown") {
      section <- paste0(section, "**Warnings:**\n")
    } else {
      section <- paste0(section, "\n  ", bold_fn("Warnings:"), "\n")
    }

    for (warning in fit_summary$warnings) {
      section <- paste0(section, diagnostic_warning_fn(warning))
    }
    section <- paste0(section, "\n")
  }

  # Add notes
  if (length(fit_summary$notes) > 0) {
    if (format == "markdown") {
      section <- paste0(section, "**Notes:**\n")
    } else {
      section <- paste0(section, "\n  ", bold_fn("Notes:"), "\n")
    }

    for (note in fit_summary$notes) {
      section <- paste0(section, diagnostic_note_fn(note))
    }
  }

  return(section)
}

#' Build Key Variables Section for GM Report
#'
#' @param distinguishing_vars List of distinguishing variables per cluster
#' @param suggested_names Named list of suggested cluster names
#' @param format Output format
#' @param heading_level Heading level for markdown
#' @return Character string with key variables section
#' @keywords internal
build_key_variables_section_gm <- function(distinguishing_vars, suggested_names, format, heading_level) {
  # Get dispatch functions
  section_header_fn <- get_format_fn(format, "section_header", "gm")
  key_variable_item_fn <- get_format_fn(format, "key_variable_item", "gm")
  bold_fn <- get_format_fn(format, "bold", "gm")

  # Build section header
  section <- section_header_fn(heading_level + 1, "Key Distinguishing Variables")

  # Add each cluster's key variables
  for (cluster_name in names(distinguishing_vars)) {
    vars_df <- distinguishing_vars[[cluster_name]]

    # Get suggested name if available
    if (!is.null(suggested_names) && cluster_name %in% names(suggested_names)) {
      display_name <- paste0(cluster_name, ': "', suggested_names[[cluster_name]], '"')
    } else {
      display_name <- cluster_name
    }

    # Add cluster name header
    if (format == "markdown") {
      section <- paste0(section, bold_fn(display_name), ":\n")
    } else {
      section <- paste0(section, "\n  ", bold_fn(display_name), ":\n")
    }

    # Add each key variable
    for (i in seq_len(nrow(vars_df))) {
      section <- paste0(
        section,
        key_variable_item_fn(
          vars_df$variable[i],
          vars_df$cluster_mean[i],
          vars_df$overall_mean[i]
        )
      )
    }

    # Add spacing between clusters
    section <- paste0(section, "\n")
  }

  return(section)
}

#' Describe Covariance Type
#'
#' Provides human-readable description of mclust covariance model codes.
#'
#' @param model_name Character string with mclust model name (e.g., "VVV")
#' @return Character string with description
#' @keywords internal
describe_covariance_type <- function(model_name) {
  descriptions <- list(
    EII = "spherical, equal volume",
    VII = "spherical, unequal volume",
    EEI = "diagonal, equal volume and shape",
    VEI = "diagonal, varying volume, equal shape",
    EVI = "diagonal, equal volume, varying shape",
    VVI = "diagonal, varying volume and shape",
    EEE = "ellipsoidal, equal volume, shape, and orientation",
    VEE = "ellipsoidal, varying volume, equal shape and orientation",
    EVE = "ellipsoidal, equal volume and orientation, varying shape",
    VVE = "ellipsoidal, varying volume, equal shape and orientation",
    EEV = "ellipsoidal, equal volume and shape, varying orientation",
    VEV = "ellipsoidal, varying volume, equal shape, varying orientation",
    EVV = "ellipsoidal, equal volume, varying shape and orientation",
    VVV = "ellipsoidal, varying volume, shape, and orientation"
  )

  if (model_name %in% names(descriptions)) {
    return(paste0(model_name, " (", descriptions[[model_name]], ")"))
  } else {
    return(model_name)
  }
}