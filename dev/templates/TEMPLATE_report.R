# Template for {MODEL}_report.R
# Replace all instances of {MODEL}, {model}, {COMPONENT}, etc. with your values

#' Build report for {MODEL} interpretation
#'
#' Formats {MODEL} interpretation results into a user-facing report with multiple
#' sections including {COMPONENT_LOWER} interpretations, model statistics, and
#' diagnostic warnings. Supports both text and markdown output formats.
#'
#' @param interpretation {model}_interpretation object containing:
#'   \item{analysis_data}{Analysis data from build_analysis_data.{CLASS}()}
#'   \item{interpretation}{LLM interpretation results (list)}
#'   \item{diagnostics}{Diagnostic information}
#'   \item{output_format}{Output format ("text" or "markdown")}
#'   \item{llm_provider}{LLM provider used}
#'   \item{llm_model}{LLM model used}
#' @param ... Additional arguments (ignored)
#'
#' @return Character string with formatted report
#' @export
#'
#' @examples
#' \dontrun{
#' # Generate interpretation
#' result <- interpret(fit, var_info, llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")
#'
#' # Build report (called automatically by print())
#' report <- build_report(result)
#' cat(report)
#' }
build_report.{model}_interpretation <- function(interpretation, ...) {

  # Pattern from fa_report.R:28-838

  # ============================================================================
  # Extract components from interpretation object
  # ============================================================================

  analysis_data <- interpretation$analysis_data
  llm_result <- interpretation$interpretation
  diagnostics <- interpretation$diagnostics
  output_format <- interpretation$output_format

  # Optional fields
  llm_provider <- interpretation$llm_provider %||% "unknown"
  llm_model <- interpretation$llm_model %||% "unknown"
  word_limit <- interpretation$word_limit %||% 150


  # ============================================================================
  # Build report sections using helper functions
  # ============================================================================

  # Section 1: Header with metadata
  header <- build_report_header_{model}(
    analysis_data = analysis_data,
    llm_provider = llm_provider,
    llm_model = llm_model,
    output_format = output_format
  )

  # Section 2: Component interpretations
  interpretations_section <- build_{component}_interpretations_{model}(
    llm_result = llm_result,
    analysis_data = analysis_data,
    output_format = output_format
  )

  # Section 3: Additional data (MODEL-SPECIFIC, optional)
  # Examples:
  #   - FA: Correlation matrix between factors
  #   - GM: Cluster statistics (sizes, separation measures)
  #   - IRT: Item statistics table
  #   - CDM: Q-matrix or attribute profiles
  additional_section <- build_additional_data_section_{model}(
    analysis_data = analysis_data,
    output_format = output_format
  )

  # Section 4: Diagnostics and warnings
  diagnostics_section <- build_diagnostics_section_{model}(
    diagnostics = diagnostics,
    output_format = output_format
  )


  # ============================================================================
  # Combine sections
  # ============================================================================

  # Collect all sections
  report_parts <- list(
    header,
    interpretations_section,
    additional_section,
    diagnostics_section
  )

  # Remove NULL sections (e.g., if no additional data or no warnings)
  report_parts <- Filter(Negate(is.null), report_parts)

  # Combine with appropriate spacing
  if (output_format == "markdown") {
    paste(report_parts, collapse = "\n\n")
  } else {
    paste(report_parts, collapse = "\n\n")
  }
}


# ==============================================================================
# Helper Function 1: Report Header
# ==============================================================================

#' Build report header for {MODEL}
#'
#' Creates the header section with title, metadata, and LLM information.
#'
#' @param analysis_data Analysis data
#' @param llm_provider LLM provider name
#' @param llm_model LLM model name
#' @param output_format Output format ("text" or "markdown")
#'
#' @return Character string with formatted header
#' @keywords internal
#' @noRd
build_report_header_{model} <- function(analysis_data,
                                         llm_provider,
                                         llm_model,
                                         output_format) {

  # Pattern from fa_report.R:132-226

  # ============================================================================
  # Extract metadata from analysis_data
  # ============================================================================

  n_components <- analysis_data$n_components
  n_variables <- analysis_data$n_variables

  # Optional: Extract model-specific parameters
  param1 <- analysis_data${PARAM1}  # TODO: Replace with actual param name
  param2 <- analysis_data${PARAM2}  # TODO: Replace with actual param name


  # ============================================================================
  # Format header based on output_format
  # ============================================================================

  if (output_format == "markdown") {
    # Markdown format with heading and bold labels
    header <- paste0(
      "# {MODEL} Interpretation Results\n\n",
      "**Number of {COMPONENTS}:** ", n_components, "\n",
      "**Number of Variables:** ", n_variables, "\n"
    )

    # Add model-specific parameters if present
    if (!is.null(param1)) {
      header <- paste0(header, "**{PARAM1}:** ", param1, "\n")
    }
    if (!is.null(param2)) {
      header <- paste0(header, "**{PARAM2}:** ", param2, "\n")
    }

    # Add LLM info
    header <- paste0(
      header,
      "**LLM Provider:** ", llm_provider, "\n",
      "**LLM Model:** ", llm_model, "\n"
    )

  } else {
    # Plain text format with separator line
    header <- paste0(
      "{MODEL} INTERPRETATION RESULTS\n",
      paste(rep("=", 70), collapse = ""), "\n\n",
      "Number of {COMPONENTS}: ", n_components, "\n",
      "Number of Variables: ", n_variables, "\n"
    )

    # Add model-specific parameters if present
    if (!is.null(param1)) {
      header <- paste0(header, "{PARAM1}: ", param1, "\n")
    }
    if (!is.null(param2)) {
      header <- paste0(header, "{PARAM2}: ", param2, "\n")
    }

    # Add LLM info
    header <- paste0(
      header,
      "LLM Provider: ", llm_provider, "\n",
      "LLM Model: ", llm_model, "\n"
    )
  }

  header
}


# ==============================================================================
# Helper Function 2: Component Interpretations Section
# ==============================================================================

#' Build {COMPONENT_LOWER} interpretations section
#'
#' Formats the LLM-generated interpretations for each {COMPONENT_LOWER}.
#'
#' @param llm_result List of {COMPONENT_LOWER} interpretations from LLM
#' @param analysis_data Analysis data
#' @param output_format Output format ("text" or "markdown")
#'
#' @return Character string with formatted interpretations
#' @keywords internal
#' @noRd
build_{component}_interpretations_{model} <- function(llm_result,
                                                       analysis_data,
                                                       output_format) {

  # Pattern from fa_report.R:321-475

  # ============================================================================
  # Extract component identifiers and interpretations
  # ============================================================================

  component_ids <- names(llm_result)

  if (length(component_ids) == 0) {
    # No interpretations - return informational message
    if (output_format == "markdown") {
      return("## {COMPONENT} Interpretations\n\nNo interpretations available.")
    } else {
      return("{COMPONENT} INTERPRETATIONS\nNo interpretations available.")
    }
  }


  # ============================================================================
  # Format each component interpretation
  # ============================================================================

  sections <- character(length(component_ids))

  for (i in seq_along(component_ids)) {
    id <- component_ids[i]
    interpretation <- llm_result[[id]]

    if (output_format == "markdown") {
      # Markdown: Use ### for component headings
      sections[i] <- paste0(
        "### ", id, "\n",
        interpretation
      )
    } else {
      # Plain text: Use component ID with underline
      sections[i] <- paste0(
        id, ":\n",
        paste(rep("-", nchar(id) + 1), collapse = ""), "\n",
        interpretation
      )
    }
  }


  # ============================================================================
  # Combine with section header
  # ============================================================================

  if (output_format == "markdown") {
    paste0(
      "## {COMPONENT} Interpretations\n\n",
      paste(sections, collapse = "\n\n")
    )
  } else {
    paste0(
      "{COMPONENT} INTERPRETATIONS\n",
      paste(rep("-", 70), collapse = ""), "\n\n",
      paste(sections, collapse = "\n\n")
    )
  }
}


# ==============================================================================
# Helper Function 3: Additional Data Section (MODEL-SPECIFIC)
# ==============================================================================

#' Build additional data section
#'
#' Formats model-specific additional information (e.g., correlations, statistics).
#' Returns NULL if no additional data to display.
#'
#' @param analysis_data Analysis data
#' @param output_format Output format ("text" or "markdown")
#'
#' @return Character string with formatted additional data, or NULL
#' @keywords internal
#' @noRd
build_additional_data_section_{model} <- function(analysis_data, output_format) {

  # Pattern from fa_report.R:477-693 (build_correlations_section)

  # ============================================================================
  # Check if additional data is available
  # ============================================================================

  # Example for FA: Check for factor correlation matrix
  # has_data <- !is.null(model_data$factor_cor_mat)

  # Example for GM: Check for cluster statistics
  # has_data <- !is.null(model_data$cluster_stats)

  # Example for IRT: Check for item statistics
  # has_data <- !is.null(model_data$item_stats)

  # TODO: Replace with your check
  additional_data <- analysis_data$additional_data_field  # TODO: Replace
  has_data <- !is.null(additional_data)

  if (!has_data) {
    return(NULL)  # No additional data to display
  }


  # ============================================================================
  # Format additional data
  # ============================================================================

  # THIS IS MODEL-SPECIFIC - format your additional data appropriately

  # Example for FA: Format correlation matrix
  # formatted_data <- format_correlation_matrix(model_data$factor_cor_mat)

  # Example for GM: Format cluster statistics table
  # formatted_data <- format_cluster_stats(model_data$cluster_stats)

  # Example for IRT: Format item statistics table
  # formatted_data <- format_item_stats(model_data$item_stats)

  # TODO: Replace with your formatting
  formatted_data <- "TODO: Format your additional data here\n"


  # ============================================================================
  # Add section header and return
  # ============================================================================

  if (output_format == "markdown") {
    paste0(
      "## Additional {MODEL} Information\n\n",  # TODO: Customize section title
      formatted_data
    )
  } else {
    paste0(
      "ADDITIONAL {MODEL} INFORMATION\n",  # TODO: Customize section title
      paste(rep("-", 70), collapse = ""), "\n\n",
      formatted_data
    )
  }
}


# ==============================================================================
# Helper Function 4: Diagnostics Section
# ==============================================================================

#' Build diagnostics section
#'
#' Formats diagnostic warnings and recommendations. Returns NULL if no warnings.
#'
#' @param fit_summary Fit summary list from create_fit_summary.{model}()
#' @param output_format Output format ("text" or "markdown")
#'
#' @return Character string with formatted diagnostics, or NULL if no warnings
#' @keywords internal
#' @noRd
build_diagnostics_section_{model} <- function(diagnostics, output_format) {

  # Pattern from fa_report.R:695-838

  # ============================================================================
  # Check if there are warnings
  # ============================================================================

  if (!diagnostics$has_warnings) {
    return(NULL)  # No warnings to display
  }


  # ============================================================================
  # Format warnings
  # ============================================================================

  warnings_text <- paste(diagnostics$warnings, collapse = "\n\n")


  # ============================================================================
  # Add section header and return
  # ============================================================================

  if (output_format == "markdown") {
    paste0(
      "## Diagnostic Warnings\n\n",
      warnings_text
    )
  } else {
    paste0(
      "DIAGNOSTIC WARNINGS\n",
      paste(rep("=", 70), collapse = ""), "\n\n",
      warnings_text
    )
  }
}


# ==============================================================================
# Additional Helper Functions for Data Formatting
# ==============================================================================

# Add model-specific formatting helpers as needed
# Keep each function focused on one formatting task

# Example 1: Format a matrix/table
# #' Format {DATA_TYPE} as text table
# #'
# #' @param data Matrix or data frame to format
# #' @param row_names Row names
# #' @param col_names Column names
# #' @param digits Number of decimal places
# #'
# #' @return Character string with formatted table
# #' @keywords internal
# #' @noRd
# format_{data_type}_table <- function(data,
#                                      row_names = NULL,
#                                      col_names = NULL,
#                                      digits = 3) {
#
#   # Convert to matrix if needed
#   if (is.data.frame(data)) {
#     data <- as.matrix(data)
#   }
#
#   # Use row/col names if not provided
#   if (is.null(row_names)) row_names <- rownames(data)
#   if (is.null(col_names)) col_names <- colnames(data)
#
#   # Format numbers
#   formatted_data <- apply(data, c(1, 2), function(x) {
#     sprintf(paste0("%.", digits, "f"), x)
#   })
#
#   # Create table string
#   # TODO: Implement table formatting with aligned columns
#
#   # Return formatted string
# }


# Example 2: Format statistics summary
# #' Format {COMPONENT_LOWER} statistics
# #'
# #' @param stats List or vector of statistics
# #' @param component_id {COMPONENT} identifier
# #'
# #' @return Character string with formatted statistics
# #' @keywords internal
# #' @noRd
# format_{component}_stats <- function(stats, component_id) {
#
#   # Format statistics
#   formatted <- paste0(
#     component_id, " Statistics:\n"
#   )
#
#   # Add each statistic
#   for (stat_name in names(stats)) {
#     formatted <- paste0(
#       formatted,
#       "  ", stat_name, ": ",
#       format_stat_value(stats[[stat_name]]),
#       "\n"
#     )
#   }
#
#   formatted
# }


# Example 3: Format a single statistic value
# #' Format statistic value with appropriate precision
# #'
# #' @param value Numeric value to format
# #'
# #' @return Character string with formatted value
# #' @keywords internal
# #' @noRd
# format_stat_value <- function(value) {
#
#   if (is.numeric(value)) {
#     # Format with 3 decimal places for small numbers, 2 for large
#     if (abs(value) < 1) {
#       sprintf("%.3f", value)
#     } else {
#       sprintf("%.2f", value)
#     }
#   } else {
#     as.character(value)
#   }
# }


# TODO: Add your model-specific formatting helpers here
