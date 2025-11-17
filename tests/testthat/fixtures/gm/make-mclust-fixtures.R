# ==============================================================================
# FIXTURE GENERATION: Mclust/GM Models
# ==============================================================================
# This script generates test fixtures for Gaussian Mixture Model testing
# Run this script when you need to update GM test fixtures

library(mclust)

# Set seed for reproducibility
set.seed(42)

# ==============================================================================
# MINIMAL GM FIXTURES
# ==============================================================================

# Create minimal test data (small clusters for fast testing)
minimal_gm_data <- matrix(rnorm(60), nrow = 20, ncol = 3)
colnames(minimal_gm_data) <- c("V1", "V2", "V3")

# Fit minimal GM model
minimal_gm_model <- Mclust(minimal_gm_data, G = 2, modelNames = "EII")

# Create minimal variable info
minimal_gm_var_info <- data.frame(
  variable = c("V1", "V2", "V3"),
  description = c("Variable 1", "Variable 2", "Variable 3"),
  stringsAsFactors = FALSE
)

# Create minimal analysis_data (what build_analysis_data.Mclust returns)
minimal_gm_analysis_data <- list(
  means = minimal_gm_model$parameters$mean,
  covariances = minimal_gm_model$parameters$variance$sigma,
  proportions = minimal_gm_model$parameters$pro,
  memberships = minimal_gm_model$z,
  classification = minimal_gm_model$classification,
  uncertainty = minimal_gm_model$uncertainty,
  covariance_type = minimal_gm_model$modelName,
  n_clusters = minimal_gm_model$G,
  n_variables = ncol(minimal_gm_data),
  n_observations = nrow(minimal_gm_data),
  analysis_type = "gm",
  variable_names = colnames(minimal_gm_data),
  cluster_names = paste0("Cluster_", 1:minimal_gm_model$G),
  min_cluster_size = 5,
  separation_threshold = 0.3,
  profile_variables = NULL,
  weight_by_uncertainty = FALSE,
  plot_type = "auto"
)

# Save minimal fixtures
saveRDS(minimal_gm_model, "minimal_gm_model.rds")
saveRDS(minimal_gm_data, "minimal_gm_data.rds")
saveRDS(minimal_gm_var_info, "minimal_gm_var_info.rds")
saveRDS(minimal_gm_analysis_data, "minimal_gm_analysis_data.rds")

# ==============================================================================
# SAMPLE GM FIXTURES (More realistic)
# ==============================================================================

# Create more realistic test data with 3 well-separated clusters
n_per_cluster <- 50
n_vars <- 5

# Cluster 1: High on all variables
cluster1 <- matrix(rnorm(n_per_cluster * n_vars, mean = 2, sd = 0.5),
                   nrow = n_per_cluster, ncol = n_vars)

# Cluster 2: Low on all variables
cluster2 <- matrix(rnorm(n_per_cluster * n_vars, mean = -2, sd = 0.5),
                   nrow = n_per_cluster, ncol = n_vars)

# Cluster 3: Mixed pattern
cluster3 <- matrix(rnorm(n_per_cluster * n_vars, mean = 0, sd = 0.5),
                   nrow = n_per_cluster, ncol = n_vars)

# Combine clusters
sample_gm_data <- rbind(cluster1, cluster2, cluster3)
colnames(sample_gm_data) <- paste0("Var", 1:n_vars)

# Fit sample GM model
sample_gm_model <- Mclust(sample_gm_data, G = 3, modelNames = "VVV")

# Create sample variable info
sample_gm_var_info <- data.frame(
  variable = paste0("Var", 1:n_vars),
  description = c(
    "Openness to experience",
    "Conscientiousness",
    "Extraversion",
    "Agreeableness",
    "Neuroticism"
  ),
  stringsAsFactors = FALSE
)

# Create sample analysis_data
sample_gm_analysis_data <- list(
  means = sample_gm_model$parameters$mean,
  covariances = sample_gm_model$parameters$variance$sigma,
  proportions = sample_gm_model$parameters$pro,
  memberships = sample_gm_model$z,
  classification = sample_gm_model$classification,
  uncertainty = sample_gm_model$uncertainty,
  covariance_type = sample_gm_model$modelName,
  n_clusters = sample_gm_model$G,
  n_variables = ncol(sample_gm_data),
  n_observations = nrow(sample_gm_data),
  analysis_type = "gm",
  variable_names = colnames(sample_gm_data),
  cluster_names = paste0("Cluster_", 1:sample_gm_model$G),
  min_cluster_size = 5,
  separation_threshold = 0.3,
  profile_variables = NULL,
  weight_by_uncertainty = FALSE,
  plot_type = "auto",
  loglik = sample_gm_model$loglik,
  bic = sample_gm_model$bic
)

# Save sample fixtures
saveRDS(sample_gm_model, "sample_gm_model.rds")
saveRDS(sample_gm_data, "sample_gm_data.rds")
saveRDS(sample_gm_var_info, "sample_gm_var_info.rds")
saveRDS(sample_gm_analysis_data, "sample_gm_analysis_data.rds")

# ==============================================================================
# STRUCTURED LIST FIXTURES
# ==============================================================================

# Create structured list (for testing validate_list_structure.gm)
sample_gm_list <- list(
  means = sample_gm_model$parameters$mean,
  covariances = sample_gm_model$parameters$variance$sigma,
  proportions = sample_gm_model$parameters$pro,
  memberships = sample_gm_model$z,
  classification = sample_gm_model$classification,
  uncertainty = sample_gm_model$uncertainty,
  covariance_type = sample_gm_model$modelName,
  variable_names = colnames(sample_gm_data),
  cluster_names = paste0("Cluster_", 1:sample_gm_model$G)
)

saveRDS(sample_gm_list, "sample_gm_list.rds")

# ==============================================================================
# EDGE CASE FIXTURES
# ==============================================================================

# Single cluster (edge case)
single_cluster_model <- Mclust(sample_gm_data, G = 1)
saveRDS(single_cluster_model, "single_cluster_model.rds")

# High uncertainty clusters (overlapping)
# Create overlapping clusters
overlap_cluster1 <- matrix(rnorm(40 * 3, mean = 0, sd = 1),
                          nrow = 40, ncol = 3)
overlap_cluster2 <- matrix(rnorm(40 * 3, mean = 0.5, sd = 1),
                          nrow = 40, ncol = 3)
overlap_data <- rbind(overlap_cluster1, overlap_cluster2)
colnames(overlap_data) <- c("X1", "X2", "X3")

overlap_model <- Mclust(overlap_data, G = 2)
saveRDS(overlap_model, "overlap_model.rds")

# Unbalanced clusters (one large, one small)
large_cluster <- matrix(rnorm(100 * 3, mean = 2, sd = 0.5),
                       nrow = 100, ncol = 3)
small_cluster <- matrix(rnorm(10 * 3, mean = -2, sd = 0.5),
                       nrow = 10, ncol = 3)
unbalanced_data <- rbind(large_cluster, small_cluster)
colnames(unbalanced_data) <- c("Y1", "Y2", "Y3")

unbalanced_model <- Mclust(unbalanced_data, G = 2)
saveRDS(unbalanced_model, "unbalanced_model.rds")

# High dimensional data
high_dim_data <- matrix(rnorm(100 * 15), nrow = 100, ncol = 15)
colnames(high_dim_data) <- paste0("Dim", 1:15)

high_dim_model <- Mclust(high_dim_data, G = 3)
saveRDS(high_dim_model, "high_dim_model.rds")

high_dim_var_info <- data.frame(
  variable = paste0("Dim", 1:15),
  description = paste("Dimension", 1:15),
  stringsAsFactors = FALSE
)
saveRDS(high_dim_var_info, "high_dim_var_info.rds")

# ==============================================================================
# JSON PARSING TEST FIXTURES
# ==============================================================================

# Valid JSON responses
valid_gm_json <- list(
  Cluster_1 = "This cluster represents individuals with high scores across all personality dimensions.",
  Cluster_2 = "This cluster shows low scores on all traits, indicating reserved personalities.",
  Cluster_3 = "This cluster has moderate scores, representing balanced personality profiles."
)
saveRDS(valid_gm_json, "valid_gm_json.rds")

# Malformed JSON (for testing extraction fallback)
malformed_gm_response <- 'Here are the interpretations:
Cluster_1: High achievers with strong conscientiousness
Cluster_2: Introverted and neurotic individuals
Cluster_3: Balanced and agreeable personalities
'
saveRDS(malformed_gm_response, "malformed_gm_response.rds")

cat("✓ All GM fixtures generated successfully!\n")
cat("Fixtures saved to: tests/testthat/fixtures/gm/\n")
