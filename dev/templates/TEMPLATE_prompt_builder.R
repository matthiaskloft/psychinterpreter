# Template for {MODEL}_prompt_builder.R
# Replace all instances of {MODEL}, {model}, {COMPONENT}, etc. with your values
#
# Example replacements for Gaussian Mixture:
#   {MODEL} -> Gaussian Mixture
#   {MODEL_FULL_NAME} -> Gaussian mixture modeling
#   {model} -> gm
#   {COMPONENT} -> Cluster
#   {COMPONENT_LOWER} -> cluster
#   {DATA_TYPE} -> cluster statistics
#   {AMBIGUOUS_CONDITION} -> no clear cluster separation

#' Build system prompt for {MODEL} interpretation
#'
#' Creates the LLM system prompt that defines the expert persona and interpretation
#' guidelines for {MODEL} analysis.
#'
#' @param analysis_type Analysis type identifier (should be "{model}")
#' @param ... Additional arguments (ignored)
#'
#' @return Character string with system prompt
#' @export
#'
#' @examples
#' prompt <- build_system_prompt("{model}")
#' cat(prompt)
build_system_prompt.{model} <- function(analysis_type, ...) {

  # Pattern from fa_prompt_builder.R:23-41

  # Define expert persona and guidelines
  paste0(
    "You are an expert in {MODEL_FULL_NAME} and psychological measurement.\n\n",

    "Your task is to interpret {MODEL} results by analyzing {DATA_TYPE} ",
    "and variable descriptions.\n\n",

    "Guidelines:\n",
    "1. Base interpretations ONLY on the provided {DATA_TYPE} and variable descriptions\n",
    "2. Identify meaningful patterns in the data that distinguish each {COMPONENT_LOWER}\n",
    "3. Provide clear, concise labels for each {COMPONENT_LOWER}\n",
    "4. Focus on psychological/theoretical constructs, not statistical jargon\n",
    "5. If a {COMPONENT_LOWER} has {AMBIGUOUS_CONDITION}, label it as 'Undefined' or use emergency rules\n",
    "6. Ensure {COMPONENT_LOWER} labels are distinct and theoretically meaningful\n",
    "7. Avoid redundant or overlapping interpretations across {COMPONENT_LOWER}s\n",
    "8. Use professional, scientific language\n",
    "9. Respond ONLY with valid JSON matching the exact format specified\n",
    "10. Do not include explanations, preambles, or additional text outside the JSON structure\n"
  )
}


#' Build main user prompt for {MODEL} interpretation
#'
#' Formats {MODEL} data into a structured user prompt for LLM interpretation,
#' including variable descriptions, {DATA_TYPE}, and output format specifications.
#'
#' @param analysis_type Analysis type identifier (should be "{model}")
#' @param analysis_data Analysis data from build_analysis_data.{CLASS}() containing {DATA_TYPE}
#' @param word_limit Maximum words per {COMPONENT_LOWER} interpretation (default: 150)
#' @param additional_info Optional additional context string
#' @param ... Additional arguments including variable_info (required)
#'
#' @return Character string with formatted user prompt
#' @export
#'
#' @examples
#' \dontrun{
#' analysis_data <- build_analysis_data(fit, var_info, analysis_type = "{model}")
#' prompt <- build_main_prompt(
#'   "{model}",
#'   analysis_data,
#'   word_limit = 100,
#'   variable_info = var_info
#' )
#' cat(prompt)
#' }
build_main_prompt.{model} <- function(analysis_type,
                                       analysis_data,
                                       word_limit = 150,
                                       additional_info = NULL,
                                       ...) {

  # Pattern from fa_prompt_builder.R:68-341

  # ============================================================================
  # Extract variable_info from ... (required for prompts)
  # ============================================================================

  dots <- list(...)
  variable_info <- dots$variable_info

  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.arg variable_info} is required for {MODEL} prompts",
        "i" = "Pass variable_info as an argument to interpret() or build_main_prompt()"
      )
    )
  }

  # ============================================================================
  # Extract data from analysis_data
  # ============================================================================

  data_field1 <- analysis_data$data_field1  # TODO: Replace with actual field name
  data_field2 <- analysis_data$data_field2  # TODO: Replace with actual field name
  n_components <- analysis_data$n_components

  # Extract model-specific parameters from analysis_data if needed
  {PARAM1} <- analysis_data${PARAM1}  # TODO: Optional - only if needed in prompt
  {PARAM2} <- analysis_data${PARAM2}  # TODO: Optional - only if needed in prompt

  # Generate component identifiers (e.g., "Cluster_1", "Factor_1", "Item_1")
  component_ids <- paste0("{COMPONENT}_", seq_len(n_components))


  # ============================================================================
  # SECTION 1: Context and task description
  # ============================================================================

  # Pattern from fa_prompt_builder.R:78-93

  context <- paste0(
    "Please interpret the following {MODEL} results.\n\n",
    "You have ", n_components, " {COMPONENT_LOWER}s to interpret.\n\n"
  )

  # Add additional_info if provided
  if (!is.null(additional_info) && nchar(additional_info) > 0) {
    context <- paste0(
      context,
      "Additional context:\n",
      additional_info, "\n\n"
    )
  }


  # ============================================================================
  # SECTION 2: Variable descriptions
  # ============================================================================

  # Pattern from fa_prompt_builder.R:95-106

  var_section <- "Variables:\n"

  for (i in seq_len(nrow(variable_info))) {
    var_section <- paste0(
      var_section,
      "- ", variable_info$variable[i], ": ",
      variable_info$description[i], "\n"
    )
  }

  var_section <- paste0(var_section, "\n")


  # ============================================================================
  # SECTION 3: Model-specific data
  # ============================================================================

  # THIS IS MODEL-SPECIFIC - format your data appropriately for LLM readability

  data_section <- "{MODEL} Results:\n\n"

  # Example for Gaussian Mixture: Format cluster means and covariances
  # for (k in 1:n_components) {
  #   data_section <- paste0(
  #     data_section,
  #     "Cluster ", k, ":\n",
  #     "  Mean values:\n"
  #   )
  #
  #   # Add mean values for each variable
  #   for (v in 1:length(variable_info$variable)) {
  #     data_section <- paste0(
  #       data_section,
  #       "    ", variable_info$variable[v], ": ",
  #       sprintf("%.3f", means[v, k]), "\n"
  #     )
  #   }
  #
  #   # Add cluster size/probability
  #   data_section <- paste0(
  #     data_section,
  #     "  Cluster probability: ", sprintf("%.3f", cluster_probs[k]), "\n\n"
  #   )
  # }

  # Example for IRT: Format item parameters
  # data_section <- paste0(data_section, "Item Parameters:\n\n")
  # data_section <- paste0(data_section, format_item_table(item_params), "\n")

  # Example for FA: Format loadings table
  # data_section <- paste0(data_section, format_loadings_table(loadings_df, cutoff), "\n")

  # TODO: Replace with your model-specific data formatting
  # Use helper functions (see bottom of file) for complex formatting

  # Placeholder - REPLACE THIS
  data_section <- paste0(
    data_section,
    "TODO: Format your {MODEL} data here\n\n",
    "Examples:\n",
    "- For GM: Show means, covariances, cluster probabilities\n",
    "- For IRT: Show item parameters (discrimination, difficulty, guessing)\n",
    "- For CDM: Show Q-matrix, item-attribute relationships\n\n"
  )


  # ============================================================================
  # SECTION 4: Output format specification
  # ============================================================================

  # Pattern from fa_prompt_builder.R:297-341

  # Create example JSON with component identifiers
  example_keys <- component_ids[1:min(3, n_components)]  # Show first 3 as examples

  output_format <- paste0(
    "Provide your interpretation as a JSON object with this EXACT structure:\n\n",
    "{\n"
  )

  # Add example keys
  for (i in seq_along(example_keys)) {
    output_format <- paste0(
      output_format,
      '  "', example_keys[i], '": "Brief interpretation here (max ', word_limit, ' words)"'
    )
    if (i < length(example_keys)) {
      output_format <- paste0(output_format, ",\n")
    } else if (n_components > 3) {
      output_format <- paste0(output_format, ",\n  ...\n")
    } else {
      output_format <- paste0(output_format, "\n")
    }
  }

  output_format <- paste0(
    output_format,
    "}\n\n",
    "Requirements:\n",
    "- Use ONLY these {COMPONENT_LOWER} identifiers as keys: ",
    paste(component_ids, collapse = ", "), "\n",
    "- Keep each interpretation under ", word_limit, " words\n",
    "- Base interpretations solely on the provided {DATA_TYPE} and variable descriptions\n",
    "- Focus on what makes each {COMPONENT_LOWER} distinct\n",
    "- Use clear, professional language suitable for scientific reporting\n",
    "- Respond with valid JSON only - no additional text, preambles, or explanations\n"
  )


  # ============================================================================
  # Combine all sections
  # ============================================================================

  paste0(context, var_section, data_section, output_format)
}


# ==============================================================================
# Helper Functions for Data Formatting
# ==============================================================================

# Add helper functions for formatting complex data structures
# Keep functions focused and reusable

# Example helper for formatting a table:
# #' Format {DATA_TYPE} as text table
# #'
# #' @param data Matrix or data frame to format
# #' @param ... Additional formatting parameters
# #'
# #' @keywords internal
# #' @noRd
# format_{data_type}_table <- function(data, ...) {
#   # Create formatted table string
#   # Use sprintf() for aligned columns
#   # Return character string
# }


# Example helper for formatting statistics:
# #' Format {COMPONENT_LOWER} statistics
# #'
# #' @param stats Vector of statistics
# #' @param variable_names Variable names
# #'
# #' @keywords internal
# #' @noRd
# format_{component}_stats <- function(stats, variable_names) {
#   # Create formatted statistics string
#   # Return character string
# }


# TODO: Add your model-specific formatting helpers here
