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
#' @param analysis_type An S3 dispatch object with class corresponding to the model type
#'   ("fa", "gm", "irt", "cdm"). Typically created as \code{structure(list(), class = "fa")}.
#'   See \code{?interpret} for supported model types.
#' @param word_limit Integer. Maximum words per interpretation (used in prompt instructions)
#' @param ... Additional arguments passed to model-specific methods (currently unused)
#'
#' @return Character. System prompt text defining LLM's role and interpretation guidelines
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
#' @param analysis_type An S3 dispatch object with class corresponding to the model type
#'   ("fa", "gm", "irt", "cdm"). See \code{?interpret} for supported model types.
#' @param analysis_data List. Standardized model data from \code{\link{build_analysis_data}}.
#'   Structure varies by model type and contains all necessary information for prompt construction.
#' @param word_limit Integer. Maximum words per interpretation (included in prompt instructions)
#' @param additional_info Character or NULL. Optional additional context to include in prompt
#' @param ... Additional arguments passed to model-specific methods, including:
#'   - \code{variable_info}: Data frame with 'variable' and 'description' columns (required by most model types)
#'   - Model-specific parameters as needed
#'
#' @return Character. User prompt text containing analysis data and interpretation instructions
#' @export
#' @keywords internal
build_main_prompt <- function(analysis_type, analysis_data, word_limit, additional_info = NULL, ...) {
  UseMethod("build_main_prompt")
}

#' Default method for build_system_prompt
#'
#' Throws an error when no model-specific method is found. This ensures
#' all supported model types have explicit prompt builders.
#'
#' @param analysis_type S3 dispatch object
#' @param word_limit Integer. Maximum words per interpretation
#' @param ... Additional arguments (ignored)
#'
#' @return Does not return (throws error)
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
      "i" = "Currently implemented: fa, gm (irt and cdm planned)",
      "i" = "Implement build_system_prompt.{model_class}() in R/{model_class}_prompt_builder.R"
    )
  )
}

#' Default method for build_main_prompt
#'
#' Throws an error when no model-specific method is found. This ensures
#' all supported model types have explicit prompt builders.
#'
#' @param analysis_type S3 dispatch object
#' @param analysis_data List from build_analysis_data()
#' @param word_limit Integer. Maximum words per interpretation
#' @param additional_info Character or NULL. Optional context
#' @param ... Additional arguments (ignored)
#'
#' @return Does not return (throws error)
#' @export
#' @keywords internal
build_main_prompt.default <- function(analysis_type, analysis_data, word_limit, additional_info = NULL, ...) {
  # Get the class name
  model_class <- if (is.character(analysis_type)) {
    analysis_type
  } else {
    class(analysis_type)[1]
  }

  cli::cli_abort(
    c(
      "No user prompt builder for model type: {.val {model_class}}",
      "i" = "Currently implemented: fa, gm (irt and cdm planned)",
      "i" = "Implement build_main_prompt.{model_class}() in R/{model_class}_prompt_builder.R"
    )
  )
}
