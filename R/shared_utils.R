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


#' Show Available Parameters for interpret()
#'
#' Displays all available parameters for \code{\link{interpret}} with their defaults,
#' types, valid ranges, and descriptions. Organizes parameters by configuration group
#' (llm_args, output_args, interpretation_args) using CLI-formatted output.
#'
#' @param analysis_type Character or NULL. Model type to show parameters for:
#'   \itemize{
#'     \item NULL (default): Shows common parameters (llm_args + output_args) applicable to all models
#'     \item "fa": Shows all parameters including FA-specific interpretation_args
#'     \item "gm": Shows all parameters including GM-specific interpretation_args
#'   }
#'   When NULL, displays a message suggesting available analysis types.
#'
#' @return Invisibly returns a data.frame with parameter metadata. Primary output
#'   is CLI-formatted text printed to console.
#'
#' @details
#' This function queries the centralized PARAMETER_REGISTRY to show current defaults
#' and parameter specifications. It's particularly useful for:
#' \itemize{
#'   \item Discovering available parameters for a specific model type
#'   \item Checking default values before customizing
#'   \item Understanding parameter types and valid ranges
#'   \item Learning what each parameter controls
#' }
#'
#' Parameters are organized by configuration group:
#' \itemize{
#'   \item \strong{LLM Arguments (llm_args)}: Control LLM behavior (provider, model, word_limit, etc.)
#'   \item \strong{Output Arguments (output_args)}: Control output formatting (format, silent, etc.)
#'   \item \strong{Interpretation Arguments (interpretation_args)}: Model-specific settings (cutoff for FA, min_cluster_size for GM, etc.)
#' }
#'
#' @export
#'
#' @examples
#' # Show common parameters for all models
#' show_interpret_args()
#'
#' \donttest{
#' # Show all parameters for Factor Analysis
#' show_interpret_args("fa")
#'
#' # Show all parameters for Gaussian Mixture Models
#' show_interpret_args("gm")
#'
#' # Capture parameter data programmatically
#' params <- show_interpret_args("fa")
#' print(params)
#' }
show_interpret_args <- function(analysis_type = NULL) {

  # Validate analysis_type if provided
  if (!is.null(analysis_type)) {
    if (!is.character(analysis_type) || length(analysis_type) != 1) {
      cli::cli_abort("{.arg analysis_type} must be a single character string or NULL")
    }

    valid_types <- c("fa", "gm", "irt", "cdm")
    if (!analysis_type %in% valid_types) {
      cli::cli_abort(
        c(
          "Invalid {.arg analysis_type}: {.val {analysis_type}}",
          "i" = "Valid types: {.val {valid_types}}"
        )
      )
    }

    # Warn if not yet implemented
    if (analysis_type %in% c("irt", "cdm")) {
      cli::cli_warn(
        c(
          "!" = "{.val {analysis_type}} model type not yet implemented",
          "i" = "Currently implemented: {.val {c('fa', 'gm')}}"
        )
      )
    }
  }

  # Show info message when analysis_type is NULL
  if (is.null(analysis_type)) {
    cli::cli_alert_info("Showing common parameters for {.fn interpret}")
    cli::cli_alert_info(
      "Specify {.code analysis_type = 'fa'} or {.code analysis_type = 'gm'} to see model-specific {.arg interpretation_args}"
    )
    cli::cat_line()
  }

  # Build parameter data.frame for return value
  param_df <- data.frame(
    parameter = character(),
    default = character(),
    type = character(),
    range_or_values = character(),
    config_group = character(),
    description = character(),
    stringsAsFactors = FALSE
  )

  # Helper function to format default values
  format_default <- function(val) {
    if (is.null(val)) {
      return("NULL")
    } else if (is.character(val)) {
      return(paste0('"', val, '"'))
    } else if (is.logical(val)) {
      return(as.character(val))
    } else {
      return(as.character(val))
    }
  }

  # Helper function to format range/allowed values
  format_range_values <- function(param_spec) {
    if (!is.null(param_spec$allowed_values)) {
      return(paste(paste0('"', param_spec$allowed_values, '"'), collapse = ", "))
    } else if (!is.null(param_spec$range)) {
      if (any(is.infinite(param_spec$range))) {
        return(paste0(param_spec$range[1], "+"))
      } else {
        return(paste0(param_spec$range[1], "-", param_spec$range[2]))
      }
    } else {
      return("-")
    }
  }

  # Helper function to print parameter section
  print_param_group <- function(group_name, params_list, header_suffix = "") {
    if (length(params_list) == 0) return()

    # Print section header
    header_text <- paste0(
      toupper(substring(group_name, 1, 1)),
      substring(group_name, 2)
    )
    header_text <- gsub("_", " ", header_text)
    if (nchar(header_suffix) > 0) {
      cli::cli_h2("{header_text} ({group_name}) {header_suffix}")
    } else {
      cli::cli_h2("{header_text} ({group_name})")
    }
    cli::cat_line()

    # Sort parameters by name for consistent display
    param_names <- sort(names(params_list))

    for (param_name in param_names) {
      param_spec <- params_list[[param_name]]

      # Build bullet points for this parameter
      bullets <- c()

      # Parameter name with type and required indicator
      type_suffix <- if (param_spec$required) " (required)" else ""
      bullets <- c(bullets, " " = paste0(
        "{.strong {param_name}} {.emph ({param_spec$type}{type_suffix})}"
      ))

      # Default value
      default_str <- format_default(param_spec$default)
      bullets <- c(bullets, " " = paste0("Default: {.val {default_str}}"))

      # Range or allowed values
      range_str <- format_range_values(param_spec)
      if (range_str != "-") {
        if (!is.null(param_spec$allowed_values)) {
          bullets <- c(bullets, " " = paste0("Allowed: {range_str}"))
        } else {
          bullets <- c(bullets, " " = paste0("Range: {range_str}"))
        }
      }

      # Description
      bullets <- c(bullets, " " = param_spec$description)

      # Print with cli_bullets
      cli::cli_bullets(bullets)
      cli::cat_line()
    }
  }

  # Get parameters for each group
  llm_params <- get_params_by_group("llm_args")
  output_params <- get_params_by_group("output_args")

  # Print LLM Arguments
  print_param_group("llm_args", llm_params)

  # Add to return dataframe
  for (param_name in names(llm_params)) {
    param_spec <- llm_params[[param_name]]
    param_df <- rbind(param_df, data.frame(
      parameter = param_name,
      default = format_default(param_spec$default),
      type = param_spec$type,
      range_or_values = format_range_values(param_spec),
      config_group = "llm_args",
      description = param_spec$description,
      stringsAsFactors = FALSE
    ))
  }

  # Print Output Arguments
  print_param_group("output_args", output_params)

  # Add to return dataframe
  for (param_name in names(output_params)) {
    param_spec <- output_params[[param_name]]
    param_df <- rbind(param_df, data.frame(
      parameter = param_name,
      default = format_default(param_spec$default),
      type = param_spec$type,
      range_or_values = format_range_values(param_spec),
      config_group = "output_args",
      description = param_spec$description,
      stringsAsFactors = FALSE
    ))
  }

  # Get and print interpretation_args if analysis_type specified
  if (!is.null(analysis_type)) {
    interp_params <- get_params_by_group("interpretation_args", model_type = analysis_type)

    if (length(interp_params) > 0) {
      suffix <- paste0("- ", toupper(analysis_type), " specific")
      print_param_group("interpretation_args", interp_params, header_suffix = suffix)

      # Add to return dataframe
      for (param_name in names(interp_params)) {
        param_spec <- interp_params[[param_name]]
        param_df <- rbind(param_df, data.frame(
          parameter = param_name,
          default = format_default(param_spec$default),
          type = param_spec$type,
          range_or_values = format_range_values(param_spec),
          config_group = "interpretation_args",
          description = param_spec$description,
          stringsAsFactors = FALSE
        ))
      }
    }
  }

  # Return dataframe invisibly
  invisible(param_df)
}


