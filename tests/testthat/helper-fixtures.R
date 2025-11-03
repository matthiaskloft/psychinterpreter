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

# Check if Ollama is available for LLM tests
has_ollama <- function() {
  # Skip on CI environments (GitHub Actions, etc.)
  if (identical(Sys.getenv("CI"), "true")) {
    return(FALSE)
  }

  # Try to check if Ollama is running by attempting a basic connection
  # This is a simple check - if ellmer can't connect, it will fail during test
  tryCatch({
    # Check if we can load ellmer package
    requireNamespace("ellmer", quietly = TRUE)
  }, error = function(e) {
    FALSE
  })
}

# Skip test if Ollama/ellmer not available
skip_if_no_llm <- function() {
  if (!has_ollama()) {
    testthat::skip("ellmer package not available for Ollama")
  }
}

# Sample interpretation result (fixture to avoid LLM calls in tests)
sample_interpretation <- function() {
  loadings <- sample_loadings()

  # Create a realistic fa_interpretation object
  result <- list(
    suggested_names = list(
      ML1 = "Cognitive Ability",
      ML2 = "Numerical Skills",
      ML3 = "Memory Performance"
    ),
    factor_summaries = list(
      ML1 = list(
        summary = "This factor captures cognitive ability and reasoning skills, with strong loadings from variables 1 and 2 (0.80, 0.70).\n\nVariables with significant loadings:\n- var1: First variable description (0.80)\n- var2: Second variable description (0.70)",
        n_loadings = 2,
        has_emergency = FALSE,
        variance_explained = 0.28
      ),
      ML2 = list(
        summary = "This factor represents numerical skills and quantitative reasoning, with strong loadings from variables 3 and 4 (0.75, 0.82).\n\nVariables with significant loadings:\n- var3: Third variable description (0.75)\n- var4: Fourth variable description (0.82)",
        n_loadings = 2,
        has_emergency = FALSE,
        variance_explained = 0.25
      ),
      ML3 = list(
        summary = "This factor reflects memory performance and recall ability, with a dominant loading from variable 5 (0.85).\n\nVariables with significant loadings:\n- var5: Fifth variable description (0.85)",
        n_loadings = 1,
        has_emergency = FALSE,
        variance_explained = 0.18
      )
    ),
    loading_matrix = data.frame(
      variable = c("var1", "var2", "var3", "var4", "var5"),
      ML1 = c(".80", ".70", "", "", ""),
      ML2 = c("", "", ".75", ".82", ""),
      ML3 = c("", "", "", "", ".85"),
      stringsAsFactors = FALSE
    ),
    factor_cor_mat = sample_factor_cor(),
    cross_loadings = data.frame(
      variable = character(0),
      factors = character(0),
      description = character(0),
      stringsAsFactors = FALSE
    ),
    no_loadings = data.frame(
      variable = character(0),
      highest_loading = character(0),
      description = character(0),
      stringsAsFactors = FALSE
    ),
    cutoff = 0.3,
    run_tokens = list(
      input = 250,
      output = 180
    ),
    llm_info = list(
      provider = "ollama",
      model = "gpt-oss:20b-cloud"
    ),
    elapsed_time = as.difftime(2.5, units = "secs"),
    report = "FACTOR ANALYSIS INTERPRETATION\n\n3 factors identified\nLoading cutoff: 0.3\n\n=== SUMMARY ===\n\nML1: Cognitive Ability\nML2: Numerical Skills\nML3: Memory Performance\n\n=== FACTOR DETAILS ===\n\n--- ML1: Cognitive Ability ---\n\nThis factor captures cognitive ability and reasoning skills, with strong loadings from variables 1 and 2 (0.80, 0.70).\n\nVariables with significant loadings:\n- var1: First variable description (0.80)\n- var2: Second variable description (0.70)\n\n--- ML2: Numerical Skills ---\n\nThis factor represents numerical skills and quantitative reasoning, with strong loadings from variables 3 and 4 (0.75, 0.82).\n\nVariables with significant loadings:\n- var3: Third variable description (0.75)\n- var4: Fourth variable description (0.82)\n\n--- ML3: Memory Performance ---\n\nThis factor reflects memory performance and recall ability, with a dominant loading from variable 5 (0.85).\n\nVariables with significant loadings:\n- var5: Fifth variable description (0.85)\n\n=== FACTOR CORRELATIONS ===\n\n       ML1   ML2   ML3\nML1   1.00  0.25 -0.15\nML2   0.25  1.00  0.30\nML3  -0.15  0.30  1.00\n"
  )

  class(result) <- c("fa_interpretation", "list")
  return(result)
}
