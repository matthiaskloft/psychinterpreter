# ==============================================================================
# PARAMETER REGISTRY - SINGLE SOURCE OF TRUTH
# ==============================================================================
# This file centralizes all parameter metadata including defaults, validation
# rules, and config group membership. It eliminates parameter definition
# duplication across validation code, config objects, and documentation.
#
# Benefits:
# - Single source of truth for all parameter metadata
# - Consistent defaults across all entry points
# - Reusable validation functions
# - Foundation for programmatic documentation
#
# Last Updated: 2025-11-16

#' Parameter Registry
#'
#' Central registry containing metadata for all psychinterpreter parameters.
#' Serves as single source of truth for defaults, validation, and documentation.
#'
#' @format Named list where each element contains:
#' \describe{
#'   \item{default}{Default value for the parameter}
#'   \item{type}{R type: "character", "integer", "numeric", "logical", "list"}
#'   \item{range}{Valid range for numeric parameters (NULL for non-numeric)}
#'   \item{allowed_values}{Character vector of allowed values (NULL if not applicable)}
#'   \item{config_group}{Which config object this parameter belongs to: "llm_args", "output_args", "interpretation_args"}
#'   \item{model_specific}{If interpretation_args, which model types use this: "fa", "gm", "irt", "cdm", or NULL for all}
#'   \item{required}{Whether parameter must be provided (TRUE/FALSE)}
#'   \item{validation_fn}{Function that validates the parameter value}
#'   \item{description}{Short description of parameter purpose}
#' }
#'
#' @export
PARAMETER_REGISTRY <- list(

  # ==========================================================================
  # LLM_ARGS PARAMETERS (8 parameters)
  # ==========================================================================

  llm_provider = list(
    default = NULL,
    type = "character",
    range = NULL,
    allowed_values = NULL,  # Any provider name is valid
    config_group = "llm_args",
    model_specific = NULL,
    required = TRUE,
    validation_fn = function(value) {
      if (is.null(value)) {
        return(list(valid = FALSE, message = "{.arg llm_provider} is required (e.g., 'ollama', 'anthropic', 'openai')"))
      }
      if (!is.character(value) || length(value) != 1) {
        return(list(valid = FALSE, message = "{.arg llm_provider} must be a single character string"))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "LLM provider name (e.g., 'anthropic', 'openai', 'ollama')"
  ),

  llm_model = list(
    default = NULL,
    type = "character",
    range = NULL,
    allowed_values = NULL,
    config_group = "llm_args",
    model_specific = NULL,
    required = FALSE,
    validation_fn = function(value) {
      if (is.null(value)) {
        return(list(valid = TRUE, message = NULL))  # NULL is allowed
      }
      if (!is.character(value) || length(value) != 1) {
        return(list(valid = FALSE, message = "{.arg llm_model} must be a single character string or NULL"))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "LLM model name (e.g., 'gpt-4o-mini', 'claude-3-5-sonnet-20241022')"
  ),

  system_prompt = list(
    default = NULL,
    type = "character",
    range = NULL,
    allowed_values = NULL,
    config_group = "llm_args",
    model_specific = NULL,
    required = FALSE,
    validation_fn = function(value) {
      if (is.null(value)) {
        return(list(valid = TRUE, message = NULL))
      }
      if (!is.character(value)) {
        return(list(valid = FALSE, message = "{.arg system_prompt} must be a character string or NULL"))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Custom system prompt to override default"
  ),

  params = list(
    default = NULL,
    type = "list",
    range = NULL,
    allowed_values = NULL,
    config_group = "llm_args",
    model_specific = NULL,
    required = FALSE,
    validation_fn = function(value) {
      if (is.null(value)) {
        return(list(valid = TRUE, message = NULL))
      }
      if (!is.list(value)) {
        return(list(valid = FALSE, message = "{.arg params} must be created using ellmer::params()"))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "ellmer params object (created via ellmer::params())"
  ),

  word_limit = list(
    default = 150,
    type = "integer",
    range = c(20, 500),
    allowed_values = NULL,
    config_group = "llm_args",
    model_specific = NULL,
    required = FALSE,
    validation_fn = function(value) {
      if (!is.numeric(value) || length(value) != 1) {
        return(list(valid = FALSE, message = "{.arg word_limit} must be a single numeric value"))
      }
      if (value < 20 || value > 500) {
        return(list(valid = FALSE, message = "{.arg word_limit} must be between 20 and 500 (recommended range: 50-200 words)"))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Maximum words for LLM interpretations"
  ),

  interpretation_guidelines = list(
    default = NULL,
    type = "character",
    range = NULL,
    allowed_values = NULL,
    config_group = "llm_args",
    model_specific = NULL,
    required = FALSE,
    validation_fn = function(value) {
      if (is.null(value)) {
        return(list(valid = TRUE, message = NULL))
      }
      if (!is.character(value)) {
        return(list(valid = FALSE, message = "{.arg interpretation_guidelines} must be a character string or NULL"))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Custom interpretation guidelines for LLM"
  ),

  additional_info = list(
    default = NULL,
    type = "character",
    range = NULL,
    allowed_values = NULL,
    config_group = "llm_args",
    model_specific = NULL,
    required = FALSE,
    validation_fn = function(value) {
      if (is.null(value)) {
        return(list(valid = TRUE, message = NULL))
      }
      if (!is.character(value)) {
        return(list(valid = FALSE, message = "{.arg additional_info} must be a character string or NULL"))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Additional context for LLM"
  ),

  echo = list(
    default = "none",
    type = "character",
    range = NULL,
    allowed_values = c("none", "output", "all"),
    config_group = "llm_args",
    model_specific = NULL,
    required = FALSE,
    validation_fn = function(value) {
      if (!is.character(value) || length(value) != 1) {
        return(list(valid = FALSE, message = "{.arg echo} must be a single character string"))
      }
      if (!value %in% c("none", "output", "all")) {
        return(list(valid = FALSE, message = "{.arg echo} must be one of: 'none', 'output', 'all'"))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Echo level: 'none', 'output', 'all'"
  ),

  # ==========================================================================
  # OUTPUT_ARGS PARAMETERS (5 parameters)
  # ==========================================================================

  format = list(
    default = "cli",
    type = "character",
    range = NULL,
    allowed_values = c("cli", "markdown"),
    config_group = "output_args",
    model_specific = NULL,
    required = FALSE,
    validation_fn = function(value) {
      if (!is.character(value) || length(value) != 1) {
        return(list(valid = FALSE, message = "{.arg format} must be a single character string"))
      }
      if (!value %in% c("cli", "markdown")) {
        return(list(valid = FALSE, message = "{.arg format} must be either 'cli' or 'markdown'"))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Output format: 'cli' or 'markdown'"
  ),

  heading_level = list(
    default = 1L,
    type = "integer",
    range = c(1, 6),
    allowed_values = NULL,
    config_group = "output_args",
    model_specific = NULL,
    required = FALSE,
    validation_fn = function(value) {
      if (!is.numeric(value) || length(value) != 1) {
        return(list(valid = FALSE, message = "{.arg heading_level} must be a single integer between 1 and 6"))
      }
      if (value < 1 || value > 6 || value != as.integer(value)) {
        # Format the value inline to avoid variable scoping issues in cli_abort
        return(list(valid = FALSE, message = paste0("{.arg heading_level} must be an integer between 1 and 6 (got ", value, ")")))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Markdown heading level (1-6)"
  ),

  suppress_heading = list(
    default = FALSE,
    type = "logical",
    range = NULL,
    allowed_values = NULL,
    config_group = "output_args",
    model_specific = NULL,
    required = FALSE,
    validation_fn = function(value) {
      if (!is.logical(value) || length(value) != 1 || is.na(value)) {
        return(list(valid = FALSE, message = "{.arg suppress_heading} must be TRUE or FALSE"))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Suppress main heading in output"
  ),

  max_line_length = list(
    default = 80L,
    type = "integer",
    range = c(40, 300),
    allowed_values = NULL,
    config_group = "output_args",
    model_specific = NULL,
    required = FALSE,
    validation_fn = function(value) {
      if (!is.numeric(value) || length(value) != 1) {
        return(list(valid = FALSE, message = "{.arg max_line_length} must be a single numeric value"))
      }
      if (value < 40 || value > 300) {
        return(list(valid = FALSE, message = "{.arg max_line_length} must be between 40 and 300 (recommended: 80-120 for console output)"))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Maximum line length for text wrapping (40-300)"
  ),

  silent = list(
    default = 0L,
    type = "integer",
    range = c(0, 2),
    allowed_values = NULL,
    config_group = "output_args",
    model_specific = NULL,
    required = FALSE,
    validation_fn = function(value) {
      # Accept logical and convert
      if (is.logical(value)) {
        value <- ifelse(value, 2L, 0L)
      }
      if (!is.numeric(value) || length(value) != 1) {
        return(list(valid = FALSE, message = "{.arg silent} must be logical (TRUE/FALSE) or integer (0/1/2)"))
      }
      if (!value %in% c(0, 1, 2)) {
        return(list(valid = FALSE, message = paste0("{.arg silent} must be 0, 1, or 2 (got ", value, ")")))
      }
      list(valid = TRUE, message = NULL, normalized = as.integer(value))
    },
    description = "Verbosity level: 0 (report+messages), 1 (messages only), 2 (silent)"
  ),

  # ==========================================================================
  # INTERPRETATION_ARGS PARAMETERS - FACTOR ANALYSIS (4 parameters)
  # ==========================================================================

  cutoff = list(
    default = 0.3,
    type = "numeric",
    range = c(0, 1),
    allowed_values = NULL,
    config_group = "interpretation_args",
    model_specific = "fa",
    required = FALSE,
    validation_fn = function(value) {
      if (!is.numeric(value) || length(value) != 1) {
        return(list(valid = FALSE, message = "{.arg cutoff} must be a single numeric value"))
      }
      if (value < 0 || value > 1) {
        return(list(valid = FALSE, message = paste0("{.arg cutoff} must be between 0 and 1 (got ", value, ")")))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Minimum loading value to consider significant (FA only)"
  ),

  n_emergency = list(
    default = 2L,
    type = "integer",
    range = c(0, Inf),
    allowed_values = NULL,
    config_group = "interpretation_args",
    model_specific = "fa",
    required = FALSE,
    validation_fn = function(value) {
      if (!is.numeric(value) || length(value) != 1) {
        return(list(valid = FALSE, message = "{.arg n_emergency} must be a single integer value"))
      }
      if (value < 0 || value != as.integer(value)) {
        return(list(valid = FALSE, message = paste0("{.arg n_emergency} must be a non-negative integer (got ", value, ")")))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Top N loadings to use when none exceed cutoff (FA only)"
  ),

  hide_low_loadings = list(
    default = FALSE,
    type = "logical",
    range = NULL,
    allowed_values = NULL,
    config_group = "interpretation_args",
    model_specific = "fa",
    required = FALSE,
    validation_fn = function(value) {
      if (!is.logical(value) || length(value) != 1 || is.na(value)) {
        return(list(valid = FALSE, message = "{.arg hide_low_loadings} must be TRUE or FALSE"))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Hide non-significant loadings in LLM prompt (FA only)"
  ),

  sort_loadings = list(
    default = TRUE,
    type = "logical",
    range = NULL,
    allowed_values = NULL,
    config_group = "interpretation_args",
    model_specific = "fa",
    required = FALSE,
    validation_fn = function(value) {
      if (!is.logical(value) || length(value) != 1 || is.na(value)) {
        return(list(valid = FALSE, message = "{.arg sort_loadings} must be TRUE or FALSE"))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Sort variables by loading strength within factors (FA only)"
  )
)


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Get Parameter Default Value
#'
#' Retrieves the default value for a parameter from the registry.
#'
#' @param param_name Character. Name of the parameter
#'
#' @return Default value for the parameter
#'
#' @export
#'
#' @examples
#' get_param_default("word_limit")
#' get_param_default("cutoff")
get_param_default <- function(param_name) {
  if (!param_name %in% names(PARAMETER_REGISTRY)) {
    cli::cli_abort(
      c(
        "Unknown parameter: {.arg {param_name}}",
        "i" = "Valid parameters: {.val {names(PARAMETER_REGISTRY)}}"
      )
    )
  }

  PARAMETER_REGISTRY[[param_name]]$default
}


#' Get Parameters by Configuration Group
#'
#' Retrieves all parameters belonging to a specific configuration group,
#' optionally filtered by model type.
#'
#' @param config_group Character. Configuration group: "llm_args", "output_args", "interpretation_args"
#' @param model_type Character or NULL. Model type filter: "fa", "gm", "irt", "cdm" (only applies to interpretation_args)
#'
#' @return Named list of parameter metadata
#'
#' @export
#'
#' @examples
#' # Get all LLM parameters
#' get_params_by_group("llm_args")
#'
#' # Get FA interpretation parameters
#' get_params_by_group("interpretation_args", model_type = "fa")
get_params_by_group <- function(config_group, model_type = NULL) {
  if (!config_group %in% c("llm_args", "output_args", "interpretation_args")) {
    cli::cli_abort(
      c(
        "Invalid config_group: {.val {config_group}}",
        "i" = "Valid groups: 'llm_args', 'output_args', 'interpretation_args'"
      )
    )
  }

  # Filter by config group
  params <- PARAMETER_REGISTRY[
    vapply(PARAMETER_REGISTRY, function(p) p$config_group == config_group, logical(1))
  ]

  # Further filter by model type if specified (only for interpretation_args)
  if (!is.null(model_type)) {
    if (config_group != "interpretation_args") {
      cli::cli_warn(
        c(
          "!" = "model_type filter only applies to interpretation_args",
          "i" = "You specified config_group = '{config_group}' with model_type = '{model_type}'",
          "i" = "Ignoring model_type filter"
        )
      )
    } else {
      params <- params[
        vapply(params, function(p) {
          is.null(p$model_specific) || p$model_specific == model_type
        }, logical(1))
      ]
    }
  }

  params
}


#' Validate Single Parameter
#'
#' Validates a single parameter value using the registry validation function.
#'
#' @param param_name Character. Name of the parameter
#' @param value Value to validate
#' @param throw_error Logical. If TRUE, throws error on validation failure. If FALSE, returns result list
#'
#' @return If throw_error = FALSE, returns list with:
#'   - valid: Logical indicating if validation passed
#'   - message: Error message if invalid (NULL if valid)
#'   - normalized: Normalized value (if validation modified it, e.g., silent conversion)
#'   If throw_error = TRUE, returns normalized value or throws error
#'
#' @export
#'
#' @examples
#' # Returns list with valid = TRUE
#' validate_param("word_limit", 150, throw_error = FALSE)
#'
#' # Returns list with valid = FALSE and error message
#' validate_param("word_limit", 1000, throw_error = FALSE)
#'
#' # Throws error
#' \dontrun{
#' validate_param("word_limit", 1000, throw_error = TRUE)
#' }
validate_param <- function(param_name, value, throw_error = TRUE) {
  if (!param_name %in% names(PARAMETER_REGISTRY)) {
    cli::cli_abort(
      c(
        "Unknown parameter: {.arg {param_name}}",
        "i" = "Valid parameters: {.val {names(PARAMETER_REGISTRY)}}"
      )
    )
  }

  param_spec <- PARAMETER_REGISTRY[[param_name]]
  result <- param_spec$validation_fn(value)

  if (throw_error && !result$valid) {
    cli::cli_abort(result$message)
  }

  # Return normalized value if present, otherwise original
  if (!throw_error) {
    result
  } else {
    result$normalized %||% value
  }
}


#' Validate Multiple Parameters
#'
#' Validates a list of parameters using registry validation functions.
#' Useful for batch validation in config object constructors.
#'
#' @param param_list Named list of parameter values to validate
#' @param throw_error Logical. If TRUE, throws error on first validation failure. If FALSE, returns results
#'
#' @return If throw_error = FALSE, returns list with:
#'   - valid: Logical indicating if all validations passed
#'   - results: Named list of individual validation results
#'   - invalid_params: Character vector of parameter names that failed validation
#'   If throw_error = TRUE, returns normalized parameter list or throws error
#'
#' @export
#'
#' @examples
#' # Valid parameters
#' params <- list(word_limit = 150, cutoff = 0.3, silent = 0)
#' validate_params(params, throw_error = FALSE)
#'
#' # Invalid parameters
#' params <- list(word_limit = 1000, cutoff = 1.5)
#' validate_params(params, throw_error = FALSE)
validate_params <- function(param_list, throw_error = TRUE) {
  if (!is.list(param_list) || is.null(names(param_list))) {
    cli::cli_abort("{.arg param_list} must be a named list")
  }

  results <- list()
  normalized <- list()
  all_valid <- TRUE

  for (param_name in names(param_list)) {
    # Skip parameters not in registry (may be custom/internal params)
    if (!param_name %in% names(PARAMETER_REGISTRY)) {
      results[[param_name]] <- list(valid = TRUE, message = "Not in registry, skipping validation")
      normalized[[param_name]] <- param_list[[param_name]]
      next
    }

    param_spec <- PARAMETER_REGISTRY[[param_name]]
    result <- param_spec$validation_fn(param_list[[param_name]])
    results[[param_name]] <- result

    if (!result$valid) {
      all_valid <- FALSE
      if (throw_error) {
        cli::cli_abort(
          c(
            "Validation failed for parameter: {.arg {param_name}}",
            "x" = result$message
          )
        )
      }
    }

    # Store normalized value if present, otherwise original
    normalized[[param_name]] <- result$normalized %||% param_list[[param_name]]
  }

  if (!throw_error) {
    invalid_params <- names(results)[vapply(results, function(r) !r$valid, logical(1))]
    list(
      valid = all_valid,
      results = results,
      invalid_params = invalid_params,
      normalized = normalized
    )
  } else {
    normalized
  }
}


#' Get Registry Parameter Names
#'
#' Returns all parameter names in the registry, optionally filtered by config group.
#'
#' @param config_group Character or NULL. Filter by configuration group
#'
#' @return Character vector of parameter names
#'
#' @export
#'
#' @examples
#' # All parameters
#' get_registry_param_names()
#'
#' # Only LLM parameters
#' get_registry_param_names("llm_args")
get_registry_param_names <- function(config_group = NULL) {
  if (is.null(config_group)) {
    return(names(PARAMETER_REGISTRY))
  }

  names(get_params_by_group(config_group))
}
