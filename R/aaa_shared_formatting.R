# ===================================================================
# FILE: shared_formatting.R
# PURPOSE: Centralized format dispatch system for report generation
# ===================================================================

#' Base Format Dispatch Table
#'
#' Core formatting functions shared across all model types.
#' Contains basic text styling, headers, and structural elements.
#'
#' @keywords internal
#' @noRd
.BASE_FORMAT_DISPATCH <- list(
  "markdown" = list(
    heading_prefix = function(level) paste(rep("#", level), collapse = ""),
    bold = function(x) paste0("**", x, "**"),
    italic = function(x) paste0("*", x, "*"),
    section_header = function(level, title) {
      h <- paste(rep("#", level), collapse = "")
      paste0("\n", h, " ", title, "\n\n")
    },
    main_header = function(title, level) {
      h <- paste(rep("#", level), collapse = "")
      paste0(h, " ", title, "\n\n")
    },
    line_break = "  \n",
    list_item = "- ",
    newline_before_section = "\n",
    newline_after_section = "\n",
    # Token display
    token_header = function(bold_fn) paste0(bold_fn("Tokens:"), "  \n"),
    token_line = function(label, value) paste0("  ", label, ": ", value, "  \n"),
    # Generic text sections
    section_intro = function(text) paste0(text, "\n\n"),
    # Colored section headers
    warning_header = function(level, title) {
      h <- paste(rep("#", level), collapse = "")
      paste0("\n", h, " ", title, "\n\n")
    },
    error_header = function(level, title) {
      h <- paste(rep("#", level), collapse = "")
      paste0("\n", h, " ", title, "\n\n")
    }
  ),
  "cli" = list(
    heading_prefix = function(level) "",
    bold = function(x) cli::style_bold(x),
    italic = function(x) cli::col_cyan(x),
    section_header = function(level, title) {
      paste0("\n", cli::col_cyan(cli::style_bold(title)), "\n",
             cli::rule(line = 1, line_col = "cyan", width = 80), "\n\n")
    },
    main_header = function(title, level) {
      paste0(cli::col_cyan(cli::style_bold(title)), "\n",
             cli::rule(line = 1, line_col = "cyan", width = 80), "\n\n")
    },
    line_break = "\n",
    list_item = paste0(cli::symbol$bullet, " "),
    newline_before_section = "\n",
    newline_after_section = "\n\n",
    # Token display
    token_header = function(bold_fn) paste0(bold_fn("Tokens:"), "\n"),
    token_line = function(label, value) paste0("  ", label, ": ", value, "\n"),
    # Generic text sections
    section_intro = function(text) paste0(text, "\n"),
    # Colored section headers
    warning_header = function(level, title) {
      paste0("\n", cli::col_yellow(cli::style_bold(title)), "\n",
             cli::rule(line = 1, line_col = "yellow", width = 80), "\n\n")
    },
    error_header = function(level, title) {
      paste0("\n", cli::col_red(cli::style_bold(title)), "\n",
             cli::rule(line = 1, line_col = "red", width = 80), "\n\n")
    }
  )
)

#' FA-Specific Format Extensions
#'
#' Formatting functions specific to factor analysis reports.
#' Extends base dispatch table with FA-specific elements.
#'
#' @keywords internal
#' @noRd
.FA_FORMAT_EXTENSIONS <- list(
  "markdown" = list(
    # Factor names display
    factor_name_item = function(i, var_explained, name) {
      paste0("- **Factor ", i, " (", round(var_explained * 100, 1), "%):** *", name, "*\n")
    },
    total_variance = function(total) {
      paste0("\n**Total variance explained by all factors: ", round(total * 100, 1), "%**\n")
    },
    # Correlation display
    correlation_item = function(factor_name, correlations, split_long = TRUE) {
      if (split_long && length(correlations) > 3) {
        line1 <- paste(correlations[1:3], collapse = ", ")
        line2 <- paste(correlations[4:length(correlations)], collapse = ", ")
        paste0("- **", factor_name, ":** ", line1, ",  \n  ", line2, "\n")
      } else {
        paste0("- **", factor_name, ":** ", paste(correlations, collapse = ", "), "\n")
      }
    },
    # Variable display
    var_display_with_desc = function(var, desc) paste0("**", var, ":** ", desc),
    var_display_no_desc = function(var) paste0("**", var, "**"),
    # Factor separator
    factor_separator = ""
  ),
  "cli" = list(
    # Factor names display
    factor_name_item = function(i, var_explained, name) {
      paste0(cli::symbol$bullet, " ",
             cli::style_bold(paste0("Factor ", i)),
             " (", round(var_explained * 100, 1), "%): ",
             cli::col_green(name), "\n")
    },
    total_variance = function(total) {
      paste0("\n", cli::style_bold("Total variance explained:"), " ",
             round(total * 100, 1), "%\n")
    },
    # Correlation display
    correlation_item = function(factor_name, correlations, split_long = FALSE) {
      paste0(factor_name, ": ", paste(correlations, collapse = ", "), "\n")
    },
    # Variable display
    var_display_with_desc = function(var, desc) paste0(var, ", ", desc),
    var_display_no_desc = function(var) var,
    # Factor separator
    factor_separator = paste0(cli::rule(line = 2, line_col = "grey", width = 80), "\n\n")
  )
)

#' GM-Specific Format Extensions
#'
#' Formatting functions specific to Gaussian Mixture Model reports.
#' Extends base dispatch table with GM-specific elements.
#'
#' @keywords internal
#' @noRd
.GM_FORMAT_EXTENSIONS <- list(
  "markdown" = list(
    # Cluster names display (analogous to factor_name_item)
    cluster_name_item = function(k, size_pct, suggested_name) {
      paste0("- **Cluster ", k, " (", size_pct, "%):** *", suggested_name, "*\n")
    },
    # Cluster header for interpretation sections
    cluster_header = function(cluster_num, cluster_name, suggested_name, size_text, heading_level) {
      hashes <- paste(rep("#", heading_level), collapse = "")
      if (!is.null(suggested_name) && suggested_name != "") {
        display_name <- paste0(cluster_name, ': "', suggested_name, '"', size_text)
      } else {
        display_name <- paste0(cluster_name, size_text)
      }
      paste0(hashes, " ", display_name, "\n\n")
    },
    # Model information items
    model_info_item = function(label, value) {
      paste0("- ", label, ": ", value, "\n")
    },
    # Diagnostic messages
    diagnostic_warning = function(message) {
      paste0("- [!] ", message, "\n")
    },
    diagnostic_note = function(message) {
      paste0("- [i] ", message, "\n")
    },
    # Key variable display
    key_variable_item = function(var_name, cluster_mean, overall_mean) {
      paste0("- ", var_name, " (mean: ", round(cluster_mean, 2),
             " vs overall: ", round(overall_mean, 2), ")\n")
    },
    # Cluster separator (like factor_separator)
    cluster_separator = ""
  ),
  "cli" = list(
    # Cluster names display
    cluster_name_item = function(k, size_pct, suggested_name) {
      paste0(cli::symbol$bullet, " ",
             cli::style_bold(paste0("Cluster ", k)),
             " (", size_pct, "%): ",
             cli::col_green(suggested_name), "\n")
    },
    # Cluster header for interpretation sections
    cluster_header = function(cluster_num, cluster_name, suggested_name, size_text, heading_level) {
      if (!is.null(suggested_name) && suggested_name != "") {
        display_name <- paste0(cluster_name, ': "', suggested_name, '"', size_text)
      } else {
        display_name <- paste0(cluster_name, size_text)
      }
      paste0(cli::style_bold(display_name), "\n")
    },
    # Model information items
    model_info_item = function(label, value) {
      paste0("  ", label, ": ", value, "\n")
    },
    # Diagnostic messages
    diagnostic_warning = function(message) {
      paste0("    ", cli::col_yellow(message), "\n")
    },
    diagnostic_note = function(message) {
      paste0("    ", cli::col_blue(message), "\n")
    },
    # Key variable display
    key_variable_item = function(var_name, cluster_mean, overall_mean) {
      paste0("    - ", var_name, " (", round(cluster_mean, 2),
             " vs ", round(overall_mean, 2), ")\n")
    },
    # Cluster separator
    cluster_separator = paste0(cli::rule(line = 2, line_col = "grey", width = 80), "\n\n")
  )
)

#' Get Format-Specific Function
#'
#' Retrieves a formatting function from the dispatch system.
#' Looks up the appropriate function based on format, element name,
#' and optionally model type.
#'
#' @param format Character string: "cli" or "markdown"
#' @param element Character string: name of formatting element to retrieve
#' @param model_type Character string or NULL: "fa", "gm", or NULL for base elements
#'
#' @return The requested formatting function or value
#'
#' @keywords internal
#' @noRd
#'
#' @examples
#' \dontrun{
#' bold_fn <- get_format_fn("markdown", "bold")
#' bold_fn("Important text")  # Returns "**Important text**"
#'
#' factor_item_fn <- get_format_fn("cli", "factor_name_item", "fa")
#' factor_item_fn(1, 0.45, "Cognitive Ability")
#' }
get_format_fn <- function(format, element, model_type = NULL) {
  format <- match.arg(format, c("cli", "markdown"))

  # Try model-specific extensions first
  if (!is.null(model_type)) {
    extension_table <- switch(
      model_type,
      "fa" = .FA_FORMAT_EXTENSIONS,
      "gm" = .GM_FORMAT_EXTENSIONS,
      NULL
    )

    if (!is.null(extension_table) && element %in% names(extension_table[[format]])) {
      return(extension_table[[format]][[element]])
    }
  }

  # Fall back to base dispatch table
  if (element %in% names(.BASE_FORMAT_DISPATCH[[format]])) {
    return(.BASE_FORMAT_DISPATCH[[format]][[element]])
  }

  # Element not found
  stop(sprintf(
    "Format element '%s' not found for format '%s'%s",
    element, format,
    if (!is.null(model_type)) paste0(" and model type '", model_type, "'") else ""
  ))
}

#' Format Heading
#'
#' Creates a formatted heading at the specified level.
#' Convenience wrapper around get_format_fn() for headers.
#'
#' @param format Character string: "cli" or "markdown"
#' @param level Integer: heading level (1-6)
#' @param title Character string: heading text
#' @param model_type Character string or NULL: model-specific formatting
#'
#' @return Formatted heading string
#'
#' @keywords internal
#' @noRd
#'
#' @examples
#' \dontrun{
#' fmt_heading("markdown", 2, "Model Information")
#' # Returns "## Model Information\n\n"
#'
#' fmt_heading("cli", 1, "Results")
#' # Returns styled CLI heading
#' }
fmt_heading <- function(format, level, title, model_type = NULL) {
  header_fn <- get_format_fn(format, "section_header", model_type)
  header_fn(level, title)
}

#' Format Text with Style
#'
#' Applies text styling (bold, italic) based on output format.
#' Convenience wrapper around get_format_fn() for text styling.
#'
#' @param format Character string: "cli" or "markdown"
#' @param text Character string: text to style
#' @param style Character string: "bold" or "italic"
#' @param model_type Character string or NULL: model-specific formatting
#'
#' @return Styled text string
#'
#' @keywords internal
#' @noRd
#'
#' @examples
#' \dontrun{
#' fmt_style("markdown", "Important", "bold")
#' # Returns "**Important**"
#'
#' fmt_style("cli", "Note", "italic")
#' # Returns styled CLI text
#' }
fmt_style <- function(format, text, style = "bold", model_type = NULL) {
  style <- match.arg(style, c("bold", "italic"))
  style_fn <- get_format_fn(format, style, model_type)
  style_fn(text)
}

#' Format Key-Value Pair
#'
#' Creates a formatted key-value display appropriate for the output format.
#' Uses list_item and bold formatting from dispatch table.
#'
#' @param format Character string: "cli" or "markdown"
#' @param key Character string: the key/label
#' @param value Character or numeric: the value
#' @param model_type Character string or NULL: model-specific formatting
#'
#' @return Formatted key-value string
#'
#' @keywords internal
#' @noRd
#'
#' @examples
#' \dontrun{
#' fmt_keyval("markdown", "BIC", 1234.56)
#' # Returns "- **BIC:** 1234.56"
#'
#' fmt_keyval("cli", "Clusters", 4)
#' # Returns styled CLI key-value
#' }
fmt_keyval <- function(format, key, value, model_type = NULL) {
  bold_fn <- get_format_fn(format, "bold", model_type)

  if (format == "markdown") {
    paste0(bold_fn(paste0(key, ":")), " ", value, "  \n")
  } else {
    paste0(bold_fn(paste0(key, ":")), " ", value, "\n")
  }
}
