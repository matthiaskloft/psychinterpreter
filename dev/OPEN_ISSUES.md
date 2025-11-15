# Open Issues and Future Work

**Last Updated**: 2025-11-15

This document tracks open issues and planned enhancements for the psychinterpreter package.

**For completed work history**: See `DEVELOPER_GUIDE.md` Section 7 (Maintenance History)

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
**Effort**: ~24 hours

**Items**:
1. Move FA-specific code from shared utilities to `fa_*.R` (4 hours)
2. Centralize parameter metadata (8 hours)
3. Replace switch statements with dispatch tables (6 hours)
4. Automate fixture generation (6 hours)

---

## Notes

- Package version 0.0.0.9000 - backwards-compatibility not required
- Document major refactorings before implementation
- Update CLAUDE.md and DEVELOPER_GUIDE.md for architectural changes
