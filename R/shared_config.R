# ==============================================================================
# CONFIGURATION OBJECTS FOR PSYCHINTERPRETER
# ==============================================================================
# This file provides constructor functions for configuration objects used
# across the package. These objects group related parameters and provide
# validation, making the API cleaner and more maintainable.

# ==============================================================================
# DISPATCH TABLE SYSTEM FOR ANALYSIS TYPES
# ==============================================================================
#
# The dispatch tables provide a centralized, data-driven approach to handling
# different analysis types without if/else chains. This makes the code more
# maintainable, scalable, and easier to extend with new analysis types.
#
# Tables defined:
# 1. INTERPRETATION_ARGS_DISPATCH - Maps analysis types to handler functions
# 2. ANALYSIS_TYPE_DISPLAY_NAMES - Maps analysis types to display names
# 3. VALID_INTERPRETATION_PARAMS - Maps analysis types to their valid parameters
#
# ==============================================================================

# Dispatch table defined after function definitions (see below line 200)

#' Display Names for Analysis Types
#'
#' Maps analysis type codes to human-readable names for printing/output.
#'
#' @keywords internal
#' @noRd
.ANALYSIS_TYPE_DISPLAY_NAMES <- c(
  fa = "Factor Analysis",
  gm = "Gaussian Mixture",
  irt = "Item Response Theory",
  cdm = "Cognitive Diagnosis"
)

#' Valid Parameters for Each Analysis Type
#'
#' Maps analysis_type to the valid parameters that can be passed to
#' interpretation_args() for that type. Used for parameter filtering.
#'
#' @keywords internal
#' @noRd
.VALID_INTERPRETATION_PARAMS <- list(
  fa = c("cutoff", "n_emergency", "hide_low_loadings", "sort_loadings"),
  gm = c("n_clusters", "covariance_type", "min_cluster_size",
         "separation_threshold", "profile_variables", "weight_by_uncertainty", "plot_type"),
  irt = character(0), # Future: placeholder for IRT parameters
  cdm = character(0)  # Future: placeholder for CDM parameters
)

#' Dispatch Table Lookup Helper
#'
#' Gets a handler function or value from dispatch table, with fallback.
#'
#' @param dispatch_table List-like dispatch table
#' @param key Character key to look up
#' @param default Default value if key not found
#' @param error_message Optional error message if key not found and no default
#'
#' @return Value from dispatch table or default
#' @keywords internal
#' @noRd
.dispatch_lookup <- function(dispatch_table, key, default = NULL, error_message = NULL) {
  if (key %in% names(dispatch_table)) {
    return(dispatch_table[[key]])
  }

  if (!is.null(default)) {
    return(default)
  }

  if (!is.null(error_message)) {
    cli::cli_abort(error_message)
  }

  NULL
}

#' Get Display Name for Analysis Type
#'
#' @param analysis_type Character analysis type code
#'
#' @return Character display name
#' @keywords internal
#' @noRd
.get_analysis_type_display_name <- function(analysis_type) {
  .dispatch_lookup(
    .ANALYSIS_TYPE_DISPLAY_NAMES,
    analysis_type,
    default = analysis_type
  )
}

#' Get Valid Parameters for Analysis Type
#'
#' @param analysis_type Character analysis type code
#'
#' @return Character vector of valid parameter names
#' @keywords internal
#' @noRd
.get_valid_interpretation_params <- function(analysis_type) {
  .dispatch_lookup(
    .VALID_INTERPRETATION_PARAMS,
    analysis_type,
    default = character(0)
  )
}

#'Create Model-Specific Interpretation Configuration
#'
#' Creates a configuration object for interpretation settings. The available
#' parameters depend on the analysis_type.
#'
#' @param analysis_type Character. Type of analysis: "fa" (factor analysis),
#'   "gm" (gaussian mixture), "irt" (item response theory), or "cdm"
#'   (cognitive diagnosis model)
#' @param ... Model-specific parameters. For FA: cutoff, n_emergency,
#'   hide_low_loadings, sort_loadings. See Details.
#'
#' @return A list with class "interpretation_args" containing validated settings
#'
#' @details
#' **Factor Analysis (analysis_type = "fa"):**
#' - `cutoff`: Numeric. Minimum loading value to consider significant (default = 0.3)
#' - `n_emergency`: Integer. When a factor has no loadings above cutoff, use top N
#'   highest loadings. If 0, factors with no significant loadings are labeled
#'   "undefined" (default = 2)
#' - `hide_low_loadings`: Logical. If TRUE, only variables with loadings at or above
#'   cutoff are included in LLM prompt (default = FALSE)
#' - `sort_loadings`: Logical. Sort variables by loading strength within factors
#'   (default = TRUE)
#'
#' **Note:** Factor correlation matrices should be passed via \code{fit_results}
#' parameter in list structure: \code{list(loadings = ..., factor_cor_mat = ...)},
#' not via \code{interpretation_args}.
#'
#' @export
#'
#' @examples
#' # Factor analysis with default settings
#' cfg <- interpretation_args(analysis_type = "fa")
#'
#' # Factor analysis with custom settings
#' cfg <- interpretation_args(
#'   analysis_type = "fa",
#'   cutoff = 0.4,
#'   n_emergency = 3,
#'   hide_low_loadings = TRUE
#' )
interpretation_args <- function(analysis_type, ...) {
  # Validate analysis_type (also checks if implemented)
  validate_analysis_type(analysis_type)

  # Look up handler function via dispatch table
  handler <- .dispatch_lookup(
    .INTERPRETATION_ARGS_DISPATCH,
    analysis_type,
    error_message = c(
      "x" = "interpretation_args for analysis_type '{analysis_type}' not yet implemented",
      "i" = "Handler function interpretation_args_{analysis_type}() not found in dispatch table",
      "i" = "Add interpretation_args_{analysis_type}() function and register in .INTERPRETATION_ARGS_DISPATCH"
    )
  )

  # Call handler function with ... parameters
  if (is.function(handler)) {
    return(handler(...))
  } else {
    cli::cli_abort(c(
      "x" = "Invalid handler for analysis_type '{analysis_type}'",
      "i" = "Dispatch table entry must be a function"
    ))
  }
}

#' Create FA-Specific Interpretation Args (Internal)
#'
#' @keywords internal
#' @noRd
interpretation_args_fa <- function(cutoff = NULL,
                                   n_emergency = NULL,
                                   hide_low_loadings = NULL,
                                   sort_loadings = NULL) {
  # Build parameter list with defaults from registry
  param_list <- list(
    analysis_type = "fa",
    cutoff = cutoff %||% get_param_default("cutoff"),
    n_emergency = n_emergency %||% get_param_default("n_emergency"),
    hide_low_loadings = hide_low_loadings %||% get_param_default("hide_low_loadings"),
    sort_loadings = sort_loadings %||% get_param_default("sort_loadings")
  )

  # Validate all parameters using registry
  validated <- validate_params(param_list, throw_error = TRUE)

  structure(
    validated,
    class = c("interpretation_args", "model_config", "list")
  )
}

# ==============================================================================
# DISPATCH TABLE (defined after function definitions to avoid forward reference)
# ==============================================================================

#' Dispatch Table for interpretation_args() Constructor Functions
#'
#' Maps analysis_type to handler functions that construct type-specific configs.
#' Functions referenced here must:
#' - Accept ... for variable parameters
#' - Return an interpretation_args object
#' - Validate their specific parameters
#'
#' @keywords internal
#' @noRd
.INTERPRETATION_ARGS_DISPATCH <- list(
  fa = interpretation_args_fa,
  gm = interpretation_args_gm
)


#' Create LLM Configuration
#'
#' Creates a configuration object for LLM interaction settings. Groups all
#' LLM-related parameters together.
#'
#' @param llm_provider Character. LLM provider (e.g., "anthropic", "openai", "ollama")
#' @param llm_model Character or NULL. LLM model name (e.g., "gpt-4o-mini", "claude-3-5-sonnet-20241022")
#' @param system_prompt Character or NULL. Custom system prompt to override default (default = NULL)
#' @param params List or NULL. ellmer params object (created via ellmer::params()) (default = NULL)
#' @param word_limit Integer. Maximum words for LLM interpretations (default = 150)
#' @param interpretation_guidelines Character or NULL. Custom interpretation guidelines (default = NULL)
#' @param additional_info Character or NULL. Additional context for LLM (default = NULL)
#' @param echo Character. Echo level: "none", "output", "all" (default = "none")
#'
#' @return A list with class "llm_args" containing validated LLM settings
#'
#' @export
#'
#' @examples
#' # Basic config
#' cfg <- llm_args(llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")
#'
#' # Advanced config
#' cfg <- llm_args(
#'   llm_provider = "anthropic",
#'   llm_model = "claude-3-5-sonnet-20241022",
#'   word_limit = 200,
#'   params = ellmer::params(temperature = 0.7, seed = 42)
#' )
llm_args <- function(llm_provider = NULL,
                       llm_model = NULL,
                       system_prompt = NULL,
                       params = NULL,
                       word_limit = NULL,
                       interpretation_guidelines = NULL,
                       additional_info = NULL,
                       echo = NULL) {

  # Build parameter list with defaults from registry
  param_list <- list(
    llm_provider = llm_provider,
    llm_model = llm_model %||% get_param_default("llm_model"),
    system_prompt = system_prompt %||% get_param_default("system_prompt"),
    params = params %||% get_param_default("params"),
    word_limit = word_limit %||% get_param_default("word_limit"),
    interpretation_guidelines = interpretation_guidelines %||% get_param_default("interpretation_guidelines"),
    additional_info = additional_info %||% get_param_default("additional_info"),
    echo = echo %||% get_param_default("echo")
  )

  # Validate all parameters using registry
  validated <- validate_params(param_list, throw_error = TRUE)

  structure(
    validated,
    class = c("llm_args", "list")
  )
}


#' Create Output Configuration
#'
#' Creates a configuration object for output/display settings. Groups all
#' output-related parameters together.
#'
#' @param format Character. Output format: "cli" or "markdown" (default = "cli")
#' @param heading_level Integer. Markdown heading level, 1-6 (default = 1)
#' @param suppress_heading Logical. Suppress main heading in output (default = FALSE)
#' @param max_line_length Integer. Maximum line length for text wrapping, 40-300 (default = 80)
#' @param silent Integer or logical. Verbosity level:
#'   - 0 or FALSE: Show report and messages (default)
#'   - 1: Show messages only, suppress report
#'   - 2 or TRUE: Completely silent
#'
#' @return A list with class "output_args" containing validated output settings
#'
#' @export
#'
#' @examples
#' # Default config
#' cfg <- output_args()
#'
#' # Custom config
#' cfg <- output_args(
#'   format = "markdown",
#'   heading_level = 2,
#'   silent = TRUE
#' )
output_args <- function(format = NULL,
                          heading_level = NULL,
                          suppress_heading = NULL,
                          max_line_length = NULL,
                          silent = NULL) {

  # Build parameter list with defaults from registry
  param_list <- list(
    format = format %||% get_param_default("format"),
    heading_level = heading_level %||% get_param_default("heading_level"),
    suppress_heading = suppress_heading %||% get_param_default("suppress_heading"),
    max_line_length = max_line_length %||% get_param_default("max_line_length"),
    silent = silent %||% get_param_default("silent")
  )

  # Validate all parameters using registry
  validated <- validate_params(param_list, throw_error = TRUE)

  structure(
    validated,
    class = c("output_args", "list")
  )
}




#' Get Default Output Config
#'
#' Returns default output configuration. Useful for programmatic access.
#'
#' @return output_args object with default settings
#' @export
default_output_args <- function() {
  output_args()
}


# ==============================================================================
# FUTURE MODEL TYPE CONFIGURATIONS (NOT YET IMPLEMENTED)
# ==============================================================================
#
# When implementing GM, IRT, or CDM support:
# 1. Uncomment the relevant section below
# 2. Define model-specific parameters and defaults
# 3. Implement validation logic
# 4. Update interpret() and handle_raw_data_interpret() to pass these args
# 5. Run devtools::document() to update NAMESPACE
#
# See dev/templates/TEMPLATE_config_additions.R for full implementation pattern
# ==============================================================================

# #' Create Gaussian Mixture Configuration
# #'
# #' @param n_components Integer. Number of mixture components (default = 2)
# #' @param covariance_type Character. Type of covariance: "full", "tied", "diag", "spherical"
# #' @param ... Additional parameters
# #'
# #' @return gm_args configuration object
# #' @export
# gm_args <- function(n_components = 2,
#                     covariance_type = "full",
#                     ...) {
#   # TODO: Add validation logic
#   structure(
#     list(
#       n_components = as.integer(n_components),
#       covariance_type = covariance_type
#     ),
#     class = c("gm_args", "model_config", "list")
#   )
# }

# #' Create IRT Configuration
# #'
# #' @param model Character. IRT model: "1PL", "2PL", "3PL", "graded"
# #' @param ability_method Character. Ability estimation: "EAP", "MAP", "MLE"
# #' @param ... Additional parameters
# #'
# #' @return irt_args configuration object
# #' @export
# irt_args <- function(model = "2PL",
#                      ability_method = "EAP",
#                      ...) {
#   # TODO: Add validation logic
#   structure(
#     list(
#       model = model,
#       ability_method = ability_method
#     ),
#     class = c("irt_args", "model_config", "list")
#   )
# }

# #' Create CDM Configuration
# #'
# #' @param cdm_type Character. CDM type: "DINA", "DINO", "GDINA"
# #' @param q_matrix Matrix. Q-matrix for attribute-item relationships
# #' @param ... Additional parameters
# #'
# #' @return cdm_args configuration object
# #' @export
# cdm_args <- function(cdm_type = "DINA",
#                      q_matrix = NULL,
#                      ...) {
#   # TODO: Add validation logic
#   structure(
#     list(
#       cdm_type = cdm_type,
#       q_matrix = q_matrix
#     ),
#     class = c("cdm_args", "model_config", "list")
#   )
# }


# ==============================================================================
# S3 METHODS FOR CONFIG OBJECTS
# ==============================================================================

#' Print method for interpretation_args
#' @export
#' @keywords internal
print.interpretation_args <- function(x, ...) {
  # Get model type display name via dispatch
  model_name <- .get_analysis_type_display_name(x$analysis_type)

  cli::cli_h2("{model_name} Interpretation Configuration")

  # Get valid parameters for this analysis type
  valid_params <- .get_valid_interpretation_params(x$analysis_type)

  # Print model-specific parameters
  if (length(valid_params) > 0) {
    # Analysis type with defined parameters - show them
    cli::cli_ul()
    for (param in valid_params) {
      if (param %in% names(x)) {
        value <- x[[param]]
        # Format parameter display nicely
        if (param == "n_emergency") {
          cli::cli_li("Emergency rule: Use top {.val {value}} loadings")
        } else if (param == "cutoff") {
          cli::cli_li("Cutoff: {.val {value}}")
        } else if (param == "hide_low_loadings") {
          cli::cli_li("Hide low loadings: {.val {value}}")
        } else if (param == "sort_loadings") {
          cli::cli_li("Sort loadings: {.val {value}}")
        } else {
          # Generic fallback for unknown parameters
          cli::cli_li("{param}: {.val {value}}")
        }
      }
    }
    cli::cli_end()
  } else {
    # Analysis type without defined parameters yet - show generic info
    config_params <- setdiff(names(x), "analysis_type")
    if (length(config_params) > 0) {
      cli::cli_alert_info("Configuration parameters: {.val {config_params}}")
    } else {
      cli::cli_alert_info("No configuration parameters defined yet")
    }
  }

  invisible(x)
}

#' Print method for llm_args
#' @export
#' @keywords internal
print.llm_args <- function(x, ...) {
  cli::cli_h2("LLM Configuration")
  cli::cli_ul()
  cli::cli_li("Provider: {.val {x$llm_provider}}")
  cli::cli_li("Model: {.val {x$llm_model %||% '(provider default)'}}")
  cli::cli_li("Word limit: {.val {x$word_limit}}")
  cli::cli_li("System prompt: {.val {if(is.null(x$system_prompt)) '(default)' else 'custom'}}")
  cli::cli_li("Echo: {.val {x$echo}}")
  cli::cli_end()
  invisible(x)
}

#' Print method for output_args
#' @export
#' @keywords internal
print.output_args <- function(x, ...) {
  cli::cli_h2("Output Configuration")
  cli::cli_ul()
  cli::cli_li("Format: {.val {x$format}}")
  cli::cli_li("Heading level: {.val {x$heading_level}}")
  cli::cli_li("Suppress heading: {.val {x$suppress_heading}}")
  cli::cli_li("Max line length: {.val {x$max_line_length}}")
  cli::cli_li("Silent: {.val {x$silent}}")
  cli::cli_end()
  invisible(x)
}

# ==============================================================================
# BUILDER FUNCTIONS FOR DUAL INTERFACE
# ==============================================================================

#' Build LLM Arguments from Multiple Sources
#'
#' Internal helper that merges direct arguments (llm_provider, llm_model) with
#' llm_args config object. Implements dual interface pattern.
#'
#' @param llm_args llm_args object, list, or NULL
#' @param llm_provider Character or NULL
#' @param llm_model Character or NULL
#' @param ... Additional arguments to merge
#'
#' @return llm_args object
#' @keywords internal
#' @noRd
build_llm_args <- function(llm_args = NULL, llm_provider = NULL, llm_model = NULL, ...) {
  # If llm_args provided, validate and use it
  if (!is.null(llm_args)) {
    # Convert list to llm_args if needed
    if (is.list(llm_args) && !inherits(llm_args, "llm_args")) {
      llm_args <- do.call("llm_args", llm_args)
    }
    # Merge with direct args if provided
    if (!is.null(llm_provider)) llm_args$llm_provider <- llm_provider
    if (!is.null(llm_model)) llm_args$llm_model <- llm_model
    return(llm_args)
  }

  # Otherwise build from direct args
  if (!is.null(llm_provider)) {
    # Filter ... to only include valid llm_args parameters
    dots <- list(...)
    valid_llm_params <- c("system_prompt", "params", "word_limit",
                          "interpretation_guidelines", "additional_info", "echo")
    llm_dots <- dots[names(dots) %in% valid_llm_params]

    return(do.call("llm_args", c(list(llm_provider = llm_provider, llm_model = llm_model), llm_dots)))
  }

  # Nothing provided
  NULL
}


#' Build Interpretation Arguments from Config Object
#'
#' Internal helper that validates and normalizes interpretation configuration
#' for any model type.
#'
#' @param interpretation_args interpretation_args object, list, or NULL
#' @param analysis_type Character or NULL. Analysis type to infer parameters
#' @param ... Additional arguments (filtered to valid interpretation_args parameters)
#'
#' @return interpretation_args object or NULL
#' @keywords internal
#' @noRd
build_interpretation_args <- function(interpretation_args = NULL, analysis_type = NULL, ...) {
  # If interpretation_args provided, validate and use it
  if (!is.null(interpretation_args)) {
    # Convert list to interpretation_args if needed
    if (is.list(interpretation_args) && !inherits(interpretation_args, "interpretation_args")) {
      # Need analysis_type to build
      if (is.null(interpretation_args$analysis_type) && is.null(analysis_type)) {
        cli::cli_abort(
          c(
            "Cannot build interpretation_args without analysis_type",
            "i" = "Provide analysis_type in the list or as a parameter"
          )
        )
      }
      mt <- interpretation_args$analysis_type %||% analysis_type
      interpretation_args <- do.call("interpretation_args", c(list(analysis_type = mt), interpretation_args))
    }
    return(interpretation_args)
  }

  # Check if any valid parameters in ... based on analysis_type
  if (!is.null(analysis_type)) {
    dots <- list(...)

    # Get valid params via dispatch table
    valid_params <- .get_valid_interpretation_params(analysis_type)

    model_dots <- dots[names(dots) %in% valid_params]

    # If we have model-specific parameters, build interpretation_args
    if (length(model_dots) > 0) {
      return(do.call("interpretation_args", c(list(analysis_type = analysis_type), model_dots)))
    }
  }

  NULL
}


#' Build Output Arguments from Config Object
#'
#' Internal helper that validates and normalizes output configuration.
#'
#' @param output_args output_args object, list, or NULL
#' @param ... Additional arguments (filtered to valid output_args parameters)
#'
#' @return output_args object or NULL
#' @keywords internal
#' @noRd
build_output_args <- function(output_args = NULL, ...) {
  # If output_args provided, validate and use it
  if (!is.null(output_args)) {
    # Convert list to output_args if needed
    if (is.list(output_args) && !inherits(output_args, "output_args")) {
      output_args <- do.call("output_args", output_args)
    }
    return(output_args)
  }

  # Check if any valid output parameters in ...
  dots <- list(...)
  valid_output_params <- c("format", "heading_level", "suppress_heading",
                           "max_line_length", "silent")
  output_dots <- dots[names(dots) %in% valid_output_params]

  # If we have output parameters, build output_args
  if (length(output_dots) > 0) {
    return(do.call("output_args", output_dots))
  }

  NULL
}


# ==============================================================================
# FUTURE MODEL TYPE BUILDERS (NOT YET IMPLEMENTED)
# ==============================================================================
#
# Uncomment when implementing GM, IRT, or CDM support
# These follow the same pattern as build_interpretation_args() above
# ==============================================================================

# #' Build GM Arguments (Internal)
# #' @keywords internal
# #' @noRd
# build_gm_args <- function(gm_args = NULL, ...) {
#   if (!is.null(gm_args)) {
#     if (is.list(gm_args) && !inherits(gm_args, "gm_args")) {
#       gm_args <- do.call("gm_args", gm_args)
#     }
#     return(gm_args)
#   }
#
#   dots <- list(...)
#   valid_gm_params <- c("n_components", "covariance_type")
#   gm_dots <- dots[names(dots) %in% valid_gm_params]
#
#   if (length(gm_dots) > 0) {
#     return(do.call("gm_args", gm_dots))
#   }
#
#   NULL
# }

# #' Build IRT Arguments (Internal)
# #' @keywords internal
# #' @noRd
# build_irt_args <- function(irt_args = NULL, ...) {
#   if (!is.null(irt_args)) {
#     if (is.list(irt_args) && !inherits(irt_args, "irt_args")) {
#       irt_args <- do.call("irt_args", irt_args)
#     }
#     return(irt_args)
#   }
#
#   dots <- list(...)
#   valid_irt_params <- c("model", "ability_method")
#   irt_dots <- dots[names(dots) %in% valid_irt_params]
#
#   if (length(irt_dots) > 0) {
#     return(do.call("irt_args", irt_dots))
#   }
#
#   NULL
# }

# #' Build CDM Arguments (Internal)
# #' @keywords internal
# #' @noRd
# build_cdm_args <- function(cdm_args = NULL, ...) {
#   if (!is.null(cdm_args)) {
#     if (is.list(cdm_args) && !inherits(cdm_args, "cdm_args")) {
#       cdm_args <- do.call("cdm_args", cdm_args)
#     }
#     return(cdm_args)
#   }
#
#   dots <- list(...)
#   valid_cdm_params <- c("cdm_type", "q_matrix")
#   cdm_dots <- dots[names(dots) %in% valid_cdm_params]
#
#   if (length(cdm_dots) > 0) {
#     return(do.call("cdm_args", cdm_dots))
#   }
#
#   NULL
# }
