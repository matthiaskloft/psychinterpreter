# ==============================================================================
# TEMPLATE: {MODEL}_report.R
# ==============================================================================
#
# PURPOSE: Format {MODEL} interpretation results into user-facing reports
#
# ARCHITECTURE: Implements Report Generation Pattern (see dev/COMMON_ARCHITECTURE_PATTERNS.md)
# - Section: "Report Generation Pattern" (lines 414-460)
# - 5-section structure: header → info → summaries → diagnostics → tokens
# - Supports both CLI and markdown formats
#
# PATTERN COMPLIANCE CHECKLIST:
# [ ] Implements format_interpretation_report.{model}_interpretation() S3 method
# [ ] Supports both "cli" and "markdown" output formats
# [ ] Follows 5-section report structure
# [ ] Uses cli:: functions for CLI format
# [ ] Uses markdown syntax for markdown format
# [ ] Includes component summaries and diagnostic information
#
# SIDE-BY-SIDE COMPARISON:
# FA: R/fa_report.R (5-section structure, CLI and markdown support)
# GM: R/gm_report.R (5-section structure, CLI and markdown support)
# Both use IDENTICAL structure, formatting functions handle model-specific data
#
# ==============================================================================
# REPLACEMENT PLACEHOLDERS
# ==============================================================================
#
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
  # Format Dispatch System
  # ============================================================================
  # Modern approach: Use dispatch tables instead of if/else chains for format handling.
  # See fa_report.R:9-120 for complete implementation.
  #
  # Benefits:
  # - 87% reduction in format conditionals (15 → 2)
  # - Easy to add new formats (HTML, JSON, PDF)
  # - Reusable formatting functions
  # - Cleaner separation of concerns
  #
  # Define dispatch table at file level (outside this function):
  #
  # .{model}_format_dispatch <- list(
  #   "markdown" = list(
  #     heading = function(text, level) paste0(strrep("#", level), " ", text),
  #     bold = function(x) paste0("**", x, "**"),
  #     italic = function(x) paste0("*", x, "*"),
  #     table_row = function(cells) paste0("| ", paste(cells, collapse = " | "), " |"),
  #     list_item = function(x) paste0("- ", x),
  #     section_header = function(title, level = 2) {
  #       paste0("\n", strrep("#", level), " ", title, "\n\n")
  #     }
  #   ),
  #   "cli" = list(
  #     heading = function(text, level) cli::col_cyan(cli::style_bold(text)),
  #     bold = function(x) cli::style_bold(x),
  #     italic = function(x) cli::col_cyan(x),
  #     table_row = function(cells) paste("  ", paste(cells, collapse = " | ")),
  #     list_item = function(x) paste0(cli::symbol$bullet, " ", x),
  #     section_header = function(title, level = 2) {
  #       paste0("\n", cli::col_cyan(cli::style_bold(title)), "\n",
  #              cli::rule(line = 1, line_col = "cyan"), "\n\n")
  #     }
  #   )
  # )
  #
  # Helper function to retrieve format-specific functions:
  #
  # get_{model}_format_fn <- function(format, element) {
  #   if (!format %in% names(.{model}_format_dispatch)) {
  #     cli::cli_abort(paste0("Unknown format: ", format,
  #                          ". Supported: 'cli', 'markdown'"))
  #   }
  #   if (!element %in% names(.{model}_format_dispatch[[format]])) {
  #     cli::cli_abort(paste0("Unknown element: ", element, " for format: ", format))
  #   }
  #   .{model}_format_dispatch[[format]][[element]]
  # }
  #
  # Usage in code:
  #   header_fn <- get_{model}_format_fn(output_format, "heading")
  #   formatted_header <- header_fn("My Title", level = 1)

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
  # Format header using dispatch table
  # ============================================================================
  # MODERN APPROACH: Use get_{model}_format_fn() to avoid if/else chains
  # Compare to OLD APPROACH (commented below) - dispatch is cleaner and extensible

  # Get format-specific functions
  heading_fn <- get_{model}_format_fn(output_format, "heading")
  bold_fn <- get_{model}_format_fn(output_format, "bold")
  section_header_fn <- get_{model}_format_fn(output_format, "section_header")

  # Build header using dispatched functions
  header_parts <- c(
    heading_fn("{MODEL} Interpretation Results", level = 1),
    "",
    paste0(bold_fn("Number of {COMPONENTS}:"), " ", n_components),
    paste0(bold_fn("Number of Variables:"), " ", n_variables)
  )

  # Add model-specific parameters if present
  if (!is.null(param1)) {
    header_parts <- c(header_parts, paste0(bold_fn("{PARAM1}:"), " ", param1))
  }
  if (!is.null(param2)) {
    header_parts <- c(header_parts, paste0(bold_fn("{PARAM2}:"), " ", param2))
  }

  # Add LLM info
  header_parts <- c(
    header_parts,
    paste0(bold_fn("LLM Provider:"), " ", llm_provider),
    paste0(bold_fn("LLM Model:"), " ", llm_model)
  )

  # Combine with appropriate line breaks for format
  paste(header_parts, collapse = "\n")

  # ============================================================================
  # OLD APPROACH (DO NOT USE - shown for comparison only):
  # ============================================================================
  # if (output_format == "markdown") {
  #   header <- paste0(
  #     "# {MODEL} Interpretation Results\n\n",
  #     "**Number of {COMPONENTS}:** ", n_components, "\n",
  #     "**Number of Variables:** ", n_variables, "\n"
  #   )
  #   # ... etc for 15+ if/else blocks
  # } else {
  #   header <- paste0(
  #     "{MODEL} INTERPRETATION RESULTS\n",
  #     paste(rep("=", 70), collapse = ""), "\n\n"
  #   )
  #   # ... etc
  # }
  #
  # Problems with old approach:
  # - Duplicates logic across 15+ locations
  # - Hard to add new formats (must update 15+ if/else chains)
  # - Easy to introduce inconsistencies
  # - Higher cyclomatic complexity
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

  # ============================================================================
  # Format each component using dispatch table
  # ============================================================================
  # MODERN APPROACH: Get format functions once, reuse in loop

  # Get format-specific functions
  subheading_fn <- get_{model}_format_fn(output_format, "heading")
  separator_fn <- get_{model}_format_fn(output_format, "section_header")

  for (i in seq_along(component_ids)) {
    id <- component_ids[i]
    interpretation <- llm_result[[id]]

    # Format component section using dispatched function
    sections[i] <- paste0(
      subheading_fn(id, level = 3),
      "\n",
      interpretation
    )
  }


  # ============================================================================
  # Combine with section header using dispatch
  # ============================================================================

  main_header <- separator_fn("{COMPONENT} Interpretations", level = 2)
  paste0(
    main_header,
    paste(sections, collapse = "\n\n")
  )

  # ============================================================================
  # OLD APPROACH (DO NOT USE - shown for comparison):
  # ============================================================================
  # for (i in seq_along(component_ids)) {
  #   if (output_format == "markdown") {
  #     sections[i] <- paste0("### ", id, "\n", interpretation)
  #   } else {
  #     sections[i] <- paste0(id, ":\n", paste(rep("-", nchar(id)), collapse = ""), "\n")
  #   }
  # }
  # if (output_format == "markdown") {
  #   paste0("## {COMPONENT} Interpretations\n\n", paste(sections, collapse = "\n\n"))
  # } else {
  #   paste0("{COMPONENT} INTERPRETATIONS\n", paste(rep("-", 70), collapse = ""), "\n\n")
  # }
  #
  # Problems:
  # - 3 separate if/else blocks for same format check
  # - Duplicated formatting logic
  # - Error-prone when adding new formats
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
  # Add section header using dispatch and return
  # ============================================================================

  section_header_fn <- get_{model}_format_fn(output_format, "section_header")

  paste0(
    section_header_fn("Additional {MODEL} Information", level = 2),  # TODO: Customize title
    formatted_data
  )

  # OLD APPROACH (avoid this pattern):
  # if (output_format == "markdown") {
  #   paste0("## Additional {MODEL} Information\n\n", formatted_data)
  # } else {
  #   paste0("ADDITIONAL {MODEL} INFORMATION\n", paste(rep("-", 70), collapse = ""))
  # }
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
  # Add section header using dispatch and return
  # ============================================================================

  # Use special warning header if available, fallback to section_header
  warning_header_fn <- tryCatch(
    get_{model}_format_fn(output_format, "warning_header"),
    error = function(e) get_{model}_format_fn(output_format, "section_header")
  )

  paste0(
    warning_header_fn("Diagnostic Warnings", level = 2),
    warnings_text
  )

  # OLD APPROACH (avoid):
  # if (output_format == "markdown") {
  #   paste0("## Diagnostic Warnings\n\n", warnings_text)
  # } else {
  #   paste0("DIAGNOSTIC WARNINGS\n", paste(rep("=", 70), collapse = ""), "\n\n")
  # }
}


# ==============================================================================
# Format Dispatch Table Definition (File Level)
# ==============================================================================
# Define this OUTSIDE of build_report.{model}_interpretation() so it's
# available to all helper functions in this file.
#
# Reference: fa_report.R:9-120 for complete example

#' Format dispatch table for {MODEL} reports
#'
#' @keywords internal
#' @noRd
.{model}_format_dispatch <- list(
  "markdown" = list(
    # Basic formatting
    heading = function(text, level = 1) {
      paste0(strrep("#", level), " ", text, "\n")
    },
    bold = function(x) paste0("**", x, "**"),
    italic = function(x) paste0("*", x, "*"),

    # Section structures
    section_header = function(title, level = 2) {
      paste0("\n", strrep("#", level), " ", title, "\n\n")
    },

    # Lists and tables
    list_item = function(x) paste0("- ", x),
    table_header = function(cols) {
      paste0("| ", paste(cols, collapse = " | "), " |\n",
             "|", paste(rep("---", length(cols)), collapse = "|"), "|\n")
    },
    table_row = function(cells) paste0("| ", paste(cells, collapse = " | "), " |\n"),

    # Special headers (optional)
    warning_header = function(title, level = 2) {
      paste0("\n", strrep("#", level), " ", title, "\n\n")
    }
  ),

  "cli" = list(
    # Basic formatting
    heading = function(text, level = 1) {
      if (level == 1) {
        paste0(cli::col_cyan(cli::style_bold(text)), "\n",
               cli::rule(line = 2, line_col = "cyan"), "\n")
      } else {
        cli::col_cyan(cli::style_bold(text))
      }
    },
    bold = function(x) cli::style_bold(x),
    italic = function(x) cli::col_cyan(x),

    # Section structures
    section_header = function(title, level = 2) {
      paste0("\n", cli::col_cyan(cli::style_bold(title)), "\n",
             cli::rule(line = 1, line_col = "cyan"), "\n\n")
    },

    # Lists and tables
    list_item = function(x) paste0(cli::symbol$bullet, " ", x),
    table_header = function(cols) {
      paste0("  ", paste(cli::style_bold(cols), collapse = " | "), "\n")
    },
    table_row = function(cells) paste0("  ", paste(cells, collapse = " | "), "\n"),

    # Special headers (optional)
    warning_header = function(title, level = 2) {
      paste0("\n", cli::col_yellow(cli::style_bold(title)), "\n",
             cli::rule(line = 1, line_col = "yellow"), "\n\n")
    }
  )
)


#' Get format-specific function for {MODEL}
#'
#' @param format Character. "cli" or "markdown"
#' @param element Character. Element name (e.g., "bold", "heading", "section_header")
#'
#' @return Function or value for the specified format and element
#'
#' @keywords internal
#' @noRd
get_{model}_format_fn <- function(format, element) {
  # Validate format
  if (!format %in% names(.{model}_format_dispatch)) {
    cli::cli_abort(paste0("Unknown format: ", format,
                         ". Supported formats: 'cli', 'markdown'"))
  }

  # Validate element
  if (!element %in% names(.{model}_format_dispatch[[format]])) {
    cli::cli_abort(paste0("Unknown element: ", element,
                         " for format: ", format))
  }

  # Return the function/value
  .{model}_format_dispatch[[format]][[element]]
}


# ==============================================================================
# Additional Helper Functions for Data Formatting
# ==============================================================================

# Add model-specific formatting helpers as needed
# Keep each function focused on one formatting task
#
# IMPORTANT: Use get_{model}_format_fn() in helpers to maintain format-agnostic code

# Example 1: Format a matrix/table using dispatch
# #' Format {DATA_TYPE} as text table
# #'
# #' @param data Matrix or data frame to format
# #' @param output_format Output format ("cli" or "markdown")
# #' @param row_names Row names
# #' @param col_names Column names
# #' @param digits Number of decimal places
# #'
# #' @return Character string with formatted table
# #' @keywords internal
# #' @noRd
# format_{data_type}_table <- function(data,
#                                      output_format,
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
#   # Get format-specific functions using dispatch
#   table_header_fn <- get_{model}_format_fn(output_format, "table_header")
#   table_row_fn <- get_{model}_format_fn(output_format, "table_row")
#
#   # Build table
#   table_parts <- c(
#     table_header_fn(c("", col_names))  # Header row
#   )
#
#   # Add data rows
#   for (i in seq_len(nrow(formatted_data))) {
#     row_data <- c(row_names[i], formatted_data[i, ])
#     table_parts <- c(table_parts, table_row_fn(row_data))
#   }
#
#   # Return formatted string
#   paste(table_parts, collapse = "")
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
