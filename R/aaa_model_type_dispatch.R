# ==============================================================================
# MODEL TYPE DISPATCH TABLES
# ==============================================================================
#
# Centralized dispatch system for model type checking and validation.
# This replaces complex inherits() checks with a clean, extensible dispatch table.
#

#' Get Model Type Dispatch Table
#'
#' Returns a dispatch table mapping model class names to their:
#' - analysis_type: The type of analysis they support (e.g., "fa")
#' - package: The package that provides the class
#' - validator_name: Name of the function that validates the model structure
#' - extractor_name: Name of the function that extracts model data
#'
#' This is a function rather than a static list to avoid initialization order issues.
#'
#' @keywords internal
#' @noRd
get_model_dispatch_table <- function() {
  list(
    # psych package models
    fa = list(
      analysis_type = "fa",
      package = "psych",
      validator_name = "validate_psych_model",
      extractor_name = "extract_psych_loadings"
    ),
    principal = list(
      analysis_type = "fa",
      package = "psych",
      validator_name = "validate_psych_model",
      extractor_name = "extract_psych_loadings"
    ),
    psych = list(
      analysis_type = "fa",
      package = "psych",
      validator_name = "validate_psych_model",
      extractor_name = "extract_psych_loadings"
    ),

    # lavaan package models
    lavaan = list(
      analysis_type = "fa",
      package = "lavaan",
      validator_name = "validate_lavaan_model",
      extractor_name = "extract_lavaan_loadings"
    ),
    efaList = list(
      analysis_type = "fa",
      package = "lavaan",
      validator_name = "validate_efalist_model",
      extractor_name = "extract_efalist_loadings"
    ),

    # mirt package models
    SingleGroupClass = list(
      analysis_type = "fa",
      package = "mirt",
      validator_name = "validate_mirt_model",
      extractor_name = "extract_mirt_loadings"
    ),

    # mclust package models
    Mclust = list(
      analysis_type = "gm",
      package = "mclust",
      validator_name = "validate_mclust_model",
      extractor_name = "extract_mclust_data"
    )
  )
}


#' Check if an Object is a Supported Model Type
#'
#' Uses the dispatch table to determine if an object's class matches any
#' registered model type.
#'
#' @param obj An object to check
#' @return Logical. TRUE if the object is a supported model type, FALSE otherwise
#' @keywords internal
#' @noRd
is_supported_model <- function(obj) {
  if (is.null(obj) || is.null(class(obj))) {
    return(FALSE)
  }

  # Get dispatch table and check if any of the object's classes are in it
  dispatch_table <- get_model_dispatch_table()
  any(class(obj) %in% names(dispatch_table))
}


#' Get Model Type Information from Dispatch Table
#'
#' Retrieves the dispatch information for a given model object.
#' Uses the first matching class in the object's class vector.
#'
#' @param obj A model object
#' @return List with analysis_type, package, validator_name, and extractor_name, or NULL if not found
#' @keywords internal
#' @noRd
get_model_info <- function(obj) {
  if (is.null(obj) || is.null(class(obj))) {
    return(NULL)
  }

  # Get dispatch table
  dispatch_table <- get_model_dispatch_table()

  # Find first matching class in dispatch table
  for (cls in class(obj)) {
    if (cls %in% names(dispatch_table)) {
      return(dispatch_table[[cls]])
    }
  }

  return(NULL)
}


#' Validate Model Structure Using Dispatch Table
#'
#' Calls the appropriate validator function for a given model object.
#'
#' @param model A model object
#' @return NULL invisibly if validation passes, errors otherwise
#' @keywords internal
#' @noRd
validate_model_structure <- function(model) {
  model_info <- get_model_info(model)

  if (is.null(model_info)) {
    cli::cli_abort(
      c(
        "Unsupported model type: {.cls {class(model)}}",
        "i" = "Supported models:",
        " " = "- psych: fa, principal",
        " " = "- lavaan: lavaan (cfa/sem), efaList (efa)",
        " " = "- mirt: SingleGroupClass"
      )
    )
  }

  # Get the validator function by name and call it
  validator_fn <- get(model_info$validator_name, mode = "function")
  validator_fn(model)

  invisible(NULL)
}


# ==============================================================================
# MODEL VALIDATORS
# ==============================================================================
# These functions validate that a model object has the required structure
# for interpretation.

#' Validate psych Package Models
#'
#' @param model A psych::fa() or psych::principal() model
#' @return NULL invisibly if valid, errors otherwise
#' @keywords internal
#' @noRd
validate_psych_model <- function(model) {
  if (!inherits(model, "psych") && !inherits(model, "principal") && !inherits(model, "fa")) {
    cli::cli_abort(
      c(
        "Model must inherit from {.cls psych}, {.cls fa}, or {.cls principal}",
        "x" = "Got class: {.cls {class(model)}}"
      )
    )
  }

  if (is.null(model$loadings)) {
    cli::cli_abort("Model does not contain loadings component")
  }

  invisible(NULL)
}


#' Validate lavaan Package Models (CFA/SEM)
#'
#' @param model A lavaan::cfa() or lavaan::sem() model
#' @return NULL invisibly if valid, errors otherwise
#' @keywords internal
#' @noRd
validate_lavaan_model <- function(model) {
  if (!inherits(model, "lavaan")) {
    cli::cli_abort(
      c(
        "Model must inherit from {.cls lavaan}",
        "x" = "Got class: {.cls {class(model)}}"
      )
    )
  }

  # Check if lavaan package is available
  if (!requireNamespace("lavaan", quietly = TRUE)) {
    cli::cli_abort(
      c(
        "Package {.pkg lavaan} is required to interpret lavaan models",
        "i" = "Install with: install.packages('lavaan')"
      )
    )
  }

  invisible(NULL)
}


#' Validate lavaan::efa() efaList Models
#'
#' @param model A lavaan::efa() model (efaList class)
#' @return NULL invisibly if valid, errors otherwise
#' @keywords internal
#' @noRd
validate_efalist_model <- function(model) {
  if (!inherits(model, "efaList")) {
    cli::cli_abort(
      c(
        "Model must inherit from {.cls efaList}",
        "x" = "Got class: {.cls {class(model)}}"
      )
    )
  }

  # Check if lavaan package is available
  if (!requireNamespace("lavaan", quietly = TRUE)) {
    cli::cli_abort(
      c(
        "Package {.pkg lavaan} is required to interpret lavaan::efa models",
        "i" = "Install with: install.packages('lavaan')"
      )
    )
  }

  invisible(NULL)
}


#' Validate mirt Package Models
#'
#' @param model A mirt::mirt() model
#' @return NULL invisibly if valid, errors otherwise
#' @keywords internal
#' @noRd
validate_mirt_model <- function(model) {
  if (!inherits(model, "SingleGroupClass")) {
    cli::cli_abort(
      c(
        "Model must inherit from {.cls SingleGroupClass}",
        "x" = "Got class: {.cls {class(model)}}"
      )
    )
  }

  # Check if mirt package is available
  if (!requireNamespace("mirt", quietly = TRUE)) {
    cli::cli_abort(
      c(
        "Package {.pkg mirt} is required to interpret mirt models",
        "i" = "Install with: install.packages('mirt')"
      )
    )
  }

  invisible(NULL)
}


#' Validate mclust Package Models
#'
#' @param model A mclust::Mclust() model
#' @return NULL invisibly if valid, errors otherwise
#' @keywords internal
#' @noRd
validate_mclust_model <- function(model) {
  if (!inherits(model, "Mclust")) {
    cli::cli_abort(
      c(
        "Model must inherit from {.cls Mclust}",
        "x" = "Got class: {.cls {class(model)}}"
      )
    )
  }

  # Check if mclust package is available
  if (!requireNamespace("mclust", quietly = TRUE)) {
    cli::cli_abort(
      c(
        "Package {.pkg mclust} is required to interpret mclust models",
        "i" = "Install with: install.packages('mclust')"
      )
    )
  }

  # Check if model has required components
  if (is.null(model$parameters) || is.null(model$parameters$mean)) {
    cli::cli_abort("Model does not contain parameters$mean component")
  }

  invisible(NULL)
}


#' Extract GM Data from mclust Models
#'
#' @param model A mclust::Mclust() model
#' @return List with GM data components
#' @keywords internal
#' @noRd
extract_mclust_data <- function(model) {
  # This is a placeholder - actual extraction is handled by build_analysis_data.Mclust()
  # We just return the model as-is since build_analysis_data.Mclust() does the real work
  list(model = model)
}


# ==============================================================================
# MODEL EXTRACTORS
# ==============================================================================
# These functions extract loadings and factor correlations from model objects.
# They are used by build_analysis_data methods.

#' Extract Loadings from psych Models
#'
#' @param model A psych::fa() or psych::principal() model
#' @return List with loadings and factor_cor_mat components
#' @keywords internal
#' @noRd
extract_psych_loadings <- function(model) {
  # Extract loadings (pattern matrix)
  loadings <- as.data.frame(unclass(model$loadings))

  # Extract factor correlations if oblique rotation
  factor_cor_mat <- if (!is.null(model$Phi)) model$Phi else NULL

  # Extract structure matrix if available (for oblique rotations)
  # This is needed for correct variance calculation
  structure_matrix <- if (!is.null(model$Structure)) {
    as.data.frame(unclass(model$Structure))
  } else {
    NULL
  }

  list(
    loadings = loadings,
    factor_cor_mat = factor_cor_mat,
    structure_matrix = structure_matrix
  )
}


#' Extract Loadings from lavaan Models
#'
#' @param model A lavaan::cfa() or lavaan::sem() model
#' @return List with loadings and factor_cor_mat components
#' @keywords internal
#' @noRd
extract_lavaan_loadings <- function(model) {
  # Check if lavaan package is available
  if (!requireNamespace("lavaan", quietly = TRUE)) {
    cli::cli_abort(
      c(
        "Package {.pkg lavaan} is required to extract lavaan model data",
        "i" = "Install with: install.packages('lavaan')"
      )
    )
  }

  # Extract standardized loadings
  loadings_matrix <- lavaan::inspect(model, what = "std")$lambda

  # Extract factor correlations
  factor_cor_mat <- lavaan::inspect(model, what = "cor.lv")
  if (is.null(dim(factor_cor_mat)) || all(factor_cor_mat == diag(nrow(factor_cor_mat)))) {
    factor_cor_mat <- NULL  # Orthogonal factors
  }

  list(
    loadings = loadings_matrix,
    factor_cor_mat = factor_cor_mat
  )
}


#' Extract Loadings from lavaan::efa() Models
#'
#' @param model A lavaan::efa() model (efaList class)
#' @return List with loadings and factor_cor_mat components
#' @keywords internal
#' @noRd
extract_efalist_loadings <- function(model) {
  # Extract loadings using stats::loadings() which works on efaList
  loadings_obj <- loadings(model)

  # Convert to data frame
  loadings <- as.data.frame(unclass(loadings_obj))

  # Try to extract factor correlations from efaList structure
  factor_cor_mat <- NULL
  if (!is.null(model$rotation) && !is.null(model$rotation$phi)) {
    factor_cor_mat <- model$rotation$phi
  }

  list(
    loadings = loadings,
    factor_cor_mat = factor_cor_mat
  )
}


#' Extract Loadings from mirt Models
#'
#' @param model A mirt::mirt() model
#' @return List with loadings and factor_cor_mat components
#' @keywords internal
#' @noRd
extract_mirt_loadings <- function(model) {
  # Check if mirt package is available
  if (!requireNamespace("mirt", quietly = TRUE)) {
    cli::cli_abort(
      c(
        "Package {.pkg mirt} is required to extract mirt model data",
        "i" = "Install with: install.packages('mirt')"
      )
    )
  }

  # Extract standardized loadings
  loadings_matrix <- mirt::summary(model, suppress = 1000)$rotF

  # Extract factor correlations if oblique
  factor_cor_mat <- mirt::summary(model, suppress = 1000)$fcor
  if (is.null(factor_cor_mat) || all(factor_cor_mat == diag(nrow(factor_cor_mat)))) {
    factor_cor_mat <- NULL  # Orthogonal factors
  }

  list(
    loadings = loadings_matrix,
    factor_cor_mat = factor_cor_mat
  )
}
