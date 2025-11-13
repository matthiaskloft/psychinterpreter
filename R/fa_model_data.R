#' Build Model Data for Factor Analysis (Internal Helper)
#'
#' Internal helper that extracts and validates FA-specific data from loadings
#' matrices, data frames, or lists. Called by all build_model_data S3 methods.
#'
#' @param fit_results Matrix, data.frame, or list containing factor loadings
#' @param variable_info Data frame with variable names and descriptions
#' @param model_type Character. Should be "fa" (used for validation)
#' @param interpretation_args FA interpretation configuration object from interpretation_args() or NULL
#' @param ... Additional arguments (cutoff, n_emergency, hide_low_loadings, etc.)
#'
#' @return List containing:
#'   \item{loadings_df}{Data frame with loadings and variable column}
#'   \item{factor_summaries}{List of summaries for each factor}
#'   \item{factor_cols}{Character vector of factor column names}
#'   \item{n_factors}{Integer number of factors}
#'   \item{n_variables}{Integer number of variables}
#'
#' @keywords internal
#' @noRd
#'
#' @importFrom dplyr left_join
#' @importFrom cli cli_abort
build_fa_model_data_internal <- function(fit_results, variable_info, model_type = "fa", interpretation_args = NULL, ...) {

  # Extract FA parameters from interpretation_args or ...
  dots <- list(...)

  # Extract from interpretation_args if provided and is a list
  cutoff <- if (!is.null(interpretation_args) && is.list(interpretation_args)) interpretation_args$cutoff else dots$cutoff
  if (is.null(cutoff)) cutoff <- 0.3

  n_emergency <- if (!is.null(interpretation_args) && is.list(interpretation_args)) interpretation_args$n_emergency else dots$n_emergency
  if (is.null(n_emergency)) n_emergency <- 2

  hide_low_loadings <- if (!is.null(interpretation_args) && is.list(interpretation_args)) interpretation_args$hide_low_loadings else dots$hide_low_loadings
  if (is.null(hide_low_loadings)) hide_low_loadings <- FALSE

  sort_loadings <- if (!is.null(interpretation_args) && is.list(interpretation_args)) interpretation_args$sort_loadings else dots$sort_loadings
  if (is.null(sort_loadings)) sort_loadings <- TRUE

  # Initialize factor_cor_mat (will be extracted from fit_results if available)
  factor_cor_mat <- NULL

  # ==========================================================================
  # STEP 1: VALIDATE FA PARAMETERS
  # ==========================================================================

  # Validate cutoff
  if (!is.numeric(cutoff) || length(cutoff) != 1 || cutoff < 0 || cutoff > 1) {
    cli::cli_abort("{.arg cutoff} must be a single numeric value between 0 and 1 (got {.val {cutoff}})")
  }

  # Validate n_emergency
  if (!is.numeric(n_emergency) || length(n_emergency) != 1 || n_emergency < 0 || n_emergency != as.integer(n_emergency)) {
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

  # ==========================================================================
  # STEP 2: EXTRACT LOADINGS FROM INPUT
  # ==========================================================================

  loadings <- NULL

  # Handle different input types
  if (is.list(fit_results) && !is.data.frame(fit_results)) {
    # List input - extract loadings component
    if (!"loadings" %in% names(fit_results)) {
      cli::cli_abort(
        c(
          "List input must contain a 'loadings' component",
          "x" = "Found components: {.field {names(fit_results)}}",
          "i" = "Use: list(loadings = your_loadings_matrix)"
        )
      )
    }
    loadings <- fit_results$loadings
    # Extract factor_cor_mat if provided in list
    if ("factor_cor_mat" %in% names(fit_results) && is.null(factor_cor_mat)) {
      factor_cor_mat <- fit_results$factor_cor_mat
    }
  } else {
    # Direct matrix/data.frame input
    loadings <- fit_results
  }

  # ==========================================================================
  # STEP 3: CONVERT TO DATA FRAME AND VALIDATE
  # ==========================================================================

  # Convert loadings to dataframe
  if (is.matrix(loadings) || inherits(loadings, "loadings")) {
    loadings_df <- as.data.frame(unclass(loadings))
    loadings_df$variable <- rownames(loadings_df)
  } else if (is.data.frame(loadings)) {
    loadings_df <- loadings
    if (!"variable" %in% names(loadings_df)) {
      loadings_df$variable <- rownames(loadings_df)
    }
  } else {
    cli::cli_abort(
      c(
        "loadings must be a matrix, data.frame, or list with loadings component",
        "x" = "Got {.cls {class(loadings)}}"
      )
    )
  }

  # Get factor names
  factor_cols <- setdiff(names(loadings_df), "variable")
  n_factors <- length(factor_cols)
  n_variables <- nrow(loadings_df)

  # Validate that there is at least one factor
  if (n_factors < 1) {
    cli::cli_abort(
      c(
        "loadings must contain at least one factor column",
        "x" = "Found only: {.field {names(loadings_df)}}",
        "i" = "Loadings should have variables as rows and factors as columns"
      )
    )
  }

  # Validate that loadings is not empty
  if (n_variables < 1) {
    cli::cli_abort("loadings must contain at least one variable (found 0 rows)")
  }

  # ==========================================================================
  # STEP 4: VALIDATE VARIABLE_INFO
  # ==========================================================================

  if (!is.data.frame(variable_info)) {
    cli::cli_abort("{.arg variable_info} must be a data frame")
  }
  if (!"variable" %in% names(variable_info)) {
    cli::cli_abort("{.arg variable_info} must contain a 'variable' column")
  }
  if (!"description" %in% names(variable_info)) {
    cli::cli_abort("{.arg variable_info} must contain a 'description' column")
  }

  # Check for variable matching
  missing_in_info <- setdiff(loadings_df$variable, variable_info$variable)
  missing_in_loadings <- setdiff(variable_info$variable, loadings_df$variable)

  if (length(missing_in_info) == nrow(loadings_df)) {
    cli::cli_abort(
      c(
        "No variables from loadings found in variable_info",
        "x" = "Check that the 'variable' column matches",
        "i" = "First few variables in loadings: {.val {head(loadings_df$variable, 3)}}"
      )
    )
  }

  if (length(missing_in_info) > 0) {
    cli::cli_abort(
      c(
        "Variables in loadings not found in variable_info:",
        "x" = "{.val {missing_in_info}}"
      )
    )
  }

  if (length(missing_in_loadings) > 0) {
    cli::cli_abort(
      c(
        "Variables in variable_info not found in loadings:",
        "x" = "{.val {missing_in_loadings}}"
      )
    )
  }

  # Merge with variable info
  loadings_with_info <- loadings_df |>
    dplyr::left_join(variable_info, by = "variable")

  # ==========================================================================
  # STEP 5: BUILD FACTOR SUMMARIES
  # ==========================================================================

  factor_summaries <- list()

  for (factor_name in factor_cols) {
    # Get absolute loadings for this factor
    abs_loadings <- abs(loadings_with_info[[factor_name]])

    # Find variables above cutoff
    significant_vars <- abs_loadings >= cutoff
    n_significant <- sum(significant_vars)

    # Apply emergency rule if needed
    used_emergency_rule <- FALSE
    if (n_significant == 0 && n_emergency > 0) {
      # No variables above cutoff - use top N
      top_n_idx <- order(abs_loadings, decreasing = TRUE)[1:min(n_emergency, length(abs_loadings))]
      significant_vars <- rep(FALSE, length(abs_loadings))
      significant_vars[top_n_idx] <- TRUE
      used_emergency_rule <- TRUE
      n_significant <- sum(significant_vars)
    }

    # Extract factor data
    if (n_significant > 0) {
      factor_data <- loadings_with_info[significant_vars, c("variable", "description", factor_name), drop = FALSE]
      names(factor_data)[3] <- "loading"

      # Sort by loading if requested
      if (sort_loadings) {
        factor_data <- factor_data[order(abs(factor_data$loading), decreasing = TRUE), , drop = FALSE]
      }

      # Calculate variance explained
      all_loadings <- loadings_with_info[[factor_name]]
      variance_explained <- sum(all_loadings^2) / length(all_loadings)
    } else {
      # No significant loadings (n_emergency = 0 case)
      factor_data <- data.frame(
        variable = character(0),
        description = character(0),
        loading = numeric(0)
      )
      variance_explained <- 0
    }

    # Store factor summary
    factor_summaries[[factor_name]] <- list(
      variables = factor_data,
      used_emergency_rule = used_emergency_rule,
      variance_explained = variance_explained
    )
  }

  # ==========================================================================
  # STEP 6: RETURN MODEL DATA
  # ==========================================================================

  list(
    model_type = model_type,
    loadings_df = loadings_df,
    factor_summaries = factor_summaries,
    factor_cols = factor_cols,
    n_factors = n_factors,
    n_variables = n_variables,
    factor_cor_mat = factor_cor_mat,
    cutoff = cutoff,
    n_emergency = n_emergency,
    hide_low_loadings = hide_low_loadings
  )
}


#' @rdname build_model_data
#' @export
#' @keywords internal
build_model_data.list <- function(fit_results, model_type = NULL, interpretation_args = NULL, ...) {
  # Extract parameters from ...
  dots <- list(...)
  variable_info <- dots$variable_info

  # For list input, determine model type and route
  if (is.null(model_type)) {
    cli::cli_abort(
      c(
        "model_type must be specified when fit_results is a list",
        "i" = "Use: interpret(..., model_type = 'fa')"
      )
    )
  }

  # Route to appropriate method based on model_type
  if (model_type == "fa") {
    # Validate variable_info is provided (required for FA)
    if (is.null(variable_info)) {
      cli::cli_abort(
        c(
          "{.var variable_info} is required for factor analysis",
          "i" = "Provide a data frame with 'variable' and 'description' columns"
        )
      )
    }
    build_fa_model_data_internal(fit_results, variable_info, model_type, interpretation_args, ...)
  } else {
    # Call default which will error with helpful message
    build_model_data.default(fit_results, model_type, interpretation_args, ...)
  }
}


#' @rdname build_model_data
#' @export
#' @keywords internal
build_model_data.matrix <- function(fit_results, model_type = "fa", interpretation_args = NULL, ...) {
  # Extract parameters from ...
  dots <- list(...)
  variable_info <- dots$variable_info

  # Validate variable_info is provided (required for FA)
  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} is required for factor analysis",
        "i" = "Provide a data frame with 'variable' and 'description' columns"
      )
    )
  }

  # Matrix input - treat as FA loadings
  build_fa_model_data_internal(fit_results, variable_info, model_type, interpretation_args, ...)
}


#' @rdname build_model_data
#' @export
#' @keywords internal
build_model_data.data.frame <- function(fit_results, model_type = "fa", interpretation_args = NULL, ...) {
  # Extract parameters from ...
  dots <- list(...)
  variable_info <- dots$variable_info

  # Validate variable_info is provided (required for FA)
  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} is required for factor analysis",
        "i" = "Provide a data frame with 'variable' and 'description' columns"
      )
    )
  }

  # Data frame input - treat as FA loadings
  build_fa_model_data_internal(fit_results, variable_info, model_type, interpretation_args, ...)
}


# ==============================================================================
# METHODS FOR FITTED MODEL OBJECTS
# ==============================================================================

#' @rdname build_model_data
#' @export
#' @keywords internal
build_model_data.psych <- function(fit_results, model_type = "fa", interpretation_args = NULL, ...) {
  # Extract parameters from ...
  dots <- list(...)
  variable_info <- dots$variable_info

  # Remove variable_info from dots to avoid passing it twice
  dots$variable_info <- NULL

  # Ensure model_type is "fa" if NULL (use default)
  if (is.null(model_type)) model_type <- "fa"

  # Validate variable_info is provided (required for FA)
  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} is required for factor analysis",
        "i" = "Provide a data frame with 'variable' and 'description' columns"
      )
    )
  }

  # Validate model structure
  if (!inherits(fit_results, "psych")) {
    cli::cli_abort(
      c("Model must inherit from {.cls psych}", "x" = "Got class: {.cls {class(fit_results)}}")
    )
  }

  if (is.null(fit_results$loadings)) {
    cli::cli_abort("Model does not contain loadings component")
  }

  # Extract loadings
  loadings <- as.data.frame(unclass(fit_results$loadings))

  # Extract factor correlations if oblique rotation
  factor_cor_mat <- if (!is.null(fit_results$Phi)) fit_results$Phi else NULL

  # Create list and route to internal helper
  loadings_list <- list(
    loadings = loadings,
    factor_cor_mat = factor_cor_mat
  )

  # Call internal function with named parameters, passing remaining dots
  do.call(
    build_fa_model_data_internal,
    c(
      list(
        fit_results = loadings_list,
        variable_info = variable_info,
        model_type = model_type,
        interpretation_args = interpretation_args
      ),
      dots
    )
  )
}


#' @rdname build_model_data
#' @export
#' @keywords internal
build_model_data.fa <- build_model_data.psych


#' @rdname build_model_data
#' @export
#' @keywords internal
build_model_data.principal <- build_model_data.psych


#' @rdname build_model_data
#' @export
#' @keywords internal
build_model_data.lavaan <- function(fit_results, model_type = "fa", interpretation_args = NULL, ...) {
  # Extract parameters from ...
  dots <- list(...)
  variable_info <- dots$variable_info

  # Remove variable_info from dots to avoid passing it twice
  dots$variable_info <- NULL

  # Ensure model_type is "fa" if NULL (use default)
  if (is.null(model_type)) model_type <- "fa"

  # Validate variable_info is provided (required for FA)
  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} is required for factor analysis",
        "i" = "Provide a data frame with 'variable' and 'description' columns"
      )
    )
  }

  # Validate model structure
  if (!inherits(fit_results, "lavaan")) {
    cli::cli_abort(
      c("Model must inherit from {.cls lavaan}", "x" = "Got class: {.cls {class(fit_results)}}")
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

  # Extract standardized loadings
  loadings_matrix <- lavaan::inspect(fit_results, what = "std")$lambda

  # Extract factor correlations
  factor_cor_mat <- lavaan::inspect(fit_results, what = "cor.lv")
  if (is.null(dim(factor_cor_mat)) || all(factor_cor_mat == diag(nrow(factor_cor_mat)))) {
    factor_cor_mat <- NULL  # Orthogonal factors
  }

  # Create list and route to internal helper
  loadings_list <- list(
    loadings = loadings_matrix,
    factor_cor_mat = factor_cor_mat
  )

  # Call internal function with named parameters, passing remaining dots
  do.call(
    build_fa_model_data_internal,
    c(
      list(
        fit_results = loadings_list,
        variable_info = variable_info,
        model_type = model_type,
        interpretation_args = interpretation_args
      ),
      dots
    )
  )
}


#' @rdname build_model_data
#' @export
#' @keywords internal
build_model_data.SingleGroupClass <- function(fit_results, model_type = "fa", interpretation_args = NULL, ...) {
  # Extract parameters from ...
  dots <- list(...)
  variable_info <- dots$variable_info

  # Remove variable_info from dots to avoid passing it twice
  dots$variable_info <- NULL

  # Ensure model_type is "fa" if NULL (use default)
  if (is.null(model_type)) model_type <- "fa"

  # Validate variable_info is provided (required for FA)
  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} is required for factor analysis",
        "i" = "Provide a data frame with 'variable' and 'description' columns"
      )
    )
  }

  # Validate model structure
  if (!inherits(fit_results, "SingleGroupClass")) {
    cli::cli_abort(
      c("Model must inherit from {.cls SingleGroupClass}", "x" = "Got class: {.cls {class(fit_results)}}")
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

  # Extract standardized loadings
  loadings_matrix <- mirt::summary(fit_results, suppress = 1000)$rotF

  # Extract factor correlations if oblique
  factor_cor_mat <- mirt::summary(fit_results, suppress = 1000)$fcor
  if (is.null(factor_cor_mat) || all(factor_cor_mat == diag(nrow(factor_cor_mat)))) {
    factor_cor_mat <- NULL  # Orthogonal factors
  }

  # Create list and route to internal helper
  loadings_list <- list(
    loadings = loadings_matrix,
    factor_cor_mat = factor_cor_mat
  )

  # Call internal function with named parameters, passing remaining dots
  do.call(
    build_fa_model_data_internal,
    c(
      list(
        fit_results = loadings_list,
        variable_info = variable_info,
        model_type = model_type,
        interpretation_args = interpretation_args
      ),
      dots
    )
  )
}


# ==============================================================================
# FA-SPECIFIC UTILITY FUNCTIONS
# ==============================================================================

#' Validate Factor Analysis List Structure
#'
#' Internal helper to validate and extract components from a structured list
#' for factor analysis. Used when fit_results is provided as a list instead of
#' a fitted model object. Accepts both "factor_cor_mat" and "Phi" as names
#' for the factor correlation matrix (psych::fa uses "Phi").
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

  # Extract factor correlation matrix (optional)
  # Accept both "factor_cor_mat" and "Phi" (psych::fa uses "Phi")
  factor_cor_mat <- NULL
  if ("factor_cor_mat" %in% names(fit_results_list)) {
    factor_cor_mat <- fit_results_list$factor_cor_mat
  } else if ("Phi" %in% names(fit_results_list)) {
    factor_cor_mat <- fit_results_list$Phi
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
  # Accept both "factor_cor_mat" and "Phi" (psych::fa uses "Phi")
  recognized_components <- c("loadings", "factor_cor_mat", "Phi")
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
