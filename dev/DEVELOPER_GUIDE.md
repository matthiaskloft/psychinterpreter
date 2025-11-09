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

### Utilities (3 files, ~446 lines)

| File | Lines | Purpose |
|------|-------|---------|
| `export_functions.R` | 132 | Export to txt/md formats |
| `utils_text_processing.R` | 107 | Text wrapping, word counting |
| `visualization.R` | 207 | S3 plot method, heatmap generation |

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
├─ STRUCTURED LIST? (is.list && !is.data.frame && !is_fitted_model)
│       ↓
│   Requires model_type or chat_session
│       ↓
│   validate_fa_list_structure():
│       ├─ Extract loadings (required)
│       ├─ Extract Phi or factor_cor_mat (optional)
│       └─ Warn about unrecognized components
│           ↓
│       handle_raw_data_interpret(extracted$loadings, ...)
│
└─ RAW DATA? (matrix or data.frame)
        ↓
    Requires model_type or chat_session
        ↓
    handle_raw_data_interpret():
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
- Single validation/routing logic in `interpret_helpers.R`

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

### Step 4: Done!

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
