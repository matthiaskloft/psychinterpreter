# ===================================================================
# FILE: gm_prompt_builder.R
# PURPOSE: Prompt construction for Gaussian Mixture Model interpretations
# ===================================================================

#' Build System Prompt for Gaussian Mixture Model Interpretation
#'
#' Creates the system prompt that defines the LLM's expertise and role
#' for interpreting clustering results.
#'
#' @param analysis_data Standardized GM analysis data
#' @return Character string containing the system prompt
#' @export
#' @keywords internal
build_system_prompt.gm <- function(analysis_data) {
  system_prompt <- paste0(
    "You are an expert in clustering analysis, Gaussian mixture models, ",
    "and psychological profiling. Your task is to interpret cluster profiles ",
    "based on the mean values of variables in each cluster.\n\n",

    "Guidelines for interpretation:\n",
    "1. Focus on the distinguishing characteristics of each cluster\n",
    "2. Identify psychological or behavioral patterns that define each group\n",
    "3. Use relative comparisons between clusters to highlight differences\n",
    "4. Describe what makes each cluster unique compared to others\n",
    "5. Avoid statistical jargon - use clear, accessible language\n",
    "6. Consider the practical significance of differences, not just numerical values\n",

    if (analysis_data$weight_by_uncertainty && !is.null(analysis_data$uncertainty)) {
      paste0(
        "7. Note that cluster assignments have varying certainty - ",
        "focus more on well-defined clusters\n"
      )
    } else {
      ""
    },

    "\nYou will receive:\n",
    "- Descriptions of the measured variables\n",
    "- Mean values for each variable in each cluster\n",
    "- Cluster sizes (proportion of observations)\n",

    if (!is.null(analysis_data$uncertainty)) {
      "- Average assignment uncertainty per cluster\n"
    } else {
      ""
    },

    "\nYour output should be a JSON object with keys 'Cluster_1', 'Cluster_2', etc., ",
    "where each value is a concise interpretation of that cluster's profile."
  )

  return(system_prompt)
}

#' Build Main Prompt for Gaussian Mixture Model Interpretation
#'
#' Constructs the user prompt containing cluster statistics and variable information.
#'
#' @param analysis_data Standardized GM analysis data
#' @param variable_info Data frame with variable descriptions
#' @param llm_args List of LLM configuration parameters
#' @return Character string containing the main prompt
#' @export
#' @keywords internal
build_main_prompt.gm <- function(analysis_data, variable_info, llm_args) {
  # Start building the prompt
  prompt_parts <- list()

  # Add context
  prompt_parts$context <- paste0(
    "Interpret the following ", analysis_data$n_clusters,
    " clusters from a Gaussian mixture model analysis with ",
    analysis_data$n_variables, " variables and ",
    analysis_data$n_observations, " observations.\n"
  )

  # Add model information
  if (!is.null(analysis_data$covariance_type)) {
    prompt_parts$model_info <- paste0(
      "Covariance structure: ", analysis_data$covariance_type, "\n"
    )
  }

  # Add variable descriptions
  prompt_parts$variables <- build_variable_section_gm(
    analysis_data, variable_info, llm_args
  )

  # Add cluster statistics
  prompt_parts$clusters <- build_cluster_section_gm(
    analysis_data, llm_args
  )

  # Add output instructions
  prompt_parts$instructions <- build_output_instructions_gm(
    analysis_data, llm_args$word_limit
  )

  # Add additional information if provided
  if (!is.null(llm_args$additional_info)) {
    prompt_parts$additional <- paste0(
      "\n\nAdditional context:\n",
      llm_args$additional_info
    )
  }

  # Combine all parts
  main_prompt <- paste(prompt_parts, collapse = "\n\n")

  return(main_prompt)
}

#' Build Variable Section for GM Prompt
#'
#' @param analysis_data Standardized GM analysis data
#' @param variable_info Data frame with variable descriptions
#' @param llm_args List of LLM configuration parameters
#' @return Character string with formatted variable information
#' @keywords internal
build_variable_section_gm <- function(analysis_data, variable_info, llm_args) {
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
  var_text <- "VARIABLE DESCRIPTIONS:\n"

  for (i in seq_len(nrow(variable_info))) {
    var_text <- paste0(
      var_text,
      variable_info$variable[i], ": ",
      variable_info$description[i], "\n"
    )
  }

  return(var_text)
}

#' Build Cluster Section for GM Prompt
#'
#' @param analysis_data Standardized GM analysis data
#' @param llm_args List of LLM configuration parameters
#' @return Character string with formatted cluster statistics
#' @keywords internal
build_cluster_section_gm <- function(analysis_data, llm_args) {
  cluster_text <- "CLUSTER PROFILES:\n\n"

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

    # Calculate z-scores if we have overall means
    z_scores <- NULL
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

    cluster_text <- paste0(cluster_text, "\n")
  }

  # Add separation information if multiple clusters
  if (analysis_data$n_clusters > 1) {
    cluster_text <- paste0(
      cluster_text,
      "Note: Values represent standardized means. ",
      "Focus on variables with the largest differences between clusters.\n"
    )
  }

  return(cluster_text)
}

#' Build Output Instructions for GM Prompt
#'
#' @param analysis_data Standardized GM analysis data
#' @param word_limit Maximum words per cluster interpretation
#' @return Character string with output format instructions
#' @keywords internal
build_output_instructions_gm <- function(analysis_data, word_limit) {
  # Build JSON structure example
  json_example <- "{\n"
  for (k in seq_len(min(2, analysis_data$n_clusters))) {
    cluster_name <- analysis_data$cluster_names[k]
    json_example <- paste0(
      json_example,
      '  "', cluster_name, '": "interpretation here"',
      ifelse(k < min(2, analysis_data$n_clusters), ",", ""),
      "\n"
    )
  }
  if (analysis_data$n_clusters > 2) {
    json_example <- paste0(json_example, "  ...\n")
  }
  json_example <- paste0(json_example, "}")

  instructions <- paste0(
    "OUTPUT INSTRUCTIONS:\n",
    "Provide interpretations as a JSON object with this structure:\n",
    json_example, "\n\n",
    "Requirements:\n",
    "- Each interpretation should be approximately ", word_limit, " words\n",
    "- Focus on what distinguishes each cluster from the others\n",
    "- Describe the profile in terms of psychological or behavioral characteristics\n",
    "- Be specific and concrete rather than vague or generic\n",

    if (analysis_data$weight_by_uncertainty && !is.null(analysis_data$uncertainty)) {
      "- Give more confidence to clusters with lower uncertainty\n"
    } else {
      ""
    },

    "- Use the variable descriptions to inform meaningful interpretations"
  )

  return(instructions)
}