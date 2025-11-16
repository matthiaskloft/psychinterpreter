# API Consistency Report

**Date**: 2025-11-16
**Purpose**: Document discrepancies between current API implementation, MODEL_IMPLEMENTATION_GUIDE.md, and templates

---

## Summary

After reviewing the current implementation, documentation, and templates, I've identified several discrepancies that need to be addressed to ensure consistency across the package.

---

## Current API Structure

### Core S3 Generics Identified

1. **build_analysis_data()** - Extracts model data from fitted objects
2. **build_structured_list()** - Builds structured list from extracted components
3. **build_system_prompt()** - Creates LLM system prompt
4. **build_main_prompt()** - Creates LLM user prompt
5. **validate_parsed_result()** - Validates JSON structure
6. **extract_by_pattern()** - Regex fallback for JSON extraction
7. **create_default_result()** - Default values when parsing fails
8. **create_fit_summary()** - Diagnostics and fit summary
9. **export_interpretation()** - Export to txt/md files
10. **extract_model_parameters()** - Extract model-specific parameters
11. **validate_model_requirements()** - Validate model requirements
12. **plot.{model}_interpretation()** - Visualization method
13. **build_report.{model}_interpretation()** - Report generation

---

## Discrepancies Found

### 1. Parameter Extraction Pattern

**Issue**: Templates use `build_interpretation_args_{model}()` but current implementation uses generic `build_interpretation_args()`

**Current Implementation** (shared_config.R):
- Single generic `build_interpretation_args()` function that handles all model types
- Uses `interpretation_args()` constructor with analysis_type parameter

**Template Pattern** (TEMPLATE_model_data.R line 114):
```r
config <- build_interpretation_args_{model}(
  interpretation_args = interpretation_args,
  dots = dots
)
```

**Recommendation**: Update templates to use the correct pattern:
```r
# Extract from interpretation_args if provided and is a list
cutoff <- if (!is.null(interpretation_args) && is.list(interpretation_args))
  interpretation_args$cutoff else dots$cutoff
```

### 2. Missing S3 Generics in Documentation

**Issue**: MODEL_IMPLEMENTATION_GUIDE.md doesn't mention all S3 generics

**Missing from Guide**:
- `extract_model_parameters()` - Listed in s3_parameter_extraction.R
- `validate_model_requirements()` - Listed in s3_parameter_extraction.R
- `build_structured_list()` - Listed in s3_model_data.R

**Recommendation**: Update MODEL_IMPLEMENTATION_GUIDE.md to include these S3 generics in the "What You Need to Implement" section

### 3. Function Naming Inconsistency

**Issue**: Templates reference `build_{model}_analysis_data_internal()` but FA implementation uses `build_fa_analysis_data_internal()`

**Template** (TEMPLATE_model_data.R line 100):
```r
build_{model}_analysis_data_internal <- function(...)
```

**FA Implementation** (fa_model_data.R line 24):
```r
build_fa_analysis_data_internal <- function(...)
```

**Status**: ✅ Consistent - template correctly shows the pattern

### 4. Configuration Object Builders

**Issue**: Guide mentions uncommenting `build_{analysis}_args()` functions, but current implementation uses single generic `build_interpretation_args()`

**MODEL_IMPLEMENTATION_GUIDE.md** (lines 1225-1228):
> Uncomment {analysis}_args() constructor function
> Uncomment build_{analysis}_args() builder function

**Actual Implementation**:
- Only `build_interpretation_args()` exists (generic for all types)
- No model-specific builders

**Recommendation**: Update guide to reflect actual pattern or implement model-specific builders

### 5. Parameter Extraction S3 Methods

**Issue**: S3 methods `extract_model_parameters()` and `validate_model_requirements()` exist but aren't used in current FA implementation

**Location**: s3_parameter_extraction.R

**FA Implementation**: Directly extracts parameters without using these S3 generics

**Recommendation**: Either:
- Remove unused S3 generics, OR
- Update FA implementation to use them for consistency

### 6. Template Config Addition File

**Issue**: TEMPLATE_config_additions.R references functions that don't match current patterns

**Template References**:
- `gm_args()` constructor
- `build_gm_args()` builder

**Current Pattern**:
- `interpretation_args(analysis_type = "gm", ...)`
- `build_interpretation_args()`

**Recommendation**: Update TEMPLATE_config_additions.R to show the correct pattern

---

## Recommendations

### Priority 1 - Update Templates

1. **TEMPLATE_model_data.R**:
   - Change `build_interpretation_args_{model}()` to direct parameter extraction pattern
   - Add note about unused S3 generics (extract_model_parameters, validate_model_requirements)

2. **TEMPLATE_config_additions.R**:
   - Show how to extend `interpretation_args()` function instead of creating new constructors
   - Remove references to `build_{model}_args()` functions

### Priority 2 - Update Documentation

1. **MODEL_IMPLEMENTATION_GUIDE.md**:
   - Add missing S3 generics to "What You Need to Implement" section
   - Update uncommenting instructions to reflect actual patterns
   - Clarify that `build_interpretation_args()` is generic, not model-specific

2. **Add note about optional S3 generics**:
   - `extract_model_parameters()` - currently unused
   - `validate_model_requirements()` - currently unused
   - `build_structured_list()` - used for list input handling

### Priority 3 - Code Consistency

1. **Decision needed**: Should we use the S3 generics in s3_parameter_extraction.R?
   - If yes: Update FA implementation to use them
   - If no: Mark as deprecated or remove

2. **Consider**: Implementing model-specific config builders for cleaner separation
   - Would make templates more accurate
   - But adds complexity

---

## Current Best Practice (Based on FA Implementation)

For new model implementations, follow the FA pattern:

1. **Parameter extraction**: Direct extraction in `build_{model}_analysis_data_internal()`
2. **Configuration**: Use `interpretation_args(analysis_type = "{model}", ...)`
3. **S3 dispatch**: Analysis type string for most methods, class for `build_analysis_data()`
4. **Structured list**: Implement `build_structured_list.{model}()` for list input support

---

## Files Needing Updates

### Templates to Update
- [ ] `dev/templates/TEMPLATE_model_data.R` - Parameter extraction pattern
- [ ] `dev/templates/TEMPLATE_config_additions.R` - Configuration pattern
- [ ] `dev/templates/IMPLEMENTATION_CHECKLIST.md` - Add missing S3 generics

### Documentation to Update
- [ ] `dev/MODEL_IMPLEMENTATION_GUIDE.md` - Missing S3 generics, configuration pattern
- [ ] Consider adding note about unused S3 generics in s3_parameter_extraction.R

### Code to Review
- [ ] `R/s3_parameter_extraction.R` - Decide if these S3 generics should be used

---

## Conclusion

The package has evolved since the templates were created, resulting in some inconsistencies. The core functionality is solid, but documentation and templates need updates to reflect the current implementation patterns. The FA implementation serves as the best reference for new model types.

**Recommendation**: Update templates and documentation to match the FA implementation pattern rather than changing working code.