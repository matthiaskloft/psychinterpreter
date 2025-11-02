#' Build Factor Analysis Interpretation Report
#'
#' Internal helper function that builds a formatted interpretation report from factor analysis results.
#' This function can generate reports in either text or markdown format and can be called
#' independently to regenerate reports in different formats after analysis.
#'
#' @param interpretation_results A list containing factor analysis interpretation results with components:
#'   factor_summaries, suggested_names, llm_info, chat, cross_loadings, no_loadings, elapsed_time, factor_cor_mat
#' @param output_format Character. Output format: "text" or "markdown" (default = "text")
#' @param heading_level Integer. Starting heading level for markdown output (default = 1)
#' @param n_factors Integer. Number of factors in the analysis
#' @param cutoff Numeric. Loading cutoff value used in the analysis
#'
#' @return Character string containing the formatted report
#'
#' @keywords internal
#' @noRd
build_fa_report <- function(interpretation_results,
                             output_format = "text",
                             heading_level = 1,
                             n_factors,
                             cutoff,
                             suppress_heading = FALSE) {

  # Extract components from results
  factor_summaries <- interpretation_results$factor_summaries
  suggested_names <- interpretation_results$suggested_names
  llm_info <- interpretation_results$llm_info
  chat <- interpretation_results$chat
  cross_loadings <- interpretation_results$cross_loadings
  no_loadings <- interpretation_results$no_loadings
  elapsed_time <- interpretation_results$elapsed_time
  factor_cor_mat <- interpretation_results$factor_cor_mat

  # Get factor column names
  factor_cols <- names(factor_summaries)

  # Generate interpretation report
  if (output_format == "markdown") {
    # Create markdown report with configurable heading levels
    h1 <- paste(rep("#", heading_level), collapse = "")
    h2 <- paste(rep("#", heading_level + 1), collapse = "")
    h3 <- paste(rep("#", heading_level + 2), collapse = "")

    # Add main heading unless suppressed
    if (!suppress_heading) {
      report <- paste0(h1, " Factor Analysis Interpretation\n\n")
    } else {
      report <- ""
    }
    report <- paste0(report, "**Number of factors:** ", n_factors, "  \n")
    report <- paste0(report, "**Loading cutoff:** ", cutoff, "  \n")

    # Handle LLM info safely
    if (!is.null(chat)) {
      report <- paste0(report,
                       "**LLM used:** ",
                       chat$get_provider()@name,
                       " - ",
                       chat$get_model(),
                       "  \n")
      # Get token information - prefer per-run tokens if available
      tokens <- NULL
      if (!is.null(interpretation_results$run_tokens)) {
        # Use per-run tokens (accurate for individual interpretations)
        tokens <- interpretation_results$run_tokens
      } else {
        # Fallback to chat object tokens (for backwards compatibility)
        tokens <- tryCatch({
          tokens_df <- chat$get_tokens()
          if (nrow(tokens_df) > 0) {
            input_tokens <- sum(tokens_df$tokens[tokens_df$role == "user"], na.rm = TRUE)
            output_tokens <- sum(tokens_df$tokens[tokens_df$role == "assistant"], na.rm = TRUE)
            list(input = input_tokens, output = output_tokens)
          } else {
            NULL
          }
        }, error = function(e) {
          NULL
        })
      }

      if (!is.null(tokens) && !is.null(tokens$input) && !is.null(tokens$output)) {
        # Ensure positive token counts for display
        input_tokens <- abs(as.numeric(tokens$input))
        output_tokens <- abs(as.numeric(tokens$output))
        report <- paste0(report, "**Tokens:**  \n  Input: ", input_tokens, "  \n  Output: ", output_tokens, "  \n")
      }
    } else if (!is.null(llm_info)) {
      report <- paste0(report,
                       "**LLM used:** ",
                       llm_info$provider,
                       " - ",
                       llm_info$model %||% "default",
                       "  \n")
    }

    report <- paste0(report, "\n", h2, " Suggested Factor Names\n\n")
    for (i in 1:length(suggested_names)) {
      name <- names(suggested_names)[i]
      var_explained <- factor_summaries[[name]]$variance_explained
      report <- paste0(
        report,
        "- **Factor ",
        i,
        " (",
        round(var_explained * 100, 1),
        "%):** *",
        suggested_names[[name]],
        "*\n"
      )
    }

    # Add total variance explained
    total_variance <- sum(sapply(factor_summaries, function(x) x$variance_explained))
    report <- paste0(report, "\n**Total variance explained by all factors: ", round(total_variance * 100, 1), "%**\n")

    # Add factor correlations section if provided
    if (!is.null(factor_cor_mat)) {
      report <- paste0(report, "\n", h2, " Factor Correlations\n\n")

      # Convert matrix to dataframe if needed and get factor names
      if (is.matrix(factor_cor_mat)) {
        cor_df <- as.data.frame(factor_cor_mat)
        cor_factors <- rownames(factor_cor_mat)
      } else {
        cor_df <- factor_cor_mat
        cor_factors <- rownames(cor_df)
      }

      # Create correlation table
      for (i in 1:length(cor_factors)) {
        factor_name <- cor_factors[i]
        if (factor_name %in% names(cor_df)) {
          correlations <- c()
          for (j in 1:length(cor_factors)) {
            other_factor <- cor_factors[j]
            if (other_factor != factor_name && other_factor %in% names(cor_df)) {
              cor_val <- round(cor_df[[other_factor]][i], 2)
              cor_formatted <- sprintf("%.2f", cor_val)
              cor_formatted <- sub("^0", "", cor_formatted)  # Remove leading zero for consistency with LLM input
              correlations <- c(correlations, paste0(other_factor, " = ", cor_formatted))
            }
          }
          if (length(correlations) > 0) {
            # Split long correlation lists for better readability
            if (length(correlations) > 3) {
              line1 <- paste(correlations[1:3], collapse = ", ")
              line2 <- paste(correlations[4:length(correlations)], collapse = ", ")
              report <- paste0(report, "- **", factor_name, ":** ", line1, ",  \n  ", line2, "\n")
            } else {
              report <- paste0(report, "- **", factor_name, ":** ", paste(correlations, collapse = ", "), "\n")
            }
          }
        }
      }
    }

    report <- paste0(report, "\n", h2, " Detailed Factor Interpretations\n\n")

    for (i in 1:n_factors) {
      factor_name <- factor_cols[i]

      # Extract the first line (factor header) from summary
      summary_lines <- strsplit(factor_summaries[[factor_name]]$summary, "\n")[[1]]
      factor_header <- summary_lines[1]
      remaining_summary <- paste(summary_lines[-1], collapse = "\n")

      # Add factor header with suggested name as h3
      report <- paste0(report, h3, " ", factor_header)
      if (!is.null(suggested_names[[factor_name]])) {
        report <- paste0(report, ": ", suggested_names[[factor_name]])
      }
      report <- paste0(report, "\n\n")

      # Parse summary to insert factor correlations after "Variance explained" line
      if (!is.null(factor_cor_mat) && factor_name %in% rownames(factor_cor_mat)) {
        # Convert matrix to dataframe if needed and get factor names
        if (is.matrix(factor_cor_mat)) {
          cor_df <- as.data.frame(factor_cor_mat)
          cor_factors <- rownames(factor_cor_mat)
        } else {
          cor_df <- factor_cor_mat
          cor_factors <- rownames(cor_df)
        }

        # Find correlations for this factor
        if (factor_name %in% names(cor_df)) {
          correlations <- c()
          for (j in 1:length(cor_factors)) {
            other_factor <- cor_factors[j]
            if (other_factor != factor_name && other_factor %in% names(cor_df)) {
              factor_idx <- which(rownames(cor_df) == factor_name)
              cor_val <- round(cor_df[[other_factor]][factor_idx], 2)
              cor_formatted <- sprintf("%.2f", cor_val)
              cor_formatted <- sub("^0", "", cor_formatted)  # Remove leading zero for consistency with LLM input
              correlations <- c(correlations, paste0(other_factor, " = ", cor_formatted))
            }
          }
          if (length(correlations) > 0) {
            # Insert correlations after "Variance explained" line
            summary_lines <- strsplit(remaining_summary, "\n")[[1]]
            modified_lines <- c()
            for (line in summary_lines) {
              modified_lines <- c(modified_lines, line)
              if (grepl("^Variance explained:", line)) {
                # Split long correlation lists for better readability
                if (length(correlations) > 3) {
                  line1 <- paste(correlations[1:3], collapse = ", ")
                  line2 <- paste(correlations[4:length(correlations)], collapse = ", ")
                  cor_line <- paste0("**Factor Correlations:** ", line1, ",  \n", line2)
                } else {
                  cor_line <- paste0("**Factor Correlations:** ", paste(correlations, collapse = ", "))
                }
                modified_lines <- c(modified_lines, cor_line)
              }
            }
            remaining_summary <- paste(modified_lines, collapse = "\n")
          }
        }
      }

      # Convert summary to markdown format - fix variables list formatting and line breaks
      summary_md <- remaining_summary

      # Add proper markdown line breaks and bold formatting for key sections
      summary_md <- gsub("(Number of significant loadings:) ([0-9]+)\\n", "**\\1** \\2  \\n", summary_md)
      summary_md <- gsub("(Variance explained:) ([0-9\\.]+%)\\n", "**\\1** \\2  \\n", summary_md)
      summary_md <- gsub("(\\*\\*Factor Correlations:\\*\\*[^\n]*)\\n", "\\1  \\n\\n", summary_md)

      # Fix variables section - add proper spacing and formatting
      summary_md <- gsub("Variables:\\n", "\\n\\n**Variables:**\\n\\n", summary_md)

      # Make WARNING section bold
      summary_md <- gsub("(WARNING:)", "**\\1**", summary_md)

      # Convert numbered list format for proper markdown rendering
      summary_md <- gsub("^  ([0-9]+\\.) ", "\\1 ", summary_md, perl = TRUE)

      report <- paste0(report, summary_md, "\n\n")

      if (!is.null(factor_summaries[[factor_name]]$llm_interpretation)) {
        report <- paste0(
          report,
          "\n**LLM Interpretation:**  \n",
          factor_summaries[[factor_name]]$llm_interpretation,
          "\n\n"
        )
      }
    }
  } else {
    # Original text format
    # Add main heading unless suppressed
    if (!suppress_heading) {
      report <- "==========================================\n"
      report <- paste0(report, "FACTOR ANALYSIS INTERPRETATION\n")
      report <- paste0(report, "==========================================\n\n")
    } else {
      report <- ""
    }
    report <- paste0(report, "Number of factors: ", n_factors, "\n")
    report <- paste0(report, "Loading cutoff: ", cutoff, "\n")

    # Handle LLM info safely
    if (!is.null(chat)) {
      report <- paste0(report,
                       "LLM used: ",
                       chat$get_provider()@name,
                       " - ",
                       chat$get_model(),
                       "\n")
      # Get token information - prefer per-run tokens if available
      tokens <- NULL
      if (!is.null(interpretation_results$run_tokens)) {
        # Use per-run tokens (accurate for individual interpretations)
        tokens <- interpretation_results$run_tokens
      } else {
        # Fallback to chat object tokens (for backwards compatibility)
        tokens <- tryCatch({
          tokens_df <- chat$get_tokens(include_system_prompt = TRUE)
          if (nrow(tokens_df) > 0) {
            input_tokens <- sum(tokens_df$tokens[tokens_df$role == "user"], na.rm = TRUE)
            output_tokens <- sum(tokens_df$tokens[tokens_df$role == "assistant"], na.rm = TRUE)
            list(input = input_tokens, output = output_tokens)
          } else {
            NULL
          }
        }, error = function(e) {
          NULL
        })
      }

      if (!is.null(tokens) && !is.null(tokens$input) && !is.null(tokens$output)) {
        # Ensure positive token counts for display
        input_tokens <- abs(as.numeric(tokens$input))
        output_tokens <- abs(as.numeric(tokens$output))
        report <- paste0(report, "Tokens:\n  Input: ", input_tokens, "\n  Output: ", output_tokens, "\n")
      }
    } else if (!is.null(llm_info)) {
      report <- paste0(report,
                       "LLM used: ",
                       llm_info$provider,
                       " - ",
                       llm_info$model %||% "default",
                       "\n")
    }

    report <- paste0(report, "\nSUGGESTED FACTOR NAMES:\n")
    report <- paste0(report, "=======================\n\n")
    for (i in 1:length(suggested_names)) {
      name <- names(suggested_names)[i]
      var_explained <- factor_summaries[[name]]$variance_explained
      report <- paste0(
        report,
        "Factor ",
        i,
        " (",
        round(var_explained * 100, 1),
        "%): ",
        suggested_names[[name]],
        "\n"
      )
    }

    # Add total variance explained
    total_variance <- sum(sapply(factor_summaries, function(x) x$variance_explained))
    report <- paste0(report, "\n\nTotal variance explained: ", round(total_variance * 100, 1), "%\n")

    # Add factor correlations section if provided
    if (!is.null(factor_cor_mat)) {
      report <- paste0(report, "\nFACTOR CORRELATIONS:\n")
      report <- paste0(report, "====================\n\n")

      # Convert matrix to dataframe if needed and get factor names
      if (is.matrix(factor_cor_mat)) {
        cor_df <- as.data.frame(factor_cor_mat)
        cor_factors <- rownames(factor_cor_mat)
      } else {
        cor_df <- factor_cor_mat
        cor_factors <- rownames(cor_df)
      }

      # Create correlation table
      for (i in 1:length(cor_factors)) {
        factor_name <- cor_factors[i]
        if (factor_name %in% names(cor_df)) {
          correlations <- c()
          for (j in 1:length(cor_factors)) {
            other_factor <- cor_factors[j]
            if (other_factor != factor_name && other_factor %in% names(cor_df)) {
              cor_val <- round(cor_df[[other_factor]][i], 2)
              cor_formatted <- sprintf("%.2f", cor_val)
              cor_formatted <- sub("^0", "", cor_formatted)  # Remove leading zero for consistency with LLM input
              correlations <- c(correlations, paste0(other_factor, " = ", cor_formatted))
            }
          }
          if (length(correlations) > 0) {
            report <- paste0(report, factor_name, ": ", paste(correlations, collapse = ", "), "\n")
          }
        }
      }
    }

    report <- paste0(report, "\n\nDETAILED FACTOR INTERPRETATIONS:\n")
    report <- paste0(report, "=================================\n\n")

    for (i in 1:n_factors) {
      factor_name <- factor_cols[i]

      # Extract the first line (factor header) from summary
      summary_lines <- strsplit(factor_summaries[[factor_name]]$summary, "\n")[[1]]
      factor_header <- summary_lines[1]
      remaining_summary <- paste(summary_lines[-1], collapse = "\n")

      # Add factor header with suggested name
      report <- paste0(report, factor_header)
      if (!is.null(suggested_names[[factor_name]])) {
        report <- paste0(report, " - ", suggested_names[[factor_name]])
      }
      # Parse summary to insert factor correlations after "Variance explained" line
      modified_summary <- remaining_summary
      if (!is.null(factor_cor_mat) && factor_name %in% rownames(factor_cor_mat)) {
        # Convert matrix to dataframe if needed and get factor names
        if (is.matrix(factor_cor_mat)) {
          cor_df <- as.data.frame(factor_cor_mat)
          cor_factors <- rownames(factor_cor_mat)
        } else {
          cor_df <- factor_cor_mat
          cor_factors <- rownames(cor_df)
        }

        # Find correlations for this factor
        if (factor_name %in% names(cor_df)) {
          correlations <- c()
          for (j in 1:length(cor_factors)) {
            other_factor <- cor_factors[j]
            if (other_factor != factor_name && other_factor %in% names(cor_df)) {
              factor_idx <- which(rownames(cor_df) == factor_name)
              cor_val <- round(cor_df[[other_factor]][factor_idx], 2)
              cor_formatted <- sprintf("%.2f", cor_val)
              cor_formatted <- sub("^0", "", cor_formatted)  # Remove leading zero for consistency with LLM input
              correlations <- c(correlations, paste0(other_factor, " = ", cor_formatted))
            }
          }
          if (length(correlations) > 0) {
            # Insert correlations after "Variance explained" line
            summary_lines <- strsplit(remaining_summary, "\n")[[1]]
            modified_lines <- c()
            for (line in summary_lines) {
              modified_lines <- c(modified_lines, line)
              if (grepl("^Variance explained:", line)) {
                cor_line <- paste("Factor Correlations:", paste(correlations, collapse = ", "))
                modified_lines <- c(modified_lines, cor_line)
              }
            }
            modified_summary <- paste(modified_lines, collapse = "\n")
          }
        }
      }

      # Apply text format line break fixes similar to markdown version
      if (!is.null(modified_summary)) {
        # Add line break after factor correlations
        modified_summary <- gsub("(Factor Correlations:[^\n]*)\n", "\\1\n\n", modified_summary)
        # Ensure Variables section has proper spacing
        modified_summary <- gsub("Variables:\n", "\nVariables:\n", modified_summary)
        # Fix numbered list so each item is on its own line (already should be from original format)
      }

      report <- paste0(report, "\n", modified_summary)

      report <- paste0(report, "\n")

      if (!is.null(factor_summaries[[factor_name]]$llm_interpretation)) {
        report <- paste0(
          report,
          "\nLLM Interpretation:\n",
          factor_summaries[[factor_name]]$llm_interpretation,
          "\n\n"
        )
      }
      report <- paste0(report, "------------------------\n\n")
    }
  }

  # Add cross-loadings section to report
  if (!is.null(cross_loadings) && nrow(cross_loadings) > 0) {
    if (output_format == "markdown") {
      report <- paste0(report, "\n", h2, " Cross-Loading Variables\n\n")
      report <- paste0(report,
                       "Variables loading on multiple factors (>= ",
                       cutoff,
                       "):\n\n")
    } else {
      report <- paste0(report, "\nCROSS-LOADING VARIABLES:\n")
      report <- paste0(report, "=========================\n\n")
      report <- paste0(report,
                       "Variables loading on multiple factors (>= ",
                       cutoff,
                       "):\n")
    }

    for (j in 1:nrow(cross_loadings)) {
      # Use description if available, otherwise fallback to variable name
      var_display <- if (!is.na(cross_loadings$description[j])) {
        if (output_format == "markdown") {
          paste0("**", cross_loadings$variable[j], ":** ", cross_loadings$description[j])
        } else {
          paste0(cross_loadings$variable[j], ", ", cross_loadings$description[j])
        }
      } else {
        if (output_format == "markdown") {
          paste0("**", cross_loadings$variable[j], "**")
        } else {
          cross_loadings$variable[j]
        }
      }

      report <- paste0(report,
                       "- ",
                       var_display,
                       ": ",
                       cross_loadings$factors[j],
                       "\n")
    }
  }

  # Add section for variables with no loadings above cutoff
  if (!is.null(no_loadings) && nrow(no_loadings) > 0) {
    if (output_format == "markdown") {
      report <- paste0(report, "\n", h2, " Variables Not Covered by Any Factor\n\n")
      report <- paste0(report,
                       "Variables with no absolute loadings >= ",
                       cutoff,
                       " (highest absolute loading shown):\n\n")
    } else {
      report <- paste0(report, "\n\nVARIABLES NOT COVERED BY ANY FACTOR:\n")
      report <- paste0(report, "=====================================\n\n")
      report <- paste0(report,
                       "Variables with no absolute loadings >= ",
                       cutoff,
                       " (highest absolute loading shown):\n")
    }

    for (j in 1:nrow(no_loadings)) {
      # Use description if available, otherwise fallback to variable name
      var_display <- if (!is.na(no_loadings$description[j])) {
        if (output_format == "markdown") {
          paste0("**", no_loadings$variable[j], ":** ", no_loadings$description[j])
        } else {
          paste0(no_loadings$variable[j], ": ", no_loadings$description[j])
        }
      } else {
        if (output_format == "markdown") {
          paste0("**", no_loadings$variable[j], "**")
        } else {
          no_loadings$variable[j]
        }
      }

      report <- paste0(report,
                       "- ",
                       var_display,
                       " (highest: ",
                       no_loadings$highest_loading[j],
                       ")\n")
    }
  }

  if (output_format == "markdown") {
    report <- paste0(report, "\n")
  } else {
    report <- paste0(report, "\n\n")
  }

  # Insert elapsed time after tokens or LLM info in the report
  if (!is.null(elapsed_time)) {
    if (output_format == "markdown") {
      # Try to insert after Tokens section, if not found try after LLM used line
      if (grepl("\\*\\*Tokens:\\*\\*", report)) {
        report <- sub("(\\*\\*Tokens:\\*\\*  \n  Input: [0-9]+  \n  Output: [0-9]+  \n)",
                      paste0("\\1**Elapsed time:** ", format(elapsed_time, digits = 3), "  \n\n"),
                      report)
      } else {
        report <- sub("(\\*\\*LLM used:\\*\\* [^\n]*  \n)",
                      paste0("\\1**Elapsed time:** ", format(elapsed_time, digits = 3), "  \n\n"),
                      report)
      }
    } else {
      # Try to insert after Tokens section, if not found try after LLM used line
      if (grepl("Tokens:", report)) {
        report <- sub("(Tokens:\n  Input: [0-9]+\n  Output: [0-9]+\n)",
                      paste0("\\1Elapsed time: ", format(elapsed_time, digits = 3), "\n\n"),
                      report)
      } else {
        report <- sub("(LLM used: [^\n]*\n)",
                      paste0("\\1Elapsed time: ", format(elapsed_time, digits = 3), "\n\n"),
                      report)
      }
    }
  }

  # Clean up any remaining formatting issues
  report <- gsub("\\n{3,}", "\n\n", report)                      # Remove excessive line breaks

  # Text format specific fixes
  if (output_format == "text") {
    # Ensure numbered list items are on separate lines
    report <- gsub("(\\)) ([0-9]+\\. )", "\\1\n\\2", report)
    report <- gsub("([0-9]{1,2}\\. [^)]+\\)) ([0-9]+\\. )", "\\1\n\\2", report)
  }

  # Final cleanup for both formats - any remaining isolated 'n' that should be newline
  report <- gsub("([a-z])n([A-Z][a-z]+:)", "\\1\n\\2", report)

  return(report)
}

#' Print Factor Analysis Interpretation Results
#'
#' S3 print method for fa_interpretation objects. Prints the interpretation report
#' with optional line wrapping for better readability in console output. Can regenerate
#' reports in different formats (text or markdown) with customizable heading levels.
#'
#' @param x fa_interpretation object from interpret_fa()
#' @param max_line_length Integer. Maximum line length for text wrapping (default = 80).
#'   Lines longer than this will be wrapped at word boundaries while preserving
#'   formatting like headers, indentation, and separators. Only applies to text format.
#' @param output_format Character. Output format: "text", "markdown", or NULL (default = NULL).
#'   If NULL, uses the existing report format. If specified, regenerates the report
#'   in the specified format using the stored analysis results.
#' @param heading_level Integer. Starting heading level for markdown output (default = 1).
#'   Only used when output_format = "markdown".
#' @param suppress_heading Logical. If TRUE, suppresses the main "Factor Analysis Interpretation"
#'   heading when regenerating the report, allowing for better integration into existing documents (default = FALSE)
#' @param ... Additional arguments (unused)
#'
#' @return Invisible NULL (prints to console)
#'
#' @examples
#' \dontrun{
#' # Get interpretation results
#' results <- interpret_fa(loadings, variable_info, silent = TRUE)
#'
#' # Print with default format (uses stored report)
#' print(results)
#'
#' # Print with custom line length
#' print(results, max_line_length = 60)
#'
#' # Convert to markdown format for integration
#' print(results, output_format = "markdown", heading_level = 3)
#'
#' # Convert back to text format
#' print(results, output_format = "text")
#' }
#'
#' @export
print.fa_interpretation <- function(x,
                                   max_line_length = 80,
                                   output_format = NULL,
                                   heading_level = 1,
                                   suppress_heading = FALSE,
                                   ...) {
  # Validate input
  if (!inherits(x, "fa_interpretation") || !is.list(x)) {
    cli::cli_abort(
      c("Input must be a fa_interpretation object", "i" = "This should be the output from interpret_fa()")
    )
  }

  if (!("report" %in% names(x)) && !("factor_summaries" %in% names(x))) {
    cli::cli_abort(
      c("fa_interpretation object must contain 'report' or 'factor_summaries' component", "i" = "This should be the output from interpret_fa()")
    )
  }

  # Validate max_line_length parameter
  if (!is.numeric(max_line_length) || length(max_line_length) != 1) {
    cli::cli_abort(
      c("{.var max_line_length} must be a single numeric value", "x" = "You supplied: {.val {max_line_length}}")
    )
  }
  if (max_line_length < 20 || max_line_length > 200) {
    cli::cli_abort(
      c(
        "{.var max_line_length} must be between 20 and 200",
        "x" = "You supplied: {.val {max_line_length}}",
        "i" = "Recommended range is 60-120 characters"
      )
    )
  }

  # Validate output_format if provided
  if (!is.null(output_format)) {
    if (!is.character(output_format) || length(output_format) != 1) {
      cli::cli_abort(
        c("{.var output_format} must be a single character string", "x" = "You supplied: {.val {output_format}}")
      )
    }
    if (!output_format %in% c("text", "markdown")) {
      cli::cli_abort(
        c(
          "{.var output_format} must be either 'text' or 'markdown'",
          "x" = "You supplied: {.val {output_format}}",
          "i" = "Supported formats: 'text', 'markdown'"
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
  if (heading_level < 1 || heading_level > 6 || heading_level != as.integer(heading_level)) {
    cli::cli_abort(
      c(
        "{.var heading_level} must be an integer between 1 and 6",
        "x" = "You supplied: {.val {heading_level}}",
        "i" = "Markdown supports heading levels 1 through 6"
      )
    )
  }

  # If output_format is specified, regenerate report in that format
  if (!is.null(output_format) && "factor_summaries" %in% names(x)) {
    # Extract n_factors and cutoff from the interpretation results if available
    n_factors <- length(x$factor_summaries)

    # Try to extract cutoff from the existing report or use default
    cutoff <- 0.3  # Default fallback
    if ("report" %in% names(x)) {
      cutoff_match <- regexpr("Loading cutoff[:\\s]*([0-9.]+)", x$report)
      if (cutoff_match > 0) {
        cutoff_text <- regmatches(x$report, cutoff_match)
        cutoff_num <- as.numeric(gsub(".*?([0-9.]+).*", "\\1", cutoff_text))
        if (!is.na(cutoff_num)) {
          cutoff <- cutoff_num
        }
      }
    }

    # Regenerate report in the specified format
    report_text <- build_fa_report(
      interpretation_results = x,
      output_format = output_format,
      heading_level = heading_level,
      n_factors = n_factors,
      cutoff = cutoff,
      suppress_heading = suppress_heading
    )
  } else {
    # Use existing report
    report_text <- x$report
  }

  # Wrap and print the report (only for text format)
  if (is.null(output_format) || output_format == "text") {
    wrapped_report <- wrap_text(report_text, max_line_length)
    cat(wrapped_report)
  } else {
    # For markdown, print without wrapping to preserve formatting
    cat(report_text)
  }

  return(invisible(NULL))
}
