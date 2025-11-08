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


#' Validate Factor Analysis List Structure
#'
#' Internal helper to validate and extract components from a structured list
#' for factor analysis. Used when model_fit is provided as a list instead of
#' a fitted model object or raw matrix.
#'
#' @param model_fit_list List with FA model components
#'
#' @return List with extracted components:
#'   - loadings: The loadings matrix (data.frame or matrix)
#'   - factor_cor_mat: The factor correlation matrix (NULL if not provided)
#'
#' @keywords internal
#' @noRd
validate_fa_list_structure <- function(model_fit_list) {

  # Check that loadings is present (required)
  if (!"loadings" %in% names(model_fit_list)) {
    cli::cli_abort(
      c(
        "{.var model_fit} list must contain a 'loadings' component",
        "x" = "Current components: {.field {names(model_fit_list)}}",
        "i" = "Minimum required structure: list(loadings = matrix(...))",
        "i" = "Optional components: factor_cor_mat"
      )
    )
  }

  # Extract loadings
  loadings <- model_fit_list$loadings

  # Validate loadings is a matrix or data.frame
  if (!is.matrix(loadings) && !is.data.frame(loadings)) {
    cli::cli_abort(
      c(
        "{.var loadings} component must be a matrix or data.frame",
        "x" = "You provided: {.cls {class(loadings)}}",
        "i" = "Convert to matrix or data.frame before passing to interpret()"
      )
    )
  }

  # Extract factor correlation matrix (optional, check both names)
  factor_cor_mat <- NULL
  if ("Phi" %in% names(model_fit_list)) {
    factor_cor_mat <- model_fit_list$Phi
  } else if ("factor_cor_mat" %in% names(model_fit_list)) {
    factor_cor_mat <- model_fit_list$factor_cor_mat
  }

  # Validate factor_cor_mat if provided
  if (!is.null(factor_cor_mat)) {
    if (!is.matrix(factor_cor_mat)) {
      cli::cli_abort(
        c(
          "Factor correlation matrix must be a matrix",
          "x" = "You provided: {.cls {class(factor_cor_mat)}}",
          "i" = "Use matrix() to create a proper correlation matrix"
        )
      )
    }
  }

  # Warn about unrecognized components
  recognized_components <- c("loadings", "Phi", "factor_cor_mat")
  unrecognized <- setdiff(names(model_fit_list), recognized_components)

  if (length(unrecognized) > 0) {
    cli::cli_warn(
      c(
        "!" = "Unrecognized components in model_fit list will be ignored",
        "i" = "Unrecognized: {.field {unrecognized}}",
        "i" = "Recognized components: {.field {recognized_components}}",
        "i" = "Note: Use {.arg additional_info} parameter for contextual information, not model_fit list"
      )
    )
  }

  # Return extracted components
  list(
    loadings = loadings,
    factor_cor_mat = factor_cor_mat
  )
}
