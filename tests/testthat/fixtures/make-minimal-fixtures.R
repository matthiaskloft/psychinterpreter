# Script to generate minimal, token-efficient test fixtures for LLM tests
# These fixtures use fewer variables and shorter descriptions to minimize token usage

# Minimal factor loadings: 3 variables × 2 factors (vs. 5 variables × 3 factors)
minimal_loadings <- data.frame(
  variable = c("v1", "v2", "v3"),
  F1 = c(0.85, 0.75, 0.05),
  F2 = c(0.10, 0.05, 0.80)
)

# Minimal variable information with very short descriptions
minimal_variable_info <- data.frame(
  variable = c("v1", "v2", "v3"),
  description = c(
    "Item 1",  # Was: "First variable description"
    "Item 2",  # Was: "Second variable description"
    "Item 3"   # Was: "Third variable description"
  ),
  stringsAsFactors = FALSE
)

# Minimal factor correlation matrix (2×2 instead of 3×3)
minimal_factor_cor <- matrix(
  c(1.00, 0.20,
    0.20, 1.00),
  nrow = 2,
  dimnames = list(c("F1", "F2"), c("F1", "F2"))
)

# Save minimal fixtures
saveRDS(minimal_loadings, "minimal_loadings.rds")
saveRDS(minimal_variable_info, "minimal_variable_info.rds")
saveRDS(minimal_factor_cor, "minimal_factor_cor.rds")

message("Minimal fixtures saved successfully!")
message("Token savings estimate: ~60-70% reduction compared to standard fixtures")
