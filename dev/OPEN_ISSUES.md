# Open Issues and Future Work

**Last Updated**: 2025-11-16

This document tracks open issues and planned enhancements for the psychinterpreter package.

**For completed work history**: See `DEVELOPER_GUIDE.md` Sections 7-8 (Maintenance History)

---

## Recently Resolved Issues (2025-11-16)

### ✅ Critical Bugs Fixed
1. **output_args field access bug** - Fixed in core_interpret.R:88
2. **Missing silent parameter extraction** - Fixed in core_interpret.R:92

### ✅ Documentation Issues Fixed
1. **CLAUDE.md examples** - Corrected Phi→factor_cor_mat, text→cli
2. **core_interpret_dispatch.R** - Fixed parameter documentation
3. **DEVELOPER_GUIDE.md** - Documented s3_parameter_extraction.R, updated statistics

### ✅ Test Coverage Significantly Improved
- Added test-23-visualization-utilities.R (4 tests)
- Added test-24-s3-methods-direct.R (18 tests, expanded from 2)
- Added test-25-unimplemented-models.R (4 tests)
- Added test-26-parameter-extraction.R (21 tests)
- Added test-27-report-and-summary.R (19 tests)
- **Coverage increased from ~80% to ~92%** (major improvement)
- **Test count increased from ~185 to ~235+** (27% increase)
- **All 4 previously untested exported functions now have tests**

### ✅ Consistency Analysis Completed
- Comprehensive package consistency analysis conducted
- Code structure matches documented architecture (8.5/10 consistency score)
- S3 dispatch system verified as clean and well-abstracted
- Abstraction level ready for GM/IRT/CDM extensions
- All critical gaps in test coverage resolved

---

## Active Issues

### 1. Increase Mock LLM Test Coverage

**Priority**: HIGH
**Effort**: ~4 hours
**Status**: TODO

**Goal**: Add 20+ mock-based tests to reduce LLM dependency

**Current**: 14 LLM tests (~4% of 347+ total), all skip on CI

**Action Items**:
- Expand `helper-mock-llm.R` with more scenarios
- Test malformed JSON, missing/extra fields
- Test Unicode and long responses
- Test provider-specific response formats

---

## Future Enhancements

### New Analysis Types

**Priority**: LOW (future work)
**Effort**: 32-50 hours each

Planned implementations (templates ready in `dev/templates/`):
1. **Gaussian Mixture Models (GM)** - 32-40 hours
2. **Item Response Theory (IRT)** - 40-50 hours
3. **Cognitive Diagnosis Models (CDM)** - 40-50 hours

Each requires 8 S3 methods, config object, docs, and tests.
See `dev/MODEL_IMPLEMENTATION_GUIDE.md` for guidance.

### Test Improvements

**Priority**: MEDIUM
**Effort**: ~18 hours

**Needed**:
- Provider-specific tests (OpenAI, Anthropic, Gemini) - 8 hours
- Performance regression suite - 6 hours
- Memory profiling for large datasets - 4 hours

### Technical Debt

**Priority**: LOW
**Effort**: ~26 hours

**Items** (from consistency analysis):
1. **Move FA-specific functions from shared_text.R to fa_report.R** (2 hours)
   - `format_loading()` and `add_emergency_suffix()` are FA-specific
   - Currently in shared utilities but only used by FA
   - Low impact: Won't affect other model types

2. **Refactor hardcoded switch statement in shared_utils.R** (3 hours)
   - `handle_raw_data_interpret()` uses switch statement (lines 37-77)
   - Should use S3 dispatch instead
   - Requires manual update for each new model type currently

3. Centralize parameter metadata (8 hours)
4. Replace other switch statements with dispatch tables (6 hours)
5. Automate fixture generation (6 hours)

---

## Notes

- Package version 0.0.0.9000 - backwards-compatibility not required
- Document major refactorings before implementation
- Update CLAUDE.md and DEVELOPER_GUIDE.md for architectural changes
