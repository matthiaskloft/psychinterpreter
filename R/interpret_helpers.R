# ==============================================================================
# HELPER FUNCTIONS FOR INTERPRET() DISPATCH SYSTEM
# ==============================================================================

#' Validate interpret() Arguments
#'
#' Internal validation helper for the interpret() dispatch system.
#' Ensures consistent behavior across all interpret() methods.
#'
#' @param x First argument to interpret() (model, data, or chat_session)
#' @param variable_info Variable descriptions dataframe
#' @param model_type Character or NULL. Explicit model type specification
#' @param chat_session chat_session object or NULL
#'
#' @return NULL (invisibly) if validation passes, errors otherwise
#' @keywords internal
#' @noRd
validate_interpret_args <- function(x, variable_info, model_type, chat_session) {

  # 1. Check chat_session validity
  if (!is.null(chat_session)) {
    if (!is.chat_session(chat_session)) {
      cli::cli_abort(
        c(
          "{.var chat_session} must be a chat_session object",
          "i" = "Create one with chat_session(model_type, provider, model)"
        )
      )
    }

    # If model_type also provided, check consistency
    if (!is.null(model_type) && chat_session$model_type != model_type) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "model_type '", model_type, "' conflicts with ",
            "chat_session model_type '", chat_session$model_type, "'"
          ),
          "i" = paste0(
            "Using chat_session model_type: '", chat_session$model_type, "'"
          )
        )
      )
    }
  }

  # 2. Don't validate variable_info structure here
  # Let interpret.default() handle it contextually:
  # - For raw data interpretation: validate structure
  # - For unsupported objects: let it error with "No method available"

  invisible(NULL)
}


#' Route Raw Data to Model-Specific Interpretation
#'
#' Internal routing helper that dispatches raw data to the appropriate
#' model-specific interpretation function.
#'
#' @param x Raw data (loadings, parameters, etc.)
#' @param variable_info Variable descriptions dataframe
#' @param model_type Character or NULL. Determined from chat_session if NULL
#' @param chat_session chat_session object or NULL
#' @param ... Additional arguments passed to model-specific function
#'
#' @return Interpretation object
#' @keywords internal
#' @noRd
handle_raw_data_interpret <- function(x, variable_info, model_type,
                                      chat_session, ...) {
  # Determine effective model_type
  effective_model_type <- if (!is.null(chat_session)) {
    chat_session$model_type
  } else {
    model_type
  }

  # Validate model_type
  valid_types <- c("fa", "gm", "irt", "cdm")
  if (!effective_model_type %in% valid_types) {
    cli::cli_abort(
      c(
        "Invalid or unsupported model_type: {.val {effective_model_type}}",
        "i" = "Valid types: {.val {valid_types}}",
        "i" = "Only 'fa' is currently implemented"
      )
    )
  }

  # Route to model-specific function
  switch(effective_model_type,
    fa = interpret_fa(x, variable_info, chat_session = chat_session, ...),
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
#' Used by model-specific interpret() methods (e.g., interpret.fa()).
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
