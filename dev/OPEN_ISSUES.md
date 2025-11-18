# Open Issues and Future Work

**Last Updated**: 2025-11-18

This document tracks active issues and planned enhancements for the psychinterpreter package.

**For completed work**: See `DEVELOPER_GUIDE.md` Section 5.3 (Recent Improvements and Refactorings)

---

## Recently Completed (2025-11-18)

### Test Suite Improvements - Phase 5
**Status**: ✅ COMPLETED

**What was done:**
- **Enhanced Mock LLM Infrastructure**: Added 5 new mock scenarios (unicode, very long responses, HTML artifacts, provider-specific errors)
- **Expanded Mock Tests**: Added 28 new mock-based tests across 3 test files
  - 13 tests for JSON edge cases (test-06-json-parsing.R)
  - 6 tests for error handling (test-10-integration-core.R)
  - 4 tests for GM-specific scenarios (test-13-integration-gm.R)
  - 5 tests for mock infrastructure validation
- **Provider-Specific Integration**: Created test-30-provider-integration.R with 18 tests
  - OpenAI tests (4 tests): interpretation, token tracking, chat sessions, rate limits
  - Anthropic tests (4 tests): interpretation, token tracking, chat sessions, prompt caching
  - Ollama tests (2 tests): no-auth operation, token tracking behavior
  - Provider switching tests (2 tests)
  - Error handling tests (2 tests)
  - Token tracking comparison tests (4 tests)
- **Test Organization**: Fixed duplicate test numbering (test-28-gm-unit-tests.R → test-14-gm-unit-tests.R)
- **Documentation**: Comprehensive provider-specific testing guide in TESTING_GUIDELINES.md

**Files modified:**
- MODIFIED: `tests/testthat/helper-mock-llm.R` (+5 scenarios: unicode, very_long, html_artifacts, provider errors)
- MODIFIED: `tests/testthat/test-06-json-parsing.R` (+13 tests for edge cases)
- MODIFIED: `tests/testthat/test-10-integration-core.R` (+6 error handling tests)
- MODIFIED: `tests/testthat/test-13-integration-gm.R` (+4 GM mock tests)
- NEW: `tests/testthat/test-30-provider-integration.R` (18 provider-specific tests)
- RENAMED: `test-28-gm-unit-tests.R` → `test-14-gm-unit-tests.R` (fixed numbering)
- MODIFIED: `dev/TESTING_GUIDELINES.md` (added Phase 5 documentation)

**Benefits:**
- **Reduced LLM dependency**: 46 new tests, only 18 require actual LLM calls (skip without API keys)
- **Better error coverage**: Mock tests cover malformed JSON, unicode, very long responses, provider errors
- **Cross-provider confidence**: Tests verify behavior across OpenAI, Anthropic, and Ollama
- **Better organized**: Fixed duplicate test numbering, clear test file categorization (3X for provider tests)

**Test Suite Stats (after Phase 5)**:
- **Total tests**: 1400+ (up from 1354)
- **Test files**: 23 (up from 22)
- **Mock scenarios**: 11 (up from 6)
- **LLM tests with skip guards**: 33 (18 provider-specific + 15 integration)
- **Test coverage**: ~92% (maintained)

### GM Report Consistency Improvements
**Status**: ✅ COMPLETED

**What was done:**
- Created centralized format dispatch system in `R/aaa_shared_formatting.R`
- Implemented `print.gm_interpretation()` method
- Added LLM metadata, token counts, and elapsed time to GM reports
- Refactored all GM report functions to use shared formatting
- Added cluster separators and detailed statistics
- Created comprehensive test suite (78 new tests/assertions)
- Reduced code duplication by 293 lines (16% reduction)

**Files modified:**
- NEW: `R/aaa_shared_formatting.R` (356 lines)
- NEW: `tests/testthat/test-21b-print-methods-gm.R` (12 tests)
- MODIFIED: `R/gm_report.R` (-105 lines, added print method + improvements)
- MODIFIED: `R/fa_report.R` (-188 lines, uses shared formatting)
- MODIFIED: `tests/testthat/test-13-integration-gm.R` (+16 test contexts)

**Benefits:**
- Perfect consistency between FA and GM report formatting
- Single source of truth for all format-specific logic
- Easy to extend for future model types (IRT, CDM)
- Comprehensive test coverage ensures reliability

---

## Active Issues

**No active high-priority issues** - All high-priority test improvements completed as of 2025-11-18

---

## Future Enhancements

### New Analysis Types

**Priority**: LOW (future work)
**Effort**: 40-50 hours each

Planned implementations (templates ready in `dev/templates/`):
1. **Item Response Theory (IRT)** - 40-50 hours
2. **Cognitive Diagnosis Models (CDM)** - 40-50 hours

Note: Gaussian Mixture Models (GM) completed 2025-11-18

Each requires 8 S3 methods, config object, docs, and tests.
See `dev/MODEL_IMPLEMENTATION_GUIDE.md` for guidance.

### Test Improvements

**Priority**: MEDIUM
**Effort**: ~10 hours remaining

**Completed** (2025-11-18):
- ✅ Provider-specific tests (OpenAI, Anthropic, Ollama) - test-30-provider-integration.R

**Remaining**:
- Performance regression suite - 6 hours
  - Baseline performance metrics for single interpretations
  - Baseline for chat sessions across providers
  - Automated regression detection
- Memory profiling for large datasets - 4 hours
  - Profile memory usage with large factor structures (50+ variables)
  - Test behavior with large GM models (10+ clusters)
  - Document memory-efficient workflows

### Technical Debt

**Priority**: LOW
**Effort**: ~12 hours remaining
**Status**: ✅ 5 of 5 major items completed (2025-11-16)

**Completed Items** (see DEVELOPER_GUIDE.md Section 5.3):
1. ✅ FA-specific functions moved to fa_utils.R
2. ✅ Switch statements refactored to S3 dispatch
3. ✅ Parameter metadata centralized (PARAMETER_REGISTRY)
4. ✅ Model type dispatch tables implemented
5. ✅ Analysis type routing dispatch tables implemented

**Optional Future Work** (not blockers):
1. **Automate fixture generation** (6 hours)
   - Create tools to auto-generate test fixtures
   - Reduce manual maintenance of test data

2. **Additional dispatch table opportunities** (4 hours)
   - Review codebase for remaining optimization opportunities
   - Convert any remaining conditional chains

---

## Notes

- Package version 0.0.0.9000 - backwards-compatibility not required
- Document major refactorings before implementation
- Update CLAUDE.md and DEVELOPER_GUIDE.md for architectural changes
