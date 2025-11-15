# Implementation Checklist for New Model Type

**Model Type**: _____________ (e.g., "Gaussian Mixture", "IRT", "CDM")

**Abbreviation**: _____________ (e.g., "gm", "irt", "cdm")

**Primary Fitted Class**: _____________ (e.g., "Mclust", "SingleGroupClass")

**Date Started**: _____________

**Date Completed**: _____________

---

## Phase 1: Setup and Planning

- [ ] **Define model abbreviation** and ensure it's unique
- [ ] **Identify fitted model classes** from relevant R packages
- [ ] **Document expected analysis_data structure** (list fields and types)
- [ ] **List model-specific parameters** (e.g., covariance_type, cutoff)
- [ ] **Define component terminology** (e.g., "Cluster", "Item", "Factor")
- [ ] **Review FA implementation** files (`R/fa_*.R`) for patterns

---

## Phase 2: Core Files (No LLM Required)

### 2.1 Configuration Object

**File**: `R/shared_config.R` (modifications)

- [ ] Copy `TEMPLATE_config_additions.R` content
- [ ] Replace all placeholders (`{MODEL}`, `{model}`, `{PARAM1}`, etc.)
- [ ] Implement `interpretation_args_{model}()` constructor with validation
- [ ] Implement `build_interpretation_args_{model}()` merger function
- [ ] Add to `R/shared_config.R` (not a separate file)
- [ ] Add routing case in main `interpretation_args()` function
- [ ] Add roxygen2 documentation with examples
- [ ] Run `devtools::document()` to update docs
- [ ] Test parameter validation manually

**Estimated Time**: 1-2 hours

### 2.2 Model Data Extractor

**File**: `R/{model}_model_data.R`

- [ ] Copy `TEMPLATE_model_data.R` to `R/{model}_model_data.R`
- [ ] Replace all placeholders
- [ ] Implement `build_analysis_data.{CLASS}()` S3 method
- [ ] Implement `build_{model}_analysis_data_internal()` helper
- [ ] Add data extraction logic from fitted model (lines ~120-150)
- [ ] Add parameter validation (lines ~180-220)
- [ ] Add variable_info validation
- [ ] Define standardized `analysis_data` structure
- [ ] Add roxygen2 documentation
- [ ] Create unit tests: `tests/testthat/test-{model}_model_data.R`
  - [ ] Test data extraction from fitted model
  - [ ] Test parameter validation (valid and invalid inputs)
  - [ ] Test variable_info validation
  - [ ] Test edge cases (empty data, missing columns, etc.)
- [ ] All tests passing

**Estimated Time**: 4-6 hours

### 2.3 List Validation S3 Method (Optional - for Structured List Support)

**File**: `R/s3_list_validation.R` (add to existing file)

- [ ] Implement `validate_list_structure.{model}()` S3 method
  - [ ] Define required components for structured list
  - [ ] Validate component types (matrix, data.frame, etc.)
  - [ ] Warn about unrecognized components
  - [ ] Return standardized extracted structure
- [ ] Add roxygen2 documentation with examples
- [ ] Create unit tests in existing test file
  - [ ] Test validation with valid structure
  - [ ] Test validation with missing required components
  - [ ] Test validation with wrong component types
  - [ ] Test warning messages for unrecognized components
- [ ] All tests passing

**Estimated Time**: 1-2 hours

**Note**: This enables users to pass structured lists like `list(difficulty = vector, discrimination = vector)` directly to `interpret()`. See `validate_list_structure.fa()` for reference implementation.

---

## Phase 3: Prompt Building (Requires LLM for Testing)

### 3.1 Prompt Builders

**File**: `R/{model}_prompt_builder.R`

- [ ] Copy `TEMPLATE_prompt_builder.R` to `R/{model}_prompt_builder.R`
- [ ] Replace all placeholders
- [ ] Implement `build_system_prompt.{model}()`
  - [ ] Define expert persona
  - [ ] Write interpretation guidelines (7-10 rules)
  - [ ] Specify JSON format requirement
- [ ] Implement `build_main_prompt.{model}()`
  - [ ] Format context and task description
  - [ ] Format variable descriptions
  - [ ] Format model-specific data (lines ~130-200)
  - [ ] Specify JSON output format with examples
- [ ] Add helper functions for complex formatting (if needed)
- [ ] Add roxygen2 documentation
- [ ] Create tests: `tests/testthat/test-{model}_prompt.R`
  - [ ] Test system prompt includes key elements
  - [ ] Test user prompt includes all sections
  - [ ] Test parameter effects on prompts
- [ ] Test prompt output manually (no LLM, just inspect strings)
- [ ] All tests passing

**Estimated Time**: 3-5 hours

---

## Phase 4: JSON Parsing

### 4.1 JSON Parser

**File**: `R/{model}_json.R`

- [ ] Copy `TEMPLATE_json.R` to `R/{model}_json.R`
- [ ] Replace all placeholders
- [ ] Implement `validate_parsed_result.{model}()`
  - [ ] Check structure validity (list, keys, value types)
  - [ ] Validate component identifiers
  - [ ] Add model-specific validation
- [ ] Implement `extract_by_pattern.{model}()`
  - [ ] Define regex patterns for component keys
  - [ ] Add fallback patterns (single quotes, no quotes)
  - [ ] Handle partial matches
- [ ] Implement `create_default_result.{model}()`
  - [ ] Generate default messages for all components
  - [ ] Add warning messages
- [ ] Add roxygen2 documentation
- [ ] Create tests: `tests/testthat/test-{model}_json.R`
  - [ ] Test validation with valid structure
  - [ ] Test validation with invalid structures
  - [ ] Test pattern extraction with malformed JSON
  - [ ] Test default result generation
- [ ] All tests passing

**Estimated Time**: 3-4 hours

---

## Phase 5: Fit Summary & Diagnostics

### 5.1 Fit Summary & Diagnostics

**File**: `R/{model}_diagnostics.R`

- [ ] Copy `TEMPLATE_diagnostics.R` to `R/{model}_diagnostics.R`
- [ ] Replace all placeholders
- [ ] Implement `create_fit_summary.{model}()`
  - [ ] Add diagnostic check 1 (define: _____________)
  - [ ] Add diagnostic check 2 (define: _____________)
  - [ ] Add diagnostic check 3 (optional)
  - [ ] Format warning messages
  - [ ] Populate diagnostics info field
- [ ] Add helper functions for each check
- [ ] Consider exported helpers (like FA's `find_cross_loadings()`)
- [ ] Add roxygen2 documentation
- [ ] Create tests: `tests/testthat/test-{model}_fit_summary.R`
  - [ ] Test each diagnostic check independently
  - [ ] Test with data that triggers warnings
  - [ ] Test with clean data (no warnings)
- [ ] All tests passing

**Estimated Time**: 3-5 hours

---

## Phase 6: Report Generation

### 6.1 Report Builder

**File**: `R/{model}_report.R`

- [ ] Copy `TEMPLATE_report.R` to `R/{model}_report.R`
- [ ] Replace all placeholders
- [ ] Implement `build_report.{model}_interpretation()`
  - [ ] Orchestrate section building
  - [ ] Combine sections with proper spacing
- [ ] Implement `build_report_header_{model}()`
  - [ ] Format metadata
  - [ ] Handle text vs markdown
- [ ] Implement `build_{component}_interpretations_{model}()`
  - [ ] Format each component interpretation
  - [ ] Handle text vs markdown
- [ ] Implement `build_additional_data_section_{model}()`
  - [ ] Format model-specific data (optional)
  - [ ] Return NULL if no additional data
- [ ] Implement `build_diagnostics_section_{model}()`
  - [ ] Format warnings
  - [ ] Return NULL if no warnings
- [ ] Add formatting helpers as needed
- [ ] Add roxygen2 documentation
- [ ] Create tests: `tests/testthat/test-{model}_report.R`
  - [ ] Test each helper function independently
  - [ ] Test text vs markdown formatting
  - [ ] Test with and without warnings
  - [ ] Test with and without additional data
- [ ] All tests passing

**Estimated Time**: 4-6 hours

---

## Phase 7: Integration

### 7.0 Add to Constants and Routing

- [ ] **Modify `R/core_constants.R`**
  - [ ] Add "{model}" to VALID_ANALYSIS_TYPES constant
  - [ ] Verify constant includes your model type
  - [ ] Test validation accepts new analysis_type

- [ ] **Modify `R/shared_config.R`**
  - [ ] Add routing case in `interpretation_args()` function for "{model}"
  - [ ] Ensure `interpretation_args_{model}()` is called correctly
  - [ ] Ensure `build_interpretation_args_{model}()` is available

### 7.1 Verification

- [ ] Run `devtools::document()` to update all documentation
- [ ] Run `devtools::check()` - resolve any warnings/errors
- [ ] Verify new analysis_type is recognized by validation
- [ ] Test basic interpretation with your model type
- [ ] All integration tests passing

**Estimated Time**: 1-2 hours

---

## Phase 8: Testing

### 8.1 Fixtures

**Directory**: `tests/testthat/fixtures/{model}/`

- [ ] Create fixtures directory
- [ ] Create `make-{model}-fixture.R` generation script
  - [ ] Generate sample fitted model
  - [ ] Create variable_info
  - [ ] Generate ONE interpretation with `word_limit = 20`
  - [ ] Save interpretation as `{model}_interpretation.rds`
  - [ ] Save analysis_data as `sample_{model}_data.rds`
- [ ] Run fixture generation script
- [ ] Verify fixtures load correctly

**Estimated Time**: 1-2 hours

### 8.2 End-to-End Test

**File**: `tests/testthat/test-interpret_{model}.R`

- [ ] Create end-to-end integration test
  - [ ] Add `skip_on_ci()` at top
  - [ ] Test with fitted model object
  - [ ] Test with structured list
  - [ ] Test with chat_session
  - [ ] Test with interpretation_args config object
  - [ ] Verify interpretation structure
  - [ ] Verify report generation
  - [ ] Use `word_limit = 20` for all LLM tests
- [ ] Run test manually (requires LLM)
- [ ] All tests passing

**Estimated Time**: 2-3 hours

### 8.3 Test Summary

- [ ] Run full test suite: `devtools::test()`
- [ ] All tests passing (100% pass rate)
- [ ] Review code coverage (optional)
- [ ] Fix any failing tests

---

## Phase 9: Documentation

### 9.1 Function Documentation

- [ ] All exported functions have roxygen2 docs
- [ ] All examples run without errors
- [ ] Run `devtools::document()` - no warnings
- [ ] Review generated `.Rd` files in `man/`

### 9.2 Vignette (Optional but Recommended)

**File**: `vignettes/{model}_interpretation.Rmd` or `.Qmd`

- [ ] Create vignette file
- [ ] Introduction to {MODEL}
- [ ] Installation instructions
- [ ] Basic usage example
- [ ] Advanced usage (chat_session, config objects)
- [ ] Interpretation of results
- [ ] Troubleshooting common issues
- [ ] Knit successfully
- [ ] Add to package build

**Estimated Time**: 3-5 hours

### 9.3 User-Facing Documentation Updates

- [ ] **Update `CLAUDE.md`**
  - [ ] Add {MODEL} to supported model types
  - [ ] Add basic usage example
  - [ ] Add to Quick Reference Tables
  - [ ] Update "Last Updated" date

- [ ] **Update `README.md`** (if applicable)
  - [ ] Add {MODEL} to feature list
  - [ ] Add example (optional)

- [ ] **Update `dev/DEVELOPER_GUIDE.md`**
  - [ ] Add to section 4.2 (Package History)
  - [ ] Document implementation date and details
  - [ ] Note any challenges or deviations from templates

**Estimated Time**: 1-2 hours

---

## Phase 10: Final Checks

### 10.1 Quality Checks

- [ ] Run `devtools::check()` - **ZERO errors, ZERO warnings**
- [ ] Run `devtools::test()` - **ALL tests passing**
- [ ] Test examples in documentation - all work
- [ ] Code follows style guidelines (see DEVELOPER_GUIDE.md 5.7)
- [ ] All functions have appropriate exports/internals
- [ ] No debugging code left in (print statements, browser(), etc.)

### 10.2 Git and Version Control

- [ ] All new files added to git
- [ ] Meaningful commit messages
- [ ] Code reviewed (self or peer)
- [ ] Branch ready for merge

### 10.3 User Testing

- [ ] Test with real data from target package
- [ ] Test with edge cases (small n, many components, etc.)
- [ ] Test error messages are helpful
- [ ] Test with different LLM providers (ollama, openai, anthropic)
- [ ] Verify output quality is acceptable

---

## Completion Checklist

- [ ] All phases completed
- [ ] All tests passing
- [ ] Documentation complete and accurate
- [ ] `devtools::check()` clean
- [ ] Code reviewed
- [ ] Ready for production use
- [ ] Implementation documented in DEVELOPER_GUIDE.md
- [ ] CLAUDE.md updated with examples
- [ ] **Celebrate!** 🎉

---

## Time Estimates

| Phase | Estimated Time |
|-------|----------------|
| Phase 1: Setup | 1-2 hours |
| Phase 2: Core Files | 5-8 hours |
| Phase 3: Prompt Building | 3-5 hours |
| Phase 4: JSON Parsing | 3-4 hours |
| Phase 5: Diagnostics | 3-5 hours |
| Phase 6: Report Generation | 4-6 hours |
| Phase 7: Integration | 2-3 hours |
| Phase 8: Testing | 5-7 hours |
| Phase 9: Documentation | 4-7 hours |
| Phase 10: Final Checks | 2-3 hours |
| **Total** | **32-50 hours** |

*Note: Times are estimates for a developer familiar with R and the package architecture.*

---

## Notes and Observations

Use this space to document challenges, deviations from templates, or lessons learned:

```
[Add notes here]
```

---

**Last Updated**: 2025-11-10
