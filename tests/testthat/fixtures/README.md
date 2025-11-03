# Test Fixtures

This directory contains test fixture data used by the psychinterpreter test suite.

## Files

**Standard Fixtures** (for comprehensive testing):
- **`sample_loadings.rds`**: Factor loadings matrix (5 variables × 3 factors)
- **`sample_variable_info.rds`**: Variable descriptions (full-length)
- **`sample_factor_cor.rds`**: Factor correlation matrix 3×3 (for oblique rotations)
- **`sample_interpretation.rds`**: Complete `fa_interpretation` object (avoids LLM calls)
- **`make-fixtures.R`**: Script to regenerate standard fixtures

**Minimal Fixtures** (for token-efficient LLM testing):
- **`minimal_loadings.rds`**: Factor loadings matrix (3 variables × 2 factors)
- **`minimal_variable_info.rds`**: Variable descriptions (very short)
- **`minimal_factor_cor.rds`**: Factor correlation matrix 2×2
- **`make-minimal-fixtures.R`**: Script to regenerate minimal fixtures

## Token Efficiency

Minimal fixtures reduce token usage by ~60-70% compared to standard fixtures:

| Fixture Type | Variables | Factors | Avg Description Length | Estimated Tokens |
|--------------|-----------|---------|----------------------|------------------|
| Standard     | 5         | 3       | ~25 characters       | ~400-500         |
| Minimal      | 3         | 2       | ~6 characters        | ~150-200         |

**When to use minimal fixtures:**
- ✅ LLM integration tests (test-interpret_fa.R, test-print_methods.R)
- ✅ Tests validating LLM response handling
- ✅ Emergency rule testing (with `word_limit = 30` or similar low values)
- ❌ Tests not calling LLMs (use standard fixtures for better edge case coverage)

**Note:** The `word_limit` parameter now accepts values as low as 20 words (changed from 50) to support ultra-minimal testing scenarios. Recommended production range remains 100-300 words.

## Usage

Fixtures are loaded via helper functions in `tests/testthat/helper.R`:

```r
# In test files:
loadings <- sample_loadings()
var_info <- sample_variable_info()
factor_cor <- sample_factor_cor()
interpretation <- sample_interpretation()
```

These functions use `test_path()` to construct correct file paths in both interactive and automated testing environments.

## Regenerating Fixtures

If you need to update the fixture data:

1. Edit the data structures in `make-fixtures.R`
2. Run the script from this directory:

```r
setwd("tests/testthat/fixtures")
source("make-fixtures.R")
```

This will regenerate all `.rds` files with the updated data.

## Design Rationale

Following best practices from [R Packages (2e)](https://r-pkgs.org/testing-design.html#storing-test-data):

- ✅ Test data stored in dedicated `fixtures/` subdirectory
- ✅ Data saved as `.rds` files (efficient, preserves R object structure)
- ✅ Accessed via `test_path()` for path portability
- ✅ Regeneration script (`make-fixtures.R`) included for maintainability
