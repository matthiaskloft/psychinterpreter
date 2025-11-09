#' Build Factor Analysis Interpretation Report
#'
#' Internal helper function that builds a formatted interpretation report from factor analysis results.
#' This function can generate reports in either text or markdown format and can be called
#' independently to regenerate reports in different formats after analysis.
#'
#' @param interpretation_results A list containing factor analysis interpretation results with components:
#'   factor_summaries, suggested_names, llm_info, chat, cross_loadings, no_loadings, elapsed_time, factor_cor_mat
#' @param output_format Character. Output format: "cli" or "markdown" (default = "cli")
#' @param heading_level Integer. Starting heading level for markdown output (default = 1)
#' @param n_factors Integer. Number of factors in the analysis
#' @param cutoff Numeric. Loading cutoff value used in the analysis
#'
#' @return Character string containing the formatted report
#'
#' @keywords internal
#' @noRd
build_fa_report <- function(interpretation_results,
                            output_format = "cli",
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
  n_emergency <- interpretation_results$params$n_emergency %||% 2  # Default to 2 if not found

  # Get factor column names
  factor_cols <- names(factor_summaries)

  # Helper function to generate summary text from minimal factor data
  build_factor_summary_text <- function(factor_summary, cutoff, n_emergency) {
    variables <- factor_summary$variables
    variance_explained <- factor_summary$variance_explained
    used_emergency_rule <- factor_summary$used_emergency_rule

    n_loadings <- nrow(variables)
    has_significant <- n_loadings > 0

    # When emergency rule is used, report 0 significant loadings
    # The variables shown are the top N below cutoff
    n_significant_loadings <- ifelse(used_emergency_rule, 0, n_loadings)

    # Build summary text
    summary_text <- paste0(
      "Number of significant loadings: ",
      n_significant_loadings,
      "\n",
      "Variance explained: ",
      round(variance_explained * 100, 2),
      "%\n"
    )

    # Show warning when emergency rule is used or when no variables at all
    if (used_emergency_rule || !has_significant) {
      if (!has_significant) {
        # No variables at all (n_emergency = 0 case)
        summary_text <- paste0(
          summary_text,
          "WARNING: No variables load above cutoff (",
          cutoff,
          "). ",
          "Factor marked as undefined (n_emergency = 0).\n"
        )
      } else {
        # Emergency rule was used (has variables, but below cutoff)
        summary_text <- paste0(
          summary_text,
          "WARNING: No variables load above cutoff (",
          cutoff,
          "). ",
          "Emergency rule applied: using top ",
          n_loadings,
          " variable(s) below cutoff for interpretation.\n"
        )
      }
    }

    summary_text <- paste0(summary_text, "\nVariables:\n")

    # Add variables
    if (n_loadings > 0) {
      for (j in 1:n_loadings) {
        var_desc <- ifelse(
          !is.na(variables$description[j]),
          variables$description[j],
          variables$variable[j]
        )
        summary_text <- paste0(
          summary_text,
          "  ",
          j,
          ". ",
          variables$variable[j],
          ", ",
          var_desc,
          " (",
          variables$direction[j],
          ", ",
          variables$strength[j],
          ", ",
          format_loading(variables$loading[j]),
          ")\n"
        )
      }
    } else {
      summary_text <- paste0(summary_text, "  No variables in this factor\n")
    }

    return(summary_text)
  }

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
                       chat$provider,
                       " - ",
                       chat$model %||% "default",
                       "  \n")


      if (!is.null(interpretation_results$input_tokens) &&
          !is.null(interpretation_results$output_tokens)) {
        report <- paste0(
          report,
          "**Tokens:**  \n  Input: ",
          interpretation_results$input_tokens,
          "  \n  Output: ",
          interpretation_results$output_tokens,
          "  \n"
        )
      }
    } else if (!is.null(llm_info)) {
      report <- paste0(
        report,
        "**LLM used:** ",
        llm_info$provider,
        " - ",
        llm_info$model %||% "default",
        "  \n"
      )
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
    total_variance <- sum(sapply(factor_summaries, function(x)
      x$variance_explained))
    report <- paste0(
      report,
      "\n**Total variance explained by all factors: ",
      round(total_variance * 100, 1),
      "%**\n"
    )

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
            if (other_factor != factor_name &&
                other_factor %in% names(cor_df)) {
              cor_val <- round(cor_df[[other_factor]][i], 2)
              cor_formatted <- format_loading(cor_val, digits = 2)
              correlations <- c(correlations,
                                paste0(other_factor, " = ", cor_formatted))
            }
          }
          if (length(correlations) > 0) {
            # Split long correlation lists for better readability
            if (length(correlations) > 3) {
              line1 <- paste(correlations[1:3], collapse = ", ")
              line2 <- paste(correlations[4:length(correlations)], collapse = ", ")
              report <- paste0(report,
                               "- **",
                               factor_name,
                               ":** ",
                               line1,
                               ",  \n  ",
                               line2,
                               "\n")
            } else {
              report <- paste0(
                report,
                "- **",
                factor_name,
                ":** ",
                paste(correlations, collapse = ", "),
                "\n"
              )
            }
          }
        }
      }
    }

    report <- paste0(report, "\n", h2, " Detailed Factor Interpretations\n\n")

    for (i in 1:n_factors) {
      factor_name <- factor_cols[i]

      # Generate header and summary from minimal factor data
      factor_header <- paste0("Factor ", i, " (", factor_name, ")")
      remaining_summary <- build_factor_summary_text(
        factor_summaries[[factor_name]],
        cutoff,
        n_emergency
      )

      # Add factor header with suggested name as h3
      report <- paste0(report, h3, " ", factor_header)
      if (!is.null(suggested_names[[factor_name]])) {
        # factor_header may already include a trailing ':' (created earlier in
        # the summary). Avoid producing a double-colon ("::") by checking for
        # an existing trailing colon and only inserting a separator when needed.
  if (grepl(":\\s*$", factor_header)) {
          report <- paste0(report, " ", suggested_names[[factor_name]])
        } else {
          report <- paste0(report, ": ", suggested_names[[factor_name]])
        }
      }
      report <- paste0(report, "\n\n")

      # Parse summary to insert factor correlations after "Variance explained" line
      if (!is.null(factor_cor_mat) &&
          factor_name %in% rownames(factor_cor_mat)) {
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
            if (other_factor != factor_name &&
                other_factor %in% names(cor_df)) {
              factor_idx <- which(rownames(cor_df) == factor_name)
              cor_val <- round(cor_df[[other_factor]][factor_idx], 2)
              cor_formatted <- format_loading(cor_val, digits = 2)
              correlations <- c(correlations,
                                paste0(other_factor, " = ", cor_formatted))
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
                  cor_line <- paste0("**Factor Correlations:** ",
                                     line1,
                                     ",  \n",
                                     line2)
                } else {
                  cor_line <- paste0("**Factor Correlations:** ",
                                     paste(correlations, collapse = ", "))
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
      summary_md <- gsub("(Number of significant loadings:) ([0-9]+)\\n",
                         "**\\1** \\2  \n",
                         summary_md)
      summary_md <- gsub("(Variance explained:) ([0-9\\.]+%)\\n",
                         "**\\1** \\2  \n",
                         summary_md)
      summary_md <- gsub("(\\*\\*Factor Correlations:\\*\\*[^\n]*)\\n",
                         "\\1  \n\n",
                         summary_md)

      # Fix variables section - add proper spacing and formatting
      summary_md <- gsub("Variables:\\n", "\n\n**Variables:**\n\n", summary_md)

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
    # CLI format with semantic styling
    # Add main heading unless suppressed
    if (!suppress_heading) {
      report <- paste0(cli::col_cyan(cli::style_bold("FACTOR ANALYSIS INTERPRETATION")), "\n")
      report <- paste0(report, cli::rule(line = 1, line_col = "cyan"), "\n\n")
    } else {
      report <- ""
    }
    report <- paste0(report, cli::style_bold("Number of factors:"), " ", n_factors, "\n")
    report <- paste0(report, cli::style_bold("Loading cutoff:"), " ", cutoff, "\n")

    # Handle LLM info safely
    if (!is.null(chat)) {
      report <- paste0(report,
                       cli::style_bold("LLM used:"), " ",
                       chat$provider,
                       " - ",
                       chat$model %||% "default",
                       "\n")

      if (!is.null(interpretation_results$input_tokens) &&
          !is.null(interpretation_results$output_tokens)) {
        report <- paste0(
          report,
          cli::style_bold("Tokens:"), "\n  Input: ",
          interpretation_results$input_tokens,
          "\n  Output: ",
          interpretation_results$output_tokens,
          "\n"
        )
      }

    } else if (!is.null(llm_info)) {
      report <- paste0(report,
                       cli::style_bold("LLM used:"), " ",
                       llm_info$provider,
                       " - ",
                       llm_info$model %||% "default",
                       "\n")
    }

    report <- paste0(report, "\n", cli::col_cyan(cli::style_bold("SUGGESTED FACTOR NAMES")), "\n")
    report <- paste0(report, cli::rule(line = 1, line_col = "cyan"), "\n\n")
    for (i in 1:length(suggested_names)) {
      name <- names(suggested_names)[i]
      var_explained <- factor_summaries[[name]]$variance_explained
      report <- paste0(
        report,
        cli::symbol$bullet, " ",
        cli::style_bold(paste0("Factor ", i)),
        " (",
        round(var_explained * 100, 1),
        "%): ",
        cli::col_green(suggested_names[[name]]),
        "\n"
      )
    }

    # Add total variance explained
    total_variance <- sum(sapply(factor_summaries, function(x)
      x$variance_explained))
    report <- paste0(report,
                     "\n",
                     cli::style_bold("Total variance explained:"), " ",
                     round(total_variance * 100, 1),
                     "%\n")

    # Add factor correlations section if provided
    if (!is.null(factor_cor_mat)) {
      report <- paste0(report, "\n", cli::col_cyan(cli::style_bold("FACTOR CORRELATIONS")), "\n")
      report <- paste0(report, cli::rule(line = 1, line_col = "cyan"), "\n\n")

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
            if (other_factor != factor_name &&
                other_factor %in% names(cor_df)) {
              cor_val <- round(cor_df[[other_factor]][i], 2)
              cor_formatted <- format_loading(cor_val, digits = 2)
              correlations <- c(correlations,
                                paste0(other_factor, " = ", cor_formatted))
            }
          }
          if (length(correlations) > 0) {
            report <- paste0(report,
                             factor_name,
                             ": ",
                             paste(correlations, collapse = ", "),
                             "\n")
          }
        }
      }
    }

    report <- paste0(report, "\n", cli::col_cyan(cli::style_bold("DETAILED FACTOR INTERPRETATIONS")), "\n")
    report <- paste0(report, cli::rule(line = 1, line_col = "cyan"), "\n\n")

    for (i in 1:n_factors) {
      factor_name <- factor_cols[i]

      # Generate header and summary from minimal factor data
      factor_header <- paste0("Factor ", i, " (", factor_name, ")")
      remaining_summary <- build_factor_summary_text(
        factor_summaries[[factor_name]],
        cutoff,
        n_emergency
      )

      # Add factor header with suggested name
      report <- paste0(report, cli::style_bold(factor_header))
      if (!is.null(suggested_names[[factor_name]])) {
        report <- paste0(report, " - ", cli::col_green(suggested_names[[factor_name]]))
      }
      # Parse summary to insert factor correlations after "Variance explained" line
      modified_summary <- remaining_summary
      if (!is.null(factor_cor_mat) &&
          factor_name %in% rownames(factor_cor_mat)) {
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
            if (other_factor != factor_name &&
                other_factor %in% names(cor_df)) {
              factor_idx <- which(rownames(cor_df) == factor_name)
              cor_val <- round(cor_df[[other_factor]][factor_idx], 2)
              cor_formatted <- format_loading(cor_val, digits = 2)
              correlations <- c(correlations,
                                paste0(other_factor, " = ", cor_formatted))
            }
          }
          if (length(correlations) > 0) {
            # Insert correlations after "Variance explained" line
            summary_lines <- strsplit(remaining_summary, "\n")[[1]]
            modified_lines <- c()
            for (line in summary_lines) {
              modified_lines <- c(modified_lines, line)
              if (grepl("^Variance explained:", line)) {
                cor_line <- paste("Factor Correlations:",
                                  paste(correlations, collapse = ", "))
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
        modified_summary <- gsub("(Factor Correlations:[^\n]*)\n",
                                 "\\1\n\n",
                                 modified_summary)
        # Ensure Variables section has proper spacing
        modified_summary <- gsub("Variables:\n", "\nVariables:\n", modified_summary)
        # Fix numbered list so each item is on its own line (already should be from original format)
      }

      report <- paste0(report, "\n", modified_summary)

      report <- paste0(report, "\n")

      if (!is.null(factor_summaries[[factor_name]]$llm_interpretation)) {
        report <- paste0(
          report,
          "\n", cli::style_bold("LLM Interpretation:"), "\n",
          factor_summaries[[factor_name]]$llm_interpretation,
          "\n\n"
        )
      }
      report <- paste0(report, cli::rule(line = 2, line_col = "grey"), "\n\n")
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
      report <- paste0(report, "\n", cli::col_yellow(cli::style_bold("CROSS-LOADING VARIABLES")), "\n")
      report <- paste0(report, cli::rule(line = 1, line_col = "yellow"), "\n\n")
      report <- paste0(report,
                       "Variables loading on multiple factors (>= ",
                       cutoff,
                       "):\n")
    }

    for (j in 1:nrow(cross_loadings)) {
      # Use description if available, otherwise fallback to variable name
      var_display <- if (!is.na(cross_loadings$description[j])) {
        if (output_format == "markdown") {
          paste0("**",
                 cross_loadings$variable[j],
                 ":** ",
                 cross_loadings$description[j])
        } else {
          paste0(cross_loadings$variable[j],
                 ", ",
                 cross_loadings$description[j])
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
      report <- paste0(
        report,
        "Variables with no absolute loadings >= ",
        cutoff,
        " (highest absolute loading shown):\n\n"
      )
    } else {
      report <- paste0(report, "\n", cli::col_red(cli::style_bold("VARIABLES NOT COVERED BY ANY FACTOR")), "\n")
      report <- paste0(report, cli::rule(line = 1, line_col = "red"), "\n\n")
      report <- paste0(
        report,
        "Variables with no absolute loadings >= ",
        cutoff,
        " (highest absolute loading shown):\n"
      )
    }

    for (j in 1:nrow(no_loadings)) {
      # Use description if available, otherwise fallback to variable name
      var_display <- if (!is.na(no_loadings$description[j])) {
        if (output_format == "markdown") {
          paste0("**",
                 no_loadings$variable[j],
                 ":** ",
                 no_loadings$description[j])
        } else {
          paste0(no_loadings$variable[j],
                 ": ",
                 no_loadings$description[j])
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

  # Clean up any remaining formatting issues
  report <- gsub("\\n{3,}", "\n\n", report)                      # Remove excessive line breaks

  # CLI format specific fixes
  if (output_format == "cli") {
    # Ensure numbered list items are on separate lines
    report <- gsub("(\\)) ([0-9]+\\. )", "\\1\n\\2", report)
    report <- gsub("([0-9]{1,2}\\. [^)]+\\)) ([0-9]+\\. )", "\\1\n\\2", report)
  }

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
#'   formatting like headers, indentation, and separators. Only applies to cli format.
#' @param output_format Character. Output format: "cli", "markdown", or NULL (default = NULL).
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
#' # Convert back to cli format
#' print(results, output_format = "cli")
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

  if (!("report" %in% names(x)) &&
      !("factor_summaries" %in% names(x))) {
    cli::cli_abort(
      c(
        "fa_interpretation object must contain 'report' or 'factor_summaries' component",
        "i" = "This should be the output from interpret_fa()"
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

#' Build Report for FA Interpretation (S3 Method)
#'
#' S3 method that integrates with the core interpret_generic() workflow.
#' Wraps the existing build_fa_report() function.
#'
#' @param interpretation fa_interpretation object
#' @param output_format Character. "cli" or "markdown"
#' @param heading_level Integer. Markdown heading level
#' @param suppress_heading Logical. Suppress report heading
#' @param ... Additional arguments (unused)
#'
#' @return Character. Formatted report text
#' @export
#' @keywords internal
build_report.fa_interpretation <- function(interpretation,
                                          output_format = "cli",
                                          heading_level = 1,
                                          suppress_heading = FALSE,
                                          ...) {
  # Extract parameters from interpretation object
  n_factors <- length(interpretation$suggested_names)
  cutoff <- interpretation$params$cutoff %||% 0.3

  # Call existing build_fa_report function
  build_fa_report(
    interpretation_results = interpretation,
    output_format = output_format,
    heading_level = heading_level,
    n_factors = n_factors,
    cutoff = cutoff,
    suppress_heading = suppress_heading
  )
}
