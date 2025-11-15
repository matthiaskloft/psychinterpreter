# Developer Documentation

**Last Updated**: 2025-11-15

This directory contains developer documentation for the psychinterpreter package.

---

## Documentation Files

### Core Documentation

| File | Purpose | Audience |
|------|---------|----------|
| **DEVELOPER_GUIDE.md** | Complete technical architecture and implementation details | Package maintainers |
| **TESTING_GUIDELINES.md** | Test suite organization, patterns, and best practices | Test developers |
| **OPEN_ISSUES.md** | Current issues, future work, and refactoring decisions | All developers |

### Implementation Guides

| File | Purpose | Audience |
|------|---------|----------|
| **MODEL_IMPLEMENTATION_GUIDE.md** | Step-by-step guide for adding new model types (GM, IRT, CDM) | New implementers |
| **FIXES_IMPLEMENTATION_SUMMARY.md** | Summary of consistency fixes (Phase 1 & 2 - 2025-11-15) | Maintainers |

### Reference

| File | Purpose |
|------|---------|
| **prompts.md** | LLM prompt templates and patterns |

---

## Quick Navigation

### I want to...

**Understand the package architecture**
→ Read `DEVELOPER_GUIDE.md`

**Add a new model type (GM, IRT, CDM)**
→ Follow `MODEL_IMPLEMENTATION_GUIDE.md`
→ Use templates in `templates/` directory

**Write or modify tests**
→ Follow `TESTING_GUIDELINES.md`

**Know what needs to be done**
→ Check `OPEN_ISSUES.md`

**Understand recent fixes**
→ Read `FIXES_IMPLEMENTATION_SUMMARY.md`

---

## Current Status (2025-11-15)

### Completed Work ✅

**Namespace Refactoring** (2025-11-15):
- Disambiguated LLM vs Analysis parameters
- `provider` → `llm_provider`, `model` → `llm_model`
- `model_type` → `analysis_type`, `model_data` → `analysis_data`
- ~450 occurrences across 50+ files

**Consistency Fixes** (2025-11-15):
- Fixed function name mismatches
- Fixed parameter examples
- Fixed test field access bugs
- Added S3 method registrations
- Added configuration precedence tests

### Active Development 🔨

**Priority: MAJOR** (this week):
- Increase mock LLM tests by 20+ (~4 hours)

**Priority: ENHANCEMENT** (next sprint):
- Test coverage improvements (~21 hours)
- Performance benchmarking (~10 hours)
- Provider-specific tests (~8 hours)

### Planned Features 📋

**New Model Types** (future):
- Gaussian Mixture (GM) - 32-40 hours
- Item Response Theory (IRT) - 40-50 hours
- Cognitive Diagnostic Models (CDM) - 40-50 hours

See `OPEN_ISSUES.md` for complete details.

---

## Package Statistics

- **R Files**: 20
- **Lines of Code**: ~6,462
- **Test Files**: 25 (including new test-22-config-precedence.R)
- **Tests**: 182 (176 original + 6 new)
- **Test Coverage**: ~80%
- **LLM Tests**: 14 (~7.7% of total, 56% reduction from original)

---

## Development Workflow

### Before Making Changes

1. Read relevant documentation above
2. Check `OPEN_ISSUES.md` for related work
3. Review `TESTING_GUIDELINES.md` for test patterns

### After Making Changes

1. Run tests: `devtools::test()`
2. Update documentation: `devtools::document()`
3. Check package: `devtools::check()`
4. Update relevant docs in `dev/`
5. Update `OPEN_ISSUES.md` if completing an issue

### Adding New Model Types

1. Follow `MODEL_IMPLEMENTATION_GUIDE.md` exactly
2. Copy templates from `templates/` directory
3. Implement 8 required S3 methods
4. Add tests following patterns in `TESTING_GUIDELINES.md`
5. Update `OPEN_ISSUES.md` to mark as complete

---

## Getting Help

- **Architecture questions**: See `DEVELOPER_GUIDE.md` Section 1-2
- **Implementation questions**: See `MODEL_IMPLEMENTATION_GUIDE.md`
- **Testing questions**: See `TESTING_GUIDELINES.md`
- **What to work on**: See `OPEN_ISSUES.md`

---

## Document Maintenance

When updating these docs:

- Update "Last Updated" date at top of file
- Keep documentation current with code
- Cross-reference related sections
- Document decisions in `OPEN_ISSUES.md`
- Remove obsolete information
