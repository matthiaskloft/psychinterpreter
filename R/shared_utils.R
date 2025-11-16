# ==============================================================================
# HELPER FUNCTIONS FOR INTERPRET() DISPATCH SYSTEM
# ==============================================================================

#' Route Structured List Data to Model-Specific Interpretation
#'
#' Internal routing helper that dispatches extracted loadings from structured
#' lists to the appropriate model-specific interpretation function.
#'
#' @param x Extracted loadings matrix/data.frame from structured list
#' @param variable_info Variable descriptions dataframe
#' @param analysis_type Character or NULL. Determined from chat_session if NULL
#' @param chat_session chat_session object or NULL
#' @param llm_args LLM configuration list
#' @param interpretation_args Model-specific interpretation configuration list
#' @param output_args Output configuration list
#' @param ... Additional arguments passed to model-specific function
#'
#' @return Interpretation object
#' @keywords internal
#' @noRd
handle_raw_data_interpret <- function(x, analysis_type,
                                      chat_session, llm_args = NULL,
                                      interpretation_args = NULL,
                                      output_args = NULL, ...) {
  # Determine effective analysis_type
  effective_analysis_type <- if (!is.null(chat_session)) {
    chat_session$analysis_type
  } else {
    analysis_type
  }

  # Validate analysis_type
  validate_analysis_type(effective_analysis_type)

  # Build structured list via S3 dispatch
  fit_results <- build_structured_list(
    x = x,
    analysis_type = effective_analysis_type,
    ...
  )

  # Call interpret_core with structured list
  interpret_core(
    fit_results = fit_results,
    analysis_type = effective_analysis_type,
    chat_session = chat_session,
    llm_args = llm_args,
    interpretation_args = interpretation_args,
    output_args = output_args,
    ...
  )
}


#' Validate Chat Session Model Type Consistency
#'
#' Internal helper to ensure chat_session analysis_type matches expected type.
#' Used by model-specific interpret() methods (e.g., interpret_model.fa()).
#'
#' @param chat_session chat_session object or NULL
#' @param expected_type Character. Expected model type (e.g., "fa")
#'
#' @return NULL (invisibly) if validation passes, errors otherwise
#' @keywords internal
#' @noRd
validate_chat_session_for_analysis_type <- function(chat_session, expected_type) {
  if (!is.null(chat_session)) {
    if (!is.chat_session(chat_session)) {
      cli::cli_abort(
        c(
          "{.var chat_session} must be a chat_session object",
          "i" = "Create one with chat_session(analysis_type, provider, model)"
        )
      )
    }

    if (chat_session$analysis_type != expected_type) {
      cli::cli_abort(
        c(
          "Chat session analysis_type mismatch",
          "x" = paste0(
            "chat_session has analysis_type '", chat_session$analysis_type, "' ",
            "but expected '", expected_type, "'"
          ),
          "i" = paste0(
            "Create a new chat_session with analysis_type = '", expected_type, "'"
          )
        )
      )
    }
  }

  invisible(NULL)
}


