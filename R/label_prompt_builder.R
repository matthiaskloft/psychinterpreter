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
    paste0("\nStyle guidance: Use ", style_hint, " terminology and phrasing.")
  } else {
    ""
  }

  # Build complete system prompt
  prompt <- paste0(
    "You are an expert at creating clear, concise variable labels from descriptions. ",
    "Your task is to generate appropriate labels that will be used in data analysis and reporting.\n\n",
    "Instructions:\n",
    "- ", label_instructions, "\n",
    "- Ensure labels are clear and unambiguous\n",
    "- Maintain consistency in style across all labels\n",
    "- Use standard terminology when applicable\n",
    "- Avoid special characters unless necessary",
    style_guidance, "\n\n",
    "Return your response as a JSON array with the following format:\n",
    '[{"variable": "variable_name", "label": "Generated Label"}, ...]'
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
  word_instruction <- if (!is.null(max_words)) {
    paste0(" (exactly ", max_words, " word", ifelse(max_words == 1, "", "s"), ")")
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

  # Build prompt
  prompt <- paste0(
    "Please create ", label_type, " labels", word_instruction, " for the following variables:\n\n",
    variable_list, "\n\n",
    "Remember to return the results as a JSON array with the format:\n",
    '[{"variable": "variable_name", "label": "Generated Label"}, ...]'
  )

  return(prompt)
}