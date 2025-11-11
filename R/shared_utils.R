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
#' @param model_type Character or NULL. Determined from chat_session if NULL
#' @param chat_session chat_session object or NULL
#' @param llm_args LLM configuration list
#' @param interpretation_args Model-specific interpretation configuration list
#' @param output_args Output configuration list
#' @param ... Additional arguments passed to model-specific function
#'
#' @return Interpretation object
#' @keywords internal
#' @noRd
handle_raw_data_interpret <- function(x, model_type,
                                      chat_session, llm_args = NULL,
                                      interpretation_args = NULL,
                                      output_args = NULL, ...) {
  # Determine effective model_type
  effective_model_type <- if (!is.null(chat_session)) {
    chat_session$model_type
  } else {
    model_type
  }

  # Validate model_type
  validate_model_type(effective_model_type)

  # Route to model-specific function
  switch(effective_model_type,
    fa = {
      # Extract factor_cor_mat from dots if provided
      dots <- list(...)
      factor_cor_mat <- dots$factor_cor_mat

      # Call interpret_core with structured list
      # Note: variable_info passed through ... to interpret_core
      interpret_core(
        fit_results = list(
          loadings = x,
          factor_cor_mat = factor_cor_mat
        ),
        model_type = "fa",
        chat_session = chat_session,
        llm_args = llm_args,
        interpretation_args = interpretation_args,
        output_args = output_args,
        ...  # Includes variable_info
      )
    },
    gm = cli::cli_abort(
      c(
        "Gaussian Mixture (gm) interpretation not yet implemented",
        "i" = "Currently only 'fa' (factor analysis) is supported"
      )
    ),
    irt = cli::cli_abort(
      c(
        "IRT interpretation not yet implemented",
        "i" = "Currently only 'fa' (factor analysis) is supported"
      )
    ),
    cdm = cli::cli_abort(
      c(
        "CDM interpretation not yet implemented",
        "i" = "Currently only 'fa' (factor analysis) is supported"
      )
    ),
    cli::cli_abort("Unsupported model_type: {effective_model_type}")
  )
}


#' Validate Chat Session Model Type Consistency
#'
#' Internal helper to ensure chat_session model_type matches expected type.
#' Used by model-specific interpret() methods (e.g., interpret_model.fa()).
#'
#' @param chat_session chat_session object or NULL
#' @param expected_type Character. Expected model type (e.g., "fa")
#'
#' @return NULL (invisibly) if validation passes, errors otherwise
#' @keywords internal
#' @noRd
validate_chat_session_for_model_type <- function(chat_session, expected_type) {
  if (!is.null(chat_session)) {
    if (!is.chat_session(chat_session)) {
      cli::cli_abort(
        c(
          "{.var chat_session} must be a chat_session object",
          "i" = "Create one with chat_session(model_type, provider, model)"
        )
      )
    }

    if (chat_session$model_type != expected_type) {
      cli::cli_abort(
        c(
          "Chat session model_type mismatch",
          "x" = paste0(
            "chat_session has model_type '", chat_session$model_type, "' ",
            "but expected '", expected_type, "'"
          ),
          "i" = paste0(
            "Create a new chat_session with model_type = '", expected_type, "'"
          )
        )
      )
    }
  }

  invisible(NULL)
}


