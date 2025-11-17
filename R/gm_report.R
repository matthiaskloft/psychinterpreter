# ===================================================================
# FILE: gm_report.R
# PURPOSE: Report generation for Gaussian Mixture Model interpretations
# ===================================================================

#' Build Report for GM Interpretation
#'
#' Creates a formatted report from GM interpretation results.
#'
#' @param interpretation An object of class "gm_interpretation"
#' @param format Output format: "cli" or "markdown"
#' @param heading_level Starting heading level for markdown (default: 2)
#' @return Character string containing the formatted report
#' @export
#' @keywords internal
build_report.gm_interpretation <- function(
    interpretation,
    format = c("cli", "markdown"),
    heading_level = 2) {

  format <- match.arg(format)

  # Extract components
  cluster_interpretations <- interpretation$interpretation
  analysis_data <- interpretation$analysis_data
  fit_summary <- interpretation$fit_summary
  suggested_names <- interpretation$suggested_names

  # Build report sections
  sections <- list()

  # Title section
  sections$title <- build_title_section_gm(
    analysis_data, format, heading_level
  )

  # Model information
  sections$model_info <- build_model_info_section_gm(
    analysis_data, fit_summary, format, heading_level
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
      distinguishing_vars, format, heading_level
    )
  }

  # Combine all sections
  report <- paste(sections, collapse = "\n\n")

  # Apply format-specific styling
  if (format == "cli") {
    report <- style_for_cli_gm(report)
  }

  return(report)
}

#' Build Title Section for GM Report
#'
#' @param analysis_data Standardized GM analysis data
#' @param format Output format
#' @param heading_level Heading level for markdown
#' @return Character string with title section
#' @keywords internal
build_title_section_gm <- function(analysis_data, format, heading_level) {
  title <- paste0(
    "Gaussian Mixture Model Interpretation: ",
    analysis_data$n_clusters, " Clusters"
  )

  if (format == "markdown") {
    hashes <- paste(rep("#", heading_level), collapse = "")
    return(paste0(hashes, " ", title))
  } else {
    # CLI format
    return(cli::cli_text("{.strong {title}}"))
  }
}

#' Build Model Information Section for GM Report
#'
#' @param analysis_data Standardized GM analysis data
#' @param fit_summary Diagnostic information
#' @param format Output format
#' @param heading_level Heading level for markdown
#' @return Character string with model information
#' @keywords internal
build_model_info_section_gm <- function(analysis_data, fit_summary, format, heading_level) {
  info_parts <- list()

  # Basic statistics
  info_parts$basic <- paste0(
    "Model: ", analysis_data$n_clusters, " clusters, ",
    analysis_data$n_variables, " variables, ",
    analysis_data$n_observations, " observations"
  )

  # Covariance structure
  if (!is.null(analysis_data$covariance_type)) {
    cov_desc <- describe_covariance_type(analysis_data$covariance_type)
    info_parts$covariance <- paste0("Covariance structure: ", cov_desc)
  }

  # Model fit
  if (!is.null(fit_summary$statistics)) {
    if (!is.null(fit_summary$statistics$bic)) {
      info_parts$bic <- paste0("BIC: ", fit_summary$statistics$bic)
    }
    if (!is.null(fit_summary$statistics$min_separation)) {
      info_parts$separation <- paste0(
        "Minimum cluster separation: ",
        fit_summary$statistics$min_separation
      )
    }
  }

  # Format section
  if (format == "markdown") {
    hashes <- paste(rep("#", heading_level + 1), collapse = "")
    section <- paste0(hashes, " Model Information\n\n")
    section <- paste0(section, paste("- ", info_parts, collapse = "\n"))
  } else {
    # CLI format
    section <- cli::cli_text("{.emph Model Information:}")
    section <- paste0(section, "\n", paste("  ", info_parts, collapse = "\n"))
  }

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

  if (format == "markdown") {
    hashes <- paste(rep("#", heading_level + 1), collapse = "")
    section <- paste0(hashes, " Cluster Interpretations\n\n")
  } else {
    section <- cli::cli_text("{.emph Cluster Interpretations:}\n")
  }

  # Add each cluster interpretation
  for (k in seq_len(analysis_data$n_clusters)) {
    cluster_name <- analysis_data$cluster_names[k]

    # Get size information
    if (!is.null(analysis_data$proportions)) {
      size_pct <- round(analysis_data$proportions[k] * 100, 1)
      size_text <- paste0(" (", size_pct, "% of observations)")
    } else {
      size_text <- ""
    }

    # Get suggested name if available
    if (!is.null(suggested_names) && cluster_name %in% names(suggested_names)) {
      display_name <- paste0(
        cluster_name, ': "', suggested_names[[cluster_name]], '"',
        size_text
      )
    } else {
      display_name <- paste0(cluster_name, size_text)
    }

    # Get interpretation
    interpretation_text <- cluster_interpretations[[cluster_name]]

    # Format based on output type
    if (format == "markdown") {
      hashes_sub <- paste(rep("#", heading_level + 2), collapse = "")
      section <- paste0(
        section,
        hashes_sub, " ", display_name, "\n\n",
        interpretation_text, "\n\n"
      )
    } else {
      # CLI format
      section <- paste0(
        section, "\n",
        cli::cli_text("{.field ", display_name, "}"), "\n",
        "  ", interpretation_text, "\n"
      )
    }
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

  if (format == "markdown") {
    hashes <- paste(rep("#", heading_level + 1), collapse = "")
    section <- paste0(hashes, " Diagnostics\n\n")

    if (length(fit_summary$warnings) > 0) {
      section <- paste0(section, "**Warnings:**\n")
      for (warning in fit_summary$warnings) {
        section <- paste0(section, "- ⚠️ ", warning, "\n")
      }
      section <- paste0(section, "\n")
    }

    if (length(fit_summary$notes) > 0) {
      section <- paste0(section, "**Notes:**\n")
      for (note in fit_summary$notes) {
        section <- paste0(section, "- ℹ️ ", note, "\n")
      }
    }
  } else {
    # CLI format
    section <- cli::cli_text("{.emph Diagnostics:}\n")

    if (length(fit_summary$warnings) > 0) {
      section <- paste0(section, "\n  {.strong Warnings:}\n")
      for (warning in fit_summary$warnings) {
        section <- paste0(section, "    ", cli::cli_text("{.warning ", warning, "}"), "\n")
      }
    }

    if (length(fit_summary$notes) > 0) {
      section <- paste0(section, "\n  {.strong Notes:}\n")
      for (note in fit_summary$notes) {
        section <- paste0(section, "    ", cli::cli_text("{.info ", note, "}"), "\n")
      }
    }
  }

  return(section)
}

#' Build Key Variables Section for GM Report
#'
#' @param distinguishing_vars List of distinguishing variables per cluster
#' @param format Output format
#' @param heading_level Heading level for markdown
#' @return Character string with key variables section
#' @keywords internal
build_key_variables_section_gm <- function(distinguishing_vars, format, heading_level) {
  if (format == "markdown") {
    hashes <- paste(rep("#", heading_level + 1), collapse = "")
    section <- paste0(hashes, " Key Distinguishing Variables\n\n")

    for (cluster_name in names(distinguishing_vars)) {
      vars_df <- distinguishing_vars[[cluster_name]]
      section <- paste0(section, "**", cluster_name, ":**\n")

      for (i in seq_len(nrow(vars_df))) {
        var_desc <- paste0(
          vars_df$variable[i],
          " (mean: ", round(vars_df$cluster_mean[i], 2),
          " vs overall: ", round(vars_df$overall_mean[i], 2), ")"
        )
        section <- paste0(section, "- ", var_desc, "\n")
      }
      section <- paste0(section, "\n")
    }
  } else {
    # CLI format
    section <- cli::cli_text("{.emph Key Distinguishing Variables:}\n")

    for (cluster_name in names(distinguishing_vars)) {
      vars_df <- distinguishing_vars[[cluster_name]]
      section <- paste0(section, "\n  {.field ", cluster_name, ":}\n")

      for (i in seq_len(nrow(vars_df))) {
        var_desc <- paste0(
          vars_df$variable[i],
          " (", round(vars_df$cluster_mean[i], 2),
          " vs ", round(vars_df$overall_mean[i], 2), ")"
        )
        section <- paste0(section, "    - ", var_desc, "\n")
      }
    }
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

#' Style Report for CLI Output (GM)
#'
#' @param report Character string with report content
#' @return Styled report for CLI display
#' @keywords internal
style_for_cli_gm <- function(report) {
  # Add any GM-specific CLI styling if needed
  # For now, return as-is since cli functions are already applied
  return(report)
}