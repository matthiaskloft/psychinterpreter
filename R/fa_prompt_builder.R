#' Factor Analysis Prompt Builders
#'
#' S3 methods for building system and user prompts specific to factor analysis.
#' These functions implement the prompt_builder S3 generics for FA.
#'
#' @name fa_prompts
#' @keywords internal
NULL

#' Build System Prompt for Factor Analysis
#'
#' Creates the expert psychometrician system prompt for FA interpretation.
#' This is the single source of truth for the FA system prompt, used by both
#' interpret_fa() and chat_session() to eliminate duplication.
#'
#' @param analysis_type Object with class "fa"
#' @param word_limit Integer. Word limit for interpretations
#' @param ... Additional arguments (unused)
#'
#' @return Character. System prompt text
#' @export
#' @keywords internal
build_system_prompt.fa <- function(analysis_type, word_limit = 100, ...) {
  paste0(
    "# ROLE\n",
    "You are an expert psychometrician specializing in exploratory factor analysis.\n\n",

    "# TASK\n",
    "Provide comprehensive factor analysis interpretation by: (1) identifying and naming meaningful constructs, (2) explaining factor composition and boundaries, and (3) analyzing relationships between factors.\n\n",

    "# KEY DEFINITIONS\n",
    "- **Loading**: Correlation coefficient (-1 to +1) between variable and factor\n",
    "- **Significant loading**: Loading with absolute value >= cutoff threshold\n",
    "- **Convergent validity**: Variables measuring similar constructs should load together; for two factors covering similar constructs, the correlation will be highly positive or negative\n",
    "- **Discriminant validity**: Factors should represent meaningfully distinct constructs; for two factors covering similar constructs, the correlation will be near zero\n",
    "- **Factor correlation**: Correlation between factors indicating relationship strength\n",
    "- **Factor interpretation**: Identifying underlying construct explaining variable relationships\n",
    "- **Variance explained**: Percentage of total data variance captured by each factor\n",
    "- **Emergency rule**: Use highest absolute loadings when none meet cutoff\n\n"
  )
}

#' Build User Prompt for Factor Analysis
#'
#' Constructs the complete user prompt containing factor loadings, variable
#' descriptions, and interpretation instructions. All FA-specific parameters
#' are extracted from analysis_data.
#'
#' @param analysis_type Object with class "fa"
#' @param analysis_data List containing:
#'   - loadings_df: Data frame with variables and factor loadings
#'   - factor_summaries: List of factor summary information
#'   - factor_cols: Character vector of factor column names
#'   - n_factors: Number of factors
#'   - n_variables: Number of variables
#'   - cutoff: Loading cutoff threshold
#'   - n_emergency: Number of top loadings to use if none exceed cutoff
#'   - hide_low_loadings: Whether to hide loadings below cutoff
#'   - factor_cor_mat: Factor correlation matrix (optional)
#' @param word_limit Integer. Word limit for interpretations
#' @param additional_info Character or NULL. Additional context
#' @param ... Additional arguments passed from generic, including variable_info
#'   (data frame with 'variable' and 'description' columns, required for FA)
#'
#' @return Character. User prompt text
#' @export
#' @keywords internal
build_main_prompt.fa <- function(analysis_type,
                                 analysis_data,
                                 word_limit,
                                 additional_info = NULL,
                                 ...) {
  # Extract parameters from ...
  dots <- list(...)
  variable_info <- dots$variable_info

  # Validate variable_info is provided (required for FA)
  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} is required for factor analysis",
        "i" = "Provide a data frame with 'variable' and 'description' columns"
      )
    )
  }

  # Extract FA-specific parameters from analysis_data
  factor_summaries <- analysis_data$factor_summaries
  factor_cols <- analysis_data$factor_cols
  n_factors <- analysis_data$n_factors

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
      "## Factor Naming\n",
      "- **Construct identification**: Identify the underlying construct each factor represents\n",
      "- **Name creation**: Create 2-4 word names capturing the essence of each factor\n",
      "- **Theoretical grounding**: Base names on domain knowledge and additional context\n\n",
      "## Factor Interpretation\n",
      "- **Convergent validity**: Explain why significantly loading variables belong together conceptually\n",
      "- **Loading patterns**: Examine both strong positive/negative loadings and notable weak loadings\n",
      "- **Construct meaning**: Describe what the factor measures and represents\n",
      "- **Factor Relationships**: Use correlation matrix and cross loadings to understand how factors relate to each other\n",
      "- **Discriminant validity**: Ensure factors represent meaningfully distinct constructs; explain how similar factors complement each other\n\n",
      "## Output Requirements\n",
      "- **Word target (Interpretation)**: Aim for ",
      round(word_limit * 0.8),
      "-",
      word_limit,
      " words per interpretation (80%-100% of limit)\n",
      "- **Writing style**: Be concise, precise, and domain-appropriate\n\n"
    )
  }

  # ============================================================================
  # SECTION 2: ADDITIONAL CONTEXT
  # ============================================================================
  if (!is.null(additional_info) && nchar(additional_info) > 0) {
    prompt <- paste0(prompt, "# ADDITIONAL CONTEXT\n", additional_info, "\n\n")
  }

  # ============================================================================
  # SECTION 3: VARIABLE DESCRIPTIONS
  # ============================================================================
  prompt <- paste0(prompt, build_variable_section_fa(variable_info), "\n")

  # ============================================================================
  # SECTION 4: FACTOR LOADINGS
  # ============================================================================
  prompt <- paste0(prompt, build_loadings_section_fa(analysis_data), "\n")

  # ============================================================================
  # SECTION 5: FACTOR CORRELATIONS (if provided)
  # ============================================================================
  if (!is.null(analysis_data$factor_cor_mat)) {
    prompt <- paste0(prompt, build_correlations_section_fa(analysis_data), "\n")
  }

  # ============================================================================
  # SECTION 6: OUTPUT FORMAT
  # ============================================================================
  prompt <- paste0(prompt, build_output_instructions_fa(analysis_data, word_limit))

  return(prompt)
}

#' Build Variable Section for FA Prompt
#'
#' Formats variable descriptions for inclusion in the FA interpretation prompt.
#'
#' @param variable_info Data frame with 'variable' and 'description' columns
#' @return Character string with formatted variable information
#' @keywords internal
build_variable_section_fa <- function(variable_info) {
  prompt <- "# VARIABLE DESCRIPTIONS\n"

  if (nrow(variable_info) > 0) {
    for (i in seq_len(min(nrow(variable_info), 1e3))) {
      var_desc <- ifelse(
        !is.na(variable_info$description[i]),
        variable_info$description[i],
        variable_info$variable[i]
      )
      prompt <- paste0(prompt, "- ", variable_info$variable[i], ": ", var_desc, "\n")
    }
  }

  return(prompt)
}

#' Build Loadings Section for FA Prompt
#'
#' Formats factor loadings and variance explained for the FA interpretation prompt.
#'
#' @param analysis_data List containing loadings_df, factor_cols, n_factors,
#'   cutoff, n_emergency, hide_low_loadings, and factor_summaries
#' @return Character string with formatted loadings and variance information
#' @keywords internal
build_loadings_section_fa <- function(analysis_data) {
  # Extract parameters
  loadings_df <- analysis_data$loadings_df
  factor_cols <- analysis_data$factor_cols
  n_factors <- analysis_data$n_factors
  cutoff <- analysis_data$cutoff
  n_emergency <- analysis_data$n_emergency
  hide_low_loadings <- analysis_data$hide_low_loadings
  factor_summaries <- analysis_data$factor_summaries

  prompt <- "# FACTOR LOADINGS\n"
  prompt <- paste0(
    prompt,
    "**Cutoff threshold**: ",
    cutoff,
    " (absolute value >=",
    cutoff,
    " considered significant)\n"
  )
  prompt <- paste0(
    prompt,
    "**Emergency rule**: Use top ",
    n_emergency,
    " variables if no significant loadings\n\n"
  )

  # Add each factor with compact vector format
  for (i in 1:n_factors) {
    factor_name <- factor_cols[i]

    # Build compact vector string for this factor
    loading_vector <- c()
    for (j in seq_len(nrow(loadings_df))) {
      var_name <- loadings_df$variable[j]
      loading_value <- loadings_df[[factor_name]][j]

      # Skip low loadings if hide_low_loadings is TRUE
      if (hide_low_loadings && abs(loading_value) < cutoff) {
        next
      }

      loading_val <- format_loading(loading_value)
      loading_vector <- c(loading_vector, paste0(var_name, "=", loading_val))
    }

    prompt <- paste0(
      prompt,
      factor_name,
      ": ",
      paste(loading_vector, collapse = " "),
      "\n"
    )
  }

  # Add variance explained
  prompt <- paste0(prompt, "\n**Variance Explained**: ")
  variance_entries <- c()
  for (i in 1:n_factors) {
    factor_name <- factor_cols[i]
    # Reuse pre-calculated variance from factor_summaries (no duplicate calculation)
    variance_explained <- factor_summaries[[factor_name]]$variance_explained
    variance_pct <- round(variance_explained * 100, 1)
    variance_entries <- c(variance_entries, paste0(factor_name, "=", variance_pct, "%"))
  }
  prompt <- paste0(prompt, paste(variance_entries, collapse = " "), "\n")

  return(prompt)
}

#' Build Correlations Section for FA Prompt
#'
#' Formats factor correlation matrix for the FA interpretation prompt.
#'
#' @param analysis_data List containing factor_cor_mat
#' @return Character string with formatted correlation information
#' @keywords internal
build_correlations_section_fa <- function(analysis_data) {
  factor_cor_mat <- analysis_data$factor_cor_mat

  prompt <- "# FACTOR CORRELATIONS\n"

  # Convert matrix to dataframe if needed and get factor names
  if (is.matrix(factor_cor_mat)) {
    cor_df <- as.data.frame(factor_cor_mat)
    cor_factors <- rownames(factor_cor_mat)
  } else {
    cor_df <- factor_cor_mat
    cor_factors <- rownames(cor_df)
  }

  # Add correlation matrix information in compact format
  prompt <- paste0(
    prompt,
    "Factor correlations help understand relationships between factors:\n"
  )
  for (i in seq_along(cor_factors)) {
    factor_name <- cor_factors[i]
    if (factor_name %in% names(cor_df)) {
      cor_vector <- c()
      for (j in seq_along(cor_factors)) {
        other_factor <- cor_factors[j]
        if (other_factor != factor_name &&
            other_factor %in% names(cor_df)) {
          cor_val <- round(cor_df[[other_factor]][i], 2)
          cor_formatted <- format_loading(cor_val, digits = 2)
          cor_vector <- c(cor_vector,
                          paste0(other_factor, "=", cor_formatted))
        }
      }
      if (length(cor_vector) > 0) {
        prompt <- paste0(
          prompt,
          factor_name,
          " with: ",
          paste(cor_vector, collapse = " "),
          "\n"
        )
      }
    }
  }

  return(prompt)
}

#' Build Output Instructions for FA Prompt
#'
#' Generates JSON format instructions and requirements for the LLM response.
#'
#' @param analysis_data List containing n_factors, factor_cols, n_emergency,
#'   and factor_summaries
#' @param word_limit Integer. Maximum words per factor interpretation
#' @return Character string with JSON format example and output requirements
#' @keywords internal
build_output_instructions_fa <- function(analysis_data, word_limit) {
  n_factors <- analysis_data$n_factors
  factor_cols <- analysis_data$factor_cols
  n_emergency <- analysis_data$n_emergency
  factor_summaries <- analysis_data$factor_summaries

  # Check for undefined factors (n_emergency = 0 case)
  undefined_factors <- c()
  for (i in 1:n_factors) {
    factor_name <- factor_cols[i]
    # Factor is undefined if it has no variables and emergency rule wasn't used
    if (nrow(factor_summaries[[factor_name]]$variables) == 0 &&
        n_emergency == 0 &&
        !isTRUE(factor_summaries[[factor_name]]$used_emergency_rule)) {
      undefined_factors <- c(undefined_factors, factor_name)
    }
  }

  prompt <- paste0(
    "# OUTPUT FORMAT\n",
    "Respond with ONLY valid JSON using factor names as object keys:\n\n",
    "```json\n",
    "{\n"
  )

  # Add example for each factor using actual factor names as keys
  for (i in 1:n_factors) {
    prompt <- paste0(
      prompt,
      '  "',
      factor_cols[i],
      '": {\n',
      '    "name": "Generate name",\n',
      '    "interpretation": "Generate interpretation"\n',
      '  }'
    )
    if (i < n_factors) {
      prompt <- paste0(prompt, ',\n')
    } else {
      prompt <- paste0(prompt, '\n')
    }
  }

  prompt_requirements <- paste0(
    "}\n",
    "```\n\n",
    "# CRITICAL REQUIREMENTS\n",
    "- Include ALL ",
    n_factors,
    " factors as object keys using their exact names: ",
    paste(factor_cols, collapse = ", "),
    "\n",
    "- Valid JSON syntax (proper quotes, commas, brackets)\n",
    "- No additional text before or after JSON\n",
    "- Factor names: 2-4 words maximum\n",
    "- Factor interpretations: target ",
    round(word_limit * 0.8),
    "-",
    word_limit,
    " words each (80%-100% of ",
    word_limit,
    " word limit)\n"
  )

  # Add emergency rule or undefined factor instructions
  if (n_emergency == 0) {
    prompt_requirements <- paste0(
      prompt_requirements,
      "- For factors with no significant loadings: respond with \"undefined\" for name and \"NA\" for interpretation\n"
    )
  } else {
    prompt_requirements <- paste0(
      prompt_requirements,
      "- Emergency rule: Use top ",
      n_emergency,
      " variables if no significant loadings\n"
    )
  }

  # Add undefined factors note if applicable
  if (length(undefined_factors) > 0) {
    prompt_requirements <- paste0(
      prompt_requirements,
      "- The following factors have no significant loadings and should receive \"undefined\" for name and \"NA\" for interpretation: ",
      paste(undefined_factors, collapse = ", "),
      "\n"
    )
  }

  prompt <- paste0(prompt, prompt_requirements)

  return(prompt)
}
