# Open Issues and Decisions

**Last Updated**: 2025-11-15

This document tracks refactoring decisions and remaining open issues for the psychinterpreter package.


## Remaining Open Issues

### 1. ⏳ Increase Mock LLM Test Coverage

**Priority**: MAJOR (should be done this week)
**Effort**: ~4 hours

**Issue**: Currently only ~20% of tests use mock LLM responses, meaning 39 tests require an actual LLM to run. This slows down testing and creates CI dependencies.

**Goal**: Add 20+ mock-based tests to reduce LLM dependency by 50%.

**Action Items**:
- Create comprehensive mock response scenarios in `helper-mock-llm.R`
- Add mock tests for malformed JSON, missing fields, extra fields
- Test Unicode characters and very long responses
- Cover edge cases without requiring actual LLM

**Status**: TODO

### 2. ⚠️ Test Coverage Gaps

**Priority**: ENHANCEMENT (next sprint)
**Effort**: ~21 hours total

**Low Coverage Areas**:
- **Chat Sessions**: Only 5 tests (needs ~10 more)
- **Export Functions**: Only 9 tests (needs error scenarios)
- **Error Handling**: Only 2 tests for malformed responses

**Missing Test Scenarios**:
- Empty/NULL variable_info handling
- Very large matrices (>100 variables)
- Provider-specific behavior (OpenAI, Anthropic)
- Token limit handling
- Rate limiting and timeouts
- File I/O errors in export
- Concurrent chat sessions
- Memory profiling for large datasets

**Status**: TODO

---

## Future Considerations

### 1. Analysis Type Implementations

The following analysis types are planned but not yet implemented:

**Priority**: ENHANCEMENT (future work)
**Effort**: 112-140 hours total

1. **Gaussian Mixture Models (GM)** - 32-40 hours
   - 8 S3 methods (build_analysis_data, build_system_prompt, etc.)
   - Configuration object (`interpretation_args_gm()`)
   - Documentation and tests
   - Status: 0% complete, templates ready

2. **Item Response Theory (IRT)** - 40-50 hours
   - Same requirements as GM
   - Status: 0% complete, templates ready

3. **Cognitive Diagnosis Models (CDM)** - 40-50 hours
   - Same requirements as GM
   - Status: 0% complete, templates ready

See `dev/templates/` for implementation templates and `dev/MODEL_IMPLEMENTATION_GUIDE.md` for guidance.

### 2. Performance & Benchmarking

**Priority**: ENHANCEMENT (next sprint)
**Effort**: ~10 hours

**Missing Infrastructure**:
- Performance regression tests (6 hours)
- Memory profiling for large datasets (4 hours)
- Benchmark suite to prevent degradation

**Action Items**:
- Add `test-99-benchmarks.R` with baseline timings
- Create `dev/scripts/memory_profiling.R`
- Document performance expectations

### 3. Provider-Specific Testing

**Priority**: ENHANCEMENT (next sprint)
**Effort**: ~8 hours

**Issue**: Currently only tests with Ollama. Need coverage for:
- OpenAI API behavior and token counting
- Anthropic Claude API behavior and caching
- Google Gemini API behavior

**Action Items**:
- Add provider-specific test files
- Test token tracking differences
- Document provider quirks

### 4. Technical Debt

**Priority**: TECH DEBT (future)
**Effort**: ~24 hours

**Items**:
1. **FA code in shared files** (4 hours) - Move FA-specific code from shared utilities to fa_*.R
2. **Parameter registry** (8 hours) - Centralize parameter metadata instead of manual filtering
3. **Dispatch tables** (6 hours) - Replace switch statements with dispatch tables
4. **Test fixture generator** (6 hours) - Automate fixture creation for new model types

### 5. Documentation Improvements

**Priority**: ENHANCEMENT (next sprint)
**Effort**: ~6 hours

**Missing/Incomplete**:
- Circular references in return value documentation
- Missing parameter descriptions (interpretation_guidelines, params)
- No documentation for interpretation class structure
- No documentation for analysis_data structure

---

## Notes

- As the package is in version 0.0.0.9000, backwards-compatibility can be ignored during development since the package is not officially released
- Major refactoring should be documented here before implementation
- Cross-reference with CLAUDE.md and DEVELOPER_GUIDE.md when making architectural changes
