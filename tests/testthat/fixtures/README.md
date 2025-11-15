# Test Fixtures

This directory contains test fixture data used by the psychinterpreter test suite.

## Files

**Standard Fixtures** (for comprehensive testing):
- **`sample_loadings.rds`**: Factor loadings matrix (5 variables × 3 factors)
- **`sample_variable_info.rds`**: Variable descriptions (full-length)
- **`sample_factor_cor.rds`**: Factor correlation matrix 3×3 (for oblique rotations)
- **`sample_interpretation.rds`**: Complete `fa_interpretation` object (avoids LLM calls)
- **`sample_interpretation_emergency.rds`**: Interpretation with emergency rule applied (n_emergency = 2)
- **`sample_interpretation_undefined.rds`**: Interpretation with undefined factor (n_emergency = 0)
- **`sample_interpretation_markdown.rds`**: Interpretation with markdown output format
- **`sample_interpretation_cross_loading.rds`**: Interpretation with cross-loading variables
- **`make-fixtures.R`**: Script to regenerate standard fixtures
- **`make-additional-fixtures.R`**: Script to regenerate cached interpretation fixtures

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

## Cached Interpretation Fixtures

Cached interpretation fixtures are pre-generated complete `fa_interpretation` objects that allow testing specific scenarios without making LLM calls. These fixtures significantly reduce test runtime.

**Available cached interpretation fixtures:**

1. **`sample_interpretation.rds`** - Standard interpretation (baseline)
   - 3 factors with clear loadings
   - All factors have loadings above default cutoff (0.3)
   - Use for: General interpretation testing, output formatting, export functions

2. **`sample_interpretation_emergency.rds`** - Emergency rule applied
   - Scenario: One weak factor with no loadings above cutoff
   - n_emergency = 2 (uses top 2 loadings)
   - Use for: Testing emergency rule behavior, weak factor handling

3. **`sample_interpretation_undefined.rds`** - Undefined factor
   - Scenario: Weak factor with no loadings above cutoff
   - n_emergency = 0 (factor marked as "undefined")
   - Use for: Testing undefined factor handling, edge case validation

4. **`sample_interpretation_markdown.rds`** - Markdown formatting
   - Scenario: Same as standard interpretation but with markdown output format
   - Use for: Testing markdown formatting, export to .md files

5. **`sample_interpretation_cross_loading.rds`** - Cross-loadings present
   - Scenario: Variables loading on multiple factors above cutoff
   - Use for: Testing cross-loading detection, complex factor structures

**When to use cached interpretation fixtures:**
- ✅ Testing print methods (avoid LLM calls)
- ✅ Testing export functions (avoid LLM calls)
- ✅ Testing visualization functions (avoid LLM calls)
- ✅ Testing output formatting (avoid LLM calls)
- ✅ Testing specific edge cases (emergency rule, undefined factors, cross-loadings)
- ❌ Integration tests that validate end-to-end LLM workflow (use real LLM)
- ❌ Performance benchmarks (use real LLM to measure actual performance)

## Usage

Fixtures are loaded via helper functions in `tests/testthat/helper.R`:

```r
# Standard fixtures:
loadings <- sample_loadings()
var_info <- sample_variable_info()
factor_cor <- sample_factor_cor()
interpretation <- sample_interpretation()

# Cached interpretation fixtures (for specific test scenarios):
interp_emergency <- sample_interpretation_emergency()
interp_undefined <- sample_interpretation_undefined()
interp_markdown <- sample_interpretation_markdown()
interp_cross <- sample_interpretation_cross_loading()

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

**Cached interpretation fixtures** (requires Ollama running):
```r
setwd("tests/testthat/fixtures/fa")
source("make-additional-fixtures.R")
```

This will regenerate the corresponding `.rds` files with the updated data.

**Note:** Regenerating cached interpretation fixtures requires a running Ollama instance with the `gpt-oss:20b-cloud` model. Each fixture generation makes 4 LLM calls with `word_limit = 20` for token efficiency.

## Design Rationale

Following best practices from [R Packages (2e)](https://r-pkgs.org/testing-design.html#storing-test-data):

- ✅ Test data stored in dedicated `fixtures/` subdirectory
- ✅ Data saved as `.rds` files (efficient, preserves R object structure)
- ✅ Accessed via `test_path()` for path portability
- ✅ Regeneration script (`make-fixtures.R`) included for maintainability
