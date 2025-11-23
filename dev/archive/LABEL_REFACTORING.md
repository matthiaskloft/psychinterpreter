# Labeling Module Refactoring Summary

## Overview
The labeling feature has been refactored to follow the package's established structure and naming conventions, matching the patterns used by the Factor Analysis (FA) and Gaussian Mixture (GM) modules.

## Changes Made

### File Reorganization

| Old Filename | New Filename | Purpose |
|-------------|--------------|---------|
| `core_label_variables.R` | `label_main.R` | Main `label_variables()` function |
| `labeling_args.R` | `label_args.R` | Configuration arguments |
| `label_utils.R` | `label_formatting.R` | Formatting utilities |
| `s3_label_builder.R` | `label_prompt_builder.R` | S3 prompt building methods |
| `s3_label_parser.R` | `label_json.R` | JSON parsing methods |
| N/A | `label_export.R` | Export/import functions (new) |

### Function Renames

- `labeling_args()` → `label_args()`
- `print.labeling_args()` → `print.label_args()`
- Class name: `labeling_args` → `label_args`

### New Functions

Added `import_labels()` function in `label_export.R` to complement the existing `export_labels()` function.

### Parameter Updates

Throughout all labeling functions:
- Parameter `labeling_args` renamed to `label_args`
- All documentation updated to reflect new naming

## New Module Structure

```
R/
├── label_main.R              # Core labeling function
├── label_args.R              # Configuration system
├── label_formatting.R        # Formatting utilities
├── label_prompt_builder.R    # LLM prompt construction (S3 methods)
├── label_json.R             # Response parsing (S3 methods)
└── label_export.R           # Import/export functionality
```

## Consistency with Package Conventions

The refactored structure now follows the same pattern as other analysis modules:

### FA Module Structure
```
R/
├── fa_model_data.R
├── fa_diagnostics.R
├── fa_report.R
├── fa_prompt_builder.R
├── fa_json.R
├── fa_export.R
└── fa_utils.R
```

### GM Module Structure
```
R/
├── gm_model_data.R
├── gm_diagnostics.R
├── gm_report.R
├── gm_prompt_builder.R
├── gm_json.R
├── gm_export.R
└── gm_utils.R
```

### Label Module Structure (NEW)
```
R/
├── label_main.R           # Equivalent to FA/GM core functions
├── label_args.R           # Configuration (like interpretation_args)
├── label_formatting.R     # Utilities
├── label_prompt_builder.R # S3 prompt methods
├── label_json.R          # S3 parsing methods
└── label_export.R        # Export/import functions
```

## Benefits of Refactoring

1. **Consistency**: Follows established package patterns for easier navigation
2. **Maintainability**: Clear separation of concerns across files
3. **Discoverability**: Predictable file naming helps developers find relevant code
4. **Modularity**: Each file has a clear, focused purpose
5. **Scalability**: Easy to add new label-related features following the pattern

## Migration Guide for Users

### Code Changes Required

Users updating from the old structure need to make these changes:

#### Before (Old Code)
```r
config <- labeling_args(
  label_type = "short",
  case = "snake"
)

labels <- label_variables(
  variable_info,
  labeling_args = config,
  llm_provider = "ollama"
)
```

#### After (New Code)
```r
config <- label_args(
  label_type = "short",
  case = "snake"
)

labels <- label_variables(
  variable_info,
  label_args = config,
  llm_provider = "ollama"
)
```

**Note**: Only the function name and parameter name changed from `labeling_args` to `label_args`.

## Testing

A test script (`tests/test_label_refactor.R`) has been created to verify:
- All new files exist in correct locations
- Core functions are available and working
- Formatting functions work correctly
- Configuration system works as expected

## Next Steps

1. Rebuild package documentation with `devtools::document()`
2. Run full package checks with `R CMD check`
3. Update any vignettes or examples that reference old function names
4. Consider adding unit tests for the labeling module following testthat conventions

## Files Modified

- `R/label_main.R` (renamed from `core_label_variables.R`)
- `R/label_args.R` (renamed from `labeling_args.R`)
- `R/label_formatting.R` (renamed from `label_utils.R`)
- `R/label_prompt_builder.R` (renamed from `s3_label_builder.R`)
- `R/label_json.R` (renamed from `s3_label_parser.R`)
- `R/label_export.R` (newly created)
- `tests/test_label_refactor.R` (newly created)

## Backward Compatibility

The old function names are no longer available. This is a **breaking change** that requires users to update their code. Consider:

1. Adding deprecation warnings if backward compatibility is needed
2. Updating DESCRIPTION file to bump version appropriately
3. Adding NEWS.md entry documenting the breaking changes
