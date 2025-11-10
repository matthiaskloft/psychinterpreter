# psychinterpreter Refactoring Plan

**Version**: 0.0.0.9000 (Pre-Release)
**Date**: 2025-11-09
**Status**: Phase 1 Complete ✅ | Phase 2 Pending
**Backwards Compatibility**: NOT REQUIRED (package not yet released)

---

## Executive Summary

This refactoring plan addresses architectural issues identified during code review, focusing on:
1. **Cleaner separation** between generic and model-specific code
2. **Simplified API** with fewer user-facing parameters
3. **Better abstraction** for extending to GM/IRT/CDM model types
4. **Consistent naming conventions** throughout the package
5. **Reduced complexity** in the dispatch system

**Key Insight**: Current architecture mixes concerns between `interpret()`, `interpret_fa()`, and `interpret_generic()`, creating confusion about which function does what and unnecessary parameter passing.

---

## Current Architecture Issues

### 1. Confusing Function Naming & Roles

**Problem**:
- `interpret()` - User-facing generic, does S3 dispatch
- `interpret_fa()` - Direct FA interpretation (also user-facing)
- `interpret_generic()` - Core orchestration (despite name, called AFTER model-specific processing)
- `interpret_model.*()` - Internal S3 methods

**Result**: Users don't know whether to call `interpret()` or `interpret_fa()`, and `interpret_generic()` isn't generic at all—it receives pre-processed `model_data`.

### 2. Redundant Entry Points

**Problem**: Two user-facing entry points do essentially the same thing:
```r
# Option 1: Call interpret() with FA model
interpret(model_fit = fa_model, variable_info = var_info, ...)

# Option 2: Call interpret_fa() directly
interpret_fa(loadings = fa_model$loadings, variable_info = var_info, ...)
```

**Result**: API confusion, documentation duplication, parameter synchronization burden.

### 3. Parameter Proliferation

**Problem**: 20+ parameters on main functions, many passed through multiple layers:
- `interpret()`: 16 parameters + `...`
- `interpret_fa()`: 20 parameters
- `interpret_generic()`: 16 parameters + `...`

**Result**: Difficult to maintain, error-prone, cognitive overload for users.

### 4. Unclear Data Flow

**Current Flow**:
```
interpret(model_fit)
  → interpret_model.fa(model) [extracts loadings]
    → interpret_fa(loadings) [processes loadings into model_data]
      → interpret_generic(model_data) [orchestrates LLM call]
```

**Problem**: `interpret_generic()` receives `model_data` (already processed), not raw model. The "generic" part happens too late.

### 5. Model-Specific Logic in "Generic" Files

**Files to audit**:
- `generic_interpret.R` - May have FA-specific assumptions in validation
- `generic_json_parser.R` - Parsing logic may not generalize
- `class_interpretation.R` - Print/plot methods may assume FA structure

### 6. Inconsistent Abstraction Levels

**Problem**: Mix of high-level and low-level concepts in same interface:
- High-level: `model_fit`, `chat_session`, `output_format`
- Low-level: `cutoff`, `n_emergency`, `hide_low_loadings`, `sort_loadings`

**Result**: FA-specific parameters leak into the generic `interpret()` interface via `...`.

---

## Proposed Architecture (3 Phases)

### Phase 1: Consolidate Entry Points & Clarify Naming ⭐ START HERE

**Goal**: Single, clear user-facing API with consistent internal names.

#### Changes:

1. **Rename Functions** (Breaking Change - OK for pre-release)
   - `interpret()` → Keep as main entry point
   - `interpret_generic()` → Rename to `interpret_core()` (reflects actual role)
   - `interpret_fa()` → Keep but mark as advanced/direct use only

2. **Single Recommended Entry Point**
   ```r
   # ONE way to do it (recommended)
   interpret(
     model_fit = <anything>,  # fa model, list, etc.
     variable_info = var_info,
     provider = "ollama",      # Simplified: provider instead of llm_provider
     model = "gpt-oss:20b"     # Simplified: model instead of llm_model
   )
   ```

3. **Move Model-Specific Params to Config Object**
   ```r
   # Instead of: interpret(..., cutoff = 0.3, n_emergency = 2, hide_low_loadings = FALSE)
   # Use:
   interpret(
     model_fit = fa_model,
     variable_info = var_info,
     config = fa_config(cutoff = 0.3, n_emergency = 2)  # Returns list with class
   )
   ```

4. **Consolidate LLM Parameters**
   ```r
   # Instead of: provider, model, params, system_prompt, echo, word_limit
   # Use:
   interpret(
     model_fit = fa_model,
     variable_info = var_info,
     llm = llm_config(
       provider = "ollama",
       model = "gpt-oss:20b",
       system_prompt = NULL,
       params = params(temperature = 0.7),
       word_limit = 150
     )
   )

   # OR simple args for common case:
   interpret(model_fit = fa_model, variable_info = var_info,
             provider = "ollama", model = "gpt-oss:20b")
   ```

5. **Consolidate Output Parameters**
   ```r
   # Instead of: output_format, heading_level, suppress_heading, max_line_length, silent
   # Use:
   interpret(
     model_fit = fa_model,
     variable_info = var_info,
     output = output_config(
       format = "markdown",
       heading_level = 2,
       max_line_length = 100,
       silent = TRUE
     )
   )

   # OR keep common ones as top-level for convenience:
   interpret(..., silent = TRUE, format = "markdown")
   ```

#### Files to Modify:
- `R/generic_interpret.R` → Rename to `R/core_interpret.R`, rename function
- `R/interpret_method_dispatch.R` → Update `interpret()` to use new parameter structure
- `R/fa_interpret.R` → Update to match new parameter structure
- `R/class_chat_session.R` → Simplify chat_session() parameters
- Add `R/config_constructors.R` → New file with `fa_config()`, `llm_config()`, `output_config()`

#### Benefits:
- ✅ Clear single entry point: `interpret()`
- ✅ Reduced parameter count (20 → ~8-10 top-level)
- ✅ Model-specific params isolated in config objects
- ✅ Better function names reflect actual roles
- ✅ Easier to add new model types

---

### Phase 2: Extract Model-Agnostic Core

**Goal**: True separation between generic orchestration and model-specific processing.

**Constraint**: R/ directory must remain flat (no subdirectories). Use file naming conventions instead.

#### Changes:

1. **Remove interpret_fa() Entirely**
   - Currently marked `@keywords internal` in Phase 1
   - Phase 2: Inline logic into build_model_data.fa() and related S3 methods
   - Remove file if no longer needed, or keep as utils only

2. **Reverse Data Flow**
   ```
   # OLD (Phase 1):
   interpret() → interpret_model.fa() → interpret_fa() → interpret_core()

   # NEW (Phase 2):
   interpret() → interpret_core() → build_model_data.fa() → [continue in core]
   ```

3. **New S3 Generics** (replace current approach)
   ```r
   # Extract and validate model-specific data
   build_model_data <- function(model_fit, variable_info, config, ...) UseMethod("build_model_data")
   build_model_data.fa <- function(model_fit, variable_info, config, ...)
   build_model_data.psych <- function(model_fit, variable_info, config, ...)

   # Create model-specific diagnostics
   create_diagnostics <- function(model_data, ...) UseMethod("create_diagnostics")  # Already exists

   # Build model-specific prompts
   build_main_prompt <- function(model_data, variable_info, ...) UseMethod("build_main_prompt")
   build_system_prompt <- function(model_type, ...) UseMethod("build_system_prompt")  # Already exists

   # Parse model-specific LLM responses
   parse_llm_response <- function(response, model_type, ...) UseMethod("parse_llm_response")  # Already exists

   # Build model-specific reports
   build_report <- function(interpretation, ...) UseMethod("build_report")  # Already exists
   ```

4. **Core Workflow** (in `interpret_core()`)
   ```r
   interpret_core <- function(model_fit, variable_info, model_type, llm_config, output_config, ...) {
     # 1. Build model data (S3 dispatch)
     model_data <- build_model_data(model_fit, variable_info, ...)

     # 2. Initialize/use chat session (generic)
     session <- initialize_session(llm_config, model_type)

     # 3. Build prompts (S3 dispatch)
     system_prompt <- build_system_prompt(model_type, llm_config)
     main_prompt <- build_main_prompt(model_data, variable_info, ...)

     # 4. Query LLM (generic)
     response <- query_llm(session, main_prompt)

     # 5. Parse response (S3 dispatch)
     parsed <- parse_llm_response(response, model_type, model_data)

     # 6. Create diagnostics (S3 dispatch)
     diagnostics <- create_diagnostics(model_data, ...)

     # 7. Build interpretation object (generic structure)
     interpretation <- new_interpretation(
       model_type = model_type,
       model_data = model_data,
       results = parsed,
       diagnostics = diagnostics,
       ...
     )

     # 8. Build report (S3 dispatch)
     interpretation$report <- build_report(interpretation, output_config)

     # 9. Print if not silent (generic)
     if (!output_config$silent) print(interpretation)

     interpretation
   }
   ```

#### Files to Create/Modify (Flat Structure):

**S3 Generic Definitions** (use `s3_` prefix):
- `R/s3_model_data.R` → `build_model_data()` generic + default method
- `R/s3_prompts.R` → `build_main_prompt()` and `build_system_prompt()` generics
- `R/s3_parsing.R` → `parse_llm_response()` generic
- `R/s3_diagnostics.R` → `create_diagnostics()` generic (may already exist)
- `R/s3_reports.R` → `build_report()` generic (may already exist)

**FA Implementations** (use `fa_` prefix):
- `R/fa_model_data.R` → `build_model_data.fa()`, `.psych`, `.lavaan`, `.mirt` methods
- `R/fa_prompts.R` → `build_system_prompt.fa()`, `build_main_prompt.fa()` (may already exist as fa_prompt_builder.R)
- `R/fa_parsing.R` → `parse_llm_response.fa()` (may already exist in fa_interpret.R)
- `R/fa_diagnostics.R` → `create_diagnostics.fa()` (may already exist)
- `R/fa_report.R` → `build_report.fa_interpretation()` (may already exist)
- `R/fa_visualization.R` → `plot.fa_interpretation()` (may already exist as visualization.R)

**Core Files**:
- `R/core_interpret.R` → Refactor to use new S3 dispatch flow
- `R/interpret_method_dispatch.R` → May need updates for new flow

**Remove or Consolidate**:
- `R/fa_interpret.R` → Remove or consolidate into S3 methods above

#### Benefits:
- ✅ Clear separation: core orchestration vs. model-specific logic
- ✅ Easy to add new model types (implement 5-6 S3 methods)
- ✅ Better testability (each S3 method tested independently)
- ✅ No model-specific assumptions in core
- ✅ Easier to understand data flow
- ✅ Discoverable naming conventions (fa_*, s3_*, utils_*)

---

### Phase 3: Optimize File Organization

**Goal**: Logical, discoverable file structure that scales to multiple model types.

**Constraint**: R/ directory must remain flat. Use file naming conventions for organization.

#### New Structure (Flat):

**File Naming Conventions**:
- `interpret*.R` → Main entry point files
- `core_*.R` → Core orchestration
- `class_*.R` → S3 class definitions and methods
- `s3_*.R` → S3 generic definitions
- `fa_*.R` → Factor Analysis implementations
- `gm_*.R` → Gaussian Mixture implementations (future)
- `irt_*.R` → IRT implementations (future)
- `utils_*.R` → Utility functions
- `export_*.R` → Export functions

```
R/
# Main entry points and core
├── interpret_method_dispatch.R    # Main user-facing interpret() + S3 dispatch
├── core_interpret.R               # Core orchestration (interpret_core)

# Class definitions
├── class_chat_session.R           # chat_session class + print method
├── class_interpretation.R         # Base interpretation class + print/plot methods

# Configuration
├── config.R                       # Config constructors: fa_args(), llm_args(), output_args()

# S3 generic definitions (alphabetical)
├── s3_build_model_data.R          # build_model_data() generic
├── s3_build_report.R              # build_report() generic
├── s3_create_diagnostics.R        # create_diagnostics() generic
├── s3_parse_response.R            # parse_llm_response() generic (or extract_by_pattern)
├── s3_prompts.R                   # build_system_prompt(), build_main_prompt() generics

# Factor Analysis implementations (alphabetical)
├── fa_diagnostics.R               # create_diagnostics.fa()
├── fa_interpret.R                 # Legacy: May be removed or consolidated in Phase 2
├── fa_model_data.R                # build_model_data.fa/psych/lavaan/mirt()
├── fa_prompt_builder.R            # build_system_prompt.fa(), build_main_prompt.fa()
├── fa_report.R                    # build_report.fa_interpretation()
├── fa_response_parser.R           # extract_by_pattern.fa(), validate_parsed_result.fa()
├── fa_visualization.R             # plot.fa_interpretation(), theme_psychinterpreter()

# Generic utilities (alphabetical)
├── utils_chat.R                   # Chat/LLM interaction utilities
├── utils_interpret.R              # Interpretation helpers
├── utils_text_processing.R        # Text formatting utilities
├── utils_token_tracking.R         # Token tracking utilities

# Export
├── export_functions.R             # export_interpretation()

tests/testthat/
# Main API tests
├── test-interpret_api.R           # Main interpret() interface tests
├── test-core_interpret.R          # Core orchestration tests (may not exist yet)
├── test-chat_session.R            # Chat session tests

# FA-specific tests (use fa_ prefix)
├── test-fa_diagnostics.R          # FA diagnostics tests
├── test-fa_interpret.R            # FA interpretation tests
├── test-fa_prompt_builder.R       # FA prompt building tests
├── test-fa_visualization.R        # FA visualization tests

# Other component tests
├── test-config.R                  # Config constructor tests
├── test-export.R                  # Export function tests
├── test-text_processing.R         # Text utilities tests

# Fixtures (can use subdirectories)
└── fixtures/
    ├── fa_minimal_loadings.rds
    ├── fa_cached_interpretation.rds
    └── bfi_sample.rds
```

#### Organizational Principles:

1. **Flat R/ Directory**: No subdirectories, all files at root level
2. **Prefix-Based Grouping**: Related files grouped by prefix (fa_*, s3_*, utils_*)
3. **Alphabetical Within Groups**: Easy to locate specific files
4. **Clear Separation**: S3 generics (`s3_*`) separate from implementations (`fa_*`, `gm_*`, etc.)
5. **Test Mirroring**: Test files named `test-<filename>.R` for corresponding source files

#### Migration from Current Structure:

**Files to Rename**:
- `visualization.R` → `fa_visualization.R`
- (Most files already follow conventions after Phase 1)

**Files to Consolidate** (Phase 2):
- Consider merging small related files if appropriate
- Ensure each file has a clear, single purpose

**Files to Create** (Phase 2):
- `s3_build_model_data.R` (new generic)
- `fa_model_data.R` (new implementation)

#### Benefits:
- ✅ Clear separation by concern using naming conventions
- ✅ Easy to find FA-specific code (all `fa_*` files)
- ✅ Template for adding GM/IRT/CDM (use `gm_*`, `irt_*`, `cdm_*` prefixes)
- ✅ S3 generics discoverable (all `s3_*` files)
- ✅ Flat structure complies with R package constraints
- ✅ Scalable to additional model types without directory restructuring

---

## Migration Strategy

### Phase 1 (Current Sprint)
1. Create config constructor functions
2. Rename `interpret_generic()` → `interpret_core()`
3. Update `interpret()` to accept new parameter structure (with backwards compat shims)
4. Update `interpret_fa()` to accept new parameters
5. Update tests to use new API
6. Update documentation

**Estimated Effort**: 4-6 hours
**Risk**: Low (mostly naming + parameter grouping)

### Phase 2 (Next Sprint)
1. Remove `interpret_fa()` or consolidate into S3 methods
2. Create S3 generic files (`s3_*.R` files)
3. Create new FA implementation files (`fa_model_data.R`, etc.)
4. Refactor `interpret_core()` to use new S3 dispatch
5. Move existing FA code to new files with `fa_*` prefix
6. Update tests for new structure
7. Verify no regressions

**Estimated Effort**: 8-12 hours
**Risk**: Medium (significant restructuring)

### Phase 3 (Future)
1. Rename remaining files to follow naming conventions
   - `visualization.R` → `fa_visualization.R`
   - Other utility files to `utils_*` prefix
2. Reorganize test files to mirror source structure
3. Regenerate documentation
4. Update vignettes with new API examples
5. Verify R CMD check passes

**Estimated Effort**: 4-6 hours
**Risk**: Low (mostly file renames and documentation)

---

## Validation Criteria

### Phase 1 Success Criteria
- [ ] Config constructors work: `fa_config()`, `llm_config()`, `output_config()`
- [ ] `interpret()` accepts new parameter structure
- [ ] `interpret()` still works with old parameter structure (via shims)
- [ ] All existing tests pass with minimal changes
- [ ] Documentation updated with new examples
- [ ] `interpret_core()` function exists and works

### Phase 2 Success Criteria
- [ ] `interpret_fa()` removed or fully consolidated
- [ ] All S3 generics defined in `s3_*.R` files
- [ ] All FA implementations in `fa_*.R` files
- [ ] `interpret_core()` uses S3 dispatch (no FA-specific code)
- [ ] Can run interpretation end-to-end with new structure
- [ ] All tests pass
- [ ] No duplicated code between generic and FA-specific files

### Phase 3 Success Criteria
- [ ] All files follow naming conventions (fa_*, s3_*, utils_*, etc.)
- [ ] R/ directory is flat (no subdirectories)
- [ ] Tests organized with matching prefixes
- [ ] Documentation builds without warnings
- [ ] R CMD check passes
- [ ] Package loads and works correctly

---

## API Comparison

### Before (Current)
```r
# Option 1: Use interpret()
interpretation <- interpret(
  model_fit = fa_model,
  variable_info = var_info,
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud",
  params = params(temperature = 0.7),
  system_prompt = NULL,
  interpretation_guidelines = NULL,
  additional_info = "Context...",
  word_limit = 150,
  output_format = "cli",
  heading_level = 1,
  suppress_heading = FALSE,
  max_line_length = 80,
  silent = 0,
  echo = "none",
  cutoff = 0.3,
  n_emergency = 2,
  hide_low_loadings = FALSE,
  sort_loadings = TRUE,
  factor_cor_mat = NULL
)

# Option 2: Use interpret_fa()
interpretation <- interpret_fa(
  loadings = fa_model$loadings,
  variable_info = var_info,
  factor_cor_mat = fa_model$Phi,
  # ... same 18 parameters as above
)
```

### After (Proposed)

```r
# Simple case (90% of usage)
interpretation <- interpret(
  model_fit = fa_model,
  variable_info = var_info,
  provider = "ollama",
  model = "gpt-oss:20b-cloud"
)

# Advanced case with configs
interpretation <- interpret(
  model_fit = fa_model,
  variable_info = var_info,
  llm = llm_config(
    provider = "ollama",
    model = "gpt-oss:20b-cloud",
    params = params(temperature = 0.7),
    word_limit = 150
  ),
  fa = fa_config(
    cutoff = 0.3,
    n_emergency = 2,
    hide_low_loadings = FALSE
  ),
  output = output_config(
    format = "markdown",
    silent = FALSE
  )
)

# Chat session case
chat <- chat_session("fa", provider = "ollama", model = "gpt-oss:20b-cloud")
interpretation <- interpret(
  model_fit = fa_model,
  variable_info = var_info,
  session = chat  # Renamed from chat_session for brevity
)
```

---

## Implementation Notes

### Backwards Compatibility Shims (Phase 1 Only)

Even though we don't need backwards compatibility (pre-release), we can add temporary shims to ease transition during development:

```r
interpret <- function(model_fit, variable_info,
                     # New style
                     provider = NULL, model = NULL,
                     llm = NULL, fa = NULL, output = NULL,
                     session = NULL,
                     # Old style (deprecated but still work)
                     llm_provider = NULL, llm_model = NULL,
                     chat_session = NULL,
                     cutoff = NULL, n_emergency = NULL,
                     output_format = NULL, silent = NULL,
                     ...) {

  # Detect which style user is using
  if (!is.null(llm_provider) || !is.null(cutoff) || !is.null(output_format)) {
    # Old style - convert to new
    cli::cli_warn("Using legacy parameter names. Consider new API (see ?interpret)")

    llm <- llm %||% llm_config(
      provider = provider %||% llm_provider,
      model = model %||% llm_model,
      ...
    )

    fa <- fa %||% fa_config(cutoff = cutoff %||% 0.3, n_emergency = n_emergency %||% 2)
    output <- output %||% output_config(format = output_format %||% "cli", silent = silent %||% 0)
    session <- session %||% chat_session
  }

  # Continue with new implementation
  interpret_core(model_fit, variable_info, llm, fa, output, session, ...)
}
```

### Config Object Design

```r
# Constructor with validation
fa_config <- function(cutoff = 0.3,
                      n_emergency = 2,
                      hide_low_loadings = FALSE,
                      sort_loadings = TRUE) {

  # Validate
  stopifnot(is.numeric(cutoff), cutoff >= 0, cutoff <= 1)
  stopifnot(is.numeric(n_emergency), n_emergency >= 0)
  stopifnot(is.logical(hide_low_loadings))
  stopifnot(is.logical(sort_loadings))

  structure(
    list(
      cutoff = cutoff,
      n_emergency = n_emergency,
      hide_low_loadings = hide_low_loadings,
      sort_loadings = sort_loadings
    ),
    class = c("fa_config", "model_config", "list")
  )
}

# Default config getter
default_fa_config <- function() fa_config()
```

---

## Questions for Discussion

1. Should we keep `interpret_fa()` as advanced API, or deprecate entirely?
 no
2. Config object naming: `fa_config()` vs `fa_options()` vs `fa_params()`?
 how about fa_args?
3. Should configs be optional (NULL = use defaults) or always required?
  yes, but can we implement that common arguments can be passed either directly to interpret() or anonymous?
4. Keep `chat_session` parameter name or rename to `session`?
  keep
5. Should `provider` and `model` be top-level args or always in `llm_config()`? 
  can we implement that common arguments can be passed either directly to interpret() or anonymous?
6. Further remarks: 
  - rename model_fit to fit_results to prevent confusion with model argument
  -    interpret(
     model_fit = fa_model,
     variable_info = var_info,
     llm = llm_config(
       provider = "ollama",
       model = "gpt-oss:20b",
       system_prompt = NULL,
       params = params(temperature = 0.7),
       word_limit = 150
     )
   ), shouldn't this be:
      interpret(
     model_fit = fa_model,
     variable_info = var_info,
     llm_config = list(
       provider = "ollama",
       model = "gpt-oss:20b",
       system_prompt = NULL,
       params = params(temperature = 0.7),
       word_limit = 150
     )
   )?

---

## Next Steps

1. Review and approve this plan
2. Implement Phase 1 (start with config constructors)
3. Update tests incrementally
4. Monitor for issues
5. Proceed to Phase 2 when Phase 1 is stable


---

## Phase 1 Implementation - COMPLETED ✅

**Date Completed**: 2025-11-09

### Changes Implemented

1. ✅ **Config Constructor Functions** (R/config.R - 445 lines)
   - `fa_args()` - Factor analysis parameters (renamed from fa_config)
   - `llm_args()` - LLM interaction parameters (renamed from llm_config)
   - `output_args()` - Output formatting parameters (renamed from output_config)
   - `default_fa_args()` and `default_output_args()` helpers
   - S3 print methods for all config types (print.fa_args, etc.)
   - Full parameter validation in each constructor
   - Builder functions: `build_llm_args()`, `build_fa_args()`, `build_output_args()`
   - Supports both S3 objects and plain lists (validates at use time)

2. ✅ **Function Renaming for Clarity**
   - `interpret_generic()` → `interpret_core()` (reflects actual role)
   - File renamed: `R/generic_interpret.R` → `R/core_interpret.R`
   - Updated all references in fa_interpret.R, fa_report.R, fa_diagnostics.R
   - Documentation regenerated: interpret_core.Rd

3. ✅ **Global Parameter Rename**
   - `model_fit` → `fit_results` across all R files and tests
   - Prevents confusion between statistical model object and LLM model name
   - Updated in all documentation examples and vignettes

4. ✅ **New interpret() Signature - Dual Interface**
   ```r
   interpret(
     fit_results,          # Renamed from model_fit
     variable_info,
     chat_session = NULL,
     model_type = NULL,
     provider = NULL,      # Top-level convenience (was llm_provider)
     model = NULL,         # Top-level convenience (was llm_model)
     llm_args = NULL,      # Config object for LLM settings
     fa_args = NULL,       # Config object for FA settings
     output_args = NULL,   # Config object for output settings
     ...
   )
   ```

5. ✅ **Updated interpret_fa() - Internal Only**
   - Added config object support (`llm_args`, `fa_args`, `output_args`)
   - Extraction logic converts config objects to individual parameters
   - Maintains backwards compatibility internally
   - Marked as `@keywords internal` and `@noRd` (not exported to users)
   - **Phase 2 Note**: Consider removing entirely and inlining logic

6. ✅ **Documentation Updates**
   - Regenerated all .Rd files with roxygen2
   - Updated NAMESPACE (removed interpret_fa export, added fa_args/llm_args/output_args)
   - Updated all examples to use new API (provider/model, fit_results)
   - Added Phase 1 note to CLAUDE.md

### API Examples

**Simple usage (90% of cases)**:
```r
interpret(
  fit_results = fa_model,
  variable_info = var_info,
  provider = "ollama",
  model = "gpt-oss:20b"
)
```

**Advanced with config objects (as plain lists)**:
```r
interpret(
  fit_results = fa_model,
  variable_info = var_info,
  llm_args = list(
    provider = "ollama",
    model = "gpt-oss:20b",
    word_limit = 200
  ),
  fa_args = list(cutoff = 0.4, n_emergency = 3),
  output_args = list(silent = TRUE, format = "markdown")
)
```

**Advanced with helper constructors**:
```r
interpret(
  fit_results = fa_model,
  variable_info = var_info,
  llm_args = llm_args(provider = "ollama", model = "gpt-oss:20b", word_limit = 200),
  fa_args = fa_args(cutoff = 0.4),
  output_args = output_args(silent = TRUE)
)
```

### Files Modified

**New**:
- `R/config.R` (445 lines)

**Renamed**:
- `R/generic_interpret.R` → `R/core_interpret.R`

**Modified**:
- `R/interpret_method_dispatch.R` - New signature, dual interface logic
- `R/fa_interpret.R` - Config extraction, removed export
- `R/fa_report.R` - References to interpret_core
- `R/fa_diagnostics.R` - References to interpret_core
- `R/utils_interpret.R` - fit_results rename
- `tests/testthat/*.R` - fit_results rename (all test files)
- `CLAUDE.md` - API changes documented
- `dev/DEVELOPER_GUIDE.md` - Phase 1 entry added
- `NAMESPACE` - Auto-generated
- `man/*.Rd` - Auto-generated (9 new, 9 deleted)

### Validation

All Phase 1 tests passed:
- ✅ Config constructors work correctly
- ✅ Package loads without errors
- ✅ `interpret()` accepts new signature (both direct args and config objects)
- ✅ `interpret_fa()` not exported (internal-only)
- ✅ Old function names removed (fa_config, llm_config, output_config)
- ✅ Documentation builds without errors
- ✅ Dual interface works (provider/model or llm_args)

### Known Limitations

- Downstream functions (interpret_core, etc.) still use individual parameters internally
- interpret_fa() still exists as internal function (will be addressed in Phase 2)
- Some parameter handling duplication (Phase 2 will consolidate)

---

