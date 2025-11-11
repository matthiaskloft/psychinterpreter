# ==============================================================================
# CONFIGURATION OBJECTS FOR PSYCHINTERPRETER
# ==============================================================================
# This file provides constructor functions for configuration objects used
# across the package. These objects group related parameters and provide
# validation, making the API cleaner and more maintainable.

#' Create Model-Specific Interpretation Configuration
#'
#' Creates a configuration object for interpretation settings. The available
#' parameters depend on the model_type.
#'
#' @param model_type Character. Type of analysis: "fa" (factor analysis),
#'   "gm" (gaussian mixture), "irt" (item response theory), or "cdm"
#'   (cognitive diagnosis model)
#' @param ... Model-specific parameters. For FA: cutoff, n_emergency,
#'   hide_low_loadings, sort_loadings. See Details.
#'
#' @return A list with class "interpretation_args" containing validated settings
#'
#' @details
#' **Factor Analysis (model_type = "fa"):**
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
#' cfg <- interpretation_args(model_type = "fa")
#'
#' # Factor analysis with custom settings
#' cfg <- interpretation_args(
#'   model_type = "fa",
#'   cutoff = 0.4,
#'   n_emergency = 3,
#'   hide_low_loadings = TRUE
#' )
interpretation_args <- function(model_type, ...) {
  # Validate model_type
  validate_model_type(model_type)

  # Delegate to model-specific constructor
  if (model_type == "fa") {
    return(interpretation_args_fa(...))
  } else if (model_type == "gm") {
    cli::cli_abort(
      c(
        "Gaussian Mixture (gm) interpretation not yet implemented",
        "i" = "Currently only 'fa' (factor analysis) is supported"
      )
    )
  } else if (model_type == "irt") {
    cli::cli_abort(
      c(
        "IRT interpretation not yet implemented",
        "i" = "Currently only 'fa' (factor analysis) is supported"
      )
    )
  } else if (model_type == "cdm") {
    cli::cli_abort(
      c(
        "CDM interpretation not yet implemented",
        "i" = "Currently only 'fa' (factor analysis) is supported"
      )
    )
  }
}

#' Create FA-Specific Interpretation Args (Internal)
#'
#' @keywords internal
#' @noRd
interpretation_args_fa <- function(cutoff = 0.3,
                                   n_emergency = 2,
                                   hide_low_loadings = FALSE,
                                   sort_loadings = TRUE) {
  # Validate cutoff
  if (!is.numeric(cutoff) || length(cutoff) != 1) {
    cli::cli_abort("{.arg cutoff} must be a single numeric value")
  }
  if (cutoff < 0 || cutoff > 1) {
    cli::cli_abort("{.arg cutoff} must be between 0 and 1 (got {.val {cutoff}})")
  }

  # Validate n_emergency
  if (!is.numeric(n_emergency) || length(n_emergency) != 1) {
    cli::cli_abort("{.arg n_emergency} must be a single integer value")
  }
  if (n_emergency < 0 || n_emergency != as.integer(n_emergency)) {
    cli::cli_abort("{.arg n_emergency} must be a non-negative integer (got {.val {n_emergency}})")
  }

  # Validate hide_low_loadings
  if (!is.logical(hide_low_loadings) || length(hide_low_loadings) != 1 || is.na(hide_low_loadings)) {
    cli::cli_abort("{.arg hide_low_loadings} must be TRUE or FALSE")
  }

  # Validate sort_loadings
  if (!is.logical(sort_loadings) || length(sort_loadings) != 1 || is.na(sort_loadings)) {
    cli::cli_abort("{.arg sort_loadings} must be TRUE or FALSE")
  }

  structure(
    list(
      model_type = "fa",
      cutoff = cutoff,
      n_emergency = as.integer(n_emergency),
      hide_low_loadings = hide_low_loadings,
      sort_loadings = sort_loadings
    ),
    class = c("interpretation_args", "model_config", "list")
  )
}


#' Create LLM Configuration
#'
#' Creates a configuration object for LLM interaction settings. Groups all
#' LLM-related parameters together.
#'
#' @param provider Character. LLM provider (e.g., "anthropic", "openai", "ollama")
#' @param model Character or NULL. Model name (e.g., "gpt-4o-mini", "claude-3-5-sonnet-20241022")
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
#' cfg <- llm_args(provider = "ollama", model = "gpt-oss:20b-cloud")
#'
#' # Advanced config
#' cfg <- llm_args(
#'   provider = "anthropic",
#'   model = "claude-3-5-sonnet-20241022",
#'   word_limit = 200,
#'   params = ellmer::params(temperature = 0.7, seed = 42)
#' )
llm_args <- function(provider,
                       model = NULL,
                       system_prompt = NULL,
                       params = NULL,
                       word_limit = 150,
                       interpretation_guidelines = NULL,
                       additional_info = NULL,
                       echo = "none") {

  # Validate provider (required)
  if (missing(provider) || is.null(provider)) {
    cli::cli_abort("{.arg provider} is required (e.g., 'ollama', 'anthropic', 'openai')")
  }
  if (!is.character(provider) || length(provider) != 1) {
    cli::cli_abort("{.arg provider} must be a single character string")
  }

  # Validate model (optional but recommended)
  if (!is.null(model) && (!is.character(model) || length(model) != 1)) {
    cli::cli_abort("{.arg model} must be a single character string or NULL")
  }

  # Validate system_prompt
  if (!is.null(system_prompt) && !is.character(system_prompt)) {
    cli::cli_abort("{.arg system_prompt} must be a character string or NULL")
  }

  # Validate params
  if (!is.null(params) && !is.list(params)) {
    cli::cli_abort(
      c(
        "{.arg params} must be created using ellmer::params()",
        "i" = "Example: params(temperature = 0.7, seed = 42)"
      )
    )
  }

  # Validate word_limit
  if (!is.numeric(word_limit) || length(word_limit) != 1) {
    cli::cli_abort("{.arg word_limit} must be a single numeric value")
  }
  if (word_limit < 20 || word_limit > 500) {
    cli::cli_abort(
      c(
        "{.arg word_limit} must be between 20 and 500",
        "i" = "Recommended range: 50-200 words"
      )
    )
  }

  # Validate interpretation_guidelines
  if (!is.null(interpretation_guidelines) && !is.character(interpretation_guidelines)) {
    cli::cli_abort("{.arg interpretation_guidelines} must be a character string or NULL")
  }

  # Validate additional_info
  if (!is.null(additional_info) && !is.character(additional_info)) {
    cli::cli_abort("{.arg additional_info} must be a character string or NULL")
  }

  # Validate echo
  if (!is.character(echo) || length(echo) != 1 || !echo %in% c("none", "output", "all")) {
    cli::cli_abort("{.arg echo} must be one of: 'none', 'output', 'all'")
  }

  structure(
    list(
      provider = provider,
      model = model,
      system_prompt = system_prompt,
      params = params,
      word_limit = as.integer(word_limit),
      interpretation_guidelines = interpretation_guidelines,
      additional_info = additional_info,
      echo = echo
    ),
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
output_args <- function(format = "cli",
                          heading_level = 1,
                          suppress_heading = FALSE,
                          max_line_length = 80,
                          silent = 0) {

  # Validate format
  if (!is.character(format) || length(format) != 1 || !format %in% c("cli", "markdown")) {
    cli::cli_abort("{.arg format} must be either 'cli' or 'markdown'")
  }

  # Validate heading_level
  if (!is.numeric(heading_level) || length(heading_level) != 1) {
    cli::cli_abort("{.arg heading_level} must be a single integer between 1 and 6")
  }
  if (heading_level < 1 || heading_level > 6 || heading_level != as.integer(heading_level)) {
    cli::cli_abort("{.arg heading_level} must be an integer between 1 and 6 (got {.val {heading_level}})")
  }

  # Validate suppress_heading
  if (!is.logical(suppress_heading) || length(suppress_heading) != 1 || is.na(suppress_heading)) {
    cli::cli_abort("{.arg suppress_heading} must be TRUE or FALSE")
  }

  # Validate max_line_length
  if (!is.numeric(max_line_length) || length(max_line_length) != 1) {
    cli::cli_abort("{.arg max_line_length} must be a single integer")
  }
  if (max_line_length < 40 || max_line_length > 300) {
    cli::cli_abort(
      c(
        "{.arg max_line_length} must be between 40 and 300",
        "i" = "Recommended: 80-120 for console output"
      )
    )
  }

  # Validate and normalize silent
  if (is.logical(silent)) {
    silent <- ifelse(silent, 2L, 0L)  # Convert logical to integer
  } else if (!is.numeric(silent) || length(silent) != 1) {
    cli::cli_abort("{.arg silent} must be logical (TRUE/FALSE) or integer (0/1/2)")
  } else if (!silent %in% c(0, 1, 2)) {
    cli::cli_abort("{.arg silent} must be 0, 1, or 2 (got {.val {silent}})")
  }

  structure(
    list(
      format = format,
      heading_level = as.integer(heading_level),
      suppress_heading = suppress_heading,
      max_line_length = as.integer(max_line_length),
      silent = as.integer(silent)
    ),
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
  # Get model type name
  model_type_names <- c(
    fa = "Factor Analysis",
    gm = "Gaussian Mixture",
    irt = "Item Response Theory",
    cdm = "Cognitive Diagnosis"
  )
  model_name <- model_type_names[x$model_type] %||% x$model_type

  cli::cli_h2("{model_name} Interpretation Configuration")

  # Print model-specific parameters
  if (x$model_type == "fa") {
    cli::cli_ul()
    cli::cli_li("Cutoff: {.val {x$cutoff}}")
    cli::cli_li("Emergency rule: Use top {.val {x$n_emergency}} loadings")
    cli::cli_li("Hide low loadings: {.val {x$hide_low_loadings}}")
    cli::cli_li("Sort loadings: {.val {x$sort_loadings}}")
    cli::cli_end()
  } else {
    # Future model types
    cli::cli_alert_info("Configuration: {.val {names(x)}}")
  }

  invisible(x)
}

#' Print method for llm_args
#' @export
#' @keywords internal
print.llm_args <- function(x, ...) {
  cli::cli_h2("LLM Configuration")
  cli::cli_ul()
  cli::cli_li("Provider: {.val {x$provider}}")
  cli::cli_li("Model: {.val {x$model %||% '(provider default)'}}")
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
#' Internal helper that merges direct arguments (provider, model) with
#' llm_args config object. Implements dual interface pattern.
#'
#' @param llm_args llm_args object, list, or NULL
#' @param provider Character or NULL
#' @param model Character or NULL
#' @param ... Additional arguments to merge
#'
#' @return llm_args object
#' @keywords internal
#' @noRd
build_llm_args <- function(llm_args = NULL, provider = NULL, model = NULL, ...) {
  # If llm_args provided, validate and use it
  if (!is.null(llm_args)) {
    # Convert list to llm_args if needed
    if (is.list(llm_args) && !inherits(llm_args, "llm_args")) {
      llm_args <- do.call("llm_args", llm_args)
    }
    # Merge with direct args if provided
    if (!is.null(provider)) llm_args$provider <- provider
    if (!is.null(model)) llm_args$model <- model
    return(llm_args)
  }

  # Otherwise build from direct args
  if (!is.null(provider)) {
    # Filter ... to only include valid llm_args parameters
    dots <- list(...)
    valid_llm_params <- c("system_prompt", "params", "word_limit",
                          "interpretation_guidelines", "additional_info", "echo")
    llm_dots <- dots[names(dots) %in% valid_llm_params]

    return(do.call("llm_args", c(list(provider = provider, model = model), llm_dots)))
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
#' @param model_type Character or NULL. Model type to infer parameters
#' @param ... Additional arguments (filtered to valid interpretation_args parameters)
#'
#' @return interpretation_args object or NULL
#' @keywords internal
#' @noRd
build_interpretation_args <- function(interpretation_args = NULL, model_type = NULL, ...) {
  # If interpretation_args provided, validate and use it
  if (!is.null(interpretation_args)) {
    # Convert list to interpretation_args if needed
    if (is.list(interpretation_args) && !inherits(interpretation_args, "interpretation_args")) {
      # Need model_type to build
      if (is.null(interpretation_args$model_type) && is.null(model_type)) {
        cli::cli_abort(
          c(
            "Cannot build interpretation_args without model_type",
            "i" = "Provide model_type in the list or as a parameter"
          )
        )
      }
      mt <- interpretation_args$model_type %||% model_type
      interpretation_args <- do.call("interpretation_args", c(list(model_type = mt), interpretation_args))
    }
    return(interpretation_args)
  }

  # Check if any valid parameters in ... based on model_type
  if (!is.null(model_type)) {
    dots <- list(...)

    # Define valid params per model type
    valid_params <- if (model_type == "fa") {
      c("cutoff", "n_emergency", "hide_low_loadings", "sort_loadings")
    } else {
      character(0)  # Future model types
    }

    model_dots <- dots[names(dots) %in% valid_params]

    # If we have model-specific parameters, build interpretation_args
    if (length(model_dots) > 0) {
      return(do.call("interpretation_args", c(list(model_type = model_type), model_dots)))
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
# These follow the same pattern as build_fa_args() above
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
