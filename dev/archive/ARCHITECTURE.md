# psychinterpreter Package Architecture

**Last Updated**: 2025-11-07
**Version**: 0.0.0.9000

---

## Overview

psychinterpreter is a modular R package for LLM-powered interpretation of psychometric analyses. The architecture uses S3 generic dispatch to support multiple model types (FA, GM, IRT, CDM) through a unified interface.

## Design Principles

1. **Generic Core + Model-Specific Implementations**
   Core interpretation logic is model-agnostic; model-specific behavior is implemented via S3 methods.

2. **Extensibility**
   Adding new model types requires implementing 7 S3 methods - no changes to core infrastructure.

3. **Token Efficiency**
   Persistent chat sessions reuse system prompts across multiple analyses, reducing token costs by ~40-60%.

4. **Backward Compatibility**
   Legacy `chat_fa()` API maintained via deprecation wrappers.

---

## File Structure

### Core Infrastructure (5 files)

| File | Lines | Purpose |
|------|-------|---------|
| **generic_interpret.R** | 392 | Main interpretation orchestration engine |
| **generic_json_parser.R** | 200 | Multi-tier JSON parsing with S3 dispatch |
| **generic_prompt_builder.R** | 83 | S3 generic system for prompt construction |
| **base_chat_session.R** | 287 | Chat session management (all model types) |
| **base_interpretation.R** | 92 | Base interpretation object infrastructure |

**Total Core**: 1,054 lines

### Factor Analysis Implementation (7 files)

| File | Lines | Purpose |
|------|-------|---------|
| **fa_interpret.R** | 645 | Main user-facing FA interpretation function |
| **fa_prompt_builder.R** | 340 | FA-specific prompt construction (S3 methods) |
| **fa_json.R** | 232 | FA-specific JSON parsing (S3 methods) |
| **fa_diagnostics.R** | 199 | Cross-loadings, no-loadings, diagnostics (S3 method) |
| **interpret_methods.R** | 744 | S3 methods for psych/lavaan/mirt packages |
| **interpret_helpers.R** | 156 | Validation and routing for interpret() dispatch |
| **report_fa.R** | 838 | Report building with S3 method |

**Total FA**: 3,154 lines

### Utilities (3 files)

| File | Lines | Purpose |
|------|-------|---------|
| **export_functions.R** | 132 | Export to txt/md formats |
| **utils_text_processing.R** | 107 | Text wrapping, word counting |
| **visualization.R** | 207 | S3 plot method, heatmap generation |

**Total Utilities**: 446 lines

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

---

## S3 Method System

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

**Factor Analysis (FA)**: All 7 methods implemented ✓
**Gaussian Mixture (GM)**: Not implemented
**Item Response Theory (IRT)**: Not implemented
**Cognitive Diagnosis Models (CDM)**: Not implemented

---

## Interpretation Workflow

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

---

## The interpret() Dispatch System

### Four Usage Patterns

#### 1. Model Object (Automatic Extraction)
```r
interpret(fa_model, variable_info, ...)
```
- S3 methods automatically extract loadings from fitted models
- Supported: `psych::fa`, `psych::principal`, `lavaan::cfa/efa`, `mirt::mirt`

#### 2. Raw Data with model_type
```r
interpret(loadings, variable_info, model_type = "fa", ...)
```
- For custom data structures or manual loading matrices
- Explicit model_type specification required

#### 3. Persistent Chat Session (Token-Efficient)
```r
chat <- chat_session(model_type = "fa", provider, model)
interpret(chat, loadings1, var_info1)
interpret(chat, loadings2, var_info2)  # Reuses system prompt!
```
- Saves ~40-60% tokens on repeated analyses
- System prompt sent once, reused for all subsequent calls

#### 4. Raw Data with chat_session Parameter
```r
interpret(loadings, variable_info, chat_session = chat)
```
- Model type inherited from chat_session
- Alternative syntax for pattern 3

### Dispatch Flow

```
interpret(chat_session=NULL, fit_results=NULL, variable_info=NULL, model_type=NULL, ...)
    ↓
[Plain function with named arguments - no S3 dispatch on position]
    ↓
Validate arguments (all named, no positional confusion):
    ├─ Check fit_results provided
    ├─ Check variable_info provided
    ├─ Validate chat_session if provided
    └─ Determine effective_model_type (from chat_session or model_type parameter)
    ↓
Detect fit_results type:
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

**Key Changes from Previous Architecture:**
- interpret() is now a **plain function**, not S3 generic
- All arguments are **named** (no positional dispatch confusion)
- Internal interpret_model() S3 generic handles fitted model objects
- Supports **structured lists** for model components
- Single validation/routing logic in one place

---

## Key Architecture Decisions

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

---

## Adding a New Model Type

Example: Adding Gaussian Mixture (GM) support

### 1. Create Model-Specific Files

```
R/gm_interpret.R        - Main user-facing function interpret_gm()
R/gm_prompt_builder.R   - S3 methods: build_system_prompt.gm(), build_main_prompt.gm()
R/gm_json.R             - S3 methods: validate_parsed_result.gm(), etc.
R/gm_diagnostics.R      - S3 method: create_diagnostics.gm()
R/report_gm.R           - S3 method: build_report.gm_interpretation()
```

### 2. Implement 7 Required S3 Methods

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

### 3. Update handle_raw_data_interpret()

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

### 4. Done!

The core infrastructure (`interpret_generic`, JSON parsing, etc.) requires no changes.

---

## Package Statistics

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

## Documentation Files

| File | Purpose |
|------|---------|
| **CLAUDE.md** | Claude Code instructions (user-facing workflows) |
| **dev/ARCHITECTURE.md** | This file (technical architecture) |
| **dev/TOKEN_TRACKING_LOGIC.md** | Token tracking implementation details |
| **README.md** | User-facing package introduction |
| **NEWS.md** | Changelog |

---

## Known Limitations

1. **Only FA Implemented**: GM, IRT, CDM models not yet supported
2. **ellmer Dependency**: Requires ellmer package for LLM communication
3. **Token Counting Variability**: Some providers (Ollama) don't report tokens accurately
4. **System Prompt Caching**: Provider-specific behavior may affect token counts

---

## Future Enhancements

1. **Additional Model Types**: Implement GM, IRT, CDM interpretation
2. **Custom Prompt System**: User-provided system prompts via parameters
3. **Batch Interpretation**: Interpret multiple models in single LLM call
4. **Caching**: Cache interpretations for identical inputs
5. **Progress Tracking**: Progress bars for long analyses

---

**Document Version**: 1.0
**Maintainer**: Update when making architectural changes
