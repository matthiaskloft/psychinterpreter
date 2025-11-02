# Test Fixtures
# Shared test data for psychinterpreter tests

# Sample factor loadings matrix
sample_loadings <- function() {
  data.frame(
    variable = c("var1", "var2", "var3", "var4", "var5"),
    ML1 = c(0.8, 0.7, 0.2, 0.1, 0.05),
    ML2 = c(0.1, 0.15, 0.75, 0.82, 0.1),
    ML3 = c(0.05, 0.1, 0.1, 0.05, 0.85)
  )
}

# Sample variable information
sample_variable_info <- function() {
  data.frame(
    variable = c("var1", "var2", "var3", "var4", "var5"),
    description = c(
      "First variable description",
      "Second variable description",
      "Third variable description",
      "Fourth variable description",
      "Fifth variable description"
    ),
    stringsAsFactors = FALSE
  )
}

# Sample factor correlation matrix (for oblique rotations)
sample_factor_cor <- function() {
  matrix(
    c(1.00, 0.25, -0.15,
      0.25, 1.00, 0.30,
      -0.15, 0.30, 1.00),
    nrow = 3,
    dimnames = list(c("ML1", "ML2", "ML3"), c("ML1", "ML2", "ML3"))
  )
}

# Check if API keys are available for LLM tests
has_openai_key <- function() {
  Sys.getenv("OPENAI_API_KEY") != ""
}

has_anthropic_key <- function() {
  Sys.getenv("ANTHROPIC_API_KEY") != ""
}

# Skip test if no API key available
skip_if_no_llm <- function() {
  if (!has_openai_key() && !has_anthropic_key()) {
    testthat::skip("No LLM API keys available")
  }
}
