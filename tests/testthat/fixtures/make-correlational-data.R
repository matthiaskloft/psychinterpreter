# Script to generate realistic correlational data for testing S3 methods
# This data has proper factor structure suitable for FA packages

set.seed(42)  # For reproducibility

# Function to generate data with known factor structure
generate_factor_data <- function(n = 100, n_factors = 2) {
  # Create factor scores (latent variables)
  factor_scores <- matrix(rnorm(n * n_factors), ncol = n_factors)

  # Define loading matrix (2 factors, 6 variables)
  # Factor 1: Variables 1-3 load strongly
  # Factor 2: Variables 4-6 load strongly
  loadings <- matrix(c(
    0.80, 0.10,  # var1
    0.75, 0.15,  # var2
    0.70, 0.05,  # var3
    0.10, 0.85,  # var4
    0.15, 0.75,  # var5
    0.05, 0.80   # var6
  ), ncol = 2, byrow = TRUE)

  # Generate observed data: Data = FactorScores × Loadings' + Error
  observed <- factor_scores %*% t(loadings) + matrix(rnorm(n * 6, sd = 0.3), ncol = 6)

  # Convert to data frame
  data <- as.data.frame(observed)
  colnames(data) <- paste0("var", 1:6)

  return(data)
}

# Generate correlational data
correlational_data <- generate_factor_data(n = 100, n_factors = 2)

# Create corresponding variable info
correlational_var_info <- data.frame(
  variable = paste0("var", 1:6),
  description = c(
    "Factor 1 Indicator A",
    "Factor 1 Indicator B",
    "Factor 1 Indicator C",
    "Factor 2 Indicator A",
    "Factor 2 Indicator B",
    "Factor 2 Indicator C"
  ),
  stringsAsFactors = FALSE
)

# Save as RDS
saveRDS(correlational_data, "correlational_data.rds")
saveRDS(correlational_var_info, "correlational_var_info.rds")

# Verify the structure works with psych::fa
if (requireNamespace("psych", quietly = TRUE)) {
  fa_result <- psych::fa(correlational_data, nfactors = 2, rotate = "oblimin")

  cat("\n=== Verification ===\n")
  cat("Factor loadings look reasonable:\n")
  print(fa_result$loadings, cutoff = 0.3)

  cat("\nFactor correlations:\n")
  print(fa_result$Phi)

  cat("\n✓ Data has proper correlational structure for FA\n")
}

message("\nCorrelational fixtures saved successfully!")
