# Script to generate psych package model fixtures for testing
# These fixtures cache psych::fa and psych::principal models
# Saves ~0.2 seconds per test run

library(psych)

# Load the correlational data used in tests
correlational_data <- readRDS("tests/testthat/fixtures/fa/correlational_data.rds")

message("Fitting psych models...")

# 1. FA model with oblique rotation (oblimin)
message("  - psych::fa with oblimin rotation...")
fa_oblimin <- fa(correlational_data, nfactors = 2, rotate = "oblimin", warnings = FALSE)
saveRDS(fa_oblimin, "tests/testthat/fixtures/fa/sample_fa_oblimin.rds")
message("    ✓ Saved to sample_fa_oblimin.rds")

# 2. FA model with orthogonal rotation (varimax)
message("  - psych::fa with varimax rotation...")
fa_varimax <- fa(correlational_data, nfactors = 2, rotate = "varimax", warnings = FALSE)
saveRDS(fa_varimax, "tests/testthat/fixtures/fa/sample_fa_varimax.rds")
message("    ✓ Saved to sample_fa_varimax.rds")

# 3. PCA model with varimax
message("  - psych::principal with varimax...")
pca_varimax <- principal(correlational_data, nfactors = 2, rotate = "varimax")
saveRDS(pca_varimax, "tests/testthat/fixtures/fa/sample_pca_varimax.rds")
message("    ✓ Saved to sample_pca_varimax.rds")

message("\n✓ All psych model fixtures created successfully!")
message("  Models: 2 FA + 1 PCA")
message("  Factors: 2 each")
message("  Variables: 6 each")
