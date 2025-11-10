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
#' @param fa_args FA configuration list
#' @param output_args Output configuration list
#' @param ... Additional arguments passed to model-specific function
#'
#' @return Interpretation object
#' @keywords internal
#' @noRd
handle_raw_data_interpret <- function(x, variable_info, model_type,
                                      chat_session, llm_args = NULL,
                                      fa_args = NULL, output_args = NULL, ...) {
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
    fa = {
      # Extract factor_cor_mat from dots if provided
      dots <- list(...)
      factor_cor_mat <- dots$factor_cor_mat

      # Call interpret_core with structured list
      interpret_core(
        fit_results = list(
          loadings = x,
          Phi = factor_cor_mat
        ),
        variable_info = variable_info,
        model_type = "fa",
        chat_session = chat_session,
        llm_args = llm_args,
        fa_args = fa_args,
        output_args = output_args,
        ...
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


#' Validate Factor Analysis List Structure
#'
#' Internal helper to validate and extract components from a structured list
#' for factor analysis. Used when fit_results is provided as a list instead of
#' a fitted model object.
#'
#' @param fit_results_list List with FA model components
#'
#' @return List with extracted components:
#'   - loadings: The loadings matrix (data.frame or matrix)
#'   - factor_cor_mat: The factor correlation matrix (NULL if not provided)
#'
#' @keywords internal
#' @noRd
validate_fa_list_structure <- function(fit_results_list) {

  # Check that loadings is present (required)
  if (!"loadings" %in% names(fit_results_list)) {
    cli::cli_abort(
      c(
        "{.var fit_results} list must contain a 'loadings' component",
        "x" = "Current components: {.field {names(fit_results_list)}}",
        "i" = "Minimum required structure: list(loadings = matrix(...))",
        "i" = "Optional components: factor_cor_mat"
      )
    )
  }

  # Extract loadings
  loadings <- fit_results_list$loadings

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
  if ("Phi" %in% names(fit_results_list)) {
    factor_cor_mat <- fit_results_list$Phi
  } else if ("factor_cor_mat" %in% names(fit_results_list)) {
    factor_cor_mat <- fit_results_list$factor_cor_mat
  }

  # Validate and convert factor_cor_mat if provided
  if (!is.null(factor_cor_mat)) {
    if (!is.matrix(factor_cor_mat) && !is.data.frame(factor_cor_mat)) {
      cli::cli_abort(
        c(
          "Factor correlation matrix must be a matrix or data.frame",
          "x" = "You provided: {.cls {class(factor_cor_mat)}}",
          "i" = "Use matrix() or data.frame() to create a proper correlation matrix"
        )
      )
    }

    # Convert data.frame to matrix if needed
    if (is.data.frame(factor_cor_mat)) {
      factor_cor_mat <- as.matrix(factor_cor_mat)
    }
  }

  # Warn about unrecognized components
  recognized_components <- c("loadings", "Phi", "factor_cor_mat")
  unrecognized <- setdiff(names(fit_results_list), recognized_components)

  if (length(unrecognized) > 0) {
    cli::cli_warn(
      c(
        "!" = "Unrecognized components in fit_results list will be ignored",
        "i" = "Unrecognized: {.field {unrecognized}}",
        "i" = "Recognized components: {.field {recognized_components}}",
        "i" = "Note: Use {.arg additional_info} parameter for contextual information, not fit_results list"
      )
    )
  }

  # Return extracted components
  list(
    loadings = loadings,
    factor_cor_mat = factor_cor_mat
  )
}

#' Normalize Token Count to Non-Negative Integer
#'
#' Ensures token counts are valid non-negative integers. Some LLM providers may
#' return negative values (e.g., due to caching) or NA. This function normalizes
#' such values to 0.
#'
#' @param x Numeric token count (may be negative or NA)
#'
#' @return Non-negative integer (0 if input is negative or NA)
#' @keywords internal
#' @noRd
normalize_token_count <- function(x) {
  if (is.na(x) || !is.numeric(x)) {
    return(0L)
  }
  max(0L, as.integer(x))
}

#' Calculate Variance Explained by a Factor
#'
#' Calculates the proportion of total variance explained by a factor based on
#' the sum of squared loadings. This is used in factor analysis to understand
#' how much of the data's variability each factor captures.
#'
#' @param loadings Numeric vector of factor loadings
#' @param n_variables Integer. Total number of variables (for proportion calculation)
#'
#' @return Numeric. Proportion of variance explained (0 to 1)
#' @keywords internal
#' @noRd
calculate_variance_explained <- function(loadings, n_variables) {
  sum(loadings^2) / n_variables
}
