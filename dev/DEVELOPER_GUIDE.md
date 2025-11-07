# psychinterpreter Developer Guide

**Last Updated**: 2025-11-07
**Version**: 0.0.0.9000
**Purpose**: Comprehensive technical reference for package maintainers and contributors

---

## Table of Contents

1. [Package Architecture](#1-package-architecture)
2. [Token Tracking System](#2-token-tracking-system)
3. [Output Format System](#3-output-format-system)
4. [Package History](#4-package-history)
5. [Development Workflow](#5-development-workflow)

---

# 1. Package Architecture

## 1.1 Overview

psychinterpreter is a modular R package for LLM-powered interpretation of psychometric analyses. The architecture uses S3 generic dispatch to support multiple model types (FA, GM, IRT, CDM) through a unified interface.

## 1.2 Design Principles

1. **Generic Core + Model-Specific Implementations**
   Core interpretation logic is model-agnostic; model-specific behavior is implemented via S3 methods.

2. **Extensibility**
   Adding new model types requires implementing 7 S3 methods - no changes to core infrastructure.

3. **Token Efficiency**
   Persistent chat sessions reuse system prompts across multiple analyses, reducing token costs by ~40-60%.

4. **Backward Compatibility**
   Legacy `chat_fa()` API maintained via deprecation wrappers.

## 1.3 File Structure

### Core Infrastructure (5 files, ~1,054 lines)

| File | Lines | Purpose |
|------|-------|---------|
| **generic_interpret.R** | 392 | Main interpretation orchestration engine |
| **generic_json_parser.R** | 200 | Multi-tier JSON parsing with S3 dispatch |
| **generic_prompt_builder.R** | 83 | S3 generic system for prompt construction |
| **base_chat_session.R** | 287 | Chat session management (all model types) |
| **base_interpretation.R** | 92 | Base interpretation object infrastructure |

### Factor Analysis Implementation (7 files, ~3,154 lines)

| File | Lines | Purpose |
|------|-------|---------|
| **fa_interpret.R** | 645 | Main user-facing FA interpretation function |
| **fa_prompt_builder.R** | 340 | FA-specific prompt construction (S3 methods) |
| **fa_json.R** | 232 | FA-specific JSON parsing (S3 methods) |
| **fa_diagnostics.R** | 199 | Cross-loadings, no-loadings, diagnostics (S3 method) |
| **interpret_methods.R** | 744 | S3 methods for psych/lavaan/mirt packages |
| **interpret_helpers.R** | 156 | Validation and routing for interpret() dispatch |
| **report_fa.R** | 838 | Report building with S3 method |

### Utilities (3 files, ~446 lines)

| File | Lines | Purpose |
|------|-------|---------|
| **export_functions.R** | 132 | Export to txt/md formats |
| **utils_text_processing.R** | 107 | Text wrapping, word counting |
| **visualization.R** | 207 | S3 plot method, heatmap generation |

### Archive (8 files, not loaded)

Old implementations kept for reference:
- `fa_report_functions.R` - Duplicate of report_fa.R (minus S3 method)
- `fa_wrapper_methods.R` - Old interpret() dispatch (replaced by interpret_methods.R)
- `fa_utilities.R` - Duplicate of fa_diagnostics.R (minus S3 method)
- `fa_chat.R` - Old FA-specific chat (replaced by base_chat_session.R)
- `utils_export.R` - Duplicate of export_functions.R
- `utils.R` - Old utilities (replaced by utils_text_processing.R)
- `interpret_fa.R.old` - Original monolithic implementation
- `interpret_fa.R.backup` - Backup

## 1.4 S3 Method System

The package uses S3 generic dispatch for extensibility. Each model type implements these 7 methods:

### Required S3 Methods per Model Type

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

## 1.5 Interpretation Workflow

```
User calls interpret() or interpret_fa()
        ↓
1. Parameter validation
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
5. Return interpretation object
```

## 1.6 The interpret() Dispatch System

### Four Usage Patterns

#### Pattern 1: Model Object (Automatic Extraction)
```r
interpret(fa_model, variable_info, ...)
```
- S3 methods automatically extract loadings from fitted models
- Supported: `psych::fa`, `psych::principal`, `lavaan::cfa/efa`, `mirt::mirt`

#### Pattern 2: Raw Data with model_type
```r
interpret(loadings, variable_info, model_type = "fa", ...)
```
- For custom data structures or manual loading matrices
- Explicit model_type specification required

#### Pattern 3: Persistent Chat Session (Token-Efficient)
```r
chat <- chat_session(model_type = "fa", provider, model)
interpret(chat, loadings1, var_info1)
interpret(chat, loadings2, var_info2)  # Reuses system prompt!
```
- Saves ~40-60% tokens on repeated analyses
- System prompt sent once, reused for all subsequent calls

#### Pattern 4: Raw Data with chat_session Parameter
```r
interpret(loadings, variable_info, chat_session = chat)
```
- Model type inherited from chat_session
- Alternative syntax for pattern 3

### Dispatch Flow

```
interpret(chat_session=NULL, model_fit=NULL, variable_info=NULL, model_type=NULL, ...)
    ↓
[Plain function with named arguments - no S3 dispatch on position]
    ↓
Validate arguments (all named, no positional confusion):
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

**Key Points:**
- interpret() is now a **plain function**, not S3 generic
- All arguments are **named** (no positional dispatch confusion)
- Internal interpret_model() S3 generic handles fitted model objects
- Supports **structured lists** for model components
- Single validation/routing logic in one place

## 1.7 Key Architecture Decisions

### 1. Flat File Structure (Not Subdirectories)
- All R files in `R/` directory (no `R/core/`, `R/models/fa/`)
- Naming convention indicates organization: `generic_*`, `fa_*`, `base_*`, `utils_*`
- **Rationale**: Simpler for R package structure, easier navigation

### 2. Single Source for Duplicate Behavior
- System prompts: Only in `fa_prompt_builder.R` (not duplicated in `fa_interpret.R`)
- Report building: Only in `report_fa.R` (not duplicated in `fa_report_functions.R`)
- Interpret methods: Only in `interpret_methods.R` (not in `fa_wrapper_methods.R`)
- **Rationale**: DRY principle, single source of truth

### 3. S3 Generics Exported, Methods Not Explicitly Exported
- Export generic: `#' @export` on `interpret()`, `build_report()`, etc.
- Export methods: `#' @export` on individual S3 methods
- **Rationale**: Standard R package practice

### 4. Persistent Chat Sessions Use Environments
- Chat sessions are environments (mutable, reference semantics)
- Token counters update in place without returning new object
- **Rationale**: Natural API for session state management

### 5. Dual-Tier Token Tracking
- **Cumulative**: `chat_session$total_input_tokens`, `chat_session$total_output_tokens`
- **Per-Run**: `interpretation$run_tokens`
- **System Prompt**: Tracked separately in `chat_session$system_prompt_tokens`
- **Rationale**: Handles system prompt caching, prevents negative accumulation

## 1.8 Adding a New Model Type

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

The core infrastructure (`interpret_generic`, JSON parsing, etc.) requires no changes.

## 1.9 Package Statistics

| Metric | Count |
|--------|-------|
| **Active R Files** | 15 |
| **Archived R Files** | 8 |
| **Total R Code** | ~4,654 lines |
| **Core Infrastructure** | ~1,054 lines (23%) |
| **FA Implementation** | ~3,154 lines (68%) |
| **Utilities** | ~446 lines (9%) |
| **Test Files** | 7 |
| **Test Fixtures** | 3 sets (standard, minimal, correlational) |
| **Total Tests** | 70+ tests |
| **Exported Functions** | 9 main functions |
| **Exported S3 Methods** | 10+ methods |

---

# 2. Token Tracking System

## 2.1 Overview

The package implements a **dual-tier token tracking system** to accurately monitor LLM API usage across single and multiple factor analysis interpretations. This system handles provider-specific behaviors, particularly system prompt caching, and conditionally includes system prompt tokens based on session type.

## 2.2 Two Tracking Tiers

### Tier 1: Cumulative Tracking (chat_session objects)
- **Purpose**: Track total tokens across multiple interpretations using a persistent chat session
- **Storage**:
  - `chat_session$total_input_tokens`: Cumulative user prompt tokens (excludes system prompt)
  - `chat_session$total_output_tokens`: Cumulative assistant response tokens
  - `chat_session$system_prompt_tokens`: One-time system prompt cost (tracked separately)
- **Implementation**: Updated after each `interpret()` call when `chat_session` parameter is provided

### Tier 2: Per-Run Tracking (interpretation results)
- **Purpose**: Report tokens used by individual interpretations
- **Storage**:
  - `results$run_tokens`: List with `input` and `output` fields
  - `results$used_chat_session`: Boolean flag indicating if persistent session was used
- **Implementation**: Extracted per-message from the chat object, conditionally including system prompt

## 2.3 The System Prompt Caching Problem

**Issue**: LLM providers (Anthropic, Ollama, Azure, etc.) cache system prompts to reduce costs and latency. In persistent chat sessions:
- First call: System prompt tokens counted
- Subsequent calls: System prompt tokens NOT counted (cached)

**Consequence**: Naive token delta calculations can produce negative values:
```r
# Without protection:
delta = tokens_after - tokens_before  # May be negative if system prompt was cached!
```

## 2.4 The Solution: Conditional Token Extraction + Dual-Method Tracking

### For Cumulative Tracking (prevents negative accumulation)
```r
# Capture before LLM call (WITH system prompt for delta calculation)
tokens_before <- chat$get_tokens(include_system_prompt = TRUE)

# ... make LLM call ...

# Capture after LLM call (WITH system prompt for delta calculation)
tokens_after <- chat$get_tokens(include_system_prompt = TRUE)

# Calculate delta with max(0, ...) protection
delta_input <- max(0, tokens_after$input - tokens_before$input)
delta_output <- max(0, tokens_after$output - tokens_before$output)

# Update cumulative counters (only if using persistent chat_session)
if (!is.null(chat_session)) {
  chat_session$total_input_tokens <- chat_session$total_input_tokens + delta_input
  chat_session$total_output_tokens <- chat_session$total_output_tokens + delta_output
}
```

### For Per-Run Reporting (conditional system prompt inclusion)
```r
# CONDITIONAL: Include system prompt based on session type
# - Temporary session (chat_session = NULL): Include system prompt (it's part of THIS run)
# - Persistent session (chat_session provided): Exclude system prompt (sent previously)
tokens_per_message <- chat$get_tokens(include_system_prompt = is.null(chat_session))

# Get last user message tokens (the prompt just sent)
run_input_tokens <- last_user_message$tokens

# Get last assistant message tokens (the response just received)
run_output_tokens <- last_assistant_message$tokens
```

## 2.5 Fallback Mechanism

If per-message token extraction fails (provider doesn't support it or returns incomplete data):
```r
if (run_input_tokens == 0 && delta_input > 0) {
  run_input_tokens <- delta_input
}
if (run_output_tokens == 0 && delta_output > 0) {
  run_output_tokens <- delta_output
}
```

## 2.6 Code Locations

- **base_chat_session.R**:
  - Token tracking initialization and storage
  - Display token counts in print method

- **fa_interpret.R** (lines 1003-1104):
  - Full token tracking implementation
  - Token capture before/after LLM call
  - Delta calculation with `max(0, ...)` protection
  - Per-message token extraction with conditional system prompt
  - Fallback to delta if per-message extraction fails
  - Update cumulative counters in chat_session object

- **report_fa.R**:
  - Conditional system prompt display in reports

## 2.7 Why This Design?

1. **Prevents negative accumulation**: `max(0, ...)` ensures cumulative counters never decrease
2. **Accurate per-run reporting**: Conditional system prompt inclusion ensures correct per-analysis costs
   - Temporary sessions: System prompt IS part of the run cost → included in run_tokens
   - Persistent sessions: System prompt was sent previously → excluded from run_tokens
3. **Transparent system prompt cost**: Separate `system_prompt_tokens` field shows one-time cost
4. **Robust fallback**: Works even when providers don't support per-message token tracking
5. **Handles caching**: Correctly accounts for cached system prompts across multiple interpretations
6. **Backwards compatible**: Fallback uses `!isTRUE(used_chat_session)` which defaults to TRUE for old results

## 2.8 Expected Output Behavior

### print(interpretation) - Per-Run Tokens
Shows tokens for THIS specific interpretation:
- **Temporary session** (no chat_session): Includes system prompt + user prompt + assistant response
- **Persistent session** (with chat_session): Excludes system prompt, only user prompt + assistant response

### print(chat_session) - Cumulative Tokens
Shows tokens across ALL interpretations in this session:
- **Total tokens - Input**: Sum of all user prompts (excludes system prompt)
- **Total tokens - Output**: Sum of all assistant responses
- **System prompt tokens**: One-time cost of system prompt (tracked separately)

**Example output:**
```
Factor Analysis Chat Session
Provider: anthropic
Model: claude-haiku-4-5-20251001
Created: 2025-11-03 14:32:10
Interpretations run: 3
Total tokens - Input: 1250, Output: 890
System prompt tokens: 487
```

## 2.9 Token Counting Caveats

- **Ollama**: Often returns 0 tokens (no tracking support)
- **Anthropic**: Caches system prompts aggressively; cumulative input tokens may undercount
- **OpenAI**: Generally accurate token reporting
- **Output tokens**: Typically accurate across all providers

Users can check:
- `results$run_tokens` for per-interpretation counts
- `print(interpretation)` to see per-run token display
- `print(chat_session)` for cumulative totals with separate system prompt cost

---

# 3. Output Format System

## 3.1 Overview

The `output_format` parameter controls report generation format throughout the package. Currently supports "text" and "markdown" formats. This section documents the complete implementation across all files.

## 3.2 Supported Formats

### Text Format
- Plain text with ASCII art separators
- Uses `====` for headings
- No special formatting
- Line wrapping via `wrap_text()` for console display

### Markdown Format
- GitHub-flavored markdown
- Uses `#` heading hierarchy
- `**bold**` and `*italic*` emphasis
- Code blocks with ` ``` `
- No line wrapping (preserves markdown formatting)

## 3.3 Core Implementation Locations

### R/fa_interpret.R (645 lines)
**Function:** `interpret_fa()`

**Parameter Definition:**
- Line 53: Documentation
- Line 163: Default parameter: `output_format = "text"`

**Validation (lines 304-314):**
```r
if (!is.character(output_format) ||
    length(output_format) != 1 ||
    !output_format %in% c("text", "markdown")) {
  cli::cli_abort("output_format must be either 'text' or 'markdown'")
}
```

**Usage:**
- Line 625: Passed to `interpret_generic()` function call

### R/generic_interpret.R (392 lines)
**Function:** `interpret_generic()`

**Parameter Definition:**
- Line 14: Documentation
- Line 46: Default parameter: `output_format = "text"`

**Usage:**
- Line 262: Stored in `params` list
- Lines 300-302: Passed to `build_report()` S3 function

### R/report_fa.R (838 lines)

#### Function 1: build_fa_report() (Internal, ~630 lines)

**Parameter Definition:**
- Line 9: Documentation
- Line 19: Default parameter: `output_format = "text"`

**Logic Flow:**
Lines 38-281 contain a massive conditional block that branches on format:
```r
if (output_format == "markdown") {
  # [Lines 38-280: 242 lines of markdown-specific logic]
} else {
  # [Lines 281-476: 195 lines of text-specific logic]
}
```

**Format-Specific Logic Differences:**

| Aspect | Text Format | Markdown Format |
|--------|------------|-----------------|
| Headings | `==== SECTION NAME ====` | `# Section Name` |
| Emphasis | Plain text | `**bold**`, `*italic*` |
| Links | None | Markdown links |
| Code blocks | Indentation | ``` markdown code blocks ``` |
| Lists | Numbered/bullet | Markdown list syntax |
| Line breaks | `\n` | `  \n` (soft breaks) |

**Critical Sections with Format Checks:**
- Lines 38-39: Main format branching (if/else)
- Lines 480, 498, 509: Format checks for cross-loadings section
- Lines 527, 549, 560: Format checks for no-loadings section
- Lines 576-579: Format-specific final spacing
- Lines 584-629: Elapsed time insertion differs by format
- Lines 635-639: Text format specific line break fixes

#### Function 2: print.fa_interpretation() (S3 method, ~120 lines)

**Parameter Definition:**
- Line 654: Documentation
- Line 686: Default parameter: `output_format = NULL`

**Special Behavior:**
- Lines 725-743: Validates output_format ∈ {NULL, "text", "markdown"}
- Lines 763-788: If output_format specified AND factor_summaries exist, regenerates report
- Lines 795-801: Post-processing:
  - Text: Wraps using `wrap_text()` function
  - Markdown: Prints without wrapping to preserve formatting

#### Function 3: build_report.fa_interpretation() (S3 method, ~18 lines)

**Purpose:** Integrates with `build_report()` generic

**Parameter Definition:**
- Line 812: Documentation
- Line 821: Default: `output_format = "text"`

**Implementation:**
- Lines 830-837: Delegates to `build_fa_report()`, passing through all parameters

### R/export_functions.R (132 lines)
**Function:** `export_interpretation()`

**Parameter Conversion:**
- Line 110: Converts export format to output_format:
  ```r
  output_format <- if (format == "txt") "text" else "markdown"
  ```

**Usage:**
- Lines 114-121: Calls `build_fa_report()` with converted output_format

## 3.4 Test Coverage

### tests/testthat/test-interpret_fa.R
**Validation Tests:**
- Tests that invalid output_format values raise errors
- Expects error message: "must be either"

### tests/testthat/test-print_methods.R
**Comprehensive Test Suite (14 tests):**

1. **output_format validation tests** (lines 54-72):
   - Tests invalid values: "invalid", vector c("text", "markdown"), numeric 123
   - Expects error: "must be either 'text' or 'markdown'"

2. **Format regeneration test** (lines 128-137):
   - Regenerates report in markdown format
   - Verifies markdown headers present

3. **Heading level tests** (lines 163-178):
   - Tests heading_level parameter only works with markdown
   - Verifies different heading levels produce different output

4. **Suppress heading tests** (lines 180-193):
   - Tests suppress_heading parameter with markdown output

## 3.5 Documentation Files

All these files document output_format:
- `man/interpret_fa.Rd`
- `man/generic_interpret.Rd`
- `man/print.fa_interpretation.Rd`
- `man/build_report.Rd`
- `man/build_report.fa_interpretation.Rd`
- `man/export_interpretation.Rd`

## 3.6 Future Enhancement: CLI Format

A "cli" format could be added using R's `cli` package features:

### Proposed CLI Format Features
```r
# Headers
cli::rule("Factor Analysis Interpretation")  # Full-width separator
cli::rule("Factor 1: Openness", line = 1)    # Heading style

# Emphasis
cli::cli_text("{.strong Number of factors:} 3")
cli::cli_text("{.emph Openness to Experience}")
cli::cli_text("{.code 0.678}")  # For loadings

# Lists with styling
cli::cli_ul(c(
  "{.strong Factor 1 (33.5%):} {.emph Openness to Experience}",
  "{.strong Factor 2 (25.2%):} {.emph Conscientiousness}"
))
```

### Implementation Requirements for CLI Format

**MUST CHANGE:**
1. **R/fa_interpret.R** (Line 307): Update validation to accept "cli"
2. **R/report_fa.R - build_fa_report()** (Lines 38-639): Add `else if (output_format == "cli")` branch
3. **R/report_fa.R - print.fa_interpretation()** (Lines 725-801): Update validation and post-processing
4. **tests/**: Update validation tests and add CLI format tests

**SHOULD CHANGE:**
- Documentation files to include "cli" as option
- Add examples showing CLI format usage

---

# 4. Package History

## 4.1 Major Cleanup (2025-11-07)

Successfully identified and eliminated **~1,559 lines of redundant code** across 3 duplicate R source files. Reorganized documentation to establish single sources of truth for all components.

### Removed Duplicate Files

1. **R/fa_report_functions.R** (804 lines)
   - **Redundant with**: R/report_fa.R
   - **Issue**: Identical except missing S3 method `build_report.fa_interpretation()`

2. **R/fa_wrapper_methods.R** (556 lines)
   - **Redundant with**: R/interpret_methods.R
   - **Issue**: Old version of interpret() dispatch system
   - **Missing**: interpret.chat_session() method and improved validation logic

3. **R/fa_utilities.R** (165 lines)
   - **Redundant with**: R/fa_diagnostics.R
   - **Issue**: Subset (same functions but missing S3 method)

### Documentation Cleanup

**Deleted Outdated Files:**
1. **dev/STATUS.md** (310 lines)
   - Documented a refactoring to subdirectories that never happened
   - Referenced non-existent files and architecture

2. **dev/FILE_STRUCTURE.md** (609 lines)
   - Mixed accurate and outdated information
   - Redundant with CLAUDE.md

**Created New Documentation:**
- **dev/DEVELOPER_GUIDE.md** (this file) - Comprehensive technical reference

**Updated Documentation:**
- **CLAUDE.md** - Updated with accurate package state

### Single Source of Truth Established

All components now have exactly **one** authoritative definition:

| Component | Previous Locations | Current Location |
|-----------|-------------------|------------------|
| **System Prompts** | interpret_fa.R, chat_fa.R | fa_prompt_builder.R (S3 method) |
| **Report Building** | fa_report_functions.R, report_fa.R | report_fa.R (with S3 method) |
| **Interpret Methods** | fa_wrapper_methods.R, interpret_methods.R | interpret_methods.R |
| **Diagnostic Functions** | fa_utilities.R, fa_diagnostics.R | fa_diagnostics.R (with S3 method) |

### Impact Assessment

**Benefits:**
1. ✓ Code maintainability - No duplicate definitions to synchronize
2. ✓ Reduced confusion - No conflicting function definitions
3. ✓ Package size - 25% reduction in active code
4. ✓ Extensibility - Clear S3 dispatch pattern

**Verification:**
- All exports still valid (same functions, different source files)
- No breaking changes to public API
- Tests reference exported functions, not file locations

## 4.2 Recent Feature Additions

### 2025-11-07: Test Suite Optimization
- **Fixture caching**: Environment-based caching (40x speedup, 97.6% time reduction)
- **LLM testing strategy**: Reduced from 33+ to ~7 LLM calls
- Separated data extraction tests from LLM interpretation tests

### 2025-11-05: Enhanced Parameters
- **hide_low_loadings**: Reduce token usage by hiding non-significant loadings
- **n_emergency = 0**: Allow undefined factors instead of forcing interpretation
- **Emergency rule indicator**: "(n.s.)" suffix on factor names from emergency rule

### 2025-11-04: Token Tracking Fix
- Fixed system prompt token capture for persistent chat sessions
- Added `system_prompt_captured` flag

### 2025-11-03: Major Refactoring
- Dual-tier token tracking system
- `interpret()` generic for psych/lavaan/mirt packages
- Export simplification (txt/md only)
- Three test fixture sets
- Word limit messaging improvement

## 4.3 Archive Contents

R/archive/ now contains 8 files (not loaded by package):
- `fa_report_functions.R` - Duplicate report builder
- `fa_wrapper_methods.R` - Old interpret dispatch
- `fa_utilities.R` - Duplicate diagnostics
- `fa_chat.R` - Old FA-specific chat
- `utils_export.R` - Duplicate export functions
- `utils.R` - Old utilities
- `interpret_fa.R.old` - Original monolithic implementation
- `interpret_fa.R.backup` - Backup

---

# 5. Development Workflow

## 5.1 Common Development Commands

```r
# Documentation
roxygen2::roxygenise()       # Generate docs from roxygen2 comments
devtools::document()         # Alternative

# Testing
devtools::test()             # Run all tests
testthat::test_file("tests/testthat/test-interpret_fa.R")  # Single file

# Checking
devtools::check()            # Run R CMD check
devtools::install()          # Install locally
devtools::load_all()         # Load for development
```

## 5.2 Documentation Regeneration

After modifying roxygen2 comments:

```r
devtools::document()
```

**Expected Result:**
- All .Rd files in man/ regenerated
- NAMESPACE updated with exports

## 5.3 Running Tests

```r
# All tests
devtools::test()

# Single file
testthat::test_file("tests/testthat/test-interpret_fa.R")

# With coverage
covr::package_coverage()
```

**Note:** LLM-requiring tests skip automatically on CI (GitHub Actions)

## 5.4 Full Package Check

```r
devtools::check()
```

**Expected Warnings (acceptable):**
- Missing suggested packages (ellmer, psych, lavaan, mirt) in dev environment
- Undocumented internal functions

**Should NOT See:**
- Errors about missing functions
- Namespace conflicts
- Documentation mismatches

## 5.5 Git Workflow

### Before Committing

```bash
# Check status
git status

# Review changes
git diff

# Run checks
Rscript -e "devtools::test()"
Rscript -e "devtools::check()"
```

### Committing Changes

```bash
# Stage changes
git add -A

# Commit with descriptive message
git commit -m "Brief summary

Detailed explanation:
- Change 1
- Change 2
- Change 3

🤖 Generated with Claude Code"
```

### Commit Message Guidelines

- First line: Brief summary (50 chars or less)
- Blank line
- Detailed explanation
- Use bullet points for multiple changes
- Reference issue numbers if applicable

## 5.6 Debugging Tips

```r
# Enable LLM prompt/response visibility
interpret_fa(..., echo = "all")

# Check token usage
chat <- chat_session(model_type = "fa", provider = "ollama", model = "gpt-oss:20b-cloud")
result <- interpret(chat_session = chat, model_fit = loadings, variable_info = var_info)
print(chat)  # Displays token counts

# Debug JSON parsing
# Set echo = "all" to see raw LLM responses
```

## 5.7 Code Style Guidelines

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

## 5.8 Test Development Guidelines

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
- Use `minimal_*` fixtures for non-LLM tests
- Set `word_limit = 20` for LLM tests (minimum allowed)
- Use chat sessions for multiple interpretations in same test

## 5.9 Known Limitations

1. **Only FA Implemented**: GM, IRT, CDM models not yet supported
2. **ellmer Dependency**: Requires ellmer package for LLM communication
3. **Token Counting Variability**: Some providers (Ollama) don't report tokens accurately
4. **System Prompt Caching**: Provider-specific behavior may affect token counts

## 5.10 Future Enhancements

1. **Additional Model Types**: Implement GM, IRT, CDM interpretation
2. **Custom Prompt System**: User-provided system prompts via parameters
3. **Batch Interpretation**: Interpret multiple models in single LLM call
4. **Caching**: Cache interpretations for identical inputs
5. **Progress Tracking**: Progress bars for long analyses
6. **Silent Parameter Enhancement**: Change to integer (0, 1, 2) for granular control
7. **Summary Method**: Implement for chat_session and interpretations

---

**Document Version**: 1.0
**Maintainer**: Update when making architectural changes
**Source Files**:
- ARCHITECTURE.md
- TOKEN_TRACKING_LOGIC.md
- OUTPUT_FORMAT_ANALYSIS.md
- CLEANUP_SUMMARY_2025-11-07.md
- POST_CLEANUP_STEPS.md
