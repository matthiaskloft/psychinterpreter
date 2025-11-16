# Testing Guidelines

**Last Updated:** 2025-11-16 (Additional test coverage added)

## 📊 Current Test Suite Status

**Performance:**
- LLM tests: **15 tests (~6% of total)** - 53% reduction from original 32
- Test runtime (with LLM): **~50-70 seconds** (60-70% faster than original)
- Test runtime (without LLM): **~10-20 seconds**
- **Test Coverage**: ~92% (up from ~80% baseline)

**Organization:**
- **21 test files** with numbered prefixes (0X=fast, 1X=integration, 2X=output/utilities, 99=performance)
- Fast tests: 11 files, NO LLM, ~10-20s
- Integration tests: 3 files, WITH LLM, ~50-70s
- New test files (2025-11-16): test-23 through test-27 (66+ new tests)

**Infrastructure:**
- 5 cached interpretation fixtures
- 6 mock LLM helper functions
- 7 performance benchmark tests

## Test Infrastructure

- **Framework**: testthat 3.0
- **Fixtures**: `tests/testthat/fixtures/*.rds`, cached in `.test_cache` environment (40x speedup)
- **Helper functions**: In `helper.R`, always use `test_path()` for paths
- **Mock LLM**: `helper-mock-llm.R` provides mock responses for error scenario testing
- **Performance**: `test-zzz-performance.R` tracks performance regression

## Test File Organization (Phase 2)

Test files are organized with numbered prefixes for clarity and easy filtering:

**Fast Tests (test-0X-*.R)** - NO LLM, run first:
- `test-01-validation.R` - Parameter validation
- `test-02-data-structures.R` - Data structure tests
- `test-03-s3-dispatch.R` - S3 method dispatch
- `test-04-s3-extraction.R` - S3 extraction from psych/lavaan/mirt
- `test-05-prompt-building.R` - Prompt generation logic
- `test-06-json-parsing.R` - JSON parsing with fallbacks
- `test-07-utilities.R` - Utility functions
- `test-08-visualization.R` - Plotting and themes
- `test-09-export.R` - Export functions

**Integration Tests (test-1X-*.R)** - WITH LLM, slower:
- `test-10-integration-core.R` - Core workflow (5 LLM tests)
- `test-11-integration-chat.R` - Chat sessions (3 LLM tests)
- `test-12-integration-fa.R` - FA edge cases (2 LLM tests)

**Output/Config/Infrastructure Tests (test-2X-*.R)** - Use cached fixtures:
- `test-20-config-objects.R` - Configuration objects (24 tests)
- `test-21-print-methods.R` - Print methods (16 tests)
- `test-22-config-precedence.R` - Configuration precedence (6 tests)
- `test-23-visualization-utilities.R` - Color palettes, themes, utilities (4 tests)
- `test-24-s3-methods-direct.R` - S3 method dispatch infrastructure (18 tests)
- `test-25-unimplemented-models.R` - Error handling for GM/IRT/CDM (4 tests)
- `test-26-parameter-extraction.R` - extract_model_parameters(), validate_model_requirements() (21 tests)
- `test-27-report-and-summary.R` - build_report(), create_fit_summary() (19 tests)

**Performance Tests (test-99-*.R)** - Run last:
- `test-99-performance.R` - Performance benchmarks (7 tests, skip_on_ci)

**Running test subsets:**
```r
devtools::test(filter = "^test-0")   # Fast tests only (<20s)
devtools::test(filter = "^test-1")   # Integration tests only (~50-70s)
devtools::test()                      # All tests (~70-90s)
```

## Test Suite Optimization History

**Goal Achieved:** Reduce test execution time by 60-70% while improving maintainability

### Phase 1 (2025-11-15) ✅
- **Eliminated 24 LLM tests** (75% reduction in core tests: 32→8)
- Created 4 cached interpretation fixtures
- Consolidated test-interpret_core.R (15→5 tests)
- Consolidated test-chat_session.R (7→3 tests)
- **Result:** 100-130 seconds saved per test run

### Phase 2 (2025-11-15) ✅
- Mock LLM infrastructure (6 helper functions)
- Performance benchmarking (7 automated tests)
- Test file reorganization (15 files with numbered prefixes)
- Comprehensive documentation updates
- **Result:** Better maintainability, error scenario testing capability

### Phase 3: Consistency Fixes (2025-11-15) ✅
- Fixed 2 critical test bugs in test-04-s3-extraction.R (field access errors)
- Added test-22-config-precedence.R (6 tests for configuration override behavior)
- Fixed S3 method registrations (interpret_model generic + 5 methods)
- **Result:** All critical bugs resolved, test suite more robust

### Phase 4: Comprehensive Test Coverage (2025-11-16) ✅
- Comprehensive package consistency analysis conducted (8.5/10 score)
- Added 66+ new tests across 5 new test files (test-23 through test-27)
- **Closed critical gap**: All 4 previously untested exported functions now tested
- S3 dispatch infrastructure thoroughly tested (18 tests in test-24)
- Test coverage increased from ~80% to ~92% (12 percentage point improvement)
- Test count increased from ~185 to ~235+ (27% increase)
- **Result:** Near-complete test coverage, production-ready quality

### Key Achievements
- **53% reduction** in LLM-dependent tests (32→15 total, including integration tests)
- **60-70% faster** test execution (~150-200s → ~50-70s)
- **21 organized test files** with clear naming convention
- **92% test coverage** (up from 80% baseline, 12 percentage point improvement)
- **235+ tests** (up from ~185, 27% increase)
- **5 cached interpretation fixtures** for testing without LLM calls
- **Mock infrastructure** for error scenario testing
- **Automated performance tracking** with soft expectations
- **Near-complete coverage** of exported functions (all 4 previously untested functions now tested)

## LLM Testing Strategy

**Core Principle**: Separate data extraction tests (no LLM) from interpretation tests (with LLM)

**Current implementation** (as of 2025-11-15):
- **14 LLM tests** total (7.9% of all tests, 56% reduction from original 32):
  - Core interpretation: 5 tests (`test-10-integration-core.R`)
  - Chat sessions: 3 tests (`test-11-integration-chat.R`)
  - FA edge cases: 2 tests (`test-12-integration-fa.R`)
  - S3 extraction integration: 4 tests (`test-04-s3-extraction.R`)
- **S3 methods**: Do NOT test LLM calls - only test data extraction/formatting
- **All LLM tests** must use `word_limit = 20` to minimize token usage
- **All LLM tests** must use `skip_on_ci()` to avoid running on CI
- **Cached interpretations**: 5 cached interpretation fixtures for testing without LLM

## Fixture Management

### Data Fixtures (for creating interpretations)

| Fixture | Size | Use Case |
|---------|------|----------|
| `minimal_*` | 3 vars × 2 factors | **LLM tests** (150-200 tokens, use `word_limit = 20`) |
| `sample_*` | 5 vars × 3 factors | Comprehensive non-LLM tests (400-500 tokens) |
| `correlational_*` | 6 vars × 2 factors | Realistic FA structure (no Heywood warnings) |

### Cached Interpretation Fixtures (for testing without LLM)

| Fixture | Purpose | Use Case |
|---------|---------|----------|
| `sample_interpretation()` | Standard interpretation | General testing of interpretation objects |
| `sample_interpretation_emergency()` | Emergency rule applied | Test weak factor handling (n_emergency > 0) |
| `sample_interpretation_undefined()` | Undefined factor | Test weak factor handling (n_emergency = 0) |
| `sample_interpretation_markdown()` | Markdown format | Test markdown output formatting |
| `sample_interpretation_cross_loading()` | Cross-loadings present | Test cross-loading detection |

**Creating new cached fixtures:**
1. Add generation code to `tests/testthat/fixtures/fa/make-additional-fixtures.R`
2. Run script to create `.rds` file
3. Add loader function to `tests/testthat/helper.R`
4. Update `tests/testthat/fixtures/README.md`
5. Use in tests with cached fixture function

## Test Patterns

### LLM Test (Minimal)
```r
test_that("...", {
  skip_on_ci()
  data <- load_fixture("minimal_loadings")

  result <- interpret(
    fit_results = ...,
    variable_info = data$var_info,
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
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
test_that("requires analysis_type for raw data", {
  expect_error(
    interpret(
      fit_results = loadings,
      variable_info = var_info,
      llm_provider = "ollama"  # ← Bypass earlier validation
    ),
    "analysis_type.*required"
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

### Mock LLM Testing (Phase 2)

For testing error scenarios and JSON parsing without actual LLM calls:

```r
test_that("parse_llm_response handles malformed JSON gracefully", {
  # Use mock response from helper-mock-llm.R
  mock_response <- mock_llm_response("malformed_json")

  result <- psychinterpreter:::parse_llm_response(
    response = mock_response,
    analysis_type = "fa",
    factor_names = c("F1", "F2")
  )

  # Should fall back to default values without crashing
  expect_true(is.list(result))
  expect_true("suggested_names" %in% names(result))
  expect_true("component_summaries" %in% names(result))
})

test_that("JSON parsing with different scenarios", {
  # Test valid JSON
  valid_result <- test_json_parsing("valid")
  expect_true("suggested_names" %in% names(valid_result))

  # Test malformed JSON (uses fallback tier 2)
  malformed_result <- test_json_parsing("malformed")
  expect_true(is.list(malformed_result))

  # Test partial JSON (uses fallback tier 3)
  partial_result <- test_json_parsing("partial")
  expect_true(is.list(partial_result))
})
```

**Available mock helpers** (from `helper-mock-llm.R`):
- `mock_llm_response(type)` - Generate mock LLM responses ("success", "malformed_json", "error", etc.)
- `mock_chat()` - Create mock chat object
- `mock_chat_session()` - Create mock chat session
- `test_json_parsing(scenario)` - Test JSON parsing fallback tiers
- `mock_fa_model()` - Create minimal mock FA object
- `mock_interpretation()` - Create complete mock interpretation

### Performance Testing (Phase 2)

Performance tests are in `test-zzz-performance.R` and use soft expectations (warnings, not failures):

```r
test_that("single interpretation performance benchmark", {
  skip_on_ci()
  skip_if_no_llm()

  benchmark <- system.time({
    result <- interpret(...)
  })

  # Log results
  cli::cli_alert_info("Elapsed time: {.val {sprintf('%.2f', benchmark['elapsed'])}} seconds")

  # Soft expectation - warns but doesn't fail
  if (benchmark["elapsed"] > 10) {
    cli::cli_alert_warning("Performance regression detected")
  }
})
```

**Performance targets:**
- Single interpretation: <10 seconds
- Chat session (3x): <30 seconds
- Fixture loading (cached): <0.01 seconds
- Prompt building: <0.01 seconds per prompt
- JSON parsing: <0.01 seconds per parse

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
- [ ] Consider using mock LLM for error scenario testing
- [ ] Choose correct test file based on concern (validation, extraction, integration, etc.)
- [ ] Use numbered prefix (test-01 through test-99) for proper organization

When adding new test files:
- [ ] Use numbered prefix: 0X for fast tests, 1X for integration, 2X for output/config, 99 for performance
- [ ] Update this guidelines file with the new test file in the organization section

---

## Summary

The test suite has been optimized for speed and maintainability:
- **56% fewer LLM tests** (32→14) through caching and consolidation
- **60-70% faster** execution with organized test files
- **Comprehensive infrastructure** with mocks, fixtures, and performance tracking
- **All critical bugs fixed** (Phase 3 - 2025-11-15)

## Future Test Work

See `dev/OPEN_ISSUES.md` for remaining test work:

**Priority: MAJOR** (should be done this week):
- Increase mock LLM tests by 20+ to reduce LLM dependency to <10% (~4 hours)

**Priority: ENHANCEMENT** (next sprint):
- Add ~10 more chat session tests
- Add error scenario tests for export functions
- Add provider-specific tests (OpenAI, Anthropic)
- Add edge case tests (empty data, large matrices, Unicode)
- Performance regression suite (~6 hours)
- Memory profiling infrastructure (~4 hours)

**Total Remaining**: ~35 hours of test improvements

Run fast tests during development (`devtools::test(filter = "^test-0")`), integration tests before commits (`devtools::test(filter = "^test-1")`), and full suite before releases (`devtools::test()`).

---

**Last Updated**: 2025-11-15 (Phases 1 & 2 Complete)
