2# Psychinterpreter Package Consistency Fix Plan

**Created**: 2025-11-12
**Author**: Claude Code Analysis
**Purpose**: Comprehensive plan to address all consistency issues identified in package analysis
**Estimated Total Effort**: 8-12 hours

---

## Executive Summary

This document provides a detailed, actionable plan to fix all consistency issues identified in the psychinterpreter package analysis. Fixes are organized by priority (High, Medium, Low) and include specific implementation steps, affected files, and verification methods.

---

## 🔴 HIGH PRIORITY FIXES (2-3 hours)

These issues affect package functionality or user-facing documentation and should be addressed immediately.

### 1. Fix NAMESPACE Export Inconsistencies

**Issue**: `interpret_core` is exported but documented as internal
**Impact**: Confuses users about which functions are part of public API
**Effort**: 30 minutes

#### Implementation Steps:

1. **Option A: Make interpret_core truly internal** (RECOMMENDED)
   ```r
   # In R/core_interpret.R:
   # 1. Remove line 42: #' @export
   # 2. Keep line 43: #' @keywords internal
   ```

   Then regenerate NAMESPACE:
   ```bash
   Rscript -e "devtools::document()"
   ```

2. **Option B: Document as public**
   ```r
   # In R/core_interpret.R:
   # 1. Keep line 42: #' @export
   # 2. Remove line 43: #' @keywords internal
   # 3. Add proper user documentation explaining when to use interpret_core vs interpret
   ```

**Verification**:
```bash
# Check NAMESPACE no longer exports interpret_core (if Option A)
grep "export(interpret_core)" NAMESPACE
# Should return nothing if properly removed
```

---

### 2. Update pkgdown.yml References

**Issue**: References non-existent functions
**Files**: `_pkgdown.yml`
**Effort**: 15 minutes

#### Implementation Steps:

1. **Remove non-existent function references**:
   ```yaml
   # In _pkgdown.yml, REMOVE these lines:
   # Line 29: - reset.chat_session
   # Line 39: - default_output_args
   ```

2. **Find correct function names**:
   ```bash
   # Check actual exports for chat session
   grep "reset" NAMESPACE
   # If exists, use correct name; if not, remove from pkgdown

   # Check for output_args related functions
   grep "output_args" NAMESPACE
   # Use only actually exported functions
   ```

3. **Update the reference section** (_pkgdown.yml:21-76):
   ```yaml
   - title: "Chat Session Management"
     contents:
       - chat_session
       - is.chat_session
       # - reset.chat_session  # REMOVE THIS LINE

   - title: "Configuration Functions"
     contents:
       - llm_args
       - interpretation_args
       - output_args
       # - default_output_args  # REMOVE THIS LINE
   ```

**Verification**:
```bash
# Build pkgdown site locally to verify no warnings
Rscript -e "pkgdown::build_reference()"
```

---

### 3. Clean Up R/archive Directory

**Issue**: Archive directory in package structure violates CRAN policies
**Impact**: Will cause R CMD check warnings
**Effort**: 30 minutes

#### Implementation Steps:

1. **Create new location outside package**:
   ```bash
   # Create archive directory at project root (not in R/)
   mkdir -p ../psychinterpreter_archive
   ```

2. **Move archived files**:
   ```bash
   # Move all archived R files
   mv R/archive/* ../psychinterpreter_archive/

   # Remove empty archive directory
   rmdir R/archive
   ```

3. **Update .Rbuildignore** to exclude any archive references:
   ```
   # Add to .Rbuildignore if not already present
   ^archive$
   ^.*_archive$
   ```

4. **Document archived code location** in README or developer guide:
   ```markdown
   ## Archived Code

   Historical implementations are preserved in `../psychinterpreter_archive/`
   outside the package structure. These files are not part of the package build.
   ```

**Verification**:
```bash
# Ensure no archive directory in R/
ls -la R/ | grep archive
# Should return nothing

# Run R CMD check to ensure no warnings
Rscript -e "devtools::check()"
```

---

### 4. Fix VALID_MODEL_TYPES Constant

**Issue**: Only "fa" is active, others commented out
**File**: `R/core_constants.R:19`
**Effort**: 30 minutes

#### Implementation Steps:

1. **Update the constant to include all planned types**:
   ```r
   # In R/core_constants.R:19
   VALID_MODEL_TYPES <- c("fa", "gm", "irt", "cdm")
   ```

2. **Update validate_model_type() to handle unimplemented types**:
   ```r
   # In R/core_constants.R:48-54
   validate_model_type <- function(model_type, allow_null = FALSE) {
     # ... existing validation code ...

     # After checking if valid, add implementation check
     if (model_type %in% c("gm", "irt", "cdm")) {
       cli::cli_abort(c(
         "x" = "Model type '{model_type}' is not yet implemented",
         "i" = "Currently only 'fa' (factor analysis) is fully supported",
         "i" = "Implementation for '{model_type}' is planned for a future release"
       ))
     }

     invisible(model_type)
   }
   ```

3. **Update error messages in interpretation_args()**:
   ```r
   # In R/shared_config.R:54-77
   # Change from cli_abort to consistent message:
   interpretation_args <- function(model_type, ...) {
     validate_model_type(model_type)  # Will now handle the error consistently

     if (model_type == "fa") {
       return(interpretation_args_fa(...))
     }
     # Remove individual error blocks for gm, irt, cdm
     # validate_model_type handles this now
   }
   ```

**Verification**:
```r
# Test that valid but unimplemented types give clear error
interpret(fit_results = list(data = 1), model_type = "gm")
# Should error with "not yet implemented" message
```

---

## 🟡 MEDIUM PRIORITY FIXES (3-4 hours)

These issues affect code quality and maintainability.

### 5. Add Missing S3 Method Documentation

**Issue**: Several exported S3 methods lack roxygen documentation
**Files**: Various
**Effort**: 1 hour

#### Implementation Steps:

1. **Add documentation for build_model_data.list**:
   ```r
   # In R/s3_model_data.R (after line 54, before the actual method):

   #' Build model data from list structure
   #'
   #' @param fit_results List containing model components
   #' @param model_type Character. Model type identifier (required)
   #' @param interpretation_args Interpretation configuration
   #' @param ... Additional arguments including variable_info
   #'
   #' @return Standardized model data structure
   #' @export
   #' @keywords internal
   build_model_data.list <- function(fit_results, model_type = NULL,
                                     interpretation_args = NULL, ...) {
     # ... existing implementation
   }
   ```

2. **Add documentation for build_model_data.data.frame**:
   ```r
   # In appropriate file:

   #' Build model data from data frame
   #'
   #' @param fit_results Data frame containing loadings
   #' @param model_type Character. Model type identifier
   #' @param interpretation_args Interpretation configuration
   #' @param ... Additional arguments
   #'
   #' @return Standardized model data structure
   #' @export
   #' @keywords internal
   build_model_data.data.frame <- function(...) {
     # ... existing implementation
   }
   ```

3. **Add documentation for build_model_data.matrix**:
   ```r
   # Similar pattern as above
   ```

4. **Regenerate documentation**:
   ```bash
   Rscript -e "devtools::document()"
   ```

**Verification**:
```bash
# Check that all exported S3 methods have .Rd files
Rscript -e "devtools::check_man()"
```

---

### 6. Standardize Test File Naming

**Issue**: Inconsistent test file naming patterns
**Location**: `tests/testthat/`
**Effort**: 45 minutes

#### Implementation Steps:

1. **Adopt consistent naming convention**:
   ```
   Pattern: test-{primary_function_or_feature}.R
   ```

2. **Rename test files** (if needed):
   ```bash
   # Current files seem mostly consistent, but verify:
   cd tests/testthat/

   # Ensure all follow pattern:
   # test-interpret_api.R → OK (tests interpret API)
   # test-interpret_fa.R → OK (tests FA interpretation)
   # test-chat_fa.R → RENAME to test-chat_session.R (more general)
   # test-fa_utilities.R → RENAME to test-utilities_fa.R (group by type)
   ```

3. **Update test descriptions**:
   ```r
   # In each test file, ensure first line describes scope:
   # test-interpret_api.R:
   # "Tests for interpret() function public API"

   # test-chat_session.R:
   # "Tests for chat_session creation and management"
   ```

**Verification**:
```bash
# Run all tests to ensure renaming didn't break anything
Rscript -e "devtools::test()"
```

---

### 7. Add Tests for interpret_core

**Issue**: Exported function lacks tests
**Effort**: 1.5 hours

#### Implementation Steps:

1. **Create new test file** `tests/testthat/test-interpret_core.R`:
   ```r
   # test-interpret_core.R
   # Tests for interpret_core internal orchestrator

   library(testthat)
   library(psychinterpreter)

   describe("interpret_core basic functionality", {

     test_that("interpret_core requires model_data or fit_results", {
       expect_error(
         interpret_core(),
         "Either.*fit_results.*or.*model_data.*must be provided"
       )
     })

     test_that("interpret_core validates model_type", {
       model_data <- list(
         loadings = matrix(1:4, 2, 2),
         model_type = "invalid_type"
       )

       expect_error(
         interpret_core(model_data = model_data),
         "Invalid model_type"
       )
     })

     test_that("interpret_core handles chat_session correctly", {
       skip("Implement after deciding if interpret_core stays public")
       # Add tests if keeping as public API
     })
   })

   describe("interpret_core parameter handling", {

     test_that("interpret_core converts logical silent to integer", {
       # Test backward compatibility
       skip("Add implementation")
     })

     test_that("interpret_core merges config objects correctly", {
       # Test llm_args, interpretation_args, output_args merging
       skip("Add implementation")
     })
   })
   ```

2. **Add edge case tests**:
   ```r
   test_that("interpret_core handles NULL parameters gracefully", {
     # Test various NULL parameter combinations
   })
   ```

**Verification**:
```bash
Rscript -e "testthat::test_file('tests/testthat/test-interpret_core.R')"
```

---

### 8. Update Package Statistics

**Issue**: Outdated statistics in documentation
**File**: `dev/DEVELOPER_GUIDE.md:779-791`
**Effort**: 30 minutes

#### Implementation Steps:

1. **Option A: Remove specific numbers**:
   ```markdown
   # In dev/DEVELOPER_GUIDE.md:
   ## 4.6 Package Statistics

   For current package statistics, run:
   ```r
   # Get line counts
   system("wc -l R/*.R")

   # Get test counts
   length(list.files("tests/testthat", pattern = "^test-"))

   # Get export counts
   length(readLines("NAMESPACE")[grepl("^export", readLines("NAMESPACE"))])
   ```
   ```

2. **Option B: Create auto-update script**:
   ```r
   # Create dev/update_stats.R:
   update_package_stats <- function() {
     stats <- list(
       r_files = length(list.files("R/", pattern = "\\.R$")),
       test_files = length(list.files("tests/testthat", pattern = "^test-")),
       total_lines = sum(sapply(list.files("R/", pattern = "\\.R$", full.names = TRUE),
                                function(x) length(readLines(x)))),
       exports = length(grep("^export", readLines("NAMESPACE")))
     )

     # Update DEVELOPER_GUIDE.md with current stats
     # ... implementation
   }
   ```

**Verification**:
```bash
# If using script, run it:
Rscript dev/update_stats.R
```

---

## 🟢 LOW PRIORITY FIXES (2-3 hours)

These are improvements that enhance quality but don't affect functionality.

### 9. Clean Up Phase Refactoring Comments

**Issue**: Residual Phase 1/2/3 comments throughout code
**Effort**: 45 minutes

#### Implementation Steps:

1. **Search and remove phase references**:
   ```bash
   # Find all phase references
   grep -r "Phase [1-3]" R/ --include="*.R"

   # Remove or update comments referring to phases
   # Keep only if they provide historical context that's valuable
   ```

2. **Update CLAUDE.md** to remove phase references:
   ```markdown
   # Remove or consolidate the "IMPORTANT API CHANGES" section
   # Keep only current API documentation
   ```

3. **Clean deprecated function references**:
   ```bash
   # Find references to fa_args (deprecated)
   grep -r "fa_args" R/ --include="*.R"
   # Update to interpretation_args where found
   ```

**Verification**:
```bash
grep -r "Phase [1-3]" R/ | wc -l
# Should be 0 or very few
```

---

### 10. Enhance Model Implementation Templates

**Issue**: Templates could be more specific
**Location**: `dev/templates/`
**Effort**: 1 hour

#### Implementation Steps:

1. **Add model-specific examples to templates**:
   ```r
   # In dev/templates/TEMPLATE_model_data.R:
   # Add specific examples for each model type as comments:

   # ==== GAUSSIAN MIXTURE EXAMPLE ====
   # For GM models, extract:
   #   - means: cluster centers
   #   - covariances: cluster covariance matrices
   #   - weights: cluster weights/probabilities
   #   - n_clusters: number of clusters

   # ==== IRT EXAMPLE ====
   # For IRT models, extract:
   #   - item_params: discrimination, difficulty, guessing
   #   - ability_scores: estimated theta values
   #   - item_fit: fit statistics per item
   ```

2. **Add validation patterns**:
   ```r
   # In templates, add model-specific validation examples:

   # ==== VALIDATION PATTERNS ====
   # GM: Ensure covariance matrices are positive definite
   # IRT: Check item parameters are within reasonable bounds
   # CDM: Validate Q-matrix structure
   ```

3. **Create COMMON_PITFALLS.md**:
   ```markdown
   # Common Pitfalls When Adding Model Types

   ## 1. Forgetting to update VALID_MODEL_TYPES
   Location: R/core_constants.R:19

   ## 2. Missing S3 method registration
   Ensure all 8 methods are properly exported

   ## 3. Incorrect parameter extraction
   Each model type has unique parameter structures

   ## 4. Token efficiency
   Consider what information is essential for LLM interpretation
   ```

**Verification**:
Review templates for completeness and clarity

---

### 11. Document Dual Interface Pattern

**Issue**: Config objects vs. direct parameters not fully explained
**Effort**: 30 minutes

#### Implementation Steps:

1. **Add section to CLAUDE.md**:
   ```markdown
   ## Understanding the Dual Interface Pattern

   The interpret() function supports two ways to pass parameters:

   ### Direct Parameters (Simple)
   ```r
   interpret(
     fit_results = model,
     variable_info = vars,
     provider = "ollama",      # Direct parameter
     model = "gpt-oss:20b",    # Direct parameter
     word_limit = 100          # Direct parameter
   )
   ```

   ### Configuration Objects (Flexible)
   ```r
   # Create reusable configurations
   llm_cfg <- llm_args(provider = "ollama", model = "gpt-oss:20b")
   fa_cfg <- interpretation_args(model_type = "fa", cutoff = 0.4)

   # Use across multiple analyses
   interpret(fit_results = model1, variable_info = vars1,
            llm_args = llm_cfg, interpretation_args = fa_cfg)
   interpret(fit_results = model2, variable_info = vars2,
            llm_args = llm_cfg, interpretation_args = fa_cfg)
   ```

   ### Precedence Rules
   Direct parameters override configuration objects:
   ```r
   interpret(
     fit_results = model,
     llm_args = llm_args(word_limit = 100),
     word_limit = 150  # This wins: final word_limit = 150
   )
   ```
   ```

2. **Update function documentation**:
   ```r
   # In R/core_interpret_dispatch.R roxygen:
   #' @section Parameter Precedence:
   #' When both direct parameters and configuration objects provide the same setting,
   #' direct parameters take precedence. This allows configuration reuse with
   #' case-specific overrides.
   ```

**Verification**:
Build pkgdown site and review documentation clarity

---

### 12. Fix Word Limit in Tests

**Issue**: Some tests use default word_limit (150) instead of minimum (20)
**Location**: `tests/testthat/`
**Effort**: 30 minutes

#### Implementation Steps:

1. **Find tests with default word_limit**:
   ```bash
   # Search for interpret calls without word_limit = 20
   grep -r "interpret(" tests/testthat/ | grep -v "word_limit = 20"
   ```

2. **Update test calls**:
   ```r
   # Change from:
   interpret(fit_results = model, variable_info = vars, provider = "ollama")

   # To:
   interpret(fit_results = model, variable_info = vars,
            provider = "ollama", word_limit = 20)
   ```

3. **Add test helper for consistency**:
   ```r
   # In tests/testthat/helper.R:
   test_interpret <- function(..., word_limit = 20) {
     interpret(..., word_limit = word_limit)
   }
   ```

**Verification**:
```bash
# Verify all LLM tests use word_limit = 20
grep -r "interpret(" tests/testthat/ | grep -v "word_limit = 20" | wc -l
# Should be 0 or only non-LLM tests
```

---

### 13. Add skip_on_ci() to All LLM Tests

**Issue**: Not all LLM tests skip on CI
**Effort**: 20 minutes

#### Implementation Steps:

1. **Find LLM tests without skip_on_ci()**:
   ```bash
   # Find test files that call interpret with a provider but no skip_on_ci
   grep -l "provider = " tests/testthat/test-*.R | \
   xargs grep -L "skip_on_ci()"
   ```

2. **Add skip_on_ci() to LLM tests**:
   ```r
   test_that("LLM interpretation works", {
     skip_on_ci()  # Add this line
     skip_if_no_ollama()  # Often also needed

     # ... test implementation
   })
   ```

**Verification**:
```bash
# On CI environment:
Rscript -e "devtools::test()"
# Should skip LLM tests
```

---

## 📋 Implementation Order

### Week 1 (High Priority)
1. ✅ Fix NAMESPACE exports (30 min)
2. ✅ Update pkgdown.yml (15 min)
3. ✅ Clean R/archive (30 min)
4. ✅ Fix VALID_MODEL_TYPES (30 min)

### Week 2 (Medium Priority)
5. ✅ Add S3 documentation (1 hr)
6. ✅ Standardize test naming (45 min)
7. ✅ Add interpret_core tests (1.5 hr)
8. ✅ Update statistics (30 min)

### Week 3 (Low Priority)
9. ✅ Clean phase comments (45 min)
10. ✅ Enhance templates (1 hr)
11. ✅ Document dual interface (30 min)
12. ✅ Fix test word_limit (30 min)
13. ✅ Add skip_on_ci (20 min)

---

## 🔍 Verification Checklist

After completing all fixes:

```bash
# 1. Check package passes R CMD check
Rscript -e "devtools::check()"

# 2. Verify all tests pass
Rscript -e "devtools::test()"

# 3. Build documentation without warnings
Rscript -e "devtools::document()"

# 4. Build pkgdown site
Rscript -e "pkgdown::build_site()"

# 5. Check test coverage
Rscript -e "covr::package_coverage()"

# 6. Verify no archive directory in package
ls -la R/ | grep -c archive  # Should be 0

# 7. Check NAMESPACE is clean
grep "export(interpret_core)" NAMESPACE  # Based on decision

# 8. Verify consistent error messages
Rscript -e "interpret(fit_results = list(data = 1), model_type = 'gm')"
# Should show "not yet implemented" consistently
```

---

## 📄 Documentation Updates

After fixes, update:

1. **CLAUDE.md**: Remove phase references, update examples
2. **DEVELOPER_GUIDE.md**: Update statistics, fix line numbers
3. **README.md**: Ensure examples work with fixed API
4. **NEWS.md**: Document all breaking changes and fixes

---

## 🎯 Success Criteria

- [ ] R CMD check: 0 errors, 0 warnings, 0 notes
- [ ] All tests pass locally and on CI
- [ ] pkgdown builds without warnings
- [ ] Documentation is internally consistent
- [ ] No deprecated code in R/ directory
- [ ] Clear error messages for unimplemented features
- [ ] Consistent test patterns and coverage > 80%

---

**END OF FIX PLAN**

*This plan addresses all issues identified in the consistency analysis. Implement in the suggested order for minimal disruption to ongoing development.*
