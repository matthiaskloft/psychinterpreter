# psychinterpreter Developer Guide

**Last Updated**: 2025-11-09
**Version**: 0.0.0.9000
**Purpose**: Technical reference for package maintainers and contributors

**For usage/user-facing documentation**: See [CLAUDE.md](../CLAUDE.md)

---

## Table of Contents

1. [Package Architecture](#1-package-architecture)
2. [Token Tracking System](#2-token-tracking-system)
3. [Implementation Details](#3-implementation-details)
4. [Package History](#4-package-history)
5. [Development Reference](#5-development-reference)

---

# 1. Package Architecture

## 1.1 Design Principles

1. **Generic Core + Model-Specific Implementations**
   - Core interpretation logic is model-agnostic
   - Model-specific behavior via S3 methods

2. **Extensibility**
   - Adding new model types requires 7 S3 methods
   - No changes to core infrastructure needed

3. **Token Efficiency**
   - Persistent chat sessions reuse system prompts (~40-60% savings)
   - Conditional token tracking accounts for system prompt caching

4. **Backward Compatibility**
   - Legacy APIs maintained via deprecation wrappers
   - Boolean silent converted to integer (FALSE→0, TRUE→2)

## 1.2 File Structure

### Core Infrastructure (5 files, ~1,054 lines)

| File | Lines | Purpose |
|------|-------|---------|
| `generic_interpret.R` | 392 | Main interpretation orchestration engine |
| `generic_json_parser.R` | 200 | Multi-tier JSON parsing with S3 dispatch |
| `generic_prompt_builder.R` | 83 | S3 generic system for prompt construction |
| `base_chat_session.R` | 287 | Chat session management (all model types) |
| `base_interpretation.R` | 92 | Base interpretation object infrastructure |

### Factor Analysis Implementation (7 files, ~3,154 lines)

| File | Lines | Purpose |
|------|-------|---------|
| `fa_interpret.R` | 645 | Main user-facing FA interpretation function |
| `fa_prompt_builder.R` | 340 | FA-specific prompt construction (S3 methods) |
| `fa_json.R` | 232 | FA-specific JSON parsing (S3 methods) |
| `fa_diagnostics.R` | 199 | Cross-loadings, no-loadings, diagnostics (S3 method) |
| `interpret_methods.R` | 744 | S3 methods for psych/lavaan/mirt packages |
| `interpret_helpers.R` | 156 | Validation and routing for interpret() dispatch |
| `report_fa.R` | 838 | Report building with S3 method |

### Utilities (3 files, ~653 lines)

| File | Lines | Purpose |
|------|-------|---------|
| `export_functions.R` | 132 | Export to txt/md formats |
| `utils_text_processing.R` | 107 | Text wrapping, word counting |
| `visualization.R` | 414 | S3 plot method, color-blind friendly palettes, custom theme |

### Archive (8 files, not loaded)

Old implementations kept for reference in `R/archive/`:
- `fa_report_functions.R` - Duplicate report builder
- `fa_wrapper_methods.R` - Old interpret dispatch
- `fa_utilities.R` - Duplicate diagnostics
- `fa_chat.R` - Old FA-specific chat
- `utils_export.R` - Duplicate export functions
- `utils.R` - Old utilities
- `interpret_fa.R.old` - Original monolithic implementation
- `interpret_fa.R.backup` - Backup

## 1.3 S3 Method System

### Required S3 Methods per Model Type

Each model type (FA, GM, IRT, CDM) must implement these 7 methods:

1. **`build_system_prompt.{model}()`** - Constructs expert system prompt
2. **`build_main_prompt.{model}()`** - Constructs user prompt with data
3. **`validate_parsed_result.{model}()`** - Validates LLM JSON response
4. **`extract_by_pattern.{model}()`** - Pattern-based extraction fallback
5. **`create_default_result.{model}()`** - Default results if parsing fails
6. **`create_diagnostics.{model}()`** - Model-specific diagnostics
7. **`build_report.{model}_interpretation()`** - Report generation

### Current Implementations

- **Factor Analysis (FA)**: All 7 methods implemented ✓
- **Gaussian Mixture (GM)**: Not implemented
- **Item Response Theory (IRT)**: Not implemented
- **Cognitive Diagnosis Models (CDM)**: Not implemented

## 1.4 Interpretation Workflow

```
User calls interpret() or interpret_fa()
        ↓
1. Parameter validation (named arguments only)
        ↓
2. Data preparation (loadings, correlations, etc.)
        ↓
3. Call interpret_generic() [core engine]
        ↓
4. interpret_generic() orchestrates:
   a. build_system_prompt.{model}()   → System prompt
   b. build_main_prompt.{model}()     → User prompt with data
   c. LLM API call (via ellmer)       → Get JSON response
   d. parse_llm_response()            → Parse JSON with S3 dispatch
      - validate_parsed_result.{model}()
      - extract_by_pattern.{model}() [if JSON parsing fails]
      - create_default_result.{model}() [ultimate fallback]
   e. create_diagnostics.{model}()    → Cross-loadings, etc.
   f. build_report.{model}_interpretation() → Generate report
        ↓
5. Return interpretation object with token tracking
```

## 1.5 The interpret() Dispatch System

### Architecture Decision: Plain Function (Not S3 Generic)

`interpret()` is implemented as a **plain function with named arguments**, not an S3 generic. This prevents positional dispatch confusion and provides clear parameter validation.

### Dispatch Flow

```
interpret(chat_session=NULL, model_fit=NULL, variable_info=NULL, model_type=NULL, ...)
    ↓
[Plain function - validates all named arguments]
    ↓
Validate arguments:
    ├─ Check model_fit provided
    ├─ Check variable_info provided
    ├─ Validate chat_session if provided
    └─ Determine effective_model_type (from chat_session or model_type parameter)
    ↓
Detect model_fit type:
    ↓
├─ FITTED MODEL? (fa, principal, lavaan, efaList, SingleGroupClass)
│       ↓
│   Call interpret_model() S3 generic [INTERNAL, NOT EXPORTED]:
│       ↓
│   ├─ interpret_model.fa() ────────────→ Extract from psych::fa
│   ├─ interpret_model.principal() ─────→ Extract from psych::principal
│   ├─ interpret_model.lavaan() ────────→ Extract from lavaan CFA/SEM
│   ├─ interpret_model.efaList() ───────→ Extract from lavaan::efa
│   ├─ interpret_model.SingleGroupClass()→ Extract from mirt::mirt
│   └─ interpret_model.psych() ─────────→ Dispatcher for psych objects
│           ↓
│       Each method calls interpret_fa(loadings, ..., chat_session=...)
│
└─ STRUCTURED LIST? (is.list && !is.data.frame && !is_fitted_model)
        ↓
    Requires model_type or chat_session
        ↓
    validate_fa_list_structure():
        ├─ Extract loadings (required)
        ├─ Extract Phi or factor_cor_mat (optional)
        └─ Warn about unrecognized components
            ↓
        handle_raw_data_interpret(extracted$loadings, ...)
            ↓
        Route based on effective_model_type:
            ├─ fa: interpret_fa()
            ├─ gm: [not implemented - error]
            ├─ irt: [not implemented - error]
            └─ cdm: [not implemented - error]
```

**Key Points**:
- `interpret()` is a plain function with all named arguments
- Internal `interpret_model()` S3 generic handles fitted model objects
- Supports structured lists for model components
- Single validation/routing logic in `utils_interpret.R`

## 1.6 Key Architecture Decisions

### 1. Flat File Structure
- All R files in `R/` directory (no subdirectories)
- Naming convention: `generic_*`, `fa_*`, `base_*`, `utils_*`
- **Rationale**: Simpler for R package structure, easier navigation

### 2. Single Source of Truth
- System prompts: Only in `fa_prompt_builder.R`
- Report building: Only in `report_fa.R`
- Interpret methods: Only in `interpret_methods.R`
- **Rationale**: DRY principle, prevents drift

### 3. S3 Export Pattern
- Export generic: `#' @export` on generic function
- Export methods: `#' @export` on individual S3 methods
- **Rationale**: Standard R package practice

### 4. Persistent Chat Sessions Use Environments
- Chat sessions are environments (mutable, reference semantics)
- Token counters update in place
- **Rationale**: Natural API for session state management

### 5. Dual-Tier Token Tracking
- **Cumulative**: Session-level totals
- **Per-Run**: Individual interpretation costs
- **System Prompt**: Tracked separately
- **Rationale**: Handles system prompt caching, prevents negative accumulation

## 1.7 Adding a New Model Type

Example: Adding Gaussian Mixture (GM) support

### Step 1: Create Model-Specific Files

```
R/gm_interpret.R        - Main user-facing function interpret_gm()
R/gm_prompt_builder.R   - S3 methods: build_system_prompt.gm(), build_main_prompt.gm()
R/gm_json.R             - S3 methods: validate_parsed_result.gm(), etc.
R/gm_diagnostics.R      - S3 method: create_diagnostics.gm()
R/report_gm.R           - S3 method: build_report.gm_interpretation()
```

### Step 2: Implement 7 Required S3 Methods

```r
#' @export
build_system_prompt.gm <- function(model_type, model_data, variable_info, ...) {
  "You are an expert in Gaussian Mixture modeling..."
}

#' @export
build_main_prompt.gm <- function(model_type, model_data, variable_info, ...) {
  # Format cluster parameters, covariance matrices, etc.
}

# ... implement remaining 5 methods
```

### Step 3: Update handle_raw_data_interpret()

```r
# In interpret_helpers.R
handle_raw_data_interpret <- function(x, variable_info, model_type, chat_session, ...) {
  effective_model_type <- if (!is.null(chat_session)) {
    chat_session$model_type
  } else {
    model_type
  }

  switch(effective_model_type,
    fa = interpret_fa(x, variable_info, chat_session = chat_session, ...),
    gm = interpret_gm(x, variable_info, chat_session = chat_session, ...),  # ADD THIS
    irt = cli::cli_abort("Not yet implemented"),
    cdm = cli::cli_abort("Not yet implemented")
  )
}
```

### Step 4: Create Model-Specific List Validation (if needed)

If your model type needs to support structured list input (like `list(loadings = ..., Phi = ...)`), create a validation function following the FA pattern:

```r
# In utils_interpret.R or model-specific file
validate_gm_list_structure <- function(model_fit_list) {
  # Check required components
  if (!"means" %in% names(model_fit_list)) {
    cli::cli_abort("model_fit list must contain 'means' component")
  }

  # Validate types
  means <- model_fit_list$means
  if (!is.matrix(means)) {
    cli::cli_abort("means component must be a matrix")
  }

  # Extract optional components
  covariances <- model_fit_list$covariances %||% NULL

  # Warn about unrecognized components
  recognized <- c("means", "covariances", "mixing_proportions")
  unrecognized <- setdiff(names(model_fit_list), recognized)
  if (length(unrecognized) > 0) {
    cli::cli_warn("Unrecognized components will be ignored: {unrecognized}")
  }

  # Return extracted components
  list(means = means, covariances = covariances)
}
```

**Decision: Model-Specific vs. Generic Validation** (2025-11-09)

Each model type should have its **own validation function** because:

1. **Truly Different Requirements**: Each model has fundamentally different components
   - FA: `loadings`, `factor_cor_mat`
   - GM: `means`, `covariances`, `mixing_proportions`
   - IRT: `difficulty`, `discrimination`, `guessing`
   - CDM: `q_matrix`, `item_parameters`

2. **YAGNI Principle**: FA is currently the only implemented type. Wait until you have **2+ implementations** before creating generic abstractions.

3. **Future Path**: After implementing 2-3 model types, evaluate if S3 dispatch adds value:
   ```r
   # Potential future generalization (only if pattern emerges)
   validate_list_structure <- function(model_fit_list, model_type) {
     UseMethod("validate_list_structure", structure(list(), class = model_type))
   }

   validate_list_structure.fa <- function(model_fit_list, model_type) { ... }
   validate_list_structure.gm <- function(model_fit_list, model_type) { ... }
   ```

4. **Rule of Three**: Only abstract after you have 3 similar implementations to identify the true common pattern.

**Current Approach**: Keep `validate_fa_list_structure()` model-specific. Create `validate_gm_list_structure()` when implementing GM. Refactor to S3 dispatch only if/when clear duplication emerges across 3+ models.

### Step 5: Done!

Core infrastructure (`interpret_generic`, JSON parsing, etc.) requires no changes.

---

# 2. Token Tracking System

## 2.1 Overview

The package implements a **dual-tier token tracking system** to accurately monitor LLM API usage across single and multiple interpretations. This system handles provider-specific behaviors (particularly system prompt caching) and conditionally includes system prompt tokens based on session type.

## 2.2 Two Tracking Tiers

### Tier 1: Cumulative Tracking (chat_session objects)
- **Purpose**: Track total tokens across multiple interpretations
- **Storage**:
  - `chat_session$total_input_tokens`: Cumulative user prompt tokens (excludes system prompt)
  - `chat_session$total_output_tokens`: Cumulative assistant response tokens
  - `chat_session$system_prompt_tokens`: One-time system prompt cost (tracked separately)
- **Updated**: After each `interpret()` call when `chat_session` parameter is provided

### Tier 2: Per-Run Tracking (interpretation results)
- **Purpose**: Report tokens used by individual interpretations
- **Storage**:
  - `results$run_tokens`: List with `input` and `output` fields
  - `results$used_chat_session`: Boolean flag indicating if persistent session was used
- **Extracted**: Per-message from chat object, conditionally including system prompt

## 2.3 The System Prompt Caching Problem

**Issue**: LLM providers cache system prompts to reduce costs. In persistent sessions:
- First call: System prompt tokens counted
- Subsequent calls: System prompt tokens NOT counted (cached)

**Consequence**: Naive delta calculations can produce negative values:
```r
# Without protection:
delta = tokens_after - tokens_before  # May be negative if system prompt was cached!
```

## 2.4 The Solution: chat_local + max(0, delta) Protection

### Problem: Incorrect Token Accumulation (Fixed 2025-11-09)

**Root Cause**: Code created local `chat` clone but never used it. Always called `chat_session$chat` which had full conversation history, causing incorrect token accumulation and negative values.

**Solution**: Introduced `chat_local` variable used consistently throughout `generic_interpret.R`:

```r
# For temporary sessions
chat_local <- chat_session$chat  # Use session's chat

# For persistent sessions (creates clone without previous messages)
chat_local <- chat_session$chat  # Clone for current interpretation only

# All subsequent operations use chat_local:
response <- chat_local$chat(user_prompt, system_prompt)
tokens_after <- chat_local$get_tokens(include_system_prompt = TRUE)
provider <- chat_local$get_provider()
```

### Token Tracking Implementation

```r
# 1. Capture before LLM call (WITH system prompt for delta)
tokens_before <- chat_local$get_tokens(include_system_prompt = TRUE)

# 2. Make LLM call
response <- chat_local$chat(user_prompt, system_prompt)

# 3. Capture after LLM call (WITH system prompt for delta)
tokens_after <- chat_local$get_tokens(include_system_prompt = TRUE)

# 4. Calculate delta with max(0, ...) protection
delta_input <- max(0, tokens_after$input - tokens_before$input)
delta_output <- max(0, tokens_after$output - tokens_before$output)

# 5. Defensive token validation (ensures numeric scalars)
if (is.null(delta_input) || length(delta_input) == 0 || !is.numeric(delta_input)) {
  delta_input <- 0.0
}
if (is.null(delta_output) || length(delta_output) == 0 || !is.numeric(delta_output)) {
  delta_output <- 0.0
}

# 6. Update cumulative counters (only if using persistent chat_session)
if (!is.null(chat_session)) {
  chat_session$total_input_tokens <- chat_session$total_input_tokens + delta_input
  chat_session$total_output_tokens <- chat_session$total_output_tokens + delta_output
}

# 7. Per-run reporting (CONDITIONAL system prompt inclusion)
# - Temporary session: Include system prompt (it's part of THIS run)
# - Persistent session: Exclude system prompt (sent previously)
tokens_per_message <- chat_local$get_tokens(include_system_prompt = is.null(chat_session))

# 8. Fallback if per-message extraction fails
if (run_input_tokens == 0 && delta_input > 0) {
  run_input_tokens <- delta_input
}
if (run_output_tokens == 0 && delta_output > 0) {
  run_output_tokens <- delta_output
}
```

## 2.5 Code Locations

- **base_chat_session.R**: Token tracking initialization, storage, print method
- **generic_interpret.R** (lines 172-260): Full token tracking implementation
  - `chat_local` variable creation
  - Token capture before/after LLM call
  - Delta calculation with `max(0, ...)` protection
  - Defensive validation for NULL/empty values
  - Per-message token extraction with conditional system prompt
  - Fallback to delta if per-message extraction fails
  - Update cumulative counters in chat_session object
- **report_fa.R**: Conditional system prompt display in reports

## 2.6 Expected Behavior

### print(interpretation) - Per-Run Tokens
- **Temporary session**: Includes system prompt + user prompt + assistant response
- **Persistent session**: Excludes system prompt, only user prompt + response

### print(chat_session) - Cumulative Tokens
- **Total Input**: Sum of all user prompts (excludes system prompt)
- **Total Output**: Sum of all assistant responses
- **System Prompt**: One-time cost tracked separately

## 2.7 Provider-Specific Caveats

- **Ollama**: No token tracking support (returns 0)
- **Anthropic**: Caches system prompts aggressively (may undercount input)
- **OpenAI**: Generally accurate token reporting
- **Output tokens**: Typically accurate across all providers

---

# 3. Implementation Details

## 3.1 JSON Parsing Strategy

Multi-tiered fallback for robust LLM response handling:

1. **Try parsing cleaned JSON** (remove extra text, fix formatting)
2. **Fall back to original response**
3. **Pattern-based extraction** if JSON parsing fails (via S3 method `extract_by_pattern.fa()`)
4. **Default values** if all methods fail (via S3 method `create_default_result.fa()`)

**Location**: `R/generic_json_parser.R` and `R/fa_json.R`
**Rationale**: Critical for handling small/local models with imperfect JSON output

## 3.2 System Prompt Architecture

The psychometric expert system prompt is defined in **ONE location**:
- `R/fa_prompt_builder.R` via S3 method `build_system_prompt.fa()`
- Used by both single-use and persistent sessions
- **Single source of truth** - no duplication

## 3.3 Emergency Rule Logic

If a factor has zero loadings above cutoff:
- Uses top `n_emergency` highest absolute loadings instead
- Clearly marked with WARNING in output
- Factor names get "(n.s.)" suffix to indicate non-significant loadings
- Can set `n_emergency = 0` to label as "undefined" instead

**Implementation**: `R/fa_diagnostics.R`

## 3.4 Output Format System

### Supported Formats

| Format | Headings | Emphasis | Line Wrapping |
|--------|----------|----------|---------------|
| **text** | `==== SECTION ====` | Plain text | Yes (via `wrap_text()`) |
| **markdown** | `# Section` | `**bold**`, `*italic*` | No (preserves formatting) |

### Implementation Locations

- **R/fa_interpret.R** (lines 304-314): Validation
- **R/generic_interpret.R** (line 262): Stored in params, passed to `build_report()`
- **R/report_fa.R** (lines 38-639): Massive conditional block branching on format
  - Lines 38-280: Markdown-specific logic (242 lines)
  - Lines 281-476: Text-specific logic (195 lines)
- **R/export_functions.R** (line 110): Converts export format to output_format

### Future Enhancement: CLI Format

A "cli" format could be added using R's `cli` package features:

**Would require changes to**:
1. **R/fa_interpret.R** (Line 307): Update validation to accept "cli"
2. **R/report_fa.R** (Lines 38-639): Add `else if (output_format == "cli")` branch
3. **R/report_fa.R** (Lines 725-801): Update validation and post-processing
4. Tests and documentation

## 3.5 Word Limit Enforcement

Targets 80-100% of `word_limit` parameter:
- System prompt includes explicit word targets
- Post-processing validates and **informs** (via `cli::cli_inform()`) if exceeded
- Helper function `count_words()` in `utils_text_processing.R`
- Changed from warning to message (2025-11-03) to reduce noise

## 3.6 Silent Parameter System

Changed from boolean to integer (2025-11-08) for granular control:

| Value | Behavior |
|-------|----------|
| **0** (or FALSE) | Show report + messages |
| **1** | Show messages only, suppress report |
| **2** (or TRUE) | Completely silent (no report, no messages) |

**Backward Compatibility**:
- `silent = FALSE` → converted to 0
- `silent = TRUE` → converted to 2

**Implementation**: 4 core files (generic_interpret.R, fa_interpret.R, interpret_method_dispatch.R, generic_export.R)

---

# 4. Package History

## 4.1 Major Cleanup (2025-11-07)

Eliminated **~1,559 lines of redundant code** across 3 duplicate R source files.

### Removed Duplicate Files

1. **R/fa_report_functions.R** (804 lines)
   - Redundant with: `R/report_fa.R`
   - Issue: Identical except missing S3 method `build_report.fa_interpretation()`

2. **R/fa_wrapper_methods.R** (556 lines)
   - Redundant with: `R/interpret_methods.R`
   - Issue: Old version of interpret() dispatch system
   - Missing: interpret.chat_session() method and improved validation

3. **R/fa_utilities.R** (165 lines)
   - Redundant with: `R/fa_diagnostics.R`
   - Issue: Subset missing S3 method

### Documentation Cleanup

**Deleted**: dev/STATUS.md (310 lines), dev/FILE_STRUCTURE.md (609 lines)
**Created**: dev/DEVELOPER_GUIDE.md (comprehensive technical reference)
**Updated**: CLAUDE.md (accurate package state)

### Single Source of Truth Established

| Component | Current Location |
|-----------|------------------|
| **System Prompts** | fa_prompt_builder.R (S3 method) |
| **Report Building** | report_fa.R (with S3 method) |
| **Interpret Methods** | interpret_methods.R |
| **Diagnostic Functions** | fa_diagnostics.R (with S3 method) |

## 4.2 Recent Feature Additions & Fixes

### 2025-11-09: Refactoring Phase 1 - API Simplification & Dual Interface

**Completed**: Phase 1 of comprehensive refactoring plan (see dev/REFACTORING_PLAN.md)

**Status**: ✅ Complete | Phase 2 Pending

**Major Changes**:

1. **Config Constructor Functions** (R/config.R - 445 lines)
   - `fa_args()` - Factor analysis parameters (renamed from fa_config)
   - `llm_args()` - LLM interaction parameters (renamed from llm_config)
   - `output_args()` - Output formatting parameters (renamed from output_config)
   - Helper functions: `default_fa_args()`, `default_output_args()`
   - Builder functions: `build_llm_args()`, `build_fa_args()`, `build_output_args()`
   - S3 print methods for all config types
   - Full parameter validation in each constructor
   - Supports both S3 objects and plain lists (hybrid approach)

2. **Function Renaming for Clarity**
   - `interpret_generic()` → `interpret_core()` (reflects actual orchestration role)
   - File renamed: `R/generic_interpret.R` → `R/core_interpret.R`
   - Updated all references in fa_interpret.R, fa_report.R, fa_diagnostics.R
   - Documentation regenerated: interpret_core.Rd

3. **Global Parameter Rename**
   - `model_fit` → `fit_results` across all R files and tests
   - Prevents confusion between statistical model object and LLM model name
   - Updated in all documentation examples and vignettes

4. **New interpret() Dual Interface** (R/interpret_method_dispatch.R)
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
   - Supports both direct args (provider/model) and config objects
   - Builder functions merge direct args with config objects
   - Simplified from 20+ parameters to ~9 top-level parameters

5. **interpret_fa() Internalization**
   - Marked as `@keywords internal` and `@noRd` (not exported to users)
   - Added config extraction logic to convert llm_args/fa_args/output_args to individual params
   - Maintains backward compatibility internally
   - **Phase 2 Note**: Will be removed entirely and logic consolidated into S3 methods

6. **Documentation Updates**
   - Regenerated all .Rd files with roxygen2
   - Updated NAMESPACE (removed interpret_fa export, added config exports)
   - Updated all examples to use new API
   - Added Phase 1 completion documentation to REFACTORING_PLAN.md

**API Examples**:

Simple usage (90% of cases):
```r
interpret(
  fit_results = fa_model,
  variable_info = var_info,
  provider = "ollama",
  model = "gpt-oss:20b"
)
```

Advanced with config objects:
```r
interpret(
  fit_results = fa_model,
  variable_info = var_info,
  llm_args = llm_args(provider = "ollama", model = "gpt-oss:20b", word_limit = 200),
  fa_args = fa_args(cutoff = 0.4),
  output_args = output_args(silent = TRUE)
)
```

**Files Modified**:
- New: `R/config.R` (445 lines)
- Renamed: `R/generic_interpret.R` → `R/core_interpret.R`
- Modified: `R/interpret_method_dispatch.R`, `R/fa_interpret.R`, `R/fa_report.R`, `R/fa_diagnostics.R`
- Updated: All test files (fit_results rename), NAMESPACE, man/*.Rd files

**Validation**:
- ✅ All tests passing
- ✅ Package loads without errors
- ✅ Dual interface works (direct args or config objects)
- ✅ interpret_fa() not exported (internal-only)
- ✅ Documentation builds without errors

**Benefits**:
- Cleaner user-facing API (fewer top-level parameters)
- Better separation of concerns (model-specific vs generic params)
- Dual interface flexibility (simple or advanced usage)
- Foundation for Phase 2 (reverse data flow, S3 generics)
- Hybrid config approach (accept both S3 objects and plain lists)

**Known Limitations**:
- Downstream functions (interpret_core, etc.) still use individual parameters internally
- interpret_fa() still exists as internal function (will be removed in Phase 2)
- Some parameter handling duplication (Phase 2 will consolidate)

**Next**: Phase 2 will remove interpret_fa(), reverse data flow, create S3 generics, and use flat file structure with naming conventions

### 2025-11-09: system_prompt Parameter Implementation
- **Completed TODO**: Synced `system_prompt` parameter across all interpretation functions
- **Added to `interpret_fa()`**: Parameter signature, roxygen documentation, and pass-through to `interpret_generic()`
- **Added to `interpret_generic()`**: Parameter signature, conditional logic to use custom prompt when provided, otherwise builds default
- **Updated `interpret()`**: Now passes `system_prompt` through both call chains (fitted models and structured lists)
- **Implementation**: Uses `final_system_prompt` variable in `interpret_generic()` to distinguish between user-provided and default prompts
- **Documentation**: All three functions now consistently document the parameter with proper defaults (NULL) and usage notes
- **Behavior**: When `system_prompt` is NULL, default model-specific prompt is built; when provided, custom prompt overrides default
- **Note**: Parameter is ignored when `chat_session` is provided, as system prompt is set during session initialization

### 2025-11-09: Color-Blind Friendly Visualizations
- **Added `psychinterpreter_colors()`**: Returns color-blind friendly palettes (diverging blue-orange, sequential, categorical Okabe-Ito)
- **Added `theme_psychinterpreter()`**: Custom ggplot2 theme for publication-ready plots
- **Updated `plot.fa_interpretation()`**: Now uses blue-orange diverging scale (replaces blue-red), applies custom theme
- **Accessibility**: All visualizations now work for deuteranopia, protanopia, tritanopia
- **Reference**: Based on Okabe & Ito (2008) Color Universal Design

### 2025-11-09: Token Tracking Fixes
- **Fix negative token accumulation bug**
  - Root cause: Code created local `chat` clone but never used it
  - Solution: Introduced `chat_local` variable used consistently
  - Result: Token tracking now correctly reads only current interpretation's tokens
- **Fix token tracking test for Ollama**
  - Added defensive code for NULL/numeric(0) token values
  - Updated chat_session initialization to use 0.0 for clarity
  - Enhanced documentation about provider limitations

### 2025-11-08: Parameter Enhancements & Documentation
- **Silent parameter refactor**: Boolean → integer (0, 1, 2) for granular control
- **Parameter reorganization**: Moved system_prompt/interpretation_guidelines to general params
- **_pkgdown.yml improvements**: Added 5 missing functions, created "Chat Session Management" section
- **Fix chat session model_type message**: Only shows when actual mismatch exists
- **Fix silent parameter behavior**: TRUE now correctly converts to 2 (completely silent)

### 2025-11-07: Test Suite Optimization
- **Fixture caching**: Environment-based caching (40x speedup, 97.6% time reduction)
- **LLM testing strategy**: Reduced from 33+ to ~7 LLM calls
- Separated data extraction tests from LLM interpretation tests

### 2025-11-05: Enhanced Parameters
- **hide_low_loadings**: Reduce token usage by hiding non-significant loadings
- **n_emergency = 0**: Allow undefined factors instead of forcing interpretation
- **Emergency rule indicator**: "(n.s.)" suffix on factor names

### 2025-11-04: Token Tracking Fix
- Fixed system prompt token capture for persistent chat sessions
- Added `system_prompt_captured` flag

### 2025-11-03: Major Refactoring
- Dual-tier token tracking system
- `interpret()` generic for psych/lavaan/mirt packages
- Export simplification (txt/md only)
- Three test fixture sets
- Word limit messaging improvement

## 4.3 Code Simplification (2025-11-09)

Systematic refactoring of FA implementation to improve maintainability and reduce duplication.

### Objectives
- Apply DRY (Don't Repeat Yourself) principle
- Separate data preparation from presentation logic
- Remove dead code and redundant validation
- Centralize utility functions

### Phase 1: Utility Function Extraction
**Created 3 utility functions** in `utils_text_processing.R`:

1. **`format_loading(x, digits = 3)`** - Formats loading values with consistent precision
   - Removes leading zeros: `0.456 → ".456"`, `-0.456 → "-.456"`
   - Replaces ~10 lines of inline formatting across 5 files

2. **`normalize_token_count(value)`** - Ensures token values are always valid numeric scalars
   - Handles NULL, NA, numeric(0) edge cases
   - Returns 0.0 for invalid values
   - Critical for Ollama compatibility (no token tracking)

3. **`add_emergency_suffix(name, used_emergency_rule)`** - Adds "(n.s.)" suffix to factor names
   - Centralizes emergency rule indicator logic
   - Replaced 2 duplicate implementations in `fa_json.R`

**Impact**: +60 lines of well-documented utilities, -24 lines of inline code

### Phase 2: Data Structure Refinement
**Streamlined `factor_summaries` structure** from 7 fields to 3 essential fields:

```r
# Before (7 fields):
header, summary, variables, n_loadings, has_significant,
used_emergency_rule, variance_explained

# After (3 fields):
variables, used_emergency_rule, variance_explained
```

**Key Changes**:
- Removed premature formatting (~77 lines) from `fa_interpret.R`
- Created `build_factor_summary_text()` helper in `fa_report.R` (generates formatted text on-demand)
- Updated `fa_prompt_builder.R` to calculate `n_loadings` and `has_significant` from data
- Fixed test checking removed `summary` field

**Impact**: -77 lines, better separation of concerns (data vs presentation)

### Phase 3: Validation & Logic Consolidation

**3.1 Removed Duplicate Validation** (~40 lines from `fa_interpret.R`):
- Silent parameter conversion (logical → integer)
- Chat session validation
- LLM provider requirement check
- All handled by `interpret_generic()` dispatcher

**3.2 Centralized Emergency Rule Logic** (~14 lines from `fa_json.R`):
- Used `add_emergency_suffix()` utility in 2 locations
- Eliminated duplicate conditional logic

**3.3 Dead Code Elimination** (~55 lines from `utils_interpret.R`):
- Removed `validate_interpret_args()` function (never called)
- Verified remaining helpers are actively used:
  - `handle_raw_data_interpret()` ✓
  - `validate_chat_session_for_model_type()` ✓
  - `validate_fa_list_structure()` ✓

**Impact**: -109 lines of duplicate/dead code

### Summary Statistics

| Metric | Value |
|--------|-------|
| **Total Lines Removed** | ~186 lines |
| **Utility Functions Added** | 3 |
| **Data Fields Removed** | 4 (from factor_summaries) |
| **Duplicate Validations Removed** | 3 |
| **Dead Functions Removed** | 1 |
| **Tests Passing** | 172/172 ✓ |

### Benefits Achieved

1. **DRY Principle**: Eliminated duplication in formatting, validation, and emergency rule logic
2. **Separation of Concerns**: Data preparation in `fa_interpret.R`, formatting in `fa_report.R`
3. **Better Maintainability**: Centralized utilities easier to update and test
4. **Leaner Codebase**: ~186 lines removed while improving clarity
5. **Consistent Behavior**: Single source of truth for token normalization, loading formatting, emergency suffixes

### Related Decision: Model-Specific Validation

Decided to keep `validate_fa_list_structure()` model-specific rather than creating generic abstraction (documented in section 1.7, Step 4). Following YAGNI principle and Rule of Three: wait for 2-3 implementations before abstracting.

### Architectural Decision: Dual-Layer chat_session Validation (2025-01-09)

**Decision**: Validate `chat_session` model_type compatibility at **two layers**:
1. **Early validation** in `interpret()` (interpret_method_dispatch.R:295-310)
2. **Safety net validation** in `interpret_generic()` (generic_interpret.R:85-97)

**Rationale**:

**Why Two Layers?**
1. **Multiple Entry Points**: Users can call:
   - `interpret()` → Primary user-facing function
   - `interpret_fa()` → Direct model-specific call
   - `interpret_generic()` → Direct core engine call (exported for advanced use)

2. **Early Failure Benefits** (at `interpret()` layer):
   - Immediate feedback at the main entry point
   - Clear context: "you called interpret() with model_type 'fa' but chat_session has 'gm'"
   - Fails before any routing or processing logic

3. **Safety Net** (at `interpret_generic()` layer):
   - Protects direct calls to `interpret_fa()`, `interpret_gm()`, etc.
   - Ensures validation even if intermediate layers are bypassed
   - Guards against future refactoring errors

**Implementation**:

```r
# Layer 1: interpret() - Early validation for main entry point
if (!is.null(chat_session) && !is.null(model_type) &&
    model_type != chat_session$model_type) {
  cli_abort("chat_session model_type mismatch...")
}

# Layer 2: interpret_generic() - Safety net for all paths
if (!is.null(chat_session) && !is.null(model_type) &&
    model_type != chat_session$model_type) {
  cli_abort("chat_session model_type mismatch...")
}
```

**Execution Paths Protected**:
- Path 1: `interpret()` → (validated) → `interpret_model.fa()` → `interpret_fa()` → (validated) → `interpret_generic()`
- Path 2: `interpret()` → (validated) → `handle_raw_data_interpret()` → `interpret_fa()` → (validated) → `interpret_generic()`
- Path 3: `interpret_fa()` → (validated) → `interpret_generic()`
- Path 4: `interpret_generic()` (validated directly)

**Trade-off**: Slight code duplication (~12 lines × 2) vs. comprehensive protection across all call paths.

**Benefit**: When implementing GM/IRT/CDM, they automatically inherit protection without any validation code needed in model-specific functions.

**Alternative Considered**: Single validation in `interpret_generic()` only.
- **Rejected because**: Would delay error detection until after routing logic, providing less clear error context for the most common usage path (`interpret()`).

## 4.4 FA Implementation Code Review & Refactoring (2025-01-09)

Comprehensive three-sprint refactoring of FA implementation addressing critical issues, validation architecture, parameter consolidation, and report builder modularization.

### Overview

**Scope**: FA model_type usage patterns, validation chains, duplicate calculations, and report generation
**Status**: ✅ All 13/13 items complete (100%)
**Total Impact**: ~295 lines removed, ~475 lines modularized, 7 helper functions added

### Sprint 1: Critical Issues & Foundation (10/13 items)

#### 1.1 Runtime Safety Enhancement

**Issue**: Token tracking vulnerable to provider inconsistencies (Ollama returns 0, Anthropic caches may undercount)

**Solution**: Created `normalize_token_count()` helper in `utils_interpret.R:204-209`
```r
normalize_token_count <- function(x) {
  if (is.na(x) || !is.numeric(x)) return(0L)
  max(0L, as.integer(x))
}
```

**Impact**: Prevents runtime errors from NA/negative token counts across all providers

#### 1.2 Eliminated Duplicate Variance Calculations

**Issue**: `calculate_variance_explained()` computed twice:
- `fa_interpret.R:452` - during interpretation
- `fa_prompt_builder.R:196` - during prompt building

**Solution**:
- Created helper in `utils_interpret.R:223-225`
- Pre-calculate once in `fa_interpret.R`, store in `model_data`
- Reuse from `factor_summaries` in `fa_prompt_builder.R:197`

**Impact**: DRY principle, performance improvement, single source of truth

#### 1.3 Dual-Layer Validation Architecture

**Issue**: chat_session validation inconsistent:
- `fa_interpret.R` had redundant validation
- `interpret_generic()` only showed info message (no abort)
- Missing validation for direct `interpret_fa()` calls

**Solution**: Implemented two-layer validation:
1. **Early Layer** - `interpret()` at `interpret_method_dispatch.R:295-310`
   - Immediate failure at main entry point
   - Clear context for common usage path
2. **Safety Net** - `interpret_generic()` at `generic_interpret.R:85-97`
   - Protects all execution paths including direct model calls
   - Guards future model types (GM, IRT, CDM)

**Protected Paths**:
- `interpret()` → `interpret_model.fa()` → `interpret_fa()` → `interpret_generic()`
- `interpret()` → `handle_raw_data_interpret()` → `interpret_fa()` → `interpret_generic()`
- `interpret_fa()` → `interpret_generic()`
- `interpret_generic()` (direct call)

**Documentation**: See section 4.3 "Architectural Decision: Dual-Layer chat_session Validation"

#### 1.4 S3 Dispatch Simplification

**Issue**: Unnecessary wrapper layer in S3 dispatch
- `interpret_model.psych()` wrapper forwarded to `interpret_model.fa()`/`interpret_model.principal()`
- R's built-in S3 dispatch already handles class inheritance

**Solution**: Removed wrapper (lines 479-487 in `interpret_method_dispatch.R`)

**Impact**: Cleaner 2-layer dispatch instead of 3, leverages R's S3 system

#### 1.5 Removed Deprecated Backward Compatibility

**Files**: `class_chat_session.R:230-290` (-60 lines)
- `chat_fa()` - Deprecated constructor
- `is.chat_fa()` - Deprecated class check
- `reset.chat_fa()` - Deprecated reset method

**Rationale**: Package version 0.0.0.9000 (pre-release), backward compatibility not required during development

#### 1.6 Documentation & Code Clarity

- Removed unused `system_prompt` parameter from `interpret_fa()` signature
- Added clear comments explaining chat cloning rationale (`generic_interpret.R:174-177`)
- Updated NAMESPACE and .Rd files automatically

**Sprint 1 Metrics**: ~225 lines removed, 2 helper functions added, 4 deprecated functions removed

---

### Sprint 2: Parameter Validation Consolidation (2/3 items)

#### 2.1 Centralized Common Parameter Validation

**Issue**: Duplicate validation logic in model-specific functions
- `interpret_fa()` had ~150 lines of validation
- Future models (GM, IRT, CDM) would duplicate same validations

**Solution**: Moved 5 common validations to `interpret_generic()` (lines 145-217):

1. **word_limit** - Range 20-500, single numeric
2. **max_line_length** - Range 40-300, single numeric
3. **output_format** - Must be "cli" or "markdown"
4. **heading_level** - Integer 1-6 for markdown
5. **suppress_heading** - Logical value

**Benefits**:
- -70 lines from `interpret_fa()`
- Automatic inheritance for GM/IRT/CDM implementations
- Single source of truth for common parameters

**Model-Specific Validations Retained in `interpret_fa()`**:
- `cutoff` - FA-specific loading threshold
- `n_emergency` - FA-specific emergency rule
- `hide_low_loadings` - FA-specific filtering
- `sort_loadings` - FA-specific ordering

#### 2.2 Null-Coalescing Standardization

**Issue**: Inconsistent null handling across files
- Some used direct `$` access (fails on NULL)
- Others used `%||%` operator with defaults

**Solution**: Applied `%||%` consistently in `class_interpretation.R:60`
```r
cat("LLM:", x$llm_info$provider %||% "unknown", "/",
    x$llm_info$model %||% "unknown", "\n")
```

**Impact**: Robust null handling, prevents edge case display errors

#### 2.3 Test Fixes

**Fixed 3 test failures** after validation order changes:

1. **test-chat_fa.R:115** - Removed obsolete `chat_fa()` test (deprecated function)
2. **test-chat_fa.R:142** - Wrapped loadings in list structure for `interpret()`
3. **test-interpret_fa.R:27** - Added `llm_provider` parameter (validated before `output_format`)

**Sprint 2 Metrics**: ~70 lines removed, 5 validations centralized, 3 tests fixed

---

### Sprint 3: Report Builder Modularization (1/1 item)

#### 3.1 Extracted Helper Functions from build_fa_report()

**Issue**: Monolithic 726-line function difficult to maintain and test
- Mixed concerns: formatting, logic, and output generation
- Hard to modify individual sections
- Not reusable for future model types

**Solution**: Extracted 5 focused helper functions in `fa_report.R`:

##### 3.1.1 `format_factor_summary()` (80 lines)
```r
format_factor_summary <- function(factor_summary, cutoff, n_emergency)
```
- Formats single factor summary with loadings, variance, variables
- Handles emergency rule warnings
- Returns plain text (format-agnostic)
- **Location**: `fa_report.R:15-94`

##### 3.1.2 `build_report_header()` (95 lines)
```r
build_report_header <- function(interpretation_results, n_factors,
                                 cutoff, output_format, heading_level,
                                 suppress_heading)
```
- Generates report header with title, metadata, LLM info
- Includes token counts when available
- Handles both markdown and CLI formats
- **Location**: `fa_report.R:96-205`

##### 3.1.3 `build_factor_names_section()` (60 lines)
```r
build_factor_names_section <- function(suggested_names, factor_summaries,
                                        output_format, heading_level)
```
- Creates factor names list with variance percentages
- Calculates total variance explained
- Dual-format output (markdown/CLI)
- **Location**: `fa_report.R:207-280`

##### 3.1.4 `build_correlations_section()` (110 lines)
```r
build_correlations_section <- function(factor_cor_mat, output_format,
                                        heading_level)
```
- Builds factor correlation matrix display
- Returns empty string if no correlations (conditional)
- Splits long correlation lists for readability
- **Location**: `fa_report.R:282-389`

##### 3.1.5 `build_diagnostics_section()` (130 lines)
```r
build_diagnostics_section <- function(cross_loadings, no_loadings,
                                       cutoff, output_format, heading_level)
```
- Combines cross-loadings and no-loadings warnings
- Conditional rendering based on diagnostics presence
- Consistent formatting across both diagnostic types
- **Location**: `fa_report.R:391-520`

#### 3.2 Refactored build_fa_report() as Orchestrator

**Before**: 726 lines of inline formatting logic

**After**: ~250 lines orchestrating helper functions
```r
build_fa_report <- function(...) {
  # 1. Header section
  report <- build_report_header(...)

  # 2. Factor names section
  report <- paste0(report, build_factor_names_section(...))

  # 3. Correlations section (conditional)
  report <- paste0(report, build_correlations_section(...))

  # 4. Detailed interpretations (inline - complex correlation logic)
  report <- paste0(report, ...)

  # 5. Diagnostics section
  report <- paste0(report, build_diagnostics_section(...))

  return(report)
}
```

**Note**: Detailed factor interpretations section kept inline due to complex per-factor correlation insertion logic

#### 3.3 Benefits Achieved

1. **Modularity**: Each section independently testable and modifiable
2. **Reusability**: Helper functions ready for GM/IRT/CDM report builders
3. **Maintainability**: Focused functions (~60-130 lines each) vs. monolithic 726 lines
4. **Readability**: Clear separation of concerns with orchestrator pattern
5. **DRY Principle**: No duplicate report building logic
6. **Testability**: Can test header, names, correlations, diagnostics independently

#### 3.4 Testing

**All 13/13 FA interpretation tests pass**:
- Parameter validation tests (no LLM)
- Comprehensive integration test (with LLM, skipped if unavailable)
- Edge case tests (emergency rule, n_emergency=0)

**Sprint 3 Metrics**: ~475 lines modularized into 5 helper functions, 0 regressions

---

### Combined Sprint Metrics

| Metric | Sprint 1 | Sprint 2 | Sprint 3 | Total |
|--------|----------|----------|----------|-------|
| **Items Completed** | 10 | 2 | 1 | 13 |
| **Items Deferred** | 3 | 1 | 0 | 0 |
| **Lines Removed** | ~225 | ~70 | 0 | ~295 |
| **Lines Modularized** | 0 | 0 | ~475 | ~475 |
| **Helper Functions Added** | 2 | 0 | 5 | 7 |
| **Functions Removed** | 4 | 0 | 0 | 4 |
| **Validations Centralized** | 0 | 5 | 0 | 5 |
| **Tests Fixed** | 0 | 3 | 0 | 3 |
| **Files Modified** | 6 | 4 | 1 | 8 unique |

### Architecture Strengths Preserved

These excellent patterns remained unchanged throughout refactoring:

1. **S3 Generic System** - `interpret_generic()` → model-specific methods
   - Now enhanced with dual-layer validation
2. **Multi-tier JSON Parsing** - Clean → parse → pattern → default
   - Robust fallback logic handles edge cases
3. **Prompt Builder Separation** - System vs user prompts
   - S3 dispatch for model-specific prompts
4. **Model Data Structure** - Structured list through pipeline
   - Now with pre-computed values (no duplicate calculations)
5. **Clear Error Messages** - Using `cli` package
   - Actionable, context-rich messages
6. **Explicit Parameter Naming** - No positional dependencies
   - Makes API clear and maintainable

### Best Practices for Future Model Types (GM, IRT, CDM)

**DO:**
- ✅ Implement only model-specific validation in `interpret_<model>()`
- ✅ Pre-compute values once, store in `model_data`
- ✅ Use S3 methods for prompts, parsing, diagnostics, reports
- ✅ Keep functions under 200 lines where possible
- ✅ Leverage dual-layer validation (inherit from `interpret()` and `interpret_generic()`)
- ✅ Reuse report builder helper functions pattern

**DON'T:**
- ❌ Duplicate validation from `interpret_generic()` or `interpret()`
- ❌ Recalculate values in prompt builders (calculate once, reuse)
- ❌ Create unnecessary wrapper methods for S3 dispatch
- ❌ Mix formatting logic between CLI and markdown in single functions
- ❌ Add chat_session validation (automatically inherited)

### Key Architectural Wins

1. **Dual-layer validation** protects all 4 execution paths automatically
2. **Helper functions** eliminate duplication (variance, token normalization, report sections)
3. **Simplified S3 dispatch** (2 layers instead of 3)
4. **Common validation** centralized (benefits all future model types)
5. **Modular report building** enables independent testing and reuse
6. **No deprecated bloat** for future implementations

---

# 5. Development Reference

## 5.1 Code Style Guidelines

### Required
- **Roxygen2 documentation** for all exported functions
- **Explicit namespacing**: Use `package::function()` (e.g., `dplyr::mutate()`)
- **CLI messaging**: Use `cli` package (`cli_alert_info`, `cli_abort`, `cli_inform`)
- **Pipe operator**: Base R `|>` (not magrittr `%>%`)
- **Parameter validation**: Extensive validation with informative errors at function start

### Naming Conventions
- **Files**: `generic_*` (core), `fa_*` (FA-specific), `base_*` (infrastructure), `utils_*` (utilities)
- **Functions**: snake_case
- **S3 methods**: `method.class()` format
- **Internal functions**: Prefix with `.` (e.g., `.internal_helper()`)

## 5.2 Test Development Guidelines

### Test Organization
- One test file per R source file (generally)
- Use descriptive test names with `test_that()`
- Group related tests with `describe()`

### Fixture Management
- Store test fixtures in `tests/testthat/fixtures/`
- Use `.rds` format for R objects
- Document fixture generation in `make-*.R` scripts
- Use fixture caching via `.test_cache` environment for speed

### Minimal LLM Testing
- Test LLM interpretation once per class (FA, GM, IRT, etc.)
- Test S3 methods for data extraction only (no LLM calls)
- Use cached interpretations in print/visualization tests
- Skip LLM tests on CI via `skip_on_ci()`

### Token Efficiency
- Use `minimal_*` fixtures for LLM tests (3 vars × 2 factors)
- Set `word_limit = 20` for LLM tests (minimum allowed)
- Use chat sessions for multiple interpretations in same test

**For detailed testing guidelines**: See [dev/TESTING_GUIDELINES.md](TESTING_GUIDELINES.md)

## 5.3 Common Development Tasks

```r
# Documentation
devtools::document()         # Regenerate .Rd files and NAMESPACE

# Testing
devtools::test()             # Run all tests
testthat::test_file("tests/testthat/test-interpret_fa.R")  # Single file
covr::package_coverage()     # Coverage report

# Checking
devtools::check()            # R CMD check
devtools::install()          # Install locally
devtools::load_all()         # Load for development

# Debugging
interpret_fa(..., echo = "all")  # View LLM prompts/responses
```

## 5.4 Git Commit Guidelines

### Before Committing
```bash
git status
git diff
Rscript -e "devtools::test()"
Rscript -e "devtools::check()"
```

### Commit Message Format
```
Brief summary (50 chars or less)

Detailed explanation:
- Change 1
- Change 2
- Change 3

🤖 Generated with Claude Code
```

## 5.5 Known Limitations

1. **Only FA Implemented**: GM, IRT, CDM models not yet supported
2. **ellmer Dependency**: Requires ellmer package for LLM communication
3. **Token Counting Variability**: Some providers (Ollama) don't report tokens accurately
4. **System Prompt Caching**: Provider-specific behavior may affect token counts

## 5.6 Package Statistics

| Metric | Count |
|--------|-------|
| **Active R Files** | 15 |
| **Archived R Files** | 8 |
| **Total R Code** | ~4,654 lines |
| **Core Infrastructure** | ~1,054 lines (23%) |
| **FA Implementation** | ~3,154 lines (68%) |
| **Utilities** | ~446 lines (9%) |
| **Test Files** | 7 |
| **Total Tests** | 70+ tests |
| **Exported Functions** | 9 |
| **Exported S3 Methods** | 10+ |

---

**Document Version**: 2.0
**Maintainer**: Update when making architectural changes
