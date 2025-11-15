#' Prompt Builder Framework
#'
#' S3 generic functions for building model-specific system and user prompts.
#' Model-specific implementations are located in R/models/\{analysis_type\}/prompt_\{analysis_type\}.R
#'
#' @name prompt_builder
#' @keywords internal
NULL

#' Build System Prompt (S3 Generic)
#'
#' Constructs the system prompt that defines the LLM's role and expertise
#' for a specific model type.
#'
#' @param analysis_type An object with class corresponding to the model type ("fa", "gm", "irt", "cdm")
#' @param word_limit Integer. Word limit for interpretations to include in prompt
#' @param ... Additional arguments passed to model-specific methods
#'
#' @return Character. System prompt text
#' @export
#' @keywords internal
build_system_prompt <- function(analysis_type, word_limit, ...) {
  UseMethod("build_system_prompt")
}

#' Build User Prompt (S3 Generic)
#'
#' Constructs the user prompt containing analysis data and instructions
#' for a specific model type.
#'
#' @param analysis_type An object with class corresponding to the model type ("fa", "gm", "irt", "cdm")
#' @param analysis_data List. Model-specific data (loadings, parameters, etc.)
#' @param ... Additional arguments passed to model-specific methods, including variable_info
#'   (data frame with 'variable' and 'description' columns, required for FA)
#'
#' @return Character. User prompt text
#' @export
#' @keywords internal
build_main_prompt <- function(analysis_type, analysis_data, ...) {
  UseMethod("build_main_prompt")
}

#' Default method for build_system_prompt
#'
#' @export
#' @keywords internal
build_system_prompt.default <- function(analysis_type, word_limit, ...) {
  # Get the class name
  model_class <- if (is.character(analysis_type)) {
    analysis_type
  } else {
    class(analysis_type)[1]
  }

  cli::cli_abort(
    c(
      "No system prompt builder for model type: {.val {model_class}}",
      "i" = "Available types: fa, gm, irt, cdm",
      "i" = "Implement build_system_prompt.{model_class}() in R/{model_class}_prompt_builder.R"
    )
  )
}

#' Default method for build_main_prompt
#'
#' @export
#' @keywords internal
build_main_prompt.default <- function(analysis_type, analysis_data, ...) {
  # Get the class name
  model_class <- if (is.character(analysis_type)) {
    analysis_type
  } else {
    class(analysis_type)[1]
  }

  cli::cli_abort(
    c(
      "No user prompt builder for model type: {.val {model_class}}",
      "i" = "Available types: fa, gm, irt, cdm",
      "i" = "Implement build_main_prompt.{model_class}() in R/{model_class}_prompt_builder.R"
    )
  )
}
