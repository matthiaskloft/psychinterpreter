> **ARCHIVED**: This document describes completed refactoring work from 2025-11-16. All work documented here has been completed and integrated into the main codebase. For current architecture, see DEVELOPER_GUIDE.md Section 5.3.

---

# Model Type Dispatch Table Refactoring

## Overview

This document describes the refactoring of model type checking in `R/core_interpret_dispatch.R` to use dispatch tables instead of complex `inherits()` checks.

**Date**: 2025-11-16
**Status**: Complete

## Motivation

The original implementation used repetitive `inherits()` checks scattered across multiple locations:

1. **Line 313-393**: Complex nested `inherits()` checks for different model classes
2. **Line 556**: psych/principal validation (duplicated logic)
3. **Line 659**: lavaan validation (duplicated logic)
4. **Line 793**: efaList validation (duplicated logic)
5. **Line 899**: SingleGroupClass validation (duplicated logic)

This pattern had several issues:
- **Duplication**: Validation logic repeated across multiple methods
- **Maintenance**: Adding new model types required changes in many places
- **Readability**: Long chains of `inherits()` checks were hard to parse
- **Error-prone**: Easy to miss updating all locations when adding support for a new model

## Solution

Created a centralized dispatch table system that:
- Maps model classes to validation functions and extractors
- Provides a single source of truth for supported model types
- Makes it trivial to add support for new model types
- Integrates cleanly with existing S3 dispatch

## Implementation

### New File: `R/aaa_model_type_dispatch.R`

**Note**: The `aaa_` prefix ensures this file loads first (R sources files alphabetically).

#### Key Functions

1. **`get_model_dispatch_table()`**
   - Returns a dispatch table mapping model classes to their metadata
   - Returns function names as strings (not function references) to avoid initialization order issues
   - Structure:
     ```r
     list(
       model_class = list(
         analysis_type = "fa",
         package = "psych",
         validator_name = "validate_psych_model",
         extractor_name = "extract_psych_loadings"
       )
     )
     ```

2. **`is_supported_model(obj)`**
   - Checks if an object is a supported model type
   - Used in dispatch routing logic
   - Returns: TRUE/FALSE

3. **`get_model_info(obj)`**
   - Retrieves dispatch information for a model object
   - Uses first matching class in object's class vector
   - Returns: List with analysis_type, package, validator_name, extractor_name

4. **`validate_model_structure(model)`**
   - Calls appropriate validator function for a model
   - Replaces scattered validation code
   - Uses `get()` to retrieve validator function by name

5. **Model Validators**: `validate_psych_model()`, `validate_lavaan_model()`, `validate_efalist_model()`, `validate_mirt_model()`
   - Consolidated validation logic from individual methods
   - Each validator checks:
     - Correct class inheritance
     - Required package availability
     - Required model components exist

6. **Model Extractors**: `extract_psych_loadings()`, `extract_lavaan_loadings()`, `extract_efalist_loadings()`, `extract_mirt_loadings()`
   - Extract loadings and factor correlations from model objects
   - Used by `build_analysis_data.*()` methods
   - Centralized extraction logic

### Modified Files

#### `R/core_interpret_dispatch.R`

**Before**:
```r
# Lines 313-322
is_fitted_model <- !is.null(class(fit_results)) &&
  (
    inherits(fit_results, "fa") ||
    inherits(fit_results, "principal") ||
    inherits(fit_results, "psych") ||
    inherits(fit_results, "lavaan") ||
    inherits(fit_results, "efaList") ||
    inherits(fit_results, "SingleGroupClass")
  )
```

**After**:
```r
# Lines 313-314
is_fitted_model <- is_supported_model(fit_results)
```

**Individual method updates** (psych, lavaan, efaList, SingleGroupClass):

**Before**:
```r
# Validate model
if (!inherits(model, "psych") && !inherits(model, "principal")) {
  cli::cli_abort(...)
}

if (is.null(model$loadings)) {
  cli::cli_abort(...)
}
```

**After**:
```r
# Validate model structure using dispatch table
validate_model_structure(model)
```

#### `R/fa_model_data.R`

**Before**:
```r
# Validate model structure
if (!inherits(fit_results, "psych")) {
  cli::cli_abort(...)
}

if (is.null(fit_results$loadings)) {
  cli::cli_abort("Model does not contain loadings component")
}

# Extract loadings
loadings <- as.data.frame(unclass(fit_results$loadings))

# Extract factor correlations if oblique rotation
factor_cor_mat <- if (!is.null(fit_results$Phi)) fit_results$Phi else NULL

# Create list
loadings_list <- list(
  loadings = loadings,
  factor_cor_mat = factor_cor_mat
)
```

**After**:
```r
# Validate model structure using dispatch table
validate_model_structure(fit_results)

# Extract loadings and correlations using dispatch table
model_info <- get_model_info(fit_results)
extractor_fn <- get(model_info$extractor_name, mode = "function")
loadings_list <- extractor_fn(fit_results)
```

## Benefits

1. **Centralized Logic**: All model type information in one place
2. **Easy Extension**: Adding new model types is now straightforward:
   - Add entry to dispatch table
   - Implement validator function
   - Implement extractor function
3. **DRY Principle**: No more duplicated validation code
4. **Maintainability**: Changes to validation/extraction logic happen in one place
5. **Readability**: Clean, self-documenting code
6. **Type Safety**: Validators ensure model structure before extraction

## Adding Support for New Model Types

To add support for a new model type (e.g., gaussian mixture models):

1. **Add dispatch table entry** in `get_model_dispatch_table()`:
   ```r
   gm_model = list(
     analysis_type = "gm",
     package = "mclust",
     validator_name = "validate_gm_model",
     extractor_name = "extract_gm_components"
   )
   ```

2. **Implement validator**:
   ```r
   validate_gm_model <- function(model) {
     if (!inherits(model, "Mclust")) {
       cli::cli_abort(...)
     }
     # Check required components
     invisible(NULL)
   }
   ```

3. **Implement extractor**:
   ```r
   extract_gm_components <- function(model) {
     list(
       means = model$parameters$mean,
       covariances = model$parameters$variance$sigma,
       posterior = model$z
     )
   }
   ```

4. **Create S3 method** in `R/core_interpret_dispatch.R`:
   ```r
   interpret_model.Mclust <- function(model, ...) {
     # Use dispatch table for validation
     validate_model_structure(model)
     # Call interpret_core
     interpret_core(...)
   }
   ```

That's it! The dispatch table handles routing automatically.

## Testing

All existing tests pass with the refactored code:
- ✅ S3 dispatch tests (test-03-s3-dispatch.R)
- ✅ S3 extraction tests (test-04-s3-extraction.R)
- ✅ Integration tests (test-10-integration-core.R, test-11-integration-chat.R)
- ✅ Model-specific tests (test-12-integration-fa.R, test-24-s3-methods-direct.R)

No changes to external API - all existing code continues to work.

## Performance Impact

Negligible. The dispatch table lookup is O(1) with a small constant factor (typically 1-6 class checks per object). The function lookups using `get()` are also O(1).

## Future Improvements

Potential enhancements:
1. Consider making validators part of a formal S3 generic system
2. Add support for custom validators/extractors registered at runtime
3. Create helper function to auto-generate dispatch table entries from model class

## Migration Notes

- No breaking changes
- All existing error messages preserved
- All functionality preserved
- Code is backward compatible

## References

- Original issue: Refactor model type checking to use dispatch tables
- Related files:
  - `R/aaa_model_type_dispatch.R` (new)
  - `R/core_interpret_dispatch.R` (modified)
  - `R/fa_model_data.R` (modified)
