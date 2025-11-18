#' Gaussian Mixture Model Prompt Builders
#'
#' S3 methods for building system and user prompts specific to Gaussian mixture models.
#' These functions implement the prompt_builder S3 generics for GM.
#'
#' @name gm_prompts
#' @keywords internal
NULL

#' Build System Prompt for Gaussian Mixture Model
#'
#' Creates the expert clustering analyst system prompt for GM interpretation.
#' This is the single source of truth for the GM system prompt, used by both
#' interpret_model.Mclust() and chat_session() to eliminate duplication.
#'
#' @param analysis_type Object with class "gm"
#' @param word_limit Integer. Word limit for interpretations
#' @param ... Additional arguments (unused)
#'
#' @return Character. System prompt text
#' @export
#' @keywords internal
build_system_prompt.gm <- function(analysis_type, word_limit = 100, ...) {
  paste0(
    "# ROLE\n",
    "You are an expert in clustering analysis, Gaussian mixture models, ",
    "and psychological profiling.\n\n",

    "# TASK\n",
    "Provide comprehensive cluster interpretation by: (1) naming each cluster with a ",
    "short, descriptive label (2-4 words), (2) explaining the profile and characteristics ",
    "of each cluster, and (3) identifying what distinguishes each cluster from others.\n\n",

    "# KEY DEFINITIONS\n",
    "- **Cluster**: A group of observations with similar patterns across variables\n",
    "- **Cluster mean**: Average value of a variable within a cluster (standardized)\n",
    "- **Cluster profile**: The pattern of means across all variables that defines the cluster\n",
    "- **Within-cluster correlation**: Correlation between variables within a specific cluster\n",
    "- **Positive correlation**: Variables that tend to increase/decrease together (0.3-0.5 = weak, 0.5-0.7 = moderate, >0.7 = strong)\n",
    "- **Negative correlation**: Variables that move in opposite directions (-0.3 to -0.5 = weak, -0.5 to -0.7 = moderate, <-0.7 = strong)\n",
    "- **Near-zero correlation**: Variables that vary independently (|r| < 0.3)\n",
    "- **Distinguishing variables**: Variables with the largest differences between clusters\n",
    "- **Uncertainty**: Measure of ambiguity in cluster assignment (lower is better)\n",
    "- **Cluster interpretation**: Identifying the psychological or behavioral profile that explains the pattern\n\n"
  )
}

#' Build Main Prompt for Gaussian Mixture Model
#'
#' Constructs the complete user prompt containing cluster statistics, variable
#' descriptions, and interpretation instructions. All GM-specific parameters
#' are extracted from analysis_data.
#'
#' @param analysis_type Object with class "gm"
#' @param analysis_data List containing:
#'   - n_clusters: Number of clusters
#'   - n_variables: Number of variables
#'   - n_observations: Number of observations
#'   - cluster_names: Character vector of cluster names
#'   - means: Matrix of cluster means (variables x clusters)
#'   - variable_names: Character vector of variable names
#'   - proportions: Numeric vector of cluster proportions
#'   - covariances: Array of covariance matrices (optional)
#'   - covariance_type: Character describing covariance structure (optional)
#'   - uncertainty: Numeric vector of uncertainty values (optional)
#'   - classification: Integer vector of cluster assignments (optional)
#'   - weight_by_uncertainty: Logical. Whether to weight by uncertainty
#'   - profile_variables: Character vector of variables to focus on (optional)
#' @param word_limit Integer. Word limit for interpretations
#' @param additional_info Character or NULL. Additional context
#' @param ... Additional arguments passed from generic, including variable_info
#'   (data frame with 'variable' and 'description' columns, required for GM)
#'
#' @return Character. User prompt text
#' @export
#' @keywords internal
build_main_prompt.gm <- function(analysis_type,
                                  analysis_data,
                                  word_limit,
                                  additional_info = NULL,
                                  ...) {
  # Extract parameters from ...
  dots <- list(...)
  variable_info <- dots$variable_info

  # Validate variable_info is provided (required for GM)
  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} is required for Gaussian mixture model interpretation",
        "i" = "Provide a data frame with 'variable' and 'description' columns"
      )
    )
  }

  # Extract optional parameters from ...
  interpretation_guidelines <- dots$interpretation_guidelines

  # Initialize prompt
  prompt <- ""

  # ============================================================================
  # SECTION 1: INTERPRETATION GUIDELINES
  # ============================================================================
  if (!is.null(interpretation_guidelines)) {
    prompt <- paste0(prompt, interpretation_guidelines)
  } else {
    # Default interpretation guidelines
    prompt <- paste0(
      prompt,
      "# INTERPRETATION GUIDELINES\n\n",
      "## Cluster Naming\n",
      "- **Profile identification**: Identify the behavioral or psychological profile each cluster represents\n",
      "- **Name creation**: Create 2-4 word names capturing the essence of each cluster\n",
      "- **Theoretical grounding**: Base names on domain knowledge and additional context\n\n",
      "## Cluster Interpretation\n",
      "- **Distinguishing characteristics**: Focus on what makes each cluster unique\n",
      "- **Variable patterns**: Examine both high and low means, especially for distinguishing variables\n",
      "- **Within-cluster correlations**: Use correlations to understand trait co-occurrence patterns\n",
      "- **Relative comparisons**: Describe clusters in relation to each other\n",
      "- **Practical significance**: Consider meaningful differences, not just numerical values\n",
      "- **Uncertainty awareness**: If provided, give more confidence to well-defined clusters\n\n",
      "## Output Requirements\n",
      "- **Word target (Interpretation)**: Aim for ",
      round(word_limit * 0.8),
      "-",
      word_limit,
      " words per interpretation (80%-100% of limit)\n",
      "- **Writing style**: Be concise, precise, and domain-appropriate\n",
      "- **Avoid jargon**: Use clear, accessible language\n\n"
    )
  }

  # ============================================================================
  # SECTION 2: ADDITIONAL CONTEXT
  # ============================================================================
  if (!is.null(additional_info) && nchar(additional_info) > 0) {
    prompt <- paste0(prompt, "# ADDITIONAL CONTEXT\n", additional_info, "\n\n")
  }

  # ============================================================================
  # SECTION 3: MODEL INFORMATION
  # ============================================================================
  prompt <- paste0(
    prompt,
    "# MODEL INFORMATION\n",
    "**Number of clusters**: ", analysis_data$n_clusters, "\n",
    "**Number of variables**: ", analysis_data$n_variables, "\n",
    "**Number of observations**: ", analysis_data$n_observations, "\n"
  )

  if (!is.null(analysis_data$covariance_type)) {
    prompt <- paste0(
      prompt,
      "**Covariance structure**: ", analysis_data$covariance_type, "\n"
    )
  }
  prompt <- paste0(prompt, "\n")

  # ============================================================================
  # SECTION 4: VARIABLE DESCRIPTIONS
  # ============================================================================
  prompt <- paste0(prompt, build_variable_section_gm(analysis_data, variable_info), "\n")

  # ============================================================================
  # SECTION 5: CLUSTER PROFILES
  # ============================================================================
  prompt <- paste0(prompt, build_cluster_section_gm(analysis_data), "\n")

  # ============================================================================
  # SECTION 6: OUTPUT FORMAT
  # ============================================================================
  prompt <- paste0(prompt, build_output_instructions_gm(analysis_data, word_limit))

  return(prompt)
}

#' Build Variable Section for GM Prompt
#'
#' Formats variable descriptions for inclusion in the GM interpretation prompt.
#' Filters to profile_variables if specified in analysis_data.
#'
#' @param analysis_data Standardized GM analysis data (list with profile_variables element)
#' @param variable_info Data frame with 'variable' and 'description' columns
#' @return Character string with formatted variable information
#' @keywords internal
build_variable_section_gm <- function(analysis_data, variable_info) {
  # Filter to profile variables if specified
  if (!is.null(analysis_data$profile_variables)) {
    variable_info <- variable_info[
      variable_info$variable %in% analysis_data$profile_variables,
    ]
    if (nrow(variable_info) == 0) {
      cli::cli_warn("No matching profile_variables found in variable_info")
      variable_info <- data.frame(
        variable = analysis_data$profile_variables,
        description = analysis_data$profile_variables
      )
    }
  }

  # Format variable descriptions
  var_text <- "# VARIABLE DESCRIPTIONS\n"

  for (i in seq_len(min(nrow(variable_info), 1e3))) {
    var_desc <- ifelse(
      !is.na(variable_info$description[i]),
      variable_info$description[i],
      variable_info$variable[i]
    )
    var_text <- paste0(var_text, "- ", variable_info$variable[i], ": ", var_desc, "\n")
  }

  return(var_text)
}

#' Build Cluster Section for GM Prompt
#'
#' Formats comprehensive cluster statistics including means, proportions, uncertainty,
#' and within-cluster correlations for the interpretation prompt. Filters to
#' profile_variables if specified.
#'
#' @param analysis_data Standardized GM analysis data (list with means, proportions,
#'   covariances, uncertainty, weight_by_uncertainty, profile_variables, etc.)
#' @return Character string with formatted cluster statistics including means,
#'   sizes, uncertainty (if enabled), and within-cluster correlations
#' @keywords internal
build_cluster_section_gm <- function(analysis_data) {
  cluster_text <- "# CLUSTER PROFILES\n\n"

  # Calculate cluster sizes
  if (!is.null(analysis_data$proportions)) {
    cluster_sizes <- analysis_data$proportions
  } else if (!is.null(analysis_data$classification)) {
    cluster_sizes <- table(analysis_data$classification) / length(analysis_data$classification)
  } else {
    cluster_sizes <- rep(1/analysis_data$n_clusters, analysis_data$n_clusters)
  }

  # Calculate average uncertainty per cluster if available
  cluster_uncertainty <- NULL
  if (!is.null(analysis_data$uncertainty) && !is.null(analysis_data$classification)) {
    cluster_uncertainty <- tapply(
      analysis_data$uncertainty,
      analysis_data$classification,
      mean,
      na.rm = TRUE
    )
  }

  # Format each cluster
  for (k in seq_len(analysis_data$n_clusters)) {
    cluster_name <- analysis_data$cluster_names[k]

    # Header with size
    cluster_text <- paste0(
      cluster_text,
      cluster_name, " (",
      round(cluster_sizes[k] * 100, 1), "% of observations)\n"
    )

    # Add uncertainty if available and weighting is enabled
    if (analysis_data$weight_by_uncertainty && !is.null(cluster_uncertainty)) {
      cluster_text <- paste0(
        cluster_text,
        "  Average uncertainty: ",
        round(cluster_uncertainty[k], 3), "\n"
      )
    }

    # Add means for each variable
    cluster_text <- paste0(cluster_text, "  Variable means:\n")

    # Get means for this cluster
    cluster_means <- analysis_data$means[, k]

    # Determine which variables to show
    if (!is.null(analysis_data$profile_variables)) {
      # Only show profile variables
      vars_to_show <- which(analysis_data$variable_names %in% analysis_data$profile_variables)
    } else {
      vars_to_show <- seq_along(cluster_means)
    }

    # Format means
    for (v in vars_to_show) {
      var_name <- analysis_data$variable_names[v]
      mean_val <- cluster_means[v]

      cluster_text <- paste0(
        cluster_text,
        "    ", var_name, ": ", round(mean_val, 3)
      )

      # Add interpretation hint for extreme values
      if (abs(mean_val) > 2) {
        cluster_text <- paste0(cluster_text, " (high)")
      } else if (abs(mean_val) > 1) {
        cluster_text <- paste0(cluster_text, " (moderate)")
      } else if (abs(mean_val) < -2) {
        cluster_text <- paste0(cluster_text, " (very low)")
      } else if (abs(mean_val) < -1) {
        cluster_text <- paste0(cluster_text, " (low)")
      }

      cluster_text <- paste0(cluster_text, "\n")
    }

    # Add within-cluster correlations if covariance matrices available
    if (!is.null(analysis_data$covariances)) {
      cluster_text <- paste0(cluster_text, "  Within-cluster correlations:\n")

      # Get covariance matrix for this cluster
      cov_matrix <- analysis_data$covariances[, , k]

      # Set variable names if available
      if (!is.null(analysis_data$variable_names)) {
        rownames(cov_matrix) <- analysis_data$variable_names
        colnames(cov_matrix) <- analysis_data$variable_names
      }

      # Convert to correlation matrix (using utility function)
      cor_matrix <- cov2cor_safe(cov_matrix)

      # Filter to profile variables if specified
      vars_to_use <- if (!is.null(analysis_data$profile_variables)) {
        analysis_data$variable_names[analysis_data$variable_names %in% analysis_data$profile_variables]
      } else {
        analysis_data$variable_names
      }

      # Format and add correlations (using utility function)
      cor_text <- format_cluster_correlations(
        cor_matrix,
        vars_to_use,
        min_correlation = 0.3
      )
      cluster_text <- paste0(cluster_text, cor_text)
    }

    cluster_text <- paste0(cluster_text, "\n")
  }

  # Add separation information if multiple clusters
  if (analysis_data$n_clusters > 1) {
    cluster_text <- paste0(
      cluster_text,
      "**Note**: Values represent standardized means. ",
      "Focus on variables with the largest differences between clusters.\n"
    )
  }

  return(cluster_text)
}

#' Build Output Instructions for GM Prompt
#'
#' Generates JSON format instructions and requirements for the LLM response,
#' including cluster name requirements and interpretation guidelines.
#'
#' @param analysis_data Standardized GM analysis data (list with n_clusters,
#'   cluster_names, weight_by_uncertainty, and uncertainty elements)
#' @param word_limit Integer. Maximum words per cluster interpretation (instructions
#'   suggest 80-100% usage of this limit)
#' @return Character string with JSON format example and output requirements
#' @keywords internal
build_output_instructions_gm <- function(analysis_data, word_limit) {
  # Build JSON structure example with name and interpretation (matching FA pattern)
  instructions <- paste0(
    "# OUTPUT FORMAT\n",
    "Respond with ONLY valid JSON using cluster names as object keys:\n\n",
    "```json\n",
    "{\n"
  )

  # Add example for each cluster using actual cluster names as keys
  for (k in seq_len(analysis_data$n_clusters)) {
    instructions <- paste0(
      instructions,
      '  "',
      analysis_data$cluster_names[k],
      '": {\n',
      '    "name": "Generate name",\n',
      '    "interpretation": "Generate interpretation"\n',
      '  }'
    )
    if (k < analysis_data$n_clusters) {
      instructions <- paste0(instructions, ',\n')
    } else {
      instructions <- paste0(instructions, '\n')
    }
  }

  instructions <- paste0(
    instructions,
    "}\n",
    "```\n\n",
    "# CRITICAL REQUIREMENTS\n",
    "- Include ALL ", analysis_data$n_clusters, " clusters as object keys using their exact names: ",
    paste(analysis_data$cluster_names, collapse = ", "), "\n",
    "- Valid JSON syntax (proper quotes, commas, brackets)\n",
    "- No additional text before or after JSON\n",
    "- Cluster names: 2-4 words maximum\n",
    "- Cluster interpretations: target ", round(word_limit * 0.8), "-", word_limit,
    " words each (80%-100% of ", word_limit, " word limit)\n",
    "- Focus on what distinguishes each cluster from the others\n",
    "- Describe the profile in terms of psychological or behavioral characteristics\n",
    "- Be specific and concrete rather than vague or generic\n"
  )

  if (analysis_data$weight_by_uncertainty && !is.null(analysis_data$uncertainty)) {
    instructions <- paste0(
      instructions,
      "- Give more confidence to clusters with lower uncertainty\n"
    )
  }

  instructions <- paste0(
    instructions,
    "- Use the variable descriptions to inform meaningful interpretations\n"
  )

  return(instructions)
}
