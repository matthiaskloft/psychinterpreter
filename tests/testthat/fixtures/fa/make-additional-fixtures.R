# Generate additional cached interpretation fixtures
# Run this script when fixtures need to be regenerated
# Reduces LLM test dependencies by providing pre-generated interpretations

library(psychinterpreter)

# Check Ollama availability
if (!requireNamespace("ellmer", quietly = TRUE)) {
  stop("ellmer package required to generate fixtures")
}

message("Generating additional cached interpretation fixtures...")
message("This will make 4 LLM calls using Ollama.")
message("")

# === Fixture 1: Emergency Rule Applied ===
message("1. Generating sample_interpretation_emergency.rds...")
message("   Scenario: n_emergency rule applied (weak factor with no loadings above cutoff)")

# Create loadings where one factor has no loadings above cutoff
weak_loadings <- data.frame(
  variable = c("v1", "v2", "v3"),
  F1 = c(0.85, 0.75, 0.70),
  F2 = c(0.05, 0.03, 0.08)  # All below 0.3 cutoff
)

var_info_weak <- data.frame(
  variable = c("v1", "v2", "v3"),
  description = c("Item 1", "Item 2", "Item 3")
)

sample_interpretation_emergency <- interpret(
  fit_results = list(loadings = weak_loadings),
  variable_info = var_info_weak,
  analysis_type = "fa",
  cutoff = 0.3,
  n_emergency = 2,  # Use top 2 loadings
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud",
  word_limit = 20,
  silent = 2
)

saveRDS(
  sample_interpretation_emergency,
  "tests/testthat/fixtures/fa/sample_interpretation_emergency.rds"
)
message("   ✓ Created sample_interpretation_emergency.rds")
message("")

# === Fixture 2: Undefined Factor ===
message("2. Generating sample_interpretation_undefined.rds...")
message("   Scenario: Weak factor marked as 'undefined' (n_emergency = 0)")

sample_interpretation_undefined <- interpret(
  fit_results = list(loadings = weak_loadings),
  variable_info = var_info_weak,
  analysis_type = "fa",
  cutoff = 0.3,
  n_emergency = 0,  # Mark as undefined
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud",
  word_limit = 20,
  silent = 2
)

saveRDS(
  sample_interpretation_undefined,
  "tests/testthat/fixtures/fa/sample_interpretation_undefined.rds"
)
message("   ✓ Created sample_interpretation_undefined.rds")
message("")

# === Fixture 3: Markdown Format ===
message("3. Generating sample_interpretation_markdown.rds...")
message("   Scenario: Interpretation with markdown output format")

# Use minimal fixtures for token efficiency
loadings <- readRDS("tests/testthat/fixtures/fa/minimal_loadings.rds")
var_info <- readRDS("tests/testthat/fixtures/fa/minimal_variable_info.rds")

sample_interpretation_markdown <- interpret(
  fit_results = list(loadings = loadings),
  variable_info = var_info,
  analysis_type = "fa",
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud",
  word_limit = 20,
  output_format = "markdown",
  silent = 2
)

saveRDS(
  sample_interpretation_markdown,
  "tests/testthat/fixtures/fa/sample_interpretation_markdown.rds"
)
message("   ✓ Created sample_interpretation_markdown.rds")
message("")

# === Fixture 4: Cross-Loadings ===
message("4. Generating sample_interpretation_cross_loading.rds...")
message("   Scenario: Variables with cross-loadings above cutoff")

cross_loadings <- data.frame(
  variable = c("v1", "v2", "v3", "v4"),
  F1 = c(0.80, 0.75, 0.35, 0.05),  # v3 cross-loads
  F2 = c(0.10, 0.15, 0.65, 0.90)   # v3 cross-loads
)

var_info_cross <- data.frame(
  variable = c("v1", "v2", "v3", "v4"),
  description = c("Item 1", "Item 2", "Cross item", "Item 4")
)

sample_interpretation_cross_loading <- interpret(
  fit_results = list(loadings = cross_loadings),
  variable_info = var_info_cross,
  analysis_type = "fa",
  cutoff = 0.3,
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud",
  word_limit = 20,
  silent = 2
)

saveRDS(
  sample_interpretation_cross_loading,
  "tests/testthat/fixtures/fa/sample_interpretation_cross_loading.rds"
)
message("   ✓ Created sample_interpretation_cross_loading.rds")
message("")

message("========================================")
message("✓ All additional fixtures created successfully!")
message("")
message("Summary:")
message("  - sample_interpretation_emergency.rds (n_emergency = 2)")
message("  - sample_interpretation_undefined.rds (n_emergency = 0)")
message("  - sample_interpretation_markdown.rds (output_format = 'markdown')")
message("  - sample_interpretation_cross_loading.rds (cross-loadings present)")
message("")
message("Next steps:")
message("  1. Add helper functions to tests/testthat/helper.R")
message("  2. Update tests/testthat/fixtures/README.md")
message("  3. Update tests to use these cached fixtures instead of LLM calls")
