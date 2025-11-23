# ===================================================================
# FILE: gm_diagnostics.R
# PURPOSE: Diagnostic functions for Gaussian Mixture Model interpretations
# ===================================================================

#' Create Fit Summary for Gaussian Mixture Models
#'
#' Generates diagnostic information about clustering quality and potential issues.
#'
#' @param analysis_type Character. Type of analysis ("gm")
#' @param analysis_data Standardized GM analysis data
#' @param ... Additional arguments (currently unused)
#' @return List with diagnostic information and warnings
#' @export
#' @keywords internal
create_fit_summary.gm <- function(analysis_type, analysis_data, ...) {
  fit_summary <- list(
    warnings = character(),
    notes = character(),
    statistics = list()
  )

  # Basic statistics
  fit_summary$statistics$n_clusters <- analysis_data$n_clusters
  fit_summary$statistics$n_variables <- analysis_data$n_variables
  fit_summary$statistics$n_observations <- analysis_data$n_observations

  # Add model fit statistics if available
  if (!is.null(analysis_data$bic)) {
    fit_summary$statistics$bic <- round(analysis_data$bic, 2)
  }
  if (!is.null(analysis_data$loglik)) {
    fit_summary$statistics$loglik <- round(analysis_data$loglik, 2)
  }
  if (!is.null(analysis_data$icl) && !is.na(analysis_data$icl)) {
    fit_summary$statistics$icl <- round(analysis_data$icl, 2)
  }
  if (!is.null(analysis_data$aic) && !is.na(analysis_data$aic)) {
    fit_summary$statistics$aic <- round(analysis_data$aic, 2)
  }

  # Add entropy measures
  if (!is.null(analysis_data$entropy) && !is.na(analysis_data$entropy)) {
    fit_summary$statistics$entropy <- round(analysis_data$entropy, 3)
  }
  if (!is.null(analysis_data$normalized_entropy) && !is.na(analysis_data$normalized_entropy)) {
    fit_summary$statistics$normalized_entropy <- round(analysis_data$normalized_entropy, 4)
  }

  # Add model complexity
  if (!is.null(analysis_data$n_parameters)) {
    fit_summary$statistics$n_parameters <- analysis_data$n_parameters
  }

  # Add convergence information
  if (!is.null(analysis_data$converged)) {
    fit_summary$statistics$converged <- analysis_data$converged
  }
  if (!is.null(analysis_data$convergence_tol) && !is.na(analysis_data$convergence_tol)) {
    fit_summary$statistics$convergence_tol <- analysis_data$convergence_tol
  }
  if (!is.null(analysis_data$max_iterations) && !is.na(analysis_data$max_iterations)) {
    fit_summary$statistics$max_iterations <- analysis_data$max_iterations
  }

  # Check cluster sizes
  if (!is.null(analysis_data$proportions)) {
    cluster_sizes <- analysis_data$proportions * analysis_data$n_observations
    small_clusters <- which(cluster_sizes < analysis_data$min_cluster_size)

    if (length(small_clusters) > 0) {
      fit_summary$warnings <- c(
        fit_summary$warnings,
        paste0(
          "Small clusters detected: ",
          paste(
            paste0(
              analysis_data$cluster_names[small_clusters],
              " (n=", round(cluster_sizes[small_clusters]), ")"
            ),
            collapse = ", "
          )
        )
      )
    }

    # Check for very unbalanced clusters
    size_ratio <- max(analysis_data$proportions) / min(analysis_data$proportions)
    if (size_ratio > 5) {
      fit_summary$warnings <- c(
        fit_summary$warnings,
        paste0(
          "Highly unbalanced cluster sizes (ratio: ",
          round(size_ratio, 1), ":1)"
        )
      )
    }
  }

  # Check uncertainty if available
  if (!is.null(analysis_data$uncertainty)) {
    avg_uncertainty <- mean(analysis_data$uncertainty, na.rm = TRUE)
    high_uncertainty_pct <- mean(
      analysis_data$uncertainty > analysis_data$separation_threshold,
      na.rm = TRUE
    ) * 100

    fit_summary$statistics$avg_uncertainty <- round(avg_uncertainty, 3)
    fit_summary$statistics$high_uncertainty_pct <- round(high_uncertainty_pct, 1)

    if (avg_uncertainty > analysis_data$separation_threshold) {
      fit_summary$warnings <- c(
        fit_summary$warnings,
        paste0(
          "High average uncertainty (",
          round(avg_uncertainty, 3),
          ") suggests overlapping clusters"
        )
      )
    }

    if (high_uncertainty_pct > 30) {
      fit_summary$warnings <- c(
        fit_summary$warnings,
        paste0(
          round(high_uncertainty_pct, 1),
          "% of observations have uncertain cluster assignments"
        )
      )
    }

    # Check uncertainty by cluster
    if (!is.null(analysis_data$classification)) {
      cluster_uncertainty <- tapply(
        analysis_data$uncertainty,
        analysis_data$classification,
        mean,
        na.rm = TRUE
      )

      high_uncertainty_clusters <- which(
        cluster_uncertainty > analysis_data$separation_threshold
      )

      if (length(high_uncertainty_clusters) > 0) {
        fit_summary$notes <- c(
          fit_summary$notes,
          paste0(
            "Clusters with high uncertainty: ",
            paste(
              paste0(
                analysis_data$cluster_names[high_uncertainty_clusters],
                " (", round(cluster_uncertainty[high_uncertainty_clusters], 3), ")"
              ),
              collapse = ", "
            )
          )
        )
      }
    }
  }

  # Check cluster separation using Mahalanobis distance
  if (!is.null(analysis_data$means) && !is.null(analysis_data$covariances)) {
    separation_matrix <- calculate_cluster_separation_gm(analysis_data)

    if (!is.null(separation_matrix)) {
      min_separation <- min(separation_matrix[upper.tri(separation_matrix)])
      fit_summary$statistics$min_separation <- round(min_separation, 2)

      if (min_separation < 2) {
        fit_summary$warnings <- c(
          fit_summary$warnings,
          paste0(
            "Poor cluster separation detected (minimum distance: ",
            round(min_separation, 2), ")"
          )
        )

        # Find which clusters are overlapping
        overlap_pairs <- which(
          separation_matrix < 2 & upper.tri(separation_matrix),
          arr.ind = TRUE
        )

        if (nrow(overlap_pairs) > 0) {
          overlap_desc <- apply(overlap_pairs, 1, function(pair) {
            paste0(
              analysis_data$cluster_names[pair[1]],
              "-",
              analysis_data$cluster_names[pair[2]]
            )
          })

          fit_summary$notes <- c(
            fit_summary$notes,
            paste0("Overlapping cluster pairs: ", paste(overlap_desc, collapse = ", "))
          )
        }
      }
    }
  }

  # Check covariance structure complexity
  if (!is.null(analysis_data$covariance_type)) {
    fit_summary$statistics$covariance_type <- analysis_data$covariance_type

    if (analysis_data$covariance_type == "VVV") {
      fit_summary$notes <- c(
        fit_summary$notes,
        "Using most complex covariance structure (VVV) - consider simpler models if overfitting"
      )
    } else if (analysis_data$covariance_type == "EII") {
      fit_summary$notes <- c(
        fit_summary$notes,
        "Using simplest covariance structure (EII) - clusters are spherical with equal variance"
      )
    }
  }

  # Add summary message
  if (length(fit_summary$warnings) == 0 && length(fit_summary$notes) == 0) {
    fit_summary$notes <- c(
      fit_summary$notes,
      "Clustering appears well-defined with good separation"
    )
  }

  return(fit_summary)
}

#' Calculate Cluster Separation for GM
#'
#' Computes pairwise Mahalanobis distances between cluster centers.
#'
#' @param analysis_data Standardized GM analysis data
#' @return Matrix of pairwise distances or NULL if not computable
#' @keywords internal
calculate_cluster_separation_gm <- function(analysis_data) {
  if (is.null(analysis_data$means) || is.null(analysis_data$covariances)) {
    return(NULL)
  }

  n_clusters <- analysis_data$n_clusters
  if (n_clusters < 2) {
    return(NULL)
  }

  # Initialize separation matrix
  separation_matrix <- matrix(0, n_clusters, n_clusters)

  # Calculate pairwise Mahalanobis distances
  for (i in 1:(n_clusters - 1)) {
    for (j in (i + 1):n_clusters) {
      # Get means
      mean_i <- analysis_data$means[, i]
      mean_j <- analysis_data$means[, j]

      # Average covariance for the pair
      cov_i <- analysis_data$covariances[, , i]
      cov_j <- analysis_data$covariances[, , j]
      avg_cov <- (cov_i + cov_j) / 2

      # Calculate Mahalanobis distance
      tryCatch({
        inv_cov <- solve(avg_cov)
        diff_means <- mean_i - mean_j
        distance <- sqrt(t(diff_means) %*% inv_cov %*% diff_means)
        separation_matrix[i, j] <- distance
        separation_matrix[j, i] <- distance
      }, error = function(e) {
        # If covariance is singular, use Euclidean distance as fallback
        distance <- sqrt(sum((mean_i - mean_j)^2))
        separation_matrix[i, j] <- distance
        separation_matrix[j, i] <- distance
      })
    }
  }

  return(separation_matrix)
}

#' Find Overlapping Clusters
#'
#' Identifies clusters with significant overlap based on separation threshold.
#'
#' @param analysis_data Standardized GM analysis data
#' @return List of overlapping cluster pairs, or NULL if no overlaps detected.
#'   Each list element contains:
#'   \itemize{
#'     \item cluster1: Character. Name of first cluster
#'     \item cluster2: Character. Name of second cluster
#'     \item distance: Numeric. Mahalanobis distance between clusters
#'   }
#'
#' @details
#' Clusters are considered overlapping if their Mahalanobis distance is below
#' the threshold of 2.0. This indicates poor cluster separation and potential
#' issues with the clustering solution.
#'
#' Mahalanobis distance accounts for both the distance between cluster centers
#' and the covariance structure of the clusters, providing a more informative
#' measure than Euclidean distance.
#'
#' @seealso [find_distinguishing_variables_gm()] for identifying key variables per cluster
#'
#' @examples
#' \dontrun{
#' # After running GM interpretation
#' library(mclust)
#' gmm_model <- Mclust(scale(data), G = 3)
#' var_info <- data.frame(variable = names(data), description = names(data))
#' interpretation <- interpret(gmm_model, variable_info = var_info,
#'                            llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")
#'
#' # Check for overlapping clusters
#' analysis_data <- interpretation$analysis_data
#' overlaps <- find_overlapping_clusters(analysis_data)
#' if (!is.null(overlaps)) {
#'   print("Found overlapping cluster pairs:")
#'   print(overlaps)
#' }
#' }
#'
#' @export
#' @keywords internal
find_overlapping_clusters <- function(analysis_data) {
  separation_matrix <- calculate_cluster_separation_gm(analysis_data)

  if (is.null(separation_matrix)) {
    return(NULL)
  }

  # Find pairs below threshold (default Mahalanobis distance of 2)
  threshold <- 2
  overlap_pairs <- which(
    separation_matrix < threshold & upper.tri(separation_matrix),
    arr.ind = TRUE
  )

  if (nrow(overlap_pairs) == 0) {
    return(NULL)
  }

  # Format results
  overlaps <- apply(overlap_pairs, 1, function(pair) {
    list(
      cluster1 = analysis_data$cluster_names[pair[1]],
      cluster2 = analysis_data$cluster_names[pair[2]],
      distance = separation_matrix[pair[1], pair[2]]
    )
  })

  return(overlaps)
}

#' Find Distinguishing Variables for Clusters
#'
#' Identifies variables that best distinguish each cluster from others.
#'
#' @param analysis_data Standardized GM analysis data
#' @param top_n Number of top distinguishing variables per cluster (default = 5)
#' @return Named list with one element per cluster. Each element is a data frame with columns:
#'   \itemize{
#'     \item variable: Character. Variable name
#'     \item cluster_mean: Numeric. Mean value in this cluster
#'     \item overall_mean: Numeric. Overall mean across all clusters
#'     \item distinctiveness: Numeric. Combined distinctiveness score
#'   }
#'   Returns NULL if means are not available.
#'
#' @details
#' Distinctiveness is calculated by combining two measures:
#' \enumerate{
#'   \item Deviation from overall mean across all clusters
#'   \item Deviation from average of other clusters
#' }
#'
#' Variables with high distinctiveness scores are those that have notably
#' different values in the target cluster compared to the overall population
#' and other clusters. These are the key variables that define each cluster's
#' unique profile.
#'
#' @seealso [find_overlapping_clusters()] for identifying cluster overlap
#'
#' @examples
#' \dontrun{
#' # After running GM interpretation
#' library(mclust)
#' gmm_model <- Mclust(scale(data), G = 3)
#' var_info <- data.frame(variable = names(data), description = names(data))
#' interpretation <- interpret(gmm_model, variable_info = var_info,
#'                            llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")
#'
#' # Find distinguishing variables for each cluster
#' analysis_data <- interpretation$analysis_data
#' distinguishing <- find_distinguishing_variables_gm(analysis_data, top_n = 5)
#'
#' # View results for first cluster
#' print(distinguishing[[1]])
#'
#' # Find more variables
#' distinguishing_extended <- find_distinguishing_variables_gm(analysis_data, top_n = 10)
#' }
#'
#' @export
#' @keywords internal
find_distinguishing_variables_gm <- function(analysis_data, top_n = 5) {
  if (is.null(analysis_data$means)) {
    return(NULL)
  }

  distinguishing_vars <- list()

  # Calculate overall means
  overall_means <- rowMeans(
    analysis_data$means,
    na.rm = TRUE
  )

  # For each cluster, find most distinctive variables
  for (k in seq_len(analysis_data$n_clusters)) {
    cluster_name <- analysis_data$cluster_names[k]
    cluster_means <- analysis_data$means[, k]

    # Calculate deviation from overall mean
    deviations <- abs(cluster_means - overall_means)

    # Also consider deviation from other clusters
    if (analysis_data$n_clusters > 1) {
      other_means <- analysis_data$means[, -k, drop = FALSE]
      avg_other_means <- rowMeans(other_means, na.rm = TRUE)
      cluster_distinctiveness <- abs(cluster_means - avg_other_means)

      # Combine both measures
      distinctiveness_score <- deviations + cluster_distinctiveness
    } else {
      distinctiveness_score <- deviations
    }

    # Get top variables
    top_indices <- order(distinctiveness_score, decreasing = TRUE)[1:min(top_n, length(distinctiveness_score))]

    distinguishing_vars[[cluster_name]] <- data.frame(
      variable = analysis_data$variable_names[top_indices],
      cluster_mean = cluster_means[top_indices],
      overall_mean = overall_means[top_indices],
      distinctiveness = distinctiveness_score[top_indices],
      stringsAsFactors = FALSE
    )
  }

  return(distinguishing_vars)
}