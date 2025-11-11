# Script to generate MIRT model fixture for testing
# This fixture caches the MIRT model to avoid expensive fitting in tests
# Saves ~4 seconds per test run

library(mirt)

# Use LSAT7 dataset (standard mirt example)
data <- expand.table(LSAT7)

# Fit a 2-dimensional 2PL model
# This is the expensive operation we want to cache
message("Fitting MIRT 2PL model (this takes ~4 seconds)...")
mirt_model <- mirt(data, 2, itemtype = "2PL", verbose = FALSE)

# Save the fitted model
output_path <- "tests/testthat/fixtures/fa/sample_mirt_model.rds"
saveRDS(mirt_model, output_path)

message("✓ MIRT model fixture saved to: ", output_path)
message("  Model: 2-dimensional 2PL IRT")
message("  Items: ", nrow(coef(mirt_model, simplify = TRUE)$items))
message("  Dimensions: 2")
