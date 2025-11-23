# Testing Guidelines

**Last Updated:** 2025-11-23

## 📊 Current Test Suite Status

**Performance:**
- LLM tests: **15-18 tests (~4% of total)** - 53% reduction from original 32
- Test runtime (with LLM, parallel): **~30-60 seconds** (5-10x faster with parallel execution)
- Test runtime (without LLM, parallel): **~2-5 seconds** (95% faster)
- Test runtime (sequential, no LLM): **~10-20 seconds**
- **Test Coverage**: ~92% (maintained from Phase 4)
- **Total test_that() calls**: ~417+

**Organization:**
- **27 test files** with numbered prefixes (0X=fast, 1X=integration, 2X=output/utilities, 3X=provider-specific, 99=performance)
- Fast tests: 11 files, NO LLM, ~10-20s (sequential), ~2-5s (parallel)
- Integration tests: 3 files, WITH LLM, ~50-70s (sequential), ~15-25s (parallel)
- Provider-specific: 1 file, WITH LLM (skips without API keys), 18 tests
- New test files (2025-11-18): test-30 (provider integration, 18 tests)
- New test files (2025-11-16): test-23 through test-27 (66+ tests)

**Infrastructure:**
- 5 cached interpretation fixtures
- 11 mock LLM scenarios (success, malformed JSON, errors, unicode, very long responses, etc.)
- 6 mock LLM helper functions
- 7 performance benchmark tests
- **Parallel test execution** (2025-11-23)
- **Test filtering helpers** (2025-11-23)

---

## ⚡ Test Execution Optimization

### 🚨 IMPORTANT: Enabling LLM Tests

**LLM tests are DISABLED BY DEFAULT** to prevent unexpected API calls and costs.

To run LLM tests, you must explicitly enable them:

```r
# Enable LLM tests for current session
Sys.setenv(RUN_LLM_TESTS = "true")

# Or add to .Renviron file:
# RUN_LLM_TESTS=true
```

See `tests/testthat/README_TEST_CONFIG.md` for detailed configuration options.

### Quick Reference

**For development** (fastest iteration - no LLM):
```r
# Smoke test - critical tests only (< 5 seconds)
source("tests/test_config.R")
test_smoke()

# Fast tests only, no LLM (< 10 seconds with parallel)
test_fast()

# Specific test file
test_file(10)  # Run test-10-integration-core.R
```

**For testing WITH LLM** (when needed):
```r
# Enable LLM tests first
Sys.setenv(RUN_LLM_TESTS = "true")

# Integration tests only (~15-25s with parallel)
source("tests/test_config.R")
test_integration()
```

**For pre-commit** (comprehensive validation):
```r
# Fast tests only (no LLM, ~5-10 seconds - RECOMMENDED)
Sys.setenv(PARALLEL_TESTS = "true")
source("tests/test_config.R")
test_fast()

# OR: All tests including LLM (~30-60 seconds)
Sys.setenv(RUN_LLM_TESTS = "true")
Sys.setenv(PARALLEL_TESTS = "true")
devtools::test()

# Or using shell alias (if sourced dev/test_commands.sh)
# test-all
```

**For CI/CD** (automated testing):
```bash
# LLM tests automatically skipped, parallel may be limited
R CMD check .
```

### Parallel Test Execution (2025-11-23)

**Impact**: 5-10x speedup on multi-core machines

Parallel execution is **enabled by default** via `tests/testthat.R` and auto-detects available cores:

```r
# Enable parallel tests (default)
PARALLEL_TESTS=true devtools::test()

# Disable if needed (for debugging race conditions)
PARALLEL_TESTS=false devtools::test()

# Control number of cores manually
test_check("psychinterpreter", parallel = 4)
```

**Auto-detection behavior**:
- Automatically uses (cores - 2) for stability
- Automatically disabled on CI to avoid resource conflicts
- Can be overridden with `PARALLEL_TESTS` environment variable

**Performance improvement**:
- Fast tests: 10-20s → **2-5s** (5-10x faster)
- Full suite: 150-200s → **30-60s** (3-5x faster)
- Integration tests: 50-70s → **15-25s** (3-4x faster)

### Test Filtering

**Helper functions** (from `tests/test_config.R`):

```r
# Load test config helpers
source("tests/test_config.R")

# Fast unit tests only (no LLM) - ~5-10 seconds with parallel
test_fast()

# Integration tests only (with LLM) - ~15-25 seconds with parallel
test_integration()

# Specific test file by number
test_file(10)  # Runs test-10-integration-core.R
test_file(23)  # Runs test-23-visualization-utilities.R

# All tests except performance benchmarks
test_all_except_perf()

# Quick smoke test - minimal coverage check (~2-5 seconds)
test_smoke()
```

**Manual filtering** (using devtools):
```r
# Fast tests only (<5s with parallel)
devtools::test(filter = "^0[1-9]")

# Integration tests only (~15-25s with parallel)
devtools::test(filter = "^1[0-4]")

# Config/output tests (~5-8s with parallel)
devtools::test(filter = "^2[0-9]")

# Provider tests (requires API keys)
devtools::test(filter = "^30")

# Specific test file
devtools::test(filter = "^10")
```

### Shell Aliases (Optional)

Source `dev/test_commands.sh` for convenient aliases:

```bash
source dev/test_commands.sh

# Now available:
test-quick        # Smoke test (< 5s)
test-fast         # Unit tests only (< 10s)
test-integration  # LLM tests (15-25s)
test-all          # Full suite (< 1 min)
test-check        # R CMD check
test-perf         # Performance benchmarks
```

### Environment Variables for Testing

Control test behavior via environment variables:

```bash
# Enable/disable LLM tests (default: false - DISABLED BY DEFAULT)
export RUN_LLM_TESTS=true

# Parallel execution (default: true)
export PARALLEL_TESTS=true

# LLM provider for tests (default: ollama)
export TEST_LLM_PROVIDER=ollama
export TEST_LLM_MODEL=llama3.2:3b  # Faster than gpt-oss:20b-cloud

# Skip LLM tests (automatic on CI)
export CI=true

# Provider-specific API keys
export OPENAI_API_KEY="your-openai-key"
export ANTHROPIC_API_KEY="your-anthropic-key"
```

**IMPORTANT:** LLM tests are **disabled by default** to prevent unexpected API calls and costs. You must explicitly set `RUN_LLM_TESTS=true` to enable them.

**Faster LLM testing** (use smaller models):
```r
# FIRST: Enable LLM tests (disabled by default)
Sys.setenv(RUN_LLM_TESTS = "true")

# THEN: Use faster model for 2-3x speedup on LLM tests
Sys.setenv(TEST_LLM_PROVIDER = "ollama")
Sys.setenv(TEST_LLM_MODEL = "llama3.2:3b")  # Much faster than 20b

# Now integration tests run in ~8-12s instead of ~15-25s
source("tests/test_config.R")
test_integration()
```

### Performance Expectations

| Command | Time (Sequential) | Time (Parallel) | LLM Calls |
|---------|------------------|-----------------|-----------|
| `test_smoke()` | ~10s | ~2-5s | No |
| `test_fast()` | ~30s | ~5-10s | No |
| `test_integration()` | ~3-5 min | ~15-25s | Yes (12-15 tests) |
| Full suite | ~5-8 min | ~30-60s | Yes |
| R CMD check | ~8-10 min | ~3-5 min | No (CI skips LLM) |

### Troubleshooting Test Performance

**Tests still slow?**

1. Check parallel execution is enabled:
   ```r
   Sys.getenv("PARALLEL_TESTS")  # Should be "true"
   ```

2. Verify LLM tests are skipped when expected:
   ```r
   Sys.getenv("CI")  # Should be "true" to skip LLM tests
   ```

3. Check LLM response time:
   ```r
   system.time(has_ollama())  # Should be < 1 second
   ```

4. Use faster LLM model:
   ```r
   Sys.setenv(TEST_LLM_MODEL = "llama3.2:3b")
   ```

**Parallel tests failing?**

Some tests may have race conditions. Disable parallel execution:
```r
PARALLEL_TESTS=false devtools::test()
```

**Out of memory?**

Reduce parallel workers:
```r
test_check("psychinterpreter", parallel = 2)  # Use only 2 cores
```

---

## Test Infrastructure

- **Framework**: testthat 3.0
- **Fixtures**: `tests/testthat/fixtures/*.rds`, cached in `.test_cache` environment (40x speedup)
- **Helper functions**: In `helper.R`, always use `test_path()` for paths
- **Mock LLM**: `helper-mock-llm.R` provides mock responses for error scenario testing
- **Performance**: `test-zzz-performance.R` tracks performance regression
- **Test filtering**: `tests/test_config.R` provides helper functions for running test subsets
- **Parallel execution**: `tests/testthat.R` enables automatic parallel test execution

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

**Provider-Specific Tests (test-3X-*.R)** - Skip without API keys:
- `test-30-provider-integration.R` - OpenAI, Anthropic, Ollama integration (18 tests, skip_on_cran, requires API keys)

**Performance Tests (test-99-*.R)** - Run last:
- `test-99-performance.R` - Performance benchmarks (7 tests, skip_on_ci)

**Running test subsets:**
```r
# Using devtools
devtools::test(filter = "^test-0")   # Fast tests only (~5-10s with parallel)
devtools::test(filter = "^test-1")   # Integration tests only (~15-25s with parallel)
devtools::test()                      # All tests (~30-60s with parallel)

# Using test_config.R helpers (recommended)
source("tests/test_config.R")
test_fast()         # Fast tests only
test_integration()  # Integration tests only
test_smoke()        # Quick smoke test
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

### Phase 5: Provider-Specific and Mock Testing (2025-11-18) ✅
- Enhanced mock LLM infrastructure with 5 new scenarios (unicode, very long, HTML artifacts, provider errors)
- Added 28 new mock-based tests (JSON edge cases, error handling, GM-specific)
- Created provider-specific integration test suite (test-30-provider-integration.R, 18 tests)
- Tests for OpenAI, Anthropic, and Ollama with proper skip guards
- Fixed duplicate test numbering (test-28-gm-unit-tests.R → test-14-gm-unit-tests.R)
- Documented provider-specific testing setup and usage
- **Result:** Reduced LLM dependency, improved cross-provider confidence, better error coverage

### Phase 6: Parallel Execution and Test Filtering (2025-11-23) ✅
- Implemented parallel test execution in `tests/testthat.R`
- Auto-detection of CPU cores with intelligent defaults (cores - 2)
- Created test filtering helpers in `tests/test_config.R`
- Added shell command aliases in `dev/test_commands.sh`
- Updated all documentation with performance benchmarks
- **Result:** 5-10x speedup on multi-core machines, better developer experience

### Key Achievements
- **53% reduction** in LLM-dependent tests (32→15 total, including integration tests)
- **95% faster** test execution with parallel (~10s → ~2-5s for fast tests)
- **5-10x speedup** on full test suite with parallel execution
- **27 organized test files** with clear naming convention
- **92% test coverage** (up from 80% baseline, 12 percentage point improvement)
- **417+ tests** (up from ~185, 125% increase)
- **5 cached interpretation fixtures** for testing without LLM calls
- **Mock infrastructure** for error scenario testing
- **Automated performance tracking** with soft expectations
- **Near-complete coverage** of exported functions (all 4 previously untested functions now tested)
- **Parallel test execution** for multi-core speedup

## LLM Testing Strategy

**Core Principle**: Separate data extraction tests (no LLM) from interpretation tests (with LLM)

**🚨 IMPORTANT: LLM tests are DISABLED BY DEFAULT** (as of 2025-11-23)
- Set `RUN_LLM_TESTS=true` environment variable to enable LLM tests
- This prevents unexpected API calls and costs during normal test runs
- See `tests/testthat/README_TEST_CONFIG.md` for configuration details

**Current implementation** (as of 2025-11-23):
- **14 LLM tests** total (3.4% of all tests, 56% reduction from original 32):
  - Core interpretation: 5 tests (`test-10-integration-core.R`)
  - Chat sessions: 3 tests (`test-11-integration-chat.R`)
  - FA edge cases: 2 tests (`test-12-integration-fa.R`)
  - S3 extraction integration: 4 tests (`test-04-s3-extraction.R`)
- **S3 methods**: Do NOT test LLM calls - only test data extraction/formatting
- **All LLM tests** must use `skip_if_no_llm()` which checks `RUN_LLM_TESTS` environment variable
- **All LLM tests** must use `word_limit = 20` to minimize token usage
- **All LLM tests** must use `skip_on_ci()` to avoid running on CI
- **Cached interpretations**: 5 cached interpretation fixtures for testing without LLM

## LLM Test Efficiency Standards

**Last Efficiency Audit**: 2025-11-23

### Current Efficiency Metrics ✅

The psychinterpreter test suite demonstrates **exceptional efficiency** in LLM usage:

| Metric | Value | Status |
|--------|-------|--------|
| **Total tests** | 430+ | ✅ Excellent coverage |
| **LLM-dependent tests** | 15-20 (4%) | ✅ Exceptional efficiency |
| **word_limit = 20 compliance** | 100% | ✅ Perfect optimization |
| **Mock/fixture coverage** | 96% | ✅ Outstanding |
| **Token usage per test run** | 5,000-7,500 | ✅ Ultra-efficient |
| **CI skip compliance** | 100% | ✅ Perfect |

### Mandatory Standards for LLM Tests

When writing tests that make actual LLM calls (via `interpret()` or `label_variables()`):

#### 1. **ALWAYS use `word_limit = 20`** (Minimum Allowed)
```r
# ✅ CORRECT
interpret(
  fit_results = minimal_fa_model(),
  variable_info = minimal_variable_info(),
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud",
  word_limit = 20,  # Minimum for maximum efficiency
  silent = TRUE
)

# ❌ INCORRECT
interpret(
  fit_results = fa_model,
  variable_info = var_info,
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud",
  word_limit = 100  # Wastes 5x more tokens
)
```

#### 2. **ALWAYS use `skip_if_no_llm()` and `skip_on_ci()`**
```r
test_that("interpretation works with real LLM", {
  skip_if_no_llm()  # ✅ REQUIRED - Checks RUN_LLM_TESTS env var
  skip_on_ci()      # ✅ REQUIRED - Prevents CI failures

  # ... test code ...
})
```

**Note:** `skip_if_no_llm()` automatically:
- Checks if `RUN_LLM_TESTS=true` is set (skips if not)
- Checks if CI environment is detected (skips if yes)
- Checks if LLM provider is available (skips if not)

#### 3. **PREFER fixtures and mocks over real LLM calls**
```r
# ✅ PREFERRED - Use cached interpretation
test_that("print method works", {
  interp <- sample_interpretation()  # No LLM call
  expect_no_error(print(interp))
})

# ❌ AVOID - Unnecessary LLM call
test_that("print method works", {
  skip_on_ci()
  interp <- interpret(...)  # Wastes LLM call just to test print
  expect_no_error(print(interp))
})
```

#### 4. **USE minimal_* fixtures for LLM tests**
```r
# ✅ CORRECT - Minimal fixtures save 60-70% tokens
test_that("interpretation with real LLM", {
  skip_on_ci()
  skip_if_no_llm()

  result <- interpret(
    fit_results = minimal_fa_model(),    # 3 vars × 2 factors
    variable_info = minimal_variable_info(),  # Short descriptions
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20
  )

  expect_s3_class(result, "fa_interpretation")
})

# ❌ INCORRECT - Wastes tokens
test_that("interpretation with real LLM", {
  skip_on_ci()

  result <- interpret(
    fit_results = sample_fa_model(),  # 6 vars × 3 factors (3x larger)
    variable_info = sample_variable_info(),
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud"
  )
})
```

#### 5. **COMBINE related LLM tests when possible**
```r
# ✅ GOOD - Test multiple aspects in one LLM call
test_that("interpretation workflow comprehensive test", {
  skip_on_ci()
  skip_if_no_llm()

  result <- interpret(...)

  # Test structure
  expect_s3_class(result, "fa_interpretation")
  # Test content
  expect_true(length(result$suggested_names) > 0)
  # Test metadata
  expect_true(!is.null(result$analysis_data))
  # Test token tracking
  expect_true(is.numeric(result$token_usage$total_tokens))
})

# ❌ AVOID - Separate tests waste LLM calls
test_that("result has correct structure", {
  skip_on_ci()
  result <- interpret(...)  # LLM call 1
  expect_s3_class(result, "fa_interpretation")
})

test_that("result has suggested names", {
  skip_on_ci()
  result <- interpret(...)  # LLM call 2 (duplicate!)
  expect_true(length(result$suggested_names) > 0)
})
```

### Non-LLM Tests (No Restrictions)

Tests that do **NOT** make LLM calls can use any `word_limit` value for testing purposes:

```r
# ✅ ACCEPTABLE - Testing prompt building logic, no actual LLM call
test_that("build_system_prompt includes word limit in prompt", {
  model_type <- structure("fa", class = "fa")

  result <- build_system_prompt(model_type, word_limit = 100)

  expect_type(result, "character")
  expect_match(result, "100 words")  # Testing that value appears in prompt
})

# ✅ ACCEPTABLE - Testing config validation, no LLM call
test_that("llm_args validates word_limit range", {
  expect_error(
    llm_args(llm_provider = "ollama", word_limit = 10),  # Below minimum
    "must be between 20 and 500"
  )

  expect_error(
    llm_args(llm_provider = "ollama", word_limit = 1000),  # Above maximum
    "must be between 20 and 500"
  )
})
```

### Verification Tools

**Automated check script**: `dev/scripts/check-test-efficiency.R`

Run this script to verify compliance:
```r
source("dev/scripts/check-test-efficiency.R")
# Checks all test files for:
# - LLM calls without word_limit = 20
# - LLM calls without skip_on_ci()
# - Use of sample_* fixtures instead of minimal_* in LLM tests
```

### Token Savings Examples

Impact of following these standards:

| Scenario | Tokens | Time | Cost (GPT-4) |
|----------|--------|------|--------------|
| **Optimal** (word_limit=20, minimal fixtures) | 150-200 | ~3s | $0.003 |
| **Suboptimal** (word_limit=100, sample fixtures) | 750-1000 | ~8s | $0.015 |
| **Wasteful** (word_limit=150, sample fixtures) | 1200-1500 | ~12s | $0.023 |

**Per full test run** (15-20 LLM tests):
- Optimal: 3,000-4,000 tokens (~$0.06)
- Wasteful: 18,000-30,000 tokens (~$0.45)
- **Savings: ~87% tokens, ~$0.39 per run**

### Rationale

1. **word_limit = 20** is the minimum allowed by the package and sufficient for validating that interpretations work correctly
2. **Minimal fixtures** reduce prompt size by 60-70% without sacrificing test validity
3. **skip_on_ci()** prevents CI failures due to API rate limits and reduces costs
4. **Mocks and fixtures** enable comprehensive error scenario testing without LLM costs
5. **Combined tests** reduce overhead from repeated system prompt sending

### Exception Cases

LLM tests can deviate from standards only when:
1. **Testing word_limit behavior specifically** - Use different values to verify the parameter works
2. **Provider-specific tests** - Testing token tracking may require longer responses
3. **Performance benchmarks** - May need realistic fixtures for accurate timing

All exceptions must be documented with inline comments explaining why the deviation is necessary.

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

### Provider-Specific Testing (Phase 5)

Provider-specific integration tests are in `test-30-provider-integration.R` and verify behavior across different LLM providers (OpenAI, Anthropic, Ollama).

**Setup:**
```r
# Set API keys as environment variables
Sys.setenv(OPENAI_API_KEY = "your-openai-key")
Sys.setenv(ANTHROPIC_API_KEY = "your-anthropic-key")

# Ollama requires local installation (no API key needed)
# Install from: https://ollama.com
```

**Test categories:**
1. **OpenAI tests** (4 tests) - Requires `OPENAI_API_KEY`
   - Successful interpretation
   - Token tracking (prompt_tokens, completion_tokens, total_tokens)
   - Chat session across multiple requests
   - Rate limit error handling

2. **Anthropic tests** (4 tests) - Requires `ANTHROPIC_API_KEY`
   - Successful interpretation
   - Token tracking (input_tokens, output_tokens)
   - Chat session with cumulative token tracking
   - Prompt caching behavior (system prompts cached on 2nd+ calls)

3. **Ollama tests** (2 tests) - Requires local Ollama installation
   - Works without API keys
   - Token tracking (returns zero/NULL - no tracking support)

4. **Provider switching tests** (2 tests)
   - Provider locked to session (cannot switch mid-session)
   - Different providers in separate sessions

5. **Error handling tests** (2 tests)
   - Invalid API key produces informative error
   - Network errors handled gracefully

**Skip conditions:**
- `skip_if_no_openai_key()` - Skips if `RUN_LLM_TESTS=true` not set OR `OPENAI_API_KEY` not set
- `skip_if_no_anthropic_key()` - Skips if `RUN_LLM_TESTS=true` not set OR `ANTHROPIC_API_KEY` not set
- `skip_on_cran()` - Skips on CRAN (all provider tests)
- `skip_on_ci()` - Skips on CI (API-based tests only, not Ollama)

**IMPORTANT:** All provider tests now require `RUN_LLM_TESTS=true` to be explicitly set, preventing accidental API calls.

**Example usage:**
```r
# FIRST: Enable LLM tests
Sys.setenv(RUN_LLM_TESTS = "true")

# THEN: Run all provider tests (requires API keys)
devtools::test_file("tests/testthat/test-30-provider-integration.R")

# Run specific provider tests
devtools::test(filter = "OpenAI")
devtools::test(filter = "Anthropic")
devtools::test(filter = "Ollama")
```

**Expected behavior:**
- **OpenAI**: Provides detailed token counts (prompt, completion, total)
- **Anthropic**: Provides token counts + cache info (cache hits can reduce counts)
- **Ollama**: May return NULL or zeros for token tracking (not supported)

**Token tracking differences:**
```r
# OpenAI format
result$token_usage
#> $prompt_tokens: 150
#> $completion_tokens: 50
#> $total_tokens: 200

# Anthropic format
result$token_usage
#> $input_tokens: 150
#> $output_tokens: 50
#> (May include cache_read_input_tokens, cache_creation_input_tokens)

# Ollama format
result$token_usage
#> NULL or list with zeros
```

**Notes:**
- All provider tests use `word_limit = 20` to minimize token usage and cost
- Tests create minimal fixtures (3 items × 2 factors) to reduce API calls
- OpenAI and Anthropic tests skip on CI to avoid API costs
- Ollama tests can run on CI if Ollama is installed locally

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
| LLM tests skipped unexpectedly | `RUN_LLM_TESTS` not set | Set `Sys.setenv(RUN_LLM_TESTS = "true")` |
| HTTP 400/429 errors in tests | LLM tests running accidentally | Tests now skip by default - check if `RUN_LLM_TESTS=true` is set |
| Parallel tests failing | Race condition or shared state | Disable parallel: `PARALLEL_TESTS=false` |
| Out of memory | Too many parallel workers | Reduce cores: `parallel = 2` |

## Quick Checklist

When adding tests after API changes:
- [ ] Tests bypass earlier validations to test target validation
- [ ] Backward compatibility test if parameter renamed
- [ ] Use `minimal_*` fixtures for LLM tests
- [ ] Add `skip_if_no_llm()` to all LLM tests (checks `RUN_LLM_TESTS` env var)
- [ ] Add `skip_on_ci()` to all LLM tests
- [ ] Use `test_path()` for all file paths
- [ ] Consider using mock LLM for error scenario testing
- [ ] Choose correct test file based on concern (validation, extraction, integration, etc.)
- [ ] Use numbered prefix (test-01 through test-99) for proper organization

When adding new test files:
- [ ] Use numbered prefix: 0X for fast tests, 1X for integration, 2X for output/config, 99 for performance
- [ ] Update this guidelines file with the new test file in the organization section

---

## CLI Error Message Testing Considerations

When testing functions that use `cli::cli_abort()` for error messages:

### Key Issue
CLI error messages with variable interpolation can cause test failures if not handled correctly. When `cli_abort()` receives messages with CLI expressions (e.g., `{.arg param_name}`), it evaluates them in the current scope.

### Best Practices

1. **Pre-format messages with external variables**:
   ```r
   # If validation message contains CLI expressions
   formatted_message <- cli::format_inline(validation_message)
   cli::cli_abort("Error: {formatted_message}")
   ```

2. **Test error message content**:
   ```r
   # Note: cli_abort only puts first element in e$message
   # Combine parts if tests need to match patterns
   expect_error(function_call(), "expected pattern")
   ```

3. **Ensure complete error messages for tests**:
   ```r
   # Bad: Multi-part messages won't match in tests
   cli::cli_abort(c("Main error", "x" = "Details"))

   # Good: Combined message for testability
   cli::cli_abort("Main error. Details")
   ```

See `dev/DEVELOPER_GUIDE.md` Section 5.3 for detailed CLI error handling documentation.

---

## Summary

The test suite has been optimized for speed and maintainability:
- **56% fewer LLM tests** (32→14) through caching and consolidation
- **95% faster with parallel execution** (10-20s → 2-5s for fast tests)
- **5-10x speedup on full suite** with multi-core parallel execution
- **Comprehensive infrastructure** with mocks, fixtures, and performance tracking
- **All critical bugs fixed** (Phase 3 - 2025-11-15)
- **Test filtering helpers** for running specific test subsets
- **Automatic parallel execution** for multi-core performance

## Future Test Work

See `dev/OPEN_ISSUES.md` for remaining test work:

**Priority: MAJOR** (should be done this week):
- Increase mock LLM tests by 20+ to reduce LLM dependency to <10% (~4 hours)

**Priority: ENHANCEMENT** (next sprint):
- Add ~10 more chat session tests
- Add error scenario tests for export functions
- Add edge case tests (empty data, large matrices, Unicode)
- Performance regression suite (~6 hours)
- Memory profiling infrastructure (~4 hours)

**Total Remaining**: ~35 hours of test improvements

---

## Development Workflow Recommendations

### Quick iteration cycle (< 5 seconds)
```r
devtools::load_all()
source("tests/test_config.R")
test_smoke()
```

### Pre-commit testing (< 10 seconds)
```r
Sys.setenv(PARALLEL_TESTS = "true")
source("tests/test_config.R")
test_fast()  # All unit tests, no LLM
```

### Full test suite (30-60 seconds)
```r
Sys.setenv(PARALLEL_TESTS = "true")
devtools::test()  # All tests including LLM
```

### Before submitting PR
```bash
# Run with parallel execution
PARALLEL_TESTS=true R CMD check .
```

### Shell aliases (optional)
```bash
# Source aliases for convenience
source dev/test_commands.sh

# Now use:
test-quick        # < 5s
test-fast         # < 10s
test-all          # < 1 min
```

---

**Last Updated**: 2025-11-23
- Added Phase 6: Parallel Execution and Test Filtering optimization
- **LLM tests now DISABLED BY DEFAULT** via `RUN_LLM_TESTS` environment variable
- Updated all examples and documentation to reflect new skip behavior
