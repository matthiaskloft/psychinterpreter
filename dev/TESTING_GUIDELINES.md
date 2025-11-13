# Testing Guidelines

## Test Infrastructure

- **Framework**: testthat 3.0
- **Fixtures**: `tests/testthat/fixtures/*.rds`, cached in `.test_cache` environment (40x speedup)
- **Helper functions**: In `helper.R`, always use `test_path()` for paths

## LLM Testing Strategy

**Core Principle**: Separate data extraction tests (no LLM) from interpretation tests (with LLM)

**Current implementation** (as of 2025-11-11):
- **12 LLM tests** with `skip_on_ci()` across all test files:
  - Core interpretation: 2+ tests per model type
  - Chat sessions: 1+ test
  - Configuration objects: 5 integration tests
  - Additional edge case tests
- **S3 methods**: Do NOT test LLM calls - only test data extraction/formatting
- **All LLM tests** must use `word_limit = 20` to minimize token usage
- **All LLM tests** must use `skip_on_ci()` to avoid running on CI

## Fixture Selection

| Fixture | Size | Use Case |
|---------|------|----------|
| `minimal_*` | 3 vars × 2 factors | **LLM tests** (150-200 tokens, use `word_limit = 20`) |
| `sample_*` | 5 vars × 3 factors | Comprehensive non-LLM tests (400-500 tokens) |
| `correlational_*` | 6 vars × 2 factors | Realistic FA structure (no Heywood warnings) |

## Test Patterns

### LLM Test (Minimal)
```r
test_that("...", {
  skip_on_ci()
  data <- load_fixture("minimal_loadings")

  result <- interpret(
    fit_results = ...,
    variable_info = data$var_info,
    provider = "ollama",
    model = "gpt-oss:20b-cloud",
    word_limit = 20
  )

  expect_s3_class(result, "fa_interpretation")
})
```

### Non-LLM Test (Data Extraction)
```r
test_that("...", {
  # No skip_on_ci()
  fa_result <- psych::fa(data, nfactors = 3)

  expect_equal(nrow(extract_loadings(fa_result)), 5)
  expect_equal(ncol(extract_loadings(fa_result)), 3)
})
```

### Validation Tests (Layered)
```r
test_that("requires model_type for raw data", {
  expect_error(
    interpret(
      fit_results = loadings,
      variable_info = var_info,
      provider = "ollama"  # ← Bypass earlier validation
    ),
    "model_type.*required"
  )
})
```

**Key**: Add minimal params to bypass earlier validations when testing later ones.

### Backward Compatibility Test
```r
test_that("old parameter name still works", {
  old_syntax <- list(loadings = loadings, Phi = phi)
  expect_true(all(c("loadings", "Phi") %in% names(old_syntax)))
})
```

## Common Issues

| Error | Cause | Fix |
|-------|-------|-----|
| "Parameter X required" but provided | Not passed through call chain | Check all intermediate functions pass it explicitly |
| Test fails in suite, passes alone | Missing `skip_on_ci()` or order dependency | Add skip or make tests independent |
| "Object not found" in helpers | Not using `test_path()` | Use `test_path("fixtures/...")` |

## Quick Checklist

When adding tests after API changes:
- [ ] Tests bypass earlier validations to test target validation
- [ ] Backward compatibility test if parameter renamed
- [ ] Use `minimal_*` fixtures for LLM tests
- [ ] Add `skip_on_ci()` to all LLM tests
- [ ] Use `test_path()` for all file paths

---

**Last Updated**: 2025-11-12
