# ===================================================================
# FILE: gm_model_data.R
# PURPOSE: Data extraction and parameter handling for Gaussian Mixture Models
# ===================================================================

#' Build Analysis Data for Mclust Objects
#'
#' Extracts and standardizes data from fitted mclust Gaussian mixture models.
#'
#' @param fit_results An object of class "Mclust" from the mclust package
#' @param analysis_type Character. Analysis type (not used, for S3 consistency)
#' @param interpretation_args List of interpretation parameters (optional)
#' @param ... Additional arguments passed to interpretation_args_gm
#'
#' @return A list with standardized GM data including: \code{means} (cluster means
#'   matrix), \code{covariances} (3D array of cluster covariance matrices),
#'   \code{proportions} (cluster mixing proportions), \code{n_clusters},
#'   \code{n_variables}, \code{n_observations}, \code{variable_names},
#'   \code{cluster_names}, \code{covariance_type} (mclust model name),
#'   \code{classification} (cluster assignments), \code{uncertainty} (assignment
#'   uncertainty values), \code{weight_by_uncertainty} (logical flag),
#'   \code{profile_variables} (subset of variables for interpretation), and
#'   \code{min_cluster_size}, \code{separation_threshold} (diagnostic thresholds)
#' @export
#' @keywords internal
build_analysis_data.Mclust <- function(fit_results, analysis_type = NULL, interpretation_args = NULL, ...) {
  # Validate model
  if (!inherits(fit_results, "Mclust")) {
    cli::cli_abort("fit_results must be an Mclust object")
  }

  # Extract GM parameters from interpretation_args or ...
  dots <- list(...)

  # Extract variable_info (required for GM)
  variable_info <- dots$variable_info

  # Validate variable_info is provided (required for GM)
  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} is required for Gaussian mixture model interpretation",
        "i" = "Provide a data frame with 'variable' and 'description' columns"
      )
    )
  }

  # Extract from interpretation_args if provided and is a list
  min_cluster_size <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
    interpretation_args$min_cluster_size
  } else {
    dots$min_cluster_size
  }
  if (is.null(min_cluster_size)) min_cluster_size <- 5

  separation_threshold <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
    interpretation_args$separation_threshold
  } else {
    dots$separation_threshold
  }
  if (is.null(separation_threshold)) separation_threshold <- 0.3

  profile_variables <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
    interpretation_args$profile_variables
  } else {
    dots$profile_variables
  }

  weight_by_uncertainty <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
    interpretation_args$weight_by_uncertainty
  } else {
    dots$weight_by_uncertainty
  }
  if (is.null(weight_by_uncertainty)) weight_by_uncertainty <- FALSE

  plot_type <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
    interpretation_args$plot_type
  } else {
    dots$plot_type
  }
  if (is.null(plot_type)) plot_type <- "auto"

  # Extract core clustering data
  n_clusters <- fit_results$G
  n_variables <- ncol(fit_results$data)
  n_observations <- nrow(fit_results$data)

  # Extract model parameters
  means <- fit_results$parameters$mean

  # Handle covariances (may be NULL for spherical models)
  covariances <- fit_results$parameters$variance$sigma
  if (is.null(covariances)) {
    # For spherical models, create diagonal covariance matrices
    sigma_val <- fit_results$parameters$variance$sigmasq
    covariances <- array(0, dim = c(n_variables, n_variables, n_clusters))
    for (k in 1:n_clusters) {
      diag(covariances[,,k]) <- sigma_val[k]
    }
  }

  # Extract other components
  proportions <- fit_results$parameters$pro
  memberships <- fit_results$z
  classification <- fit_results$classification
  uncertainty <- fit_results$uncertainty

  # Get model type
  covariance_type <- fit_results$modelName

  # Prepare variable names
  if (!is.null(colnames(fit_results$data))) {
    variable_names <- colnames(fit_results$data)
  } else {
    variable_names <- paste0("V", seq_len(n_variables))
  }

  # Validate variable matching with variable_info
  validate_variable_matching(variable_names, variable_info, "GM")

  # Set cluster names
  cluster_names <- paste0("Cluster_", seq_len(n_clusters))

  # Build standardized analysis_data
  analysis_data <- list(
    # Core clustering data
    means = means,
    covariances = covariances,
    proportions = proportions,
    memberships = memberships,

    # Optional data
    classification = classification,
    uncertainty = uncertainty,
    covariance_type = covariance_type,

    # Metadata
    n_clusters = n_clusters,
    n_variables = n_variables,
    n_observations = n_observations,
    analysis_type = "gm",
    variable_names = variable_names,
    cluster_names = cluster_names,

    # Parameters from interpretation_args
    min_cluster_size = min_cluster_size,
    separation_threshold = separation_threshold,
    profile_variables = profile_variables,
    weight_by_uncertainty = weight_by_uncertainty,
    plot_type = plot_type
  )

  # Add fit statistics
  analysis_data$loglik <- fit_results$loglik
  analysis_data$bic <- fit_results$bic
  analysis_data$icl <- ifelse(!is.null(fit_results$icl), fit_results$icl, NA)

  # Calculate AIC
  analysis_data$aic <- if (!is.null(fit_results$loglik) && !is.null(fit_results$df)) {
    -2 * fit_results$loglik + 2 * fit_results$df
  } else {
    NA
  }

  # Calculate entropy from soft assignments
  analysis_data$entropy <- if (!is.null(fit_results$z)) {
    -sum(fit_results$z * log(fit_results$z + 1e-10), na.rm = TRUE)
  } else {
    NA
  }

  # Calculate normalized entropy (0-1 scale)
  analysis_data$normalized_entropy <- if (!is.null(fit_results$z) && !is.null(fit_results$n) && !is.null(fit_results$G)) {
    max_entropy <- fit_results$n * log(fit_results$G)
    if (max_entropy > 0) {
      analysis_data$entropy / max_entropy
    } else {
      NA
    }
  } else {
    NA
  }

  # Add model complexity information
  analysis_data$n_parameters <- fit_results$df

  # Convergence information
  analysis_data$converged <- !is.null(fit_results$loglik)

  # Note: Actual iteration count is not stored by default in Mclust objects
  # but we can check for control parameters
  if (!is.null(fit_results$control)) {
    analysis_data$convergence_tol <- fit_results$control$tol
    analysis_data$max_iterations <- fit_results$control$itmax
  } else {
    analysis_data$convergence_tol <- NA
    analysis_data$max_iterations <- NA
  }

  return(analysis_data)
}

#' Validate List Structure for Gaussian Mixture Models (Implementation)
#'
#' Validates and standardizes structured list input for GM interpretation.
#' This is the actual implementation called by the S3 dispatcher in s3_list_validation.R
#'
#' @param fit_results A list containing GM data
#' @param interpretation_args List of interpretation parameters (optional)
#' @param ... Additional arguments passed to interpretation_args_gm
#'
#' @return A validated and standardized analysis_data list
#' @keywords internal
validate_list_structure_gm_impl <- function(fit_results, interpretation_args = NULL, ...) {
  # Check required components
  required <- c("means")
  missing <- setdiff(required, names(fit_results))

  if (length(missing) > 0) {
    cli::cli_abort(c(
      "Missing required components in fit_results list:",
      "x" = "Missing: {.field {missing}}",
      "i" = "Required components: {.field {required}}"
    ))
  }

  # Extract GM parameters from interpretation_args or ...
  dots <- list(...)

  # Extract variable_info (required for GM)
  variable_info <- dots$variable_info

  # Validate variable_info is provided (required for GM)
  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} is required for Gaussian mixture model interpretation",
        "i" = "Provide a data frame with 'variable' and 'description' columns"
      )
    )
  }

  # Extract from interpretation_args if provided and is a list
  min_cluster_size <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
    interpretation_args$min_cluster_size
  } else {
    dots$min_cluster_size
  }
  if (is.null(min_cluster_size)) min_cluster_size <- 5

  separation_threshold <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
    interpretation_args$separation_threshold
  } else {
    dots$separation_threshold
  }
  if (is.null(separation_threshold)) separation_threshold <- 0.3

  profile_variables <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
    interpretation_args$profile_variables
  } else {
    dots$profile_variables
  }

  weight_by_uncertainty <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
    interpretation_args$weight_by_uncertainty
  } else {
    dots$weight_by_uncertainty
  }
  if (is.null(weight_by_uncertainty)) weight_by_uncertainty <- FALSE

  plot_type <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
    interpretation_args$plot_type
  } else {
    dots$plot_type
  }
  if (is.null(plot_type)) plot_type <- "auto"

  # Extract and validate means
  means <- fit_results$means

  # Determine dimensions
  if (is.matrix(means)) {
    n_clusters <- ncol(means)
    n_variables <- nrow(means)
  } else if (is.data.frame(means)) {
    means <- as.matrix(means)
    n_clusters <- ncol(means)
    n_variables <- nrow(means)
  } else {
    cli::cli_abort("means must be a matrix or data.frame")
  }

  # Extract or create other components
  covariances <- fit_results$covariances
  if (is.null(covariances)) {
    # Create identity covariances if not provided
    covariances <- array(0, dim = c(n_variables, n_variables, n_clusters))
    for (k in 1:n_clusters) {
      diag(covariances[,,k]) <- 1
    }
  }

  # Extract or create proportions
  proportions <- fit_results$proportions
  if (is.null(proportions)) {
    # Equal proportions if not provided
    proportions <- rep(1/n_clusters, n_clusters)
  }

  # Extract optional components
  memberships <- fit_results$memberships
  classification <- fit_results$classification
  uncertainty <- fit_results$uncertainty

  # Only include covariance_type if explicitly provided
  # (Don't default to "VVV" for generic lists - that's misleading)
  covariance_type <- fit_results$covariance_type  # May be NULL

  # Variable names
  if (!is.null(rownames(means))) {
    variable_names <- rownames(means)
  } else if (!is.null(fit_results$variable_names)) {
    variable_names <- fit_results$variable_names
  } else {
    variable_names <- paste0("V", seq_len(n_variables))
  }

  # Validate variable matching with variable_info
  validate_variable_matching(variable_names, variable_info, "GM")

  # Cluster names
  if (!is.null(colnames(means))) {
    cluster_names <- colnames(means)
  } else if (!is.null(fit_results$cluster_names)) {
    cluster_names <- fit_results$cluster_names
  } else {
    cluster_names <- paste0("Cluster_", seq_len(n_clusters))
  }

  # Build standardized analysis_data
  analysis_data <- list(
    # Core clustering data
    means = means,
    covariances = covariances,
    proportions = proportions,
    memberships = memberships,

    # Optional data
    classification = classification,
    uncertainty = uncertainty,
    covariance_type = covariance_type,

    # Metadata
    n_clusters = n_clusters,
    n_variables = n_variables,
    n_observations = ifelse(
      !is.null(fit_results$n_observations),
      fit_results$n_observations,
      ifelse(!is.null(memberships), nrow(memberships), NA)
    ),
    analysis_type = "gm",
    variable_names = variable_names,
    cluster_names = cluster_names,

    # Parameters from interpretation_args
    min_cluster_size = min_cluster_size,
    separation_threshold = separation_threshold,
    profile_variables = profile_variables,
    weight_by_uncertainty = weight_by_uncertainty,
    plot_type = plot_type
  )

  # Add any fit statistics if provided
  if (!is.null(fit_results$loglik)) analysis_data$loglik <- fit_results$loglik
  if (!is.null(fit_results$bic)) analysis_data$bic <- fit_results$bic
  if (!is.null(fit_results$icl)) analysis_data$icl <- fit_results$icl

  return(analysis_data)
}

#' Create Interpretation Arguments for Gaussian Mixture Models
#'
#' Creates a configuration object for GM-specific interpretation parameters.
#'
#' @param analysis_type Character string, must be "gm"
#' @param n_clusters Integer or NULL. Number of clusters (default: NULL, inferred from model)
#' @param covariance_type Character or NULL. Covariance structure (e.g., "VVV", "EII") (default: NULL, inferred from model)
#' @param min_cluster_size Integer or NULL. Minimum meaningful cluster size (default from registry: 5)
#' @param separation_threshold Numeric or NULL. Overlap threshold for diagnostics (default from registry: 0.3)
#' @param profile_variables Character vector or NULL. Subset of variables to focus on (default: NULL)
#' @param weight_by_uncertainty Logical or NULL. Whether to weight by uncertainty if available (default from registry: FALSE)
#' @param plot_type Character or NULL. Visualization type: "heatmap", "parallel", "radar", or "auto" (default from registry: "auto")
#' @param ... Additional arguments (currently unused)
#'
#' @return A list of class "interpretation_args_gm" with validated parameters
#' @export
#'
#' @examples
#' \dontrun{
#' # Create GM-specific configuration
#' gm_args <- interpretation_args(
#'   analysis_type = "gm",
#'   min_cluster_size = 10,
#'   separation_threshold = 0.2,
#'   plot_type = "heatmap"
#' )
#'
#' # Use in interpretation
#' interpret(
#'   fit_results = mclust_model,
#'   variable_info = var_info,
#'   interpretation_args = gm_args,
#'   llm_provider = "ollama",
#'   llm_model = "llama3"
#' )
#' }
interpretation_args_gm <- function(
    analysis_type = "gm",
    n_clusters = NULL,
    covariance_type = NULL,
    min_cluster_size = NULL,
    separation_threshold = NULL,
    profile_variables = NULL,
    weight_by_uncertainty = NULL,
    plot_type = NULL,
    ...) {

  # Validate analysis_type
  if (analysis_type != "gm") {
    cli::cli_abort("analysis_type must be 'gm' for interpretation_args_gm()")
  }

  # Build parameter list with defaults from registry
  param_list <- list(
    analysis_type = analysis_type,
    n_clusters = n_clusters,  # NULL is valid
    covariance_type = covariance_type,  # NULL is valid
    min_cluster_size = min_cluster_size %||% get_param_default("min_cluster_size"),
    separation_threshold = separation_threshold %||% get_param_default("separation_threshold"),
    profile_variables = profile_variables,  # NULL is valid
    weight_by_uncertainty = weight_by_uncertainty %||% get_param_default("weight_by_uncertainty"),
    plot_type = plot_type %||% get_param_default("plot_type")
  )

  # Validate all parameters using registry
  validated <- validate_params(param_list, throw_error = TRUE)

  structure(
    validated,
    class = c("interpretation_args_gm", "interpretation_args", "list")
  )
}