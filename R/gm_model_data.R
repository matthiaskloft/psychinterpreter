# ===================================================================
# FILE: gm_model_data.R
# PURPOSE: Data extraction and parameter handling for Gaussian Mixture Models
# ===================================================================

#' Build Analysis Data for Mclust Objects
#'
#' Extracts and standardizes data from fitted mclust Gaussian mixture models.
#'
#' @param fit_results An object of class "Mclust" from the mclust package
#' @param interpretation_args List of interpretation parameters (optional)
#' @param ... Additional arguments passed to interpretation_args_gm
#'
#' @return A list containing standardized GM data for interpretation
#' @export
#' @keywords internal
build_analysis_data.Mclust <- function(fit_results, interpretation_args = NULL, ...) {
  # Validate model
  if (!inherits(fit_results, "Mclust")) {
    cli::cli_abort("fit_results must be an Mclust object")
  }

  # Get interpretation parameters
  args <- resolve_interpretation_args(
    interpretation_args = interpretation_args,
    analysis_type = "gm",
    ...
  )

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
    min_cluster_size = args$min_cluster_size,
    separation_threshold = args$separation_threshold,
    profile_variables = args$profile_variables,
    weight_by_uncertainty = args$weight_by_uncertainty,
    plot_type = args$plot_type
  )

  # Add fit statistics
  analysis_data$loglik <- fit_results$loglik
  analysis_data$bic <- fit_results$bic
  analysis_data$icl <- ifelse(!is.null(fit_results$icl), fit_results$icl, NA)

  return(analysis_data)
}

#' Validate List Structure for Gaussian Mixture Models
#'
#' Validates and standardizes structured list input for GM interpretation.
#'
#' @param fit_results A list containing GM data
#' @param interpretation_args List of interpretation parameters (optional)
#' @param ... Additional arguments passed to interpretation_args_gm
#'
#' @return A validated and standardized analysis_data list
#' @export
#' @keywords internal
validate_list_structure.gm <- function(fit_results, interpretation_args = NULL, ...) {
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

  # Get interpretation parameters
  args <- resolve_interpretation_args(
    interpretation_args = interpretation_args,
    analysis_type = "gm",
    ...
  )

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
  covariance_type <- ifelse(
    !is.null(fit_results$covariance_type),
    fit_results$covariance_type,
    "VVV"
  )

  # Variable names
  if (!is.null(rownames(means))) {
    variable_names <- rownames(means)
  } else if (!is.null(fit_results$variable_names)) {
    variable_names <- fit_results$variable_names
  } else {
    variable_names <- paste0("V", seq_len(n_variables))
  }

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
    min_cluster_size = args$min_cluster_size,
    separation_threshold = args$separation_threshold,
    profile_variables = args$profile_variables,
    weight_by_uncertainty = args$weight_by_uncertainty,
    plot_type = args$plot_type
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
#' @param n_clusters Integer, number of clusters (optional)
#' @param covariance_type Character, covariance structure (e.g., "VVV", "EII")
#' @param min_cluster_size Integer, minimum meaningful cluster size (default: 5)
#' @param separation_threshold Numeric, overlap threshold for diagnostics (default: 0.3)
#' @param profile_variables Character vector, subset of variables to focus on (optional)
#' @param weight_by_uncertainty Logical, whether to weight by uncertainty if available (default: FALSE)
#' @param plot_type Character, visualization type: "heatmap", "parallel", "radar", or "auto" (default: "auto")
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
    min_cluster_size = 5,
    separation_threshold = 0.3,
    profile_variables = NULL,
    weight_by_uncertainty = FALSE,
    plot_type = "auto",
    ...) {

  # Validate analysis_type
  if (analysis_type != "gm") {
    cli::cli_abort("analysis_type must be 'gm' for interpretation_args_gm()")
  }

  # Validate n_clusters if provided
  if (!is.null(n_clusters)) {
    if (!is.numeric(n_clusters) || n_clusters < 1 || n_clusters != round(n_clusters)) {
      cli::cli_abort("n_clusters must be a positive integer")
    }
  }

  # Validate covariance_type if provided
  valid_cov_types <- c("EII", "VII", "EEI", "VEI", "EVI", "VVI",
                       "EEE", "VEE", "EVE", "VVE", "EEV", "VEV",
                       "EVV", "VVV")
  if (!is.null(covariance_type)) {
    if (!covariance_type %in% valid_cov_types) {
      cli::cli_abort(c(
        "Invalid covariance_type: {.val {covariance_type}}",
        "i" = "Valid types: {.val {valid_cov_types}}"
      ))
    }
  }

  # Validate min_cluster_size
  if (!is.numeric(min_cluster_size) || min_cluster_size < 1) {
    cli::cli_abort("min_cluster_size must be a positive integer")
  }

  # Validate separation_threshold
  if (!is.numeric(separation_threshold) || separation_threshold < 0 || separation_threshold > 1) {
    cli::cli_abort("separation_threshold must be between 0 and 1")
  }

  # Validate profile_variables if provided
  if (!is.null(profile_variables)) {
    if (!is.character(profile_variables)) {
      cli::cli_abort("profile_variables must be a character vector")
    }
  }

  # Validate weight_by_uncertainty
  if (!is.logical(weight_by_uncertainty)) {
    cli::cli_abort("weight_by_uncertainty must be TRUE or FALSE")
  }

  # Validate plot_type
  valid_plot_types <- c("auto", "heatmap", "parallel", "radar", "all")
  if (!plot_type %in% valid_plot_types) {
    cli::cli_abort(c(
      "Invalid plot_type: {.val {plot_type}}",
      "i" = "Valid types: {.val {valid_plot_types}}"
    ))
  }

  # Create configuration object
  args <- list(
    analysis_type = analysis_type,
    n_clusters = n_clusters,
    covariance_type = covariance_type,
    min_cluster_size = as.integer(min_cluster_size),
    separation_threshold = separation_threshold,
    profile_variables = profile_variables,
    weight_by_uncertainty = weight_by_uncertainty,
    plot_type = plot_type
  )

  class(args) <- c("interpretation_args_gm", "interpretation_args", "list")

  return(args)
}

#' Extract Model Parameters for Gaussian Mixture Models
#'
#' @param analysis_data Standardized GM analysis data
#' @return List of model-specific parameters
#' @keywords internal
extract_model_parameters.gm <- function(analysis_data) {
  params <- list(
    min_cluster_size = analysis_data$min_cluster_size,
    separation_threshold = analysis_data$separation_threshold,
    weight_by_uncertainty = analysis_data$weight_by_uncertainty,
    plot_type = analysis_data$plot_type
  )

  # Only include profile_variables if specified
  if (!is.null(analysis_data$profile_variables)) {
    params$profile_variables <- analysis_data$profile_variables
  }

  return(params)
}

#' Validate Model Requirements for Gaussian Mixture Models
#'
#' @param analysis_data Standardized GM analysis data
#' @return Invisible NULL (throws error if validation fails)
#' @keywords internal
validate_model_requirements.gm <- function(analysis_data) {
  # Check for minimum number of clusters
  if (analysis_data$n_clusters < 1) {
    cli::cli_abort("GM model must have at least 1 cluster")
  }

  # Check for valid means
  if (is.null(analysis_data$means)) {
    cli::cli_abort("GM model must have cluster means")
  }

  # Check dimensions consistency
  if (!is.null(analysis_data$memberships)) {
    if (ncol(analysis_data$memberships) != analysis_data$n_clusters) {
      cli::cli_abort("Membership matrix columns must match number of clusters")
    }
  }

  # Check proportions sum to 1
  if (!is.null(analysis_data$proportions)) {
    prop_sum <- sum(analysis_data$proportions)
    if (abs(prop_sum - 1) > 0.01) {
      cli::cli_warn("Cluster proportions sum to {.val {round(prop_sum, 3)}}, not 1.0")
    }
  }

  invisible(NULL)
}