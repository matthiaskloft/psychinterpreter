#' S3 Generics for Model-Specific Parameter Extraction
#'
#' These generics allow each model type to define its own parameter extraction
#' and validation logic, making the core interpret functions model-agnostic.
#'
#' @name parameter_extraction
#' @keywords internal
NULL


#' Extract Model-Specific Parameters from Config Objects
#'
#' S3 generic for extracting model-specific parameters from interpretation_args
#' configuration objects. This allows each model type to define what parameters
#' it needs without hardcoding them in core functions.
#'
#' @param analysis_type Object with model type class for S3 dispatch
#' @param interpretation_args List or config object with model parameters
#' @param ... Additional arguments for specific implementations
#'
#' @return Named list of extracted parameters
#' @export
#' @keywords internal
extract_model_parameters <- function(analysis_type, interpretation_args, ...) {
  UseMethod("extract_model_parameters")
}


#' Default Method for extract_model_parameters
#'
#' Returns an empty list for unknown model types.
#'
#' @param analysis_type Object with model type class
#' @param interpretation_args Config object
#' @param ... Additional arguments
#'
#' @return Empty list
#' @export
#' @keywords internal
extract_model_parameters.default <- function(analysis_type, interpretation_args, ...) {
  # For unknown model types, return empty list (no model-specific parameters)
  list()
}


#' Extract FA-Specific Parameters
#'
#' Extracts factor analysis specific parameters like cutoff, n_emergency,
#' hide_low_loadings, and sort_loadings from the interpretation_args.
#'
#' @param analysis_type FA analysis type object
#' @param interpretation_args Config object with FA parameters
#' @param ... Additional arguments
#'
#' @return Named list with FA-specific parameters
#' @export
#' @keywords internal
extract_model_parameters.fa <- function(analysis_type, interpretation_args, ...) {
  # Extract FA-specific parameters with defaults
  params <- list()

  if (!is.null(interpretation_args)) {
    # Extract FA-specific parameters
    if ("cutoff" %in% names(interpretation_args)) {
      params$cutoff <- interpretation_args$cutoff
    }
    if ("n_emergency" %in% names(interpretation_args)) {
      params$n_emergency <- interpretation_args$n_emergency
    }
    if ("hide_low_loadings" %in% names(interpretation_args)) {
      params$hide_low_loadings <- interpretation_args$hide_low_loadings
    }
    if ("sort_loadings" %in% names(interpretation_args)) {
      params$sort_loadings <- interpretation_args$sort_loadings
    }
  }

  params
}


#' Validate Model-Specific Requirements
#'
#' S3 generic for validating that model-specific requirements are met.
#' This includes checking for required data like variable_info for FA.
#'
#' @param analysis_type Object with model type class for S3 dispatch
#' @param ... Model-specific data to validate (e.g., variable_info for FA)
#'
#' @return Invisible NULL if validation passes, errors if not
#' @export
#' @keywords internal
validate_model_requirements <- function(analysis_type, ...) {
  UseMethod("validate_model_requirements")
}


#' Default Method for validate_model_requirements
#'
#' No validation for unknown model types.
#'
#' @param analysis_type Object with model type class
#' @param ... Additional arguments
#'
#' @return Invisible NULL
#' @export
#' @keywords internal
validate_model_requirements.default <- function(analysis_type, ...) {
  # No validation for unknown types
  invisible(NULL)
}


#' Validate FA Requirements
#'
#' Validates that variable_info is provided for factor analysis.
#'
#' @param analysis_type FA analysis type object
#' @param ... Should include variable_info
#'
#' @return Invisible NULL if valid, errors if not
#' @export
#' @keywords internal
validate_model_requirements.fa <- function(analysis_type, ...) {
  dots <- list(...)
  variable_info <- dots$variable_info

  # FA requires variable_info
  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} is required for factor analysis interpretation",
        "i" = "Provide a data frame with 'variable' and 'description' columns",
        "i" = "Example: data.frame(variable = c('var1', 'var2'), description = c('Description 1', 'Description 2'))"
      )
    )
  }

  # Validate structure
  if (!is.data.frame(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} must be a data frame",
        "x" = "You provided: {.cls {class(variable_info)}}"
      )
    )
  }

  if (!all(c("variable", "description") %in% names(variable_info))) {
    cli::cli_abort(
      c(
        "{.var variable_info} must have 'variable' and 'description' columns",
        "x" = "Found columns: {.val {names(variable_info)}}"
      )
    )
  }

  invisible(NULL)
}


#' Extract GM-Specific Parameters
#'
#' Extracts Gaussian Mixture Model specific parameters from interpretation_args,
#' including cluster configuration, separation thresholds, and uncertainty settings.
#'
#' @param analysis_type GM analysis type object
#' @param interpretation_args Config object containing GM parameters (n_clusters,
#'   covariance_type, min_cluster_size, separation_threshold, weight_by_uncertainty,
#'   profile_variables)
#' @param ... Additional arguments
#'
#' @return Named list with GM parameters extracted from interpretation_args
#' @export
#' @keywords internal
extract_model_parameters.gm <- function(analysis_type, interpretation_args, ...) {
  # Extract GM-specific parameters from interpretation_args
  params <- list()

  if (!is.null(interpretation_args)) {
    if ("n_clusters" %in% names(interpretation_args)) {
      params$n_clusters <- interpretation_args$n_clusters
    }
    if ("covariance_type" %in% names(interpretation_args)) {
      params$covariance_type <- interpretation_args$covariance_type
    }
  }

  params
}


#' Validate GM Requirements
#'
#' Validates requirements for Gaussian Mixture Model interpretations. Unlike FA,
#' GM does not strictly require variable_info (cluster names can be assigned
#' without variable descriptions), but variable_info is recommended for
#' meaningful interpretations.
#'
#' @param analysis_type GM analysis type object
#' @param ... Additional arguments (may include fit_results for future validation)
#'
#' @return Invisible NULL (validation failures throw errors via cli::cli_abort)
#' @export
#' @keywords internal
validate_model_requirements.gm <- function(analysis_type, ...) {
  # GM doesn't strictly require variable_info, but it's recommended
  # Future: Could validate cluster counts, covariance structures, etc.
  invisible(NULL)
}
