# Script to generate lavaan CFA model fixture for testing
# This fixture caches the lavaan CFA model to avoid expensive fitting in tests
# Saves ~0.5 seconds per test run

library(lavaan)

# Simple CFA model (same as used in tests)
model_syntax <- '
  visual  =~ x1 + x2 + x3
  textual =~ x4 + x5 + x6
'

# Fit CFA model on HolzingerSwineford1939 dataset
message("Fitting lavaan CFA model (this takes ~0.5 seconds)...")
cfa_fit <- cfa(model_syntax, data = HolzingerSwineford1939, std.lv = TRUE)

# Save the fitted model
output_path <- "tests/testthat/fixtures/fa/sample_lavaan_cfa.rds"
saveRDS(cfa_fit, output_path)

# Get model info for verification
std_sol <- lavaan::standardizedSolution(cfa_fit)
n_loadings <- sum(std_sol$op == "=~")
n_factors <- length(unique(std_sol$lhs[std_sol$op == "=~"]))

message("✓ lavaan CFA model fixture saved to: ", output_path)
message("  Model: Confirmatory Factor Analysis")
message("  Factors: ", n_factors)
message("  Indicators: ", n_loadings)
message("  Dataset: HolzingerSwineford1939")
