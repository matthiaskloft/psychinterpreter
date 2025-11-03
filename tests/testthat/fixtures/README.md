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

**Correlational Fixtures** (for S3 method testing with real FA packages):
- **`correlational_data.rds`**: Dataset with proper factor structure (6 variables, 100 obs)
- **`correlational_var_info.rds`**: Variable descriptions for correlational data
- **`make-correlational-data.R`**: Script to regenerate correlational fixtures

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

## Correlational Data Fixtures

Correlational fixtures provide realistic data with proper factor structure for testing S3 methods with real FA packages (psych, lavaan, mirt):

- **Purpose**: Avoid Heywood case warnings and ensure valid factor analysis results
- **Structure**: 6 variables with known two-factor structure (Factor 1: var1-var3, Factor 2: var4-var6)
- **Generation method**: FactorScores × Loadings' + Error
- **Use cases**: Testing `interpret.fa()`, `interpret.principal()`, `interpret.lavaan()`, etc.

**Why not use random data?**
Random uncorrelated data (e.g., `matrix(rnorm(100), ncol=5)`) violates FA assumptions and produces warnings like "The estimated weights for the factor scores are probably incorrect." Correlational fixtures have proper covariance structure that FA expects.

## Usage

Fixtures are loaded via helper functions in `tests/testthat/helper.R`:

```r
# Standard fixtures:
loadings <- sample_loadings()
var_info <- sample_variable_info()
factor_cor <- sample_factor_cor()
interpretation <- sample_interpretation()

# Minimal fixtures (for LLM tests):
loadings <- minimal_loadings()
var_info <- minimal_variable_info()
factor_cor <- minimal_factor_cor()

# Correlational fixtures (for S3 method tests):
data <- correlational_data()
var_info <- correlational_var_info()
```

These functions use `test_path()` to construct correct file paths in both interactive and automated testing environments.

## Regenerating Fixtures

If you need to update the fixture data:

**Standard fixtures:**
```r
setwd("tests/testthat/fixtures")
source("make-fixtures.R")
```

**Minimal fixtures:**
```r
setwd("tests/testthat/fixtures")
source("make-minimal-fixtures.R")
```

**Correlational fixtures:**
```r
setwd("tests/testthat/fixtures")
source("make-correlational-data.R")
```

This will regenerate the corresponding `.rds` files with the updated data.

## Design Rationale

Following best practices from [R Packages (2e)](https://r-pkgs.org/testing-design.html#storing-test-data):

- ✅ Test data stored in dedicated `fixtures/` subdirectory
- ✅ Data saved as `.rds` files (efficient, preserves R object structure)
- ✅ Accessed via `test_path()` for path portability
- ✅ Regeneration script (`make-fixtures.R`) included for maintainability
