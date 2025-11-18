# ==============================================================================
# UTILITY FUNCTIONS FOR GAUSSIAN MIXTURE MODEL ANALYSIS
# ==============================================================================

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
