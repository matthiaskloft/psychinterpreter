# ==============================================================================
# S3 METHODS FOR INTERPRETING FACTOR ANALYSIS RESULTS FROM COMMON PACKAGES
# ==============================================================================

#' Interpret Psychometric Analysis Results
#'
#' Unified interface for interpreting psychometric analysis results with LLMs.
#' Supports fitted model objects, structured lists, and persistent chat sessions
#' for efficient multi-analysis workflows.
#'
#' @param fit_results One of:
#'   - **Fitted model object**:
#'     - psych package: \code{fa()}, \code{principal()}
#'     - lavaan package: \code{cfa()}, \code{sem()}, \code{efa()}
#'     - mirt package: \code{mirt()}
#'   - **Structured list** with model components:
#'     - For FA: \code{list(loadings = matrix, factor_cor_mat = matrix)} or \code{list(loadings = matrix)}
#'       (both loadings and factor_cor_mat can be matrices or data.frames)
#'     - For GM: Not yet implemented
#'     - For IRT: Not yet implemented
#'     - For CDM: Not yet implemented
#' @param chat_session Optional. A chat_session object created with \code{\link{chat_session}}
#'   for token-efficient multi-analysis workflows (default = NULL).
#' @param model_type Character. Type of analysis ("fa", "gm", "irt", "cdm"). Required when using
#'   structured list without chat_session. Automatically inferred from chat_session if provided (default = NULL).
#'
#' @param provider Character. LLM provider (e.g., "openai", "anthropic", "ollama", "gemini").
#'   Required when chat_session is NULL. Top-level convenience parameter (default = NULL).
#' @param model Character. Specific model to use (e.g., "gpt-4o-mini", "claude-3-5-sonnet-20241022", "gemma2:9b").
#'   If NULL, uses provider default. Top-level convenience parameter (default = NULL).
#'
#' @param llm_args List or llm_args object. LLM configuration settings. Can be created with
#'   \code{\link{llm_args}} or passed as a plain list. Contains: system_prompt, params, word_limit,
#'   interpretation_guidelines, additional_info, echo. If provider/model are provided at top-level,
#'   they override values in llm_args (default = NULL).
#' @param interpretation_args List or interpretation_args object. Model-specific interpretation configuration.
#'   Can be created with \code{\link{interpretation_args}} or passed as a plain list. Contents vary by model type.
#'   For FA: cutoff, n_emergency, hide_low_loadings, sort_loadings, factor_cor_mat (default = NULL).
#' @param output_args List or output_args object. Output configuration settings. Can be created with
#'   \code{\link{output_args}} or passed as a plain list. Contains: format, heading_level,
#'   suppress_heading, max_line_length, silent (default = NULL).
#'
#' @param ... Additional arguments passed to model-specific methods. Model-specific methods may require:
#'   - \code{variable_info}: Data frame with 'variable' and 'description' columns (required for FA)
#'
#' @note While only \code{provider} and \code{model} are exposed as top-level parameters for convenience,
#'   the dual interface pattern allows any argument to be passed either directly or through the respective
#'   configuration object (\code{llm_args}, \code{interpretation_args}, \code{output_args}). This keeps the primary
#'   signature clean while maintaining flexibility
#'
#'
#' @details
#' All arguments are named to prevent positional confusion. The function detects which pattern
#' you're using based on which arguments are provided.
#'
#' ## Usage Patterns
#'
#' **Pattern 1: Fitted Model Object**
#'
#' Automatically extracts model components from fitted objects.
#'
#' \preformatted{
#' interpret(
#'   fit_results = fa_model,
#'   variable_info = var_info,
#'   provider = "ollama",
#'   model = "gpt-oss:20b-cloud"
#' )
#' }
#'
#' **Pattern 2: Structured List**
#'
#' For custom data structures or manual extraction.
#'
#' For FA, provide loadings (required) and optionally factor_cor_mat:
#'
#' \preformatted{
#' interpret(
#'   fit_results = list(
#'     loadings = loadings_matrix,
#'     factor_cor_mat = factor_cor_mat
#'   ),
#'   variable_info = var_info,
#'   model_type = "fa"
#' )
#' }
#'
#' **Pattern 3: Chat Session (Token-Efficient)**
#'
#' Reuse chat session across analyses to save tokens.
#'
#' \preformatted{
#' chat <- chat_session(model_type = "fa", provider = "ollama", model = "gpt-oss:20b-cloud")
#' result1 <- interpret(chat_session = chat, fit_results = model1, variable_info = var_info1)
#' result2 <- interpret(chat_session = chat, fit_results = model2, variable_info = var_info2)
#' }
#'
#' **Pattern 4: Configuration Objects (Advanced)**
#'
#' Use configuration objects for reusable settings and cleaner code.
#'
#' \preformatted{
#' # Create configuration objects
#' interp_config <- interpretation_args(model_type = "fa", cutoff = 0.4, n_emergency = 2)
#' llm_config <- llm_args(word_limit = 100, additional_info = "Study context")
#' output_config <- output_args(output_format = "markdown", silent = 1)
#'
#' # Use in interpret() call
#' interpret(
#'   fit_results = fa_model,
#'   variable_info = var_info,
#'   interpretation_args = interp_config,
#'   llm_args = llm_config,
#'   output_args = output_config,
#'   provider = "ollama",
#'   model = "gpt-oss:20b-cloud"
#' )
#'
#' # Or mix config objects with direct parameters (direct parameters override)
#' interpret(
#'   fit_results = fa_model,
#'   variable_info = var_info,
#'   interpretation_args = interp_config,
#'   provider = "ollama",
#'   model = "gpt-oss:20b-cloud",
#'   word_limit = 150  # Overrides llm_config if it were provided
#' )
#' }
#'
#' ## Supported Model Types
#'
#' - **fa** (Factor Analysis): psych::fa(), psych::principal(), lavaan::cfa/efa(), mirt::mirt()
#' - **gm** (Gaussian Mixture): Not yet implemented
#' - **irt** (Item Response Theory): Not yet implemented
#' - **cdm** (Cognitive Diagnosis Models): Not yet implemented
#'
#' @return Model-specific interpretation object:
#'   - FA: \code{fa_interpretation} (see \code{\link{interpret}})
#'   - Future: \code{gm_interpretation}, \code{irt_interpretation}, etc.
#'
#' @seealso \code{\link{interpret}}, \code{\link{chat_session}}
#'
#' @importFrom cli cli_abort cli_warn
#' @importFrom tidyr pivot_wider
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(psych)
#' fa_model <- fa(mtcars[,1:4], nfactors = 2, rotate = "oblimin")
#'
#' var_info <- data.frame(
#'   variable = c("mpg", "cyl", "disp", "hp"),
#'   description = c("Miles per gallon", "Cylinders", "Displacement", "Horsepower")
#' )
#'
#' # Pattern 1: Fitted model
#' result1 <- interpret(
#'   fit_results = fa_model,
#'   variable_info = var_info,
#'   provider = "ollama",
#'   model = "gpt-oss:20b-cloud"
#' )
#'
#' # Pattern 2: Structured list
#' # Extract loadings from fitted model
#' loadings <- as.data.frame(unclass(fa_model$loadings))
#'
#' # Option A: Loadings only (orthogonal rotation)
#' result2a <- interpret(
#'   fit_results = list(loadings = loadings),
#'   variable_info = var_info,
#'   model_type = "fa",
#'   provider = "ollama",
#'   model = "gpt-oss:20b-cloud"
#' )
#'
#' # Option B: Loadings + factor correlations (oblique rotation)
#' result2b <- interpret(
#'   fit_results = list(
#'     loadings = loadings,
#'     factor_cor_mat = fa_model$Phi
#'   ),
#'   variable_info = var_info,
#'   model_type = "fa",
#'   provider = "ollama",
#'   model = "gpt-oss:20b-cloud"
#' )
#'
#' # Pattern 3: Chat session (token-efficient for multiple analyses)
#' chat <- chat_session(model_type = "fa", provider = "ollama", model = "gpt-oss:20b-cloud")
#' result3a <- interpret(chat_session = chat, fit_results = fa_model, variable_info = var_info)
#' result3b <- interpret(chat_session = chat, fit_results = fa_model2, variable_info = var_info2)
#' print(chat)  # Check token usage
#' }
interpret <- function(fit_results = NULL,
                      chat_session = NULL,
                      model_type = NULL,
                      provider = NULL,
                      model = NULL,
                      llm_args = NULL,
                      interpretation_args = NULL,
                      output_args = NULL,
                      ...) {
  # ============================================================================
  # ARGUMENT VALIDATION AND CONFIG BUILDING
  # ============================================================================

  # Check if all key arguments are missing
  if (is.null(chat_session) && is.null(fit_results)) {
    cli::cli_abort(
      c(
        "No arguments provided to interpret()",
        "i" = "Usage patterns:",
        " " = "1. interpret(fit_results = model, variable_info = var_info, provider = ...)",
        " " = "2. interpret(fit_results = model, variable_info = var_info, llm_args = list(...))",
        " " = "3. interpret(chat_session = chat, fit_results = ..., variable_info = var_info)",
        "i" = "See ?interpret for details"
      )
    )
  }

  # Validate chat_session if provided
  if (!is.null(chat_session)) {
    # Check if it's a valid chat session (inherits from "chat_session" or has class ending in "_chat_session")
    valid_chat <- inherits(chat_session, "chat_session") ||
                  any(grepl("_chat_session$", class(chat_session)))
    if (!valid_chat) {
      cli::cli_abort(
        c(
          "chat_session must be a chat_session object",
          "x" = "You supplied: {.type {chat_session}}",
          "i" = "Create with: chat_session(model_type, provider, model)"
        )
      )
    }
  }

  # Determine effective model_type for config building
  effective_model_type <- if (!is.null(chat_session)) {
    chat_session$model_type
  } else {
    model_type
  }

  # Build configuration objects from dual interface
  llm_cfg <- build_llm_args(llm_args, provider, model, ...)
  interpretation_cfg <- build_interpretation_args(interpretation_args, effective_model_type, ...)
  out_cfg <- build_output_args(output_args, ...)

  # Check if fit_results is missing
  if (is.null(fit_results)) {
    cli::cli_abort(
      c(
        "{.var fit_results} is required",
        "i" = "Provide one of:",
        " " = "- Fitted model: psych::fa/principal, lavaan::cfa/sem/efa, mirt::mirt",
        " " = "- Structured list: list(loadings = matrix, factor_cor_mat = matrix)"
      )
    )
  }

  # Note: variable_info validation moved to model-specific methods
  # Models that require it (like FA) will validate it themselves

  # Validate chat_session if provided
  if (!is.null(chat_session)) {
    if (!is.chat_session(chat_session)) {
      cli::cli_abort(
        c(
          "{.var chat_session} must be a chat_session object",
          "x" = "You provided: {.cls {class(chat_session)}}",
          "i" = "Create with: chat_session(model_type, provider, model)"
        )
      )
    }
  }

  # Validate LLM configuration when chat_session is NULL
  if (is.null(chat_session) && is.null(llm_cfg)) {
    cli::cli_abort(
      c(
        "LLM configuration required when {.var chat_session} is NULL",
        "i" = "Provide one of:",
        " " = "- Direct: provider = 'ollama', model = 'gpt-oss:20b'",
        " " = "- Config: llm_args = list(provider = 'ollama', model = 'gpt-oss:20b')",
        "i" = "Or provide a chat_session created with chat_session()"
      )
    )
  }

  # Validate model_type conflicts with chat_session
  if (!is.null(chat_session) && !is.null(model_type) &&
      model_type != effective_model_type) {
    cli::cli_abort(
      c(
        "chat_session model_type mismatch",
        "x" = paste0(
          "chat_session has model_type '", effective_model_type, "' ",
          "but you requested interpretation for model_type '", model_type, "'"
        ),
        "i" = "Create a new chat_session with model_type = '{model_type}'",
        "i" = "Or omit the model_type argument to use the chat_session's type"
      )
    )
  }

  # ============================================================================
  # DISPATCH TO APPROPRIATE HANDLER
  # ============================================================================

  # Check if fit_results is a fitted model object (has a class that might have a method)
  is_fitted_model <- !is.null(class(fit_results)) &&
    (
      inherits(fit_results, "fa") ||
        inherits(fit_results, "principal") ||
        inherits(fit_results, "psych") ||
        inherits(fit_results, "lavaan") ||
        inherits(fit_results, "efaList") ||
        inherits(fit_results, "SingleGroupClass")
    )

  # Check if fit_results is a list (but not a data.frame, which is also a list)
  is_structured_list <- is.list(fit_results) &&
    !is.data.frame(fit_results) && !is_fitted_model

  # ============================================================================
  # ROUTE 1: Fitted Model Object
  # ============================================================================
  if (is_fitted_model) {
    # Use internal interpret_model() S3 generic
    # Pass all explicit parameters that were made non-anonymous
    # Note: variable_info now passed through ... (model-specific)
    return(
      interpret_model(
        fit_results,
        chat_session = chat_session,
        llm_args = llm_cfg,
        interpretation_args = interpretation_cfg,
        output_args = out_cfg,
        ...
      )
    )
  }

  # ============================================================================
  # ROUTE 2: Structured List
  # ============================================================================
  if (is_structured_list) {
    # Need effective_model_type to know how to handle the list
    if (is.null(effective_model_type)) {
      cli::cli_abort(
        c(
          "{.var model_type} or {.var chat_session} required when using structured list",
          "i" = "Specify model_type explicitly or provide a chat_session"
        )
      )
    }

    # Validate and extract list components (model-specific via S3 dispatch)
    extracted <- validate_list_structure(
      model_type = effective_model_type,
      fit_results_list = fit_results
    )

    # For FA, extract loadings and factor_cor_mat for handle_raw_data_interpret
    # For other model types, the S3 method will return appropriate structure
    if (effective_model_type == "fa") {
      # Call handle_raw_data_interpret with extracted FA components
      return(
        handle_raw_data_interpret(
          x = extracted$loadings,
          model_type = effective_model_type,
          chat_session = chat_session,
          factor_cor_mat = extracted$factor_cor_mat,
          llm_args = llm_cfg,
          interpretation_args = interpretation_cfg,
          output_args = out_cfg,
          ...  # variable_info passed through dots
        )
      )
    } else {
      # For future model types (gm, irt, cdm), handle their specific structure here
      cli::cli_abort(
        c(
          "Structured list routing not yet implemented for model_type: {.val {effective_model_type}}",
          "i" = "The list was validated successfully, but routing logic needs to be added",
          "i" = "Implement handle_raw_data_interpret routing for {.val {effective_model_type}}"
        )
      )
    }
  }

  # ============================================================================
  # FALLBACK: Unknown fit_results type
  # ============================================================================
  cli::cli_abort(
    c(
      "Cannot interpret object of class {.cls {class(fit_results)}}",
      "i" = "Supported types:",
      " " = "- Fitted models: psych (fa, principal), lavaan (cfa, sem, efa), mirt (mirt)",
      " " = "- Structured list: list(loadings = matrix, factor_cor_mat = matrix)",
      "i" = "See ?interpret for details"
    )
  )
}


# ==============================================================================
# INTERNAL S3 GENERIC FOR FITTED MODEL OBJECTS
# ==============================================================================

#' Internal S3 Generic for Interpreting Fitted Model Objects
#'
#' This is an internal generic used by interpret() to dispatch on fitted
#' model objects from various packages. Not exported - users should call
#' interpret() directly.
#'
#' @param model Fitted model object
#' @param ... Additional arguments passed to model-specific methods, including
#'   variable_info (data frame with 'variable' and 'description' columns)
#'
#' @return Interpretation object
#' @noRd
interpret_model <- function(model, ...) {
  UseMethod("interpret_model")
}

# ==============================================================================
# METHODS FOR PSYCH PACKAGE
# ==============================================================================
# Note: R's S3 dispatch automatically handles psych objects through their class
# vector (e.g., c("fa", "psych")). The interpret_model.fa() and
# interpret_model.principal() methods below are called directly by R's dispatch
# system - no wrapper method needed.

#' Interpret Results from psych::fa()
#'
#' Internal S3 method to interpret exploratory factor analysis results from the psych package.
#' Automatically extracts factor loadings and factor correlations (for oblique rotations).
#'
#' @param model A fitted model from \code{psych::fa()}
#' @param variable_info Dataframe with variable names and descriptions
#' @param ... Additional arguments passed to \code{\link{interpret_core}}
#'
#' @return An \code{fa_interpretation} object
#'
#' @details
#' This method extracts:
#' - Factor loadings from \code{model$loadings}
#' - Factor correlations from \code{model$Phi} (for oblique rotations)
#'
#' @keywords internal
#' @noRd
#'
#' @examples
#' \dontrun{
#' library(psych)
#' fa_model <- fa(mtcars[,1:4], nfactors = 2, rotate = "oblimin")
#'
#' var_info <- data.frame(
#'   variable = c("mpg", "cyl", "disp", "hp"),
#'   description = c("Miles per gallon", "Cylinders", "Displacement", "Horsepower")
#' )
#'
#' result <- interpret(fit_results = fa_model, variable_info = var_info,
#'                     provider = "ollama", model = "gpt-oss:20b-cloud")
#' }
interpret_model.fa <- function(model, ...) {
  # Extract parameters from ...
  dots <- list(...)
  chat_session <- dots$chat_session
  variable_info <- dots$variable_info

  # Validate chat_session if provided
  validate_chat_session_for_model_type(chat_session, "fa")

  # Validate variable_info is provided (required for FA)
  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} is required for factor analysis",
        "i" = "Provide a data frame with 'variable' and 'description' columns"
      )
    )
  }

  # Call interpret_core with fit_results (build_model_data will extract loadings)
  result <- interpret_core(
    fit_results = model,
    model_type = "fa",
    ...  # Includes variable_info
  )

  # Validate return class
  stopifnot(inherits(result, "fa_interpretation"))

  return(result)
}

#' Interpret Results from psych::principal()
#'
#' Internal S3 method to interpret principal components analysis results from the psych package.
#' Automatically extracts component loadings.
#'
#' @param model A fitted model from \code{psych::principal()}
#' @param variable_info Dataframe with variable names and descriptions
#' @param ... Additional arguments passed to \code{\link{interpret_core}}
#'
#' @return An \code{fa_interpretation} object
#'
#' @details
#' This method extracts component loadings from \code{model$loadings}.
#' Principal components are orthogonal, so no factor correlations are extracted.
#'
#' @keywords internal
#' @noRd
#'
#' @examples
#' \dontrun{
#' library(psych)
#' pca_model <- principal(mtcars[,1:4], nfactors = 2, rotate = "varimax")
#'
#' var_info <- data.frame(
#'   variable = c("mpg", "cyl", "disp", "hp"),
#'   description = c("Miles per gallon", "Cylinders", "Displacement", "Horsepower")
#' )
#'
#' result <- interpret(fit_results = pca_model, variable_info = var_info,
#'                     provider = "ollama", model = "gpt-oss:20b-cloud")
#' }
interpret_model.principal <- function(model, ...) {
  # Extract parameters from ...
  dots <- list(...)
  chat_session <- dots$chat_session
  variable_info <- dots$variable_info

  # Validate chat_session if provided
  validate_chat_session_for_model_type(chat_session, "fa")

  # Validate variable_info is provided (required for FA/PCA)
  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} is required for principal components analysis",
        "i" = "Provide a data frame with 'variable' and 'description' columns"
      )
    )
  }

  # Validate model structure
  if (!inherits(model, "psych") && !inherits(model, "principal")) {
    cli::cli_abort(
      c("Model must be of class {.cls psych.principal}", "x" = "You supplied class: {.cls {class(model)}}")
    )
  }

  if (is.null(model$loadings)) {
    cli::cli_abort("Model does not contain loadings component")
  }

  # Extract loadings and convert to data frame
  loadings <- as.data.frame(unclass(model$loadings))

  # PCA produces orthogonal components, no correlations
  # Call interpret_core with extracted model
  result <- interpret_core(
    fit_results = model,
    model_type = "fa",
    ...  # Includes variable_info
  )

  # Validate return class
  stopifnot(inherits(result, "fa_interpretation"))

  return(result)
}


# ==============================================================================
# METHODS FOR LAVAAN PACKAGE
# ==============================================================================

#' Interpret Results from lavaan Models (CFA/SEM)
#'
#' Internal S3 method to interpret confirmatory factor analysis or structural equation
#' models from the lavaan package. Automatically extracts standardized factor
#' loadings and factor correlations.
#'
#' @param model A fitted model from \code{lavaan::cfa()}, \code{lavaan::sem()},
#'   or \code{lavaan::lavaan()}
#' @param variable_info Dataframe with variable names and descriptions
#' @param ... Additional arguments passed to \code{\link{interpret_core}}
#'
#' @return An \code{fa_interpretation} object
#'
#' @details
#' This method extracts:
#' - Standardized factor loadings using \code{lavaan::standardizedSolution()}
#' - Factor correlations from latent variable covariances
#'
#' The method filters for measurement model relationships (op == "=~") and
#' reshapes them into a loadings matrix format.
#'
#' @keywords internal
#' @noRd
#'
#' @examples
#' \dontrun{
#' library(lavaan)
#' model_syntax <- '
#'   visual  =~ x1 + x2 + x3
#'   textual =~ x4 + x5 + x6
#'   speed   =~ x7 + x8 + x9
#' '
#' fit <- cfa(model_syntax, data = HolzingerSwineford1939)
#'
#' var_info <- data.frame(
#'   variable = paste0("x", 1:9),
#'   description = paste("Visual/Textual/Speed indicator", 1:9)
#' )
#'
#' result <- interpret(fit_results = fit, variable_info = var_info,
#'                     provider = "ollama",
#'                     model = "gpt-oss:20b-cloud")
#' }
interpret_model.lavaan <- function(model, ...) {
  # Extract parameters from ...
  dots <- list(...)
  chat_session <- dots$chat_session
  variable_info <- dots$variable_info

  # Validate chat_session if provided
  validate_chat_session_for_model_type(chat_session, "fa")

  # Validate variable_info is provided (required for lavaan)
  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} is required for lavaan models",
        "i" = "Provide a data frame with 'variable' and 'description' columns"
      )
    )
  }

  # Check if lavaan is available
  if (!requireNamespace("lavaan", quietly = TRUE)) {
    cli::cli_abort(
      c("Package {.pkg lavaan} is required for this method", "i" = "Install with: install.packages(\"lavaan\")")
    )
  }

  # Validate model
  if (!inherits(model, "lavaan")) {
    cli::cli_abort(
      c("Model must be of class {.cls lavaan}", "x" = "You supplied class: {.cls {class(model)}}")
    )
  }

  # Extract standardized solution
  std_solution <- lavaan::standardizedSolution(model)

  # Filter for loading relationships (measurement model)
  loadings_long <- std_solution[std_solution$op == "=~", ]

  if (nrow(loadings_long) == 0) {
    cli::cli_abort(
      c("No factor loadings found in model", "i" = "Make sure the model contains measurement model relationships (=~)")
    )
  }

  # Reshape to wide format (variables × factors)
  loadings_wide <- tidyr::pivot_wider(
    loadings_long,
    id_cols = "rhs",
    names_from = "lhs",
    values_from = "est.std",
    values_fill = 0
  )

  # Convert to data frame with proper row names
  loadings <- as.data.frame(loadings_wide[, -1])
  rownames(loadings) <- loadings_wide$rhs

  # Extract factor correlations (latent variable correlations)
  factor_cor_mat <- NULL
  cor_data <- std_solution[std_solution$op == "~~" &
                             std_solution$lhs %in% unique(loadings_long$lhs) &
                             std_solution$rhs %in% unique(loadings_long$lhs) &
                             std_solution$lhs != std_solution$rhs, ]

  if (nrow(cor_data) > 0) {
    # Get unique factor names
    factor_names <- unique(loadings_long$lhs)
    n_factors <- length(factor_names)

    # Create correlation matrix
    factor_cor_mat <- diag(n_factors)
    rownames(factor_cor_mat) <- factor_names
    colnames(factor_cor_mat) <- factor_names

    # Fill in correlations
    for (i in seq_len(nrow(cor_data))) {
      f1 <- cor_data$lhs[i]
      f2 <- cor_data$rhs[i]
      cor_val <- cor_data$est.std[i]
      factor_cor_mat[f1, f2] <- cor_val
      factor_cor_mat[f2, f1] <- cor_val
    }
  }

  # Call interpret_core
  result <- interpret_core(
    fit_results = model,
    model_type = "fa",
    ...  # Includes variable_info
  )

  # Validate return class
  stopifnot(inherits(result, "fa_interpretation"))

  return(result)
}


#' Interpret Results from lavaan::efa()
#'
#' Internal S3 method to interpret exploratory factor analysis results from lavaan's
#' efa() function when output="efa" is specified.
#'
#' @param model A fitted model from \code{lavaan::efa()} with output="efa"
#' @param variable_info Dataframe with variable names and descriptions
#' @param ... Additional arguments passed to \code{\link{interpret_core}}
#'
#' @return An \code{fa_interpretation} object
#'
#' @details
#' This method extracts factor loadings using the \code{loadings()} function
#' from the stats package, which works on efaList objects.
#'
#' @keywords internal
#' @noRd
#'
#' @examples
#' \dontrun{
#' library(lavaan)
#' fit <- efa(data = HolzingerSwineford1939[, 7:15],
#'            nfactors = 3,
#'            rotation = "geomin")
#'
#' var_info <- data.frame(
#'   variable = paste0("x", 1:9),
#'   description = paste("Indicator", 1:9)
#' )
#'
#' result <- interpret(fit_results = fit, variable_info = var_info,
#'                     provider = "ollama", model = "gpt-oss:20b-cloud")
#' }
interpret_model.efaList <- function(model, ...) {
  # Extract parameters from ...
  dots <- list(...)
  variable_info <- dots$variable_info

  # Validate variable_info is provided (required for efaList)
  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} is required for lavaan::efa models",
        "i" = "Provide a data frame with 'variable' and 'description' columns"
      )
    )
  }

  chat_session <- dots$chat_session

  # Validate chat_session if provided
  validate_chat_session_for_model_type(chat_session, "fa")

  # Check if lavaan is available
  if (!requireNamespace("lavaan", quietly = TRUE)) {
    cli::cli_abort(
      c("Package {.pkg lavaan} is required for this method", "i" = "Install with: install.packages(\"lavaan\")")
    )
  }

  # Validate model
  if (!inherits(model, "efaList")) {
    cli::cli_abort(
      c("Model must be of class {.cls efaList}", "x" = "You supplied class: {.cls {class(model)}}")
    )
  }

  # Extract loadings using stats::loadings() which works on efaList
  loadings_obj <- loadings(model)

  # Convert to data frame
  loadings <- as.data.frame(unclass(loadings_obj))

  # Try to extract factor correlations from efaList structure
  factor_cor_mat <- NULL
  if (!is.null(model$rotation) && !is.null(model$rotation$phi)) {
    factor_cor_mat <- model$rotation$phi
  }

  # Call interpret_core with structured list
  result <- interpret_core(
    fit_results = list(
      loadings = loadings,
      factor_cor_mat = factor_cor_mat
    ),
    variable_info = variable_info,
    model_type = "fa",
    ...
  )

  # Validate return class
  stopifnot(inherits(result, "fa_interpretation"))

  return(result)
}


# ==============================================================================
# METHODS FOR MIRT PACKAGE
# ==============================================================================

#' Interpret Results from mirt::mirt()
#'
#' Internal S3 method to interpret multidimensional item response theory models from
#' the mirt package. Automatically extracts standardized factor loadings and
#' factor correlations.
#'
#' @param model A fitted model from \code{mirt::mirt()}
#' @param variable_info Dataframe with variable (item) names and descriptions
#' @param rotate Character. Rotation method to apply when extracting loadings.
#'   Options include "oblimin", "varimax", "promax", etc. Default is "oblimin"
#' @param ... Additional arguments passed to \code{\link{interpret_core}}
#'
#' @return An \code{fa_interpretation} object
#'
#' @details
#' This method extracts standardized factor loadings using \code{summary(model)}
#' with the specified rotation. For multidimensional models, it also attempts
#' to extract factor correlations.
#'
#' @keywords internal
#' @noRd
#'
#' @examples
#' \dontrun{
#' library(mirt)
#' # Fit a 2-dimensional model
#' data <- expand.table(LSAT7)
#' model <- mirt(data, 2, itemtype = "2PL")
#'
#' var_info <- data.frame(
#'   variable = colnames(data),
#'   description = paste("LSAT item", 1:5)
#' )
#'
#' result <- interpret(fit_results = model, variable_info = var_info,
#'                     provider = "ollama", model = "gpt-oss:20b-cloud")
#' }
interpret_model.SingleGroupClass <- function(model, rotate = "oblimin", ...) {
  # Extract parameters from ...
  dots <- list(...)
  variable_info <- dots$variable_info

  # Validate variable_info is provided (required for mirt)
  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} is required for mirt models",
        "i" = "Provide a data frame with 'variable' and 'description' columns"
      )
    )
  }

  chat_session <- dots$chat_session

  # Validate chat_session if provided
  validate_chat_session_for_model_type(chat_session, "fa")

  # Check if mirt is available
  if (!requireNamespace("mirt", quietly = TRUE)) {
    cli::cli_abort(
      c("Package {.pkg mirt} is required for this method", "i" = "Install with: install.packages(\"mirt\")")
    )
  }

  # Validate model
  if (!inherits(model, "SingleGroupClass")) {
    cli::cli_abort(
      c("Model must be of class {.cls SingleGroupClass}", "x" = "You supplied class: {.cls {class(model)}}")
    )
  }

  # Extract standardized loadings using summary with rotation
  sum_obj <- mirt::summary(model, rotate = rotate, verbose = FALSE)

  # Extract loadings from summary object
  # The structure varies, but typically loadings are in $rotF or similar
  if (!is.null(sum_obj$rotF)) {
    loadings <- as.data.frame(sum_obj$rotF)
  } else if (!is.null(sum_obj$fcor)) {
    # Try alternative extraction method using coef
    coef_list <- mirt::coef(model, simplify = TRUE)
    if (!is.null(coef_list$items)) {
      # Extract a1, a2, etc. columns (discrimination parameters = loadings)
      items <- coef_list$items
      loading_cols <- grep("^a[0-9]+$", colnames(items), value = TRUE)
      if (length(loading_cols) > 0) {
        loadings <- as.data.frame(items[, loading_cols, drop = FALSE])
        # Rename columns to F1, F2, etc.
        colnames(loadings) <- paste0("F", seq_len(ncol(loadings)))
      } else {
        cli::cli_abort("Could not extract loadings from mirt model")
      }
    } else {
      cli::cli_abort("Could not extract loadings from mirt model")
    }
  } else {
    cli::cli_abort("Could not extract loadings from mirt model summary")
  }

  # Extract factor correlations if available
  factor_cor_mat <- NULL
  if (!is.null(sum_obj$fcor)) {
    factor_cor_mat <- sum_obj$fcor
  } else if (!is.null(model@Phi)) {
    factor_cor_mat <- model@Phi
  }

  # Call interpret_core
  result <- interpret_core(
    fit_results = model,
    model_type = "fa",
    ...  # Includes variable_info
  )

  # Validate return class
  stopifnot(inherits(result, "fa_interpretation"))

  return(result)
}
