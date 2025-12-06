#' Label Prompt Builder Framework
#'
#' S3 methods for building prompts for variable labeling tasks.
#'
#' @name label_prompt_builder
#' @keywords internal
NULL

#' Build System Prompt for Variable Labeling
#'
#' @param analysis_type S3 dispatch object with class "label"
#' @param word_limit Integer. Unused for labeling (compatibility with generic)
#' @param ... Additional arguments including label_type, style_hint
#'
#' @return Character. System prompt for labeling task
#' @export
#' @keywords internal
build_system_prompt.label <- function(analysis_type, word_limit = NULL, ...) {

  # Extract label-specific parameters from ...
  dots <- list(...)
  label_type <- dots$label_type %||% "short"
  style_hint <- dots$style_hint
  max_chars <- dots$max_chars

  # Define label type instructions
  label_instructions <- switch(label_type,
    "short" = "Create concise labels using 1-3 words that capture the essential meaning.",
    "phrase" = "Create descriptive phrases using 4-7 words that clearly explain the variable.",
    "acronym" = {
      # Use max_chars if provided, otherwise default to 5
      max_len <- if (!is.null(max_chars)) max_chars else 5
      paste0("Create acronyms or abbreviations of 3-", max_len, " characters.")
    },
    "custom" = "Create labels based on the specific instructions provided.",
    "Create appropriate labels for each variable."  # default
  )

  # Add style hint if provided
  style_guidance <- if (!is.null(style_hint)) {
    paste0("\n- **Style**: Use ", style_hint, " terminology and phrasing")
  } else {
    ""
  }

  # Add few-shot examples based on label_type (improves consistency)
  examples_section <- switch(label_type,
    "short" = paste0(
      "# EXAMPLES\n",
      "Description: \"How satisfied are you with your current job overall?\"\n",
      "Label: \"Job Satisfaction\"\n\n",
      "Description: \"Total number of years of formal education completed\"\n",
      "Label: \"Education Years\"\n\n"
    ),
    "phrase" = paste0(
      "# EXAMPLES\n",
      "Description: \"How satisfied are you with your current job overall?\"\n",
      "Label: \"Overall Job Satisfaction Rating\"\n\n",
      "Description: \"Total number of years of formal education completed\"\n",
      "Label: \"Years of Formal Education Completed\"\n\n"
    ),
    "acronym" = paste0(
      "# EXAMPLES\n",
      "Description: \"Body Mass Index calculated from height and weight\"\n",
      "Label: \"BMI\"\n\n",
      "Description: \"Socioeconomic Status composite score\"\n",
      "Label: \"SES\"\n\n"
    ),
    ""
  )

  # Build complete system prompt
  prompt <- paste0(
    "# ROLE\n",
    "You are a research data analyst specializing in variable labeling for statistical ",
    "analysis and reporting. You create clear, consistent labels that follow research ",
    "data management conventions.\n\n",

    "# TASK\n",
    label_instructions, "\n\n",

    "# KEY PRINCIPLES\n",
    "- **Consistency**: Use identical formatting style across all labels\n",
    "- **Clarity**: Labels should be unambiguous and self-explanatory\n",
    "- **Conciseness**: Capture essential meaning with minimal words\n",
    "- **Standard terminology**: Use established terms from the domain when applicable\n",
    "- **No special characters**: Avoid punctuation except hyphens or underscores if needed",
    style_guidance, "\n\n",

    examples_section
  )

  return(prompt)
}

#' Build User Prompt for Variable Labeling
#'
#' @param analysis_type S3 dispatch object with class "label"
#' @param analysis_data Unused for labeling (compatibility with generic)
#' @param word_limit Integer. Unused for labeling (compatibility with generic)
#' @param additional_info Character or NULL. Unused for labeling (compatibility with generic)
#' @param ... Additional arguments including variable_info, label_type, max_words
#'
#' @return Character. User prompt containing variables to label
#' @export
#' @keywords internal
build_main_prompt.label <- function(analysis_type, analysis_data = NULL, word_limit = NULL,
                                     additional_info = NULL, ...) {

  # Extract label-specific parameters from ...
  dots <- list(...)
  variable_info <- dots$variable_info
  label_type <- dots$label_type %||% "short"
  max_words <- dots$max_words
  max_chars <- dots$max_chars

  # Validate input
  if (!is.data.frame(variable_info)) {
    cli::cli_abort("variable_info must be a data frame")
  }

  # Note: By the time we reach this function, variable_info should always have
  # both columns because label_variables() auto-generates variable names if needed
  if (!all(c("variable", "description") %in% names(variable_info))) {
    cli::cli_abort("variable_info must contain 'variable' and 'description' columns")
  }

  # Determine word count instruction
  # Note: max_words is ignored for acronyms (they use max_chars instead)
  word_instruction <- if (!is.null(max_words) && label_type != "acronym") {
    paste0(" (up to ", max_words, " word", ifelse(max_words == 1, "", "s"), ")")
  } else {
    switch(label_type,
      "short" = " (1-3 words)",
      "phrase" = " (4-7 words)",
      "acronym" = {
        # Use max_chars if provided, otherwise default to 5
        max_len <- if (!is.null(max_chars)) max_chars else 5
        paste0(" (3-", max_len, " characters)")
      },
      ""
    )
  }

  # Format variable list
  variable_list <- paste(
    mapply(function(var, desc) {
      paste0("- ", var, ": \"", desc, "\"")
    }, variable_info$variable, variable_info$description),
    collapse = "\n"
  )

  # Build prompt with structured sections
  prompt <- paste0(
    "# VARIABLES TO LABEL\n",
    "Create ", label_type, " labels", word_instruction, " for:\n\n",
    variable_list, "\n\n",

    "# OUTPUT FORMAT\n",
    "Return a JSON array:\n",
    "```json\n",
    '[{"variable": "var_name", "label": "Your Label"}]\n',
    "```\n\n",

    "# REQUIREMENTS\n",
    "- Include ALL ", nrow(variable_info), " variables\n",
    "- Use exact variable names from the list above\n",
    "- Valid JSON syntax (no trailing commas)\n",
    "- No additional text outside the JSON array\n"
  )

  return(prompt)
}