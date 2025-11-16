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

## Phase 7: Integration - Dispatch Table Registration

### 7.0 Dispatch Table Registration (CRITICAL)

The package uses centralized dispatch tables for routing. You must register your model type in THREE places:

**File**: `R/shared_config.R`

#### 7.0.1 Add to `.ANALYSIS_TYPE_DISPLAY_NAMES` dispatch table

- [ ] Add entry: `{model} = "{MODEL}"` (human-readable display name)
  - Example: `gm = "Gaussian Mixture"`
  - This is used in help text and documentation

#### 7.0.2 Add to `.VALID_INTERPRETATION_PARAMS` dispatch table

- [ ] Add entry: `{model} = c("param1", "param2", ...)`
  - Example: `gm = c("n_components", "covariance_type")`
  - List ALL valid configuration parameters for your model type
  - These are validated when `interpretation_args()` is called

#### 7.0.3 Add to `.INTERPRETATION_ARGS_DISPATCH` dispatch table

- [ ] Add entry: `{model} = interpretation_args_{model}`
  - Example: `gm = interpretation_args_gm`
  - This maps your analysis type to its configuration handler function
  - Handler function must be defined in same file (shared_config.R)

### 7.0.4 Parameter Registry (from TEMPLATE_config_additions.R)

- [ ] Implement `interpretation_args_{model}()` constructor function
  - [ ] Accept model-specific parameters as named arguments
  - [ ] Provide default values
  - [ ] Return list with `analysis_type = "{model}"` first element
  - [ ] Add roxygen2 documentation with examples

- [ ] Implement `build_interpretation_args_{model}()` merger function
  - [ ] Accept base config and user overrides
  - [ ] Merge configurations appropriately
  - [ ] Return merged config

- [ ] Add validation inside both functions
  - [ ] Validate parameter types
  - [ ] Check valid ranges/values
  - [ ] Return helpful error messages

### 7.1 Model Type Dispatch (Optional but Recommended)

**File**: `R/aaa_model_type_dispatch.R`

If your model type supports fitted model objects (like `psych::fa()` does):

- [ ] Add model class mapping to `get_model_dispatch_table()`:
  - [ ] `classes = c("YourClass", "fallback_class")`
  - [ ] Include all expected fitted model classes from target package

- [ ] Implement validator function (e.g., `validate_yourpackage_model()`)
  - [ ] Check required structure elements
  - [ ] Return TRUE if valid, error otherwise

- [ ] Implement extractor function (e.g., `extract_yourpackage_loadings()`)
  - [ ] Extract analysis data from fitted model
  - [ ] Return standardized list format

### 7.2 Add to Constants

**File**: `R/core_constants.R`

- [ ] Add "{model}" to `VALID_ANALYSIS_TYPES` character vector
  - This is used for early validation of analysis_type parameter
  - Example: `c("fa", "gm", "irt")`

### 7.3 Verification

- [ ] Run `devtools::document()` to update all documentation
- [ ] Run `devtools::check()` - resolve any warnings/errors
- [ ] Verify new analysis_type is recognized by validation:
  ```r
  # This should work without error
  interpretation_args(analysis_type = "{model}", param1 = value1)
  ```
- [ ] Test dispatch table lookups work:
  ```r
  # These should return valid values
  psychinterpreter:::.get_analysis_type_display_name("{model}")
  psychinterpreter:::.get_valid_interpretation_params("{model}")
  ```
- [ ] Test basic interpretation with your model type
- [ ] All integration tests passing

**Estimated Time**: 2-3 hours

**References**:
- See `dev/archive/DISPATCH_TABLE_SUMMARY.md` for detailed dispatch table architecture
- See `R/shared_config.R` for FA examples of all required registrations
- See `R/core_constants.R` for VALID_ANALYSIS_TYPES constant

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

## Phase 10: Dispatch Table Validation

### 10.1 Critical Dispatch Table Validation Checklist

Before moving to final checks, verify dispatch table integration:

**In `R/shared_config.R`**:
- [ ] Entry added to `.ANALYSIS_TYPE_DISPLAY_NAMES` with correct model abbreviation
- [ ] Entry added to `.VALID_INTERPRETATION_PARAMS` with complete parameter list
- [ ] Entry added to `.INTERPRETATION_ARGS_DISPATCH` mapping to handler function
- [ ] `interpretation_args_{model}()` function defined and exported
- [ ] `build_interpretation_args_{model}()` function defined (internal)
- [ ] All parameter validation implemented and tested

**In `R/core_constants.R`**:
- [ ] Model abbreviation added to `VALID_ANALYSIS_TYPES` vector

**In `R/aaa_model_type_dispatch.R`** (if using fitted models):
- [ ] Model class mapping added to `get_model_dispatch_table()`
- [ ] Validator function implemented
- [ ] Extractor function implemented

**Manual Testing** (run in R console):
```r
# Test parameter registration works
cfg <- interpretation_args(analysis_type = "{model}", param1 = value)
print(cfg)  # Should show your model's parameters

# Test dispatch table lookup
psychinterpreter:::.get_analysis_type_display_name("{model}")  # Should return human-readable name
psychinterpreter:::.get_valid_interpretation_params("{model}")  # Should return your params

# Test with interpret() function
result <- interpret(
  fit_results = your_model_object,
  variable_info = var_info,
  analysis_type = "{model}",
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud"
)
```

---

## Phase 11: Final Checks

### 11.1 Quality Checks

- [ ] Run `devtools::check()` - **ZERO errors, ZERO warnings**
- [ ] Run `devtools::test()` - **ALL tests passing**
- [ ] Test examples in documentation - all work
- [ ] Code follows style guidelines (see DEVELOPER_GUIDE.md 5.7)
- [ ] All functions have appropriate exports/internals
- [ ] No debugging code left in (print statements, browser(), etc.)

### 11.2 Git and Version Control

- [ ] All new files added to git
- [ ] Meaningful commit messages
- [ ] Code reviewed (self or peer)
- [ ] Branch ready for merge

### 11.3 User Testing

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
- [ ] Dispatch tables registered and validated
- [ ] **Celebrate!**

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
| Phase 7: Dispatch Table Integration | 2-3 hours |
| Phase 8: Testing | 5-7 hours |
| Phase 9: Documentation | 4-7 hours |
| Phase 10: Dispatch Table Validation | 1-2 hours |
| Phase 11: Final Checks | 2-3 hours |
| **Total** | **34-52 hours** |

*Note: Times are estimates for a developer familiar with R and the package architecture. Dispatch table integration time increased from Phase 7 due to additional registration and validation steps.*

---

## Notes and Observations

Use this space to document challenges, deviations from templates, or lessons learned:

```
[Add notes here]
```

---

**Last Updated**: 2025-11-16
