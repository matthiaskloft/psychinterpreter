# ==============================================================================
# UTILITY FUNCTIONS FOR GAUSSIAN MIXTURE MODEL ANALYSIS
# ==============================================================================

#' Extract One Cluster's Covariance Matrix
#'
#' Returns cluster \code{k}'s covariance as a \code{p x p} matrix, never a bare
#' scalar. \code{covariances[, , k]} drops dimensions when \code{p == 1}, which
#' silently breaks every consumer that calls \code{diag()}, \code{rownames()} or
#' \code{cov2cor()} on the result - \code{diag(0.77)} returns a 0 x 0 matrix
#' rather than erroring, so a one-variable model produced \code{NA} variances in
#' the LLM prompt instead of failing loudly.
#'
#' @param covariances Numeric array \code{[p, p, G]}
#' @param k Integer. Cluster index
#'
#' @return Numeric \code{p x p} matrix, with dimnames preserved where present
#' @keywords internal
gm_cluster_cov <- function(covariances, k) {
  p <- dim(covariances)[1]
  slice <- covariances[, , k, drop = FALSE]
  dim(slice) <- c(p, p)
  dn <- dimnames(covariances)
  if (!is.null(dn) && !is.null(dn[[1]])) {
    dimnames(slice) <- list(dn[[1]], dn[[2]])
  }
  slice
}

#' Normalize GM Parameter Shapes to a Canonical Form
#'
#' Coerces cluster means and covariances to the canonical shapes every
#' downstream consumer (diagnostics, prompt building, visualization) assumes:
#' \code{means[n_variables, n_clusters]} and
#' \code{covariances[n_variables, n_variables, n_clusters]}.
#'
#' This is required because \code{mclust} does not use a uniform representation.
#' For a one-variable mixture it supplies \code{parameters$mean} as a bare vector
#' of length \code{n_clusters} and \code{parameters$variance$sigma} as a scalar
#' (equal-variance models) or a vector of length \code{n_clusters} (varying
#' variance) - neither of which carries the dimensions the rest of the package
#' indexes into.
#'
#' @param means Numeric matrix, data frame, or vector of cluster means
#' @param covariances Numeric 3-d array, matrix, vector, or scalar of covariances
#' @param n_variables Integer. Number of variables (p)
#' @param n_clusters Integer. Number of clusters (G)
#' @param variable_names Character or NULL. Row names to apply
#' @param cluster_names Character or NULL. Column names to apply
#'
#' @return List with canonical \code{means} and \code{covariances}
#' @keywords internal
normalize_gm_shapes <- function(means,
                                covariances,
                                n_variables,
                                n_clusters,
                                variable_names = NULL,
                                cluster_names = NULL) {

  # ---- means -> [n_variables, n_clusters] ----------------------------------
  if (is.data.frame(means)) means <- as.matrix(means)

  if (is.null(dim(means))) {
    if (length(means) != n_variables * n_clusters) {
      cli::cli_abort(c(
        "Cannot reshape cluster means to {n_variables} x {n_clusters}",
        "x" = "Received {length(means)} value{?s}, expected {n_variables * n_clusters}"
      ))
    }
    means <- matrix(means, nrow = n_variables, ncol = n_clusters)
  } else if (!all(dim(means) == c(n_variables, n_clusters))) {
    # Already dimensioned but not canonical. Do not silently accept it - a
    # transposed [G, p] matrix would otherwise flow straight through.
    cli::cli_abort(c(
      "Cluster means have the wrong dimensions",
      "x" = "Got {paste(dim(means), collapse = ' x ')}, expected {n_variables} x {n_clusters}",
      "i" = "Rows must be variables and columns must be clusters"
    ))
  }

  # ---- covariances -> [n_variables, n_variables, n_clusters] ---------------
  cov_dim <- dim(covariances)

  if (is.null(cov_dim) || length(cov_dim) != 3L) {
    values <- as.numeric(covariances)

    if (!is.null(cov_dim) && length(cov_dim) == 2L &&
        all(cov_dim == c(n_variables, n_variables))) {
      # A single p x p matrix shared across clusters: replicate it.
      shared <- matrix(values, nrow = n_variables, ncol = n_variables)
      normalized <- array(0, dim = c(n_variables, n_variables, n_clusters))
      for (k in seq_len(n_clusters)) normalized[, , k] <- shared

    } else if (n_variables == 1L && length(values) %in% c(1L, n_clusters)) {
      # Univariate: scalar (equal variance) or one value per cluster.
      values <- rep(values, length.out = n_clusters)
      normalized <- array(values, dim = c(1L, 1L, n_clusters))

    } else if (length(values) == n_variables * n_variables * n_clusters) {
      normalized <- array(values, dim = c(n_variables, n_variables, n_clusters))

    } else {
      cli::cli_abort(c(
        "Cannot reshape covariances to {n_variables} x {n_variables} x {n_clusters}",
        "x" = "Received {length(values)} value{?s}",
        "i" = "Expected a scalar, one value per cluster, a {n_variables} x {n_variables} matrix, or a 3-d array"
      ))
    }
    covariances <- normalized

  } else if (!all(cov_dim == c(n_variables, n_variables, n_clusters))) {
    cli::cli_abort(c(
      "Covariances have the wrong dimensions",
      "x" = "Got {paste(cov_dim, collapse = ' x ')}, expected {n_variables} x {n_variables} x {n_clusters}"
    ))
  }

  # ---- dimnames ------------------------------------------------------------
  if (!is.null(variable_names) && length(variable_names) == n_variables) {
    rownames(means) <- variable_names
    dimnames(covariances) <- list(variable_names, variable_names, NULL)
  }
  if (!is.null(cluster_names) && length(cluster_names) == n_clusters) {
    colnames(means) <- cluster_names
  }

  list(means = means, covariances = covariances)
}

#' Convert Covariance Matrix to Correlation Matrix (Safe)
#'
#' Safely converts a covariance matrix to correlation matrix with protection
#' against zero or near-zero variances (which would cause division by zero).
#' Returns NA matrix if degenerate variables detected.
#'
#' @param cov_matrix Numeric matrix. Covariance matrix with named dimensions
#' @return Numeric matrix. Correlation matrix with diagonal = 1, or NA matrix if degenerate
#' @keywords internal
cov2cor_safe <- function(cov_matrix) {
  # Get standard deviations
  sds <- sqrt(diag(cov_matrix))

  # Check for zero or near-zero variances
  if (any(sds < 1e-10)) {
    # Return matrix of NAs if we have degenerate variables
    cor_matrix <- matrix(NA, nrow = nrow(cov_matrix), ncol = ncol(cov_matrix))
    dimnames(cor_matrix) <- dimnames(cov_matrix)
    return(cor_matrix)
  }

  # Convert to correlation
  cor_matrix <- cov_matrix / (sds %*% t(sds))

  # Ensure diagonal is exactly 1
  diag(cor_matrix) <- 1

  return(cor_matrix)
}

#' Format Within-Cluster Correlations
#'
#' Formats notable within-cluster correlations for the GM prompt. Only reports
#' correlations exceeding the minimum threshold to focus on meaningful relationships.
#' Uses upper triangle only to avoid duplication. Threshold of 0.3 aligns with
#' system prompt definition of "weak" correlation boundary.
#'
#' @param cor_matrix Numeric matrix. Correlation matrix for a single cluster
#' @param variable_names Character vector. Variable names matching matrix dimensions
#' @param min_correlation Numeric. Minimum absolute correlation to report (default: 0.3,
#'   representing the boundary between "near-zero" and "weak" correlations per system prompt)
#' @return Character string with formatted correlations (arrow notation), or message if none found
#' @keywords internal
format_cluster_correlations <- function(cor_matrix, variable_names, min_correlation = 0.3) {
  n_vars <- length(variable_names)

  if (n_vars < 2) {
    return("  (Only one variable, no correlations to report)\n")
  }

  cor_text <- ""
  has_correlations <- FALSE

  # Report correlations above threshold (only upper triangle to avoid duplication)
  for (i in 1:(n_vars - 1)) {
    for (j in (i + 1):n_vars) {
      cor_val <- cor_matrix[i, j]

      # Skip if NA or below threshold
      if (is.na(cor_val) || abs(cor_val) < min_correlation) {
        next
      }

      has_correlations <- TRUE
      cor_formatted <- sprintf("%+.2f", cor_val)

      cor_text <- paste0(
        cor_text,
        "    ", variable_names[i], " <-> ", variable_names[j], ": ", cor_formatted, "\n"
      )
    }
  }

  if (!has_correlations) {
    return("  (No strong within-cluster correlations above |0.3|)\n")
  }

  return(cor_text)
}
