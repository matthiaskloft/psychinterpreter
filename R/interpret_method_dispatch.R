# ==============================================================================
# S3 METHODS FOR INTERPRETING FACTOR ANALYSIS RESULTS FROM COMMON PACKAGES
# ==============================================================================

#' Interpret Psychometric Analysis Results
#'
#' Unified interface for interpreting psychometric analysis results with LLMs.
#' Supports fitted model objects, raw data with model_type specification,
#' structured lists, and persistent chat sessions for efficient multi-analysis workflows.
#'
#' @param chat_session Optional. A chat_session object created with \code{\link{chat_session}}
#'   for token-efficient multi-analysis workflows.
#' @param model_fit One of:
#'   - **Fitted model object**:
#'     - psych package: \code{fa()}, \code{principal()}
#'     - lavaan package: \code{cfa()}, \code{sem()}, \code{efa()}
#'     - mirt package: \code{mirt()}
#'   - **Structured list** with model components (raw data):
#'     - For FA: \code{list(loadings = matrix, factor_cor_mat = matrix)} or \code{list(loadings = matrix)}
#'     - For GM: Not yet implemented
#'     - For IRT: Not yet implemented
#'     - For CDM: Not yet implemented
#' @param variable_info Dataframe with 'variable' and 'description' columns describing the variables.
#' @param model_type Character. Type of analysis ("fa", "gm", "irt", "cdm"). Required when using
#'   structured list without chat_session. Automatically inferred from chat_session if provided.
#'
#' @param llm_provider Character. LLM provider to use (e.g., "openai", "anthropic", "ollama", "gemini").
#'   Any provider supported by ellmer::chat(). Required when chat_session is NULL. See ellmer documentation
#'   for complete list (default = NULL).
#' @param llm_model Character. Specific model to use (e.g., "gpt-4o-mini", "claude-3-5-sonnet-20241022", "gemma2:9b").
#'   If NULL, uses provider default (default = NULL).
#' @param params Parameters for the LLM created using ellmer::params() (e.g., params(temperature = 0.7, seed = 42)).
#'   Provides provider-agnostic interface for setting model parameters like temperature, seed, max_tokens, etc.
#'   If NULL, uses provider defaults (default = NULL).
#' @param system_prompt Character. Optional custom system prompt to override the package default psychometric
#'   system prompt. Use this to provide institution- or project-specific framing for the LLM (e.g., preferred
#'   terminology, audience level, or reporting conventions). If NULL, the internal default system prompt is used.
#'   Note: This parameter is ignored if chat_session is provided, as the system prompt has already been set
#'   during chat session initialization (default = NULL).
#' @param interpretation_guidelines Character. Optional custom interpretation guidelines for the LLM that override
#'   the package default guidelines. Use this to specify particular theoretical frameworks, interpretation styles,
#'   or domain-specific conventions. If NULL, built-in interpretation guidelines are applied (default = NULL).
#' @param additional_info Character. Optional additional context for the LLM, such as theoretical background,
#'   research area information, or domain-specific knowledge to inform interpretation (default = NULL).
#' @param word_limit Integer. Maximum number of words for LLM interpretations (default = 150).
#'
#' @param output_format Character. Output format for the report: "cli" or "markdown" (default = "cli").
#' @param heading_level Integer. Starting heading level for markdown output (default = 1). Used when output_format = "markdown".
#' @param suppress_heading Logical. If TRUE, suppresses the main interpretation heading for `output_format` = "markdown,
#'   allowing better integration into existing documents (default = FALSE).
#' @param max_line_length Integer. Maximum line length for console output text wrapping (default = 80).
#'
#' @param silent Integer or logical. Controls output verbosity:
#'   - 0 or FALSE: Show report and all messages (default)
#'   - 1: Show messages only, suppress report
#'   - 2 or TRUE: Completely silent, suppress all output
#'   For backward compatibility, logical values are accepted and converted to integers.
#' @param echo Character. Controls what is echoed during LLM interaction. One of "none" (no output),
#'   "output" (show only LLM responses), or "all" (show prompts and responses). Useful for debugging (default = "none").
#'
#' @param ... Additional model-specific parameters:
#'  - **FA-specific** (see \code{\link{interpret_fa}}):
#'    - `cutoff`: Minimum loading value to consider (default = 0.3)
#'    - `n_emergency`: Number of highest loadings to use when no loadings exceed cutoff (default = 2)
#'    - `hide_low_loadings`: Hide loadings below cutoff in LLM prompt (default = FALSE).
#'    This prevents the LLM from considering them for interpretation, which might happen otherwise.
#'    - `sort_loadings`: Sort variables by loading strength within factors (default = TRUE)
#'    - `factor_cor_mat`: Factor correlation matrix for oblique rotations (default = NULL)
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
#'   model_fit = fa_model,
#'   variable_info = var_info,
#'   llm_provider = "ollama",
#'   llm_model = "gpt-oss:20b-cloud"
#' )
#' }
#'
#' **Pattern 2: Structured List (Raw Data)**
#'
#' For custom data structures or manual extraction. Always use a structured list.
#'
#' For FA, provide loadings (required) and optionally factor_cor_mat:
#'
#' \preformatted{
#' interpret(
#'   model_fit = list(
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
#' result1 <- interpret(chat_session = chat, model_fit = model1, variable_info = var_info1)
#' result2 <- interpret(chat_session = chat, model_fit = model2, variable_info = var_info2)
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
#'   - FA: \code{fa_interpretation} (see \code{\link{interpret_fa}})
#'   - Future: \code{gm_interpretation}, \code{irt_interpretation}, etc.
#'
#' @seealso \code{\link{interpret_fa}}, \code{\link{chat_session}}
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
#'   model_fit = fa_model,
#'   variable_info = var_info,
#'   llm_provider = "ollama",
#'   llm_model = "gpt-oss:20b-cloud"
#' )
#'
#' # Pattern 2: Structured list (raw data)
#' # Extract loadings from fitted model
#' loadings <- as.data.frame(unclass(fa_model$loadings))
#'
#' # Option A: Loadings only (orthogonal rotation)
#' result2a <- interpret(
#'   model_fit = list(loadings = loadings),
#'   variable_info = var_info,
#'   model_type = "fa",
#'   llm_provider = "ollama",
#'   llm_model = "gpt-oss:20b-cloud"
#' )
#'
#' # Option B: Loadings + factor correlations (oblique rotation)
#' result2b <- interpret(
#'   model_fit = list(
#'     loadings = loadings,
#'     factor_cor_mat = fa_model$Phi  # Extract Phi from fitted model
#'   ),
#'   variable_info = var_info,
#'   model_type = "fa",
#'   llm_provider = "ollama",
#'   llm_model = "gpt-oss:20b-cloud"
#' )
#'
#' # Pattern 3: Chat session (token-efficient for multiple analyses)
#' chat <- chat_session(model_type = "fa", provider = "ollama", model = "gpt-oss:20b-cloud")
#' result3a <- interpret(chat_session = chat, model_fit = fa_model, variable_info = var_info)
#' result3b <- interpret(chat_session = chat, model_fit = fa_model2, variable_info = var_info2)
#' print(chat)  # Check token usage
#' }
interpret <- function(chat_session = NULL,
                      model_fit = NULL,
                      variable_info = NULL,
                      model_type = NULL,
                      llm_provider = NULL,
                      llm_model = NULL,
                      params = NULL,
                      system_prompt = NULL,
                      interpretation_guidelines = NULL,
                      additional_info = NULL,
                      word_limit = 150,
                      output_format = "cli",
                      heading_level = 1,
                      suppress_heading = FALSE,
                      max_line_length = 80,
                      silent = 0,
                      echo = "none",
                      ...) {
  # ============================================================================
  # ARGUMENT VALIDATION AND PATTERN DETECTION
  # ============================================================================

  # Handle backward compatibility: Convert logical to integer
  if (is.logical(silent)) {
    silent <- ifelse(silent, 2, 0)  # FALSE -> 0, TRUE -> 2
  }

  # Check if all key arguments are missing
  if (is.null(chat_session) &&
      is.null(model_fit) && is.null(variable_info)) {
    cli::cli_abort(
      c(
        "No arguments provided to interpret()",
        "i" = "Usage patterns:",
        " " = "1. interpret(model_fit = model, variable_info = var_info, llm_provider = ...)",
        " " = "2. interpret(model_fit = list(loadings = ...), variable_info = var_info, model_type = 'fa', llm_provider = ...)",
        " " = "3. interpret(chat_session = chat, model_fit = ..., variable_info = var_info)",
        "i" = "See ?interpret for details"
      )
    )
  }

  # Check if model_fit is missing
  if (is.null(model_fit)) {
    cli::cli_abort(
      c(
        "{.var model_fit} is required",
        "i" = "Provide one of:",
        " " = "- Fitted model: psych::fa/principal, lavaan::cfa/sem/efa, mirt::mirt",
        " " = "- Structured list: list(loadings = matrix, factor_cor_mat = matrix)"
      )
    )
  }

  # Check if variable_info is missing
  if (is.null(variable_info)) {
    cli::cli_abort(
      c("{.var variable_info} is required", "i" = "Provide a data frame with 'variable' and 'description' columns")
    )
  }

  # Validate variable_info structure
  if (!is.data.frame(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} must be a data frame",
        "x" = "You provided: {.cls {class(variable_info)}}",
        "i" = "Use data.frame(variable = c(...), description = c(...))"
      )
    )
  }

  if (!"variable" %in% names(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} must contain a 'variable' column",
        "x" = "Current columns: {.field {names(variable_info)}}",
        "i" = "Ensure columns include: 'variable', 'description'"
      )
    )
  }

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

  # Validate llm_provider when chat_session is NULL
  if (is.null(chat_session) && is.null(llm_provider)) {
    cli::cli_abort(
      c(
        "{.var llm_provider} is required when {.var chat_session} is NULL",
        "i" = "Specify llm_provider (e.g., 'anthropic', 'openai', 'ollama', 'gemini')",
        "i" = "Or provide a chat_session created with chat_session()"
      )
    )
  }

  # Determine effective model_type
  effective_model_type <- NULL
  if (!is.null(chat_session)) {
    effective_model_type <- chat_session$model_type

    # Warn if both chat_session and model_type are provided and conflict
    if (!is.null(model_type) &&
        model_type != effective_model_type) {
      cli::cli_warn(
        c(
          "!" = "Both {.var chat_session} and {.var model_type} provided with different values",
          "i" = "Using model_type from chat_session: {.val {effective_model_type}}",
          "i" = "Ignoring model_type argument: {.val {model_type}}"
        )
      )
    }
  } else {
    effective_model_type <- model_type
  }

  # ============================================================================
  # DISPATCH TO APPROPRIATE HANDLER
  # ============================================================================

  # Check if model_fit is a fitted model object (has a class that might have a method)
  is_fitted_model <- !is.null(class(model_fit)) &&
    (
      inherits(model_fit, "fa") ||
        inherits(model_fit, "principal") ||
        inherits(model_fit, "psych") ||
        inherits(model_fit, "lavaan") ||
        inherits(model_fit, "efaList") ||
        inherits(model_fit, "SingleGroupClass")
    )

  # Check if model_fit is a list (but not a data.frame, which is also a list)
  is_structured_list <- is.list(model_fit) &&
    !is.data.frame(model_fit) && !is_fitted_model

  # Check if model_fit is raw data (matrix or data.frame)
  is_raw_data <- (is.matrix(model_fit) ||
                    is.data.frame(model_fit)) && !is_fitted_model

  # ============================================================================
  # ROUTE 1: Fitted Model Object
  # ============================================================================
  if (is_fitted_model) {
    # Use internal interpret_model() S3 generic
    # Pass all explicit parameters that were made non-anonymous
    return(
      interpret_model(
        model_fit,
        variable_info,
        chat_session = chat_session,
        llm_provider = llm_provider,
        llm_model = llm_model,
        params = params,
        additional_info = additional_info,
        word_limit = word_limit,
        output_format = output_format,
        heading_level = heading_level,
        suppress_heading = suppress_heading,
        max_line_length = max_line_length,
        silent = silent,
        echo = echo,
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

    # Handle list structure based on model type
    if (effective_model_type == "fa") {
      # Validate and extract FA list components
      extracted <- validate_fa_list_structure(model_fit)

      # Call handle_raw_data_interpret with extracted loadings
      return(
        handle_raw_data_interpret(
          x = extracted$loadings,
          variable_info = variable_info,
          model_type = effective_model_type,
          chat_session = chat_session,
          factor_cor_mat = extracted$factor_cor_mat,
          llm_provider = llm_provider,
          llm_model = llm_model,
          params = params,
          additional_info = additional_info,
          word_limit = word_limit,
          output_format = output_format,
          heading_level = heading_level,
          suppress_heading = suppress_heading,
          max_line_length = max_line_length,
          silent = silent,
          echo = echo,
          ...
        )
      )
    } else {
      cli::cli_abort(
        c(
          "Structured list support not yet implemented for model_type: {.val {effective_model_type}}",
          "i" = "Currently only 'fa' supports list structure"
        )
      )
    }
  }

  # ============================================================================
  # ROUTE 3: Raw Data (matrix or data.frame)
  # ============================================================================
  if (is_raw_data) {
    # Need effective_model_type to know how to interpret the data
    if (is.null(effective_model_type)) {
      cli::cli_abort(
        c(
          "{.var model_type} or {.var chat_session} required when using raw data",
          "i" = "Specify model_type explicitly or provide a chat_session"
        )
      )
    }

    # Route to model-specific handling
    return(
      handle_raw_data_interpret(
        x = model_fit,
        variable_info = variable_info,
        model_type = effective_model_type,
        chat_session = chat_session,
        ...
      )
    )
  }

  # ============================================================================
  # FALLBACK: Unknown model_fit type
  # ============================================================================
  cli::cli_abort(
    c(
      "Cannot interpret object of class {.cls {class(model_fit)}}",
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
#' @param variable_info Variable descriptions dataframe
#' @param ... Additional arguments
#'
#' @return Interpretation object
#' @keywords internal
interpret_model <- function(model, variable_info, ...) {
  UseMethod("interpret_model")
}


# ==============================================================================
# METHODS FOR PSYCH PACKAGE
# ==============================================================================

#' @keywords internal
#' @noRd
interpret_model.psych <- function(model, variable_info, ...) {
  if (inherits(model, "fa")) {
    interpret_model.fa(model, variable_info, ...)
  } else if (inherits(model, "principal")) {
    interpret_model.principal(model, variable_info, ...)
  } else {
    cli::cli_abort(c("Unsupported psych model type", "x" = "Class of object: {.cls {class(model)}}"))
  }
}


#' Interpret Results from psych::fa()
#'
#' Internal S3 method to interpret exploratory factor analysis results from the psych package.
#' Automatically extracts factor loadings and factor correlations (for oblique rotations).
#'
#' @param model A fitted model from \code{psych::fa()}
#' @param variable_info Dataframe with variable names and descriptions
#' @param ... Additional arguments passed to \code{\link{interpret_fa}}
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
#' result <- interpret(model_fit = fa_model, variable_info = var_info,
#'                     llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")
#' }
interpret_model.fa <- function(model, variable_info, ...) {
  # Extract chat_session from ... if present
  dots <- list(...)
  chat_session <- dots$chat_session

  # Validate chat_session if provided
  validate_chat_session_for_model_type(chat_session, "fa")

  # Validate model structure
  if (!inherits(model, "psych") && !inherits(model, "fa")) {
    cli::cli_abort(
      c("Model must be of class {.cls psych.fa}", "x" = "You supplied class: {.cls {class(model)}}")
    )
  }

  if (is.null(model$loadings)) {
    cli::cli_abort("Model does not contain loadings component")
  }

  # Extract loadings and convert to data frame
  loadings <- as.data.frame(unclass(model$loadings))

  # Extract factor correlations if oblique rotation was used
  factor_cor_mat <- if (!is.null(model$Phi)) {
    model$Phi
  } else {
    NULL
  }

  # Call interpret_fa with extracted components
  result <- interpret_fa(
    loadings = loadings,
    variable_info = variable_info,
    factor_cor_mat = factor_cor_mat,
    ...
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
#' @param ... Additional arguments passed to \code{\link{interpret_fa}}
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
#' result <- interpret(model_fit = pca_model, variable_info = var_info,
#'                     llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")
#' }
interpret_model.principal <- function(model, variable_info, ...) {
  # Extract chat_session from ... if present
  dots <- list(...)
  chat_session <- dots$chat_session

  # Validate chat_session if provided
  validate_chat_session_for_model_type(chat_session, "fa")

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
  # Call interpret_fa with extracted components
  result <- interpret_fa(
    loadings = loadings,
    variable_info = variable_info,
    factor_cor_mat = NULL,
    ...
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
#' @param ... Additional arguments passed to \code{\link{interpret_fa}}
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
#' result <- interpret(model_fit = fit, variable_info = var_info,
#'                     llm_provider = "ollama",
#'                     llm_model = "gpt-oss:20b-cloud")
#' }
interpret_model.lavaan <- function(model, variable_info, ...) {
  # Extract chat_session from ... if present
  dots <- list(...)
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

  # Call interpret_fa
  result <- interpret_fa(
    loadings = loadings,
    variable_info = variable_info,
    factor_cor_mat = factor_cor_mat,
    ...
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
#' @param ... Additional arguments passed to \code{\link{interpret_fa}}
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
#' result <- interpret(model_fit = fit, variable_info = var_info,
#'                     llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")
#' }
interpret_model.efaList <- function(model, variable_info, ...) {
  # Extract chat_session from ... if present
  dots <- list(...)
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

  # Call interpret_fa
  result <- interpret_fa(
    loadings = loadings,
    variable_info = variable_info,
    factor_cor_mat = factor_cor_mat,
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
#' @param ... Additional arguments passed to \code{\link{interpret_fa}}
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
#' result <- interpret(model_fit = model, variable_info = var_info,
#'                     llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")
#' }
interpret_model.SingleGroupClass <- function(model, variable_info, rotate = "oblimin", ...) {
  # Extract chat_session from ... if present
  dots <- list(...)
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

  # Call interpret_fa
  result <- interpret_fa(
    loadings = loadings,
    variable_info = variable_info,
    factor_cor_mat = factor_cor_mat,
    ...
  )

  # Validate return class
  stopifnot(inherits(result, "fa_interpretation"))

  return(result)
}
