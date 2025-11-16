# Open Issues and Future Work

**Last Updated**: 2025-11-16

This document tracks active issues and planned enhancements for the psychinterpreter package.

**For completed work**: See `DEVELOPER_GUIDE.md` Section 5.3 (Recent Improvements and Refactorings)

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
