# psychinterpreter Developer Guide

**Last Updated**: 2025-11-11
**Version**: 0.0.0.9000
**Purpose**: Technical reference for package maintainers and contributors

**For usage/user-facing documentation**: See [CLAUDE.md](../CLAUDE.md)

---

## Table of Contents

1. [Package Architecture](#1-package-architecture)
2. [Token Tracking System](#2-token-tracking-system)
3. [Implementation Details](#3-implementation-details)
4. [Development Reference](#4-development-reference)

---

## Glossary

### Key Terminology

**Model Type**
- String identifier used internally to route to appropriate S3 methods
- Valid values: `"fa"`, `"gm"`, `"irt"`, `"cdm"`
- Examples: `model_type = "fa"`, `interpretation_args(model_type = "fa")`
- Used in: Function parameters, configuration objects, S3 method dispatch

**Model Class**
- R object class of fitted model objects from external packages
- Examples: `"fa"` (psych), `"psych"` (psych), `"principal"` (psych), `"lavaan"` (lavaan), `"SingleGroupClass"` (mirt), `"Mclust"` (mclust)
- Used in: S3 method dispatch for `build_model_data.{class}()`
- Note: Multiple model classes can map to the same model type (e.g., psych, lavaan, mirt all map to "fa")

**Interpretation Args**
- Configuration object created by `interpretation_args(model_type, ...)`
- Contains model-specific settings (e.g., cutoff, n_emergency for FA)
- Replaces deprecated `fa_args()` from Phase 3 refactoring

**Core Methods**
- The 8 required S3 methods that every model type must implement
- Essential for interpretation workflow to function
- See section 1.3 for complete list

**Optional Methods**
- Additional S3 methods that enhance functionality but aren't required
- Currently: `export_interpretation()` and `plot()`
- Recommended to implement for complete feature parity

---

# 1. Package Architecture

## 1.1 Design Principles

1. **Generic Core + Model-Specific Implementations**
   - Core interpretation logic is model-agnostic
   - Model-specific behavior via S3 methods

2. **Extensibility**
   - Adding new model types requires 8 S3 methods
   - No changes to core infrastructure needed

3. **Token Efficiency**
   - Persistent chat sessions reuse system prompts (~40-60% savings)
   - Conditional token tracking accounts for system prompt caching

4. **Backward Compatibility**
   - Legacy APIs maintained via deprecation wrappers
   - Boolean silent converted to integer (FALSE→0, TRUE→2)

## 1.2 File Structure

All R files are organized in a **flat `R/` directory** (no subdirectories) following a **prefix-first naming convention**. This structure simplifies R package development while making the abstraction hierarchy immediately clear.

**Naming Pattern**: `{prefix}_{description}.R` where prefix indicates the file's role:
- `core_*` = Core infrastructure
- `s3_*` = S3 generic definitions (interfaces)
- `class_*` = S3 class definitions
- `{model}_*` = Model-specific implementations (e.g., `fa_*`)
- `shared_*` = Shared utilities (regular functions, not S3)

**See section 4.1 "Naming Conventions"** for detailed explanation of prefix meanings and distinctions.

---

### Core Infrastructure (4 files)

| File | Lines | Purpose |
|------|-------|---------|
| `core_constants.R` | ~30 | Package constants (`VALID_MODEL_TYPES`) and `validate_model_type()` |
| `core_interpret_dispatch.R` | ~760 | Main `interpret()` generic + routing to model-specific methods |
| `core_interpret.R` | ~550 | Universal `interpret_core()` orchestrator (all model types) |
| *(archive/)* | - | Legacy files (deprecated code) |

### S3 Generic Definitions (4 files)

**Purpose**: Define the interface that model-specific methods must implement

| File | Lines | Purpose |
|------|-------|---------|
| `s3_model_data.R` | ~60 | Generic: `build_model_data()` for extracting model data |
| `s3_prompt_builder.R` | ~83 | Generics: `build_system_prompt()`, `build_main_prompt()` |
| `s3_json_parser.R` | ~200 | Generics: `validate_parsed_result()`, `extract_by_pattern()`, `create_default_result()` |
| `s3_export.R` | ~132 | Generic: `build_report()` for report generation |

### Class Definitions (2 files)

| File | Lines | Purpose |
|------|-------|---------|
| `class_chat_session.R` | ~287 | `chat_session` class (constructors, validators, print); uses environments for mutable state |
| `class_interpretation.R` | ~92 | Base `interpretation` class infrastructure |

### Shared Utilities (4 files)

**Purpose**: Regular utility functions used by all model types (not S3 methods)

| File | Lines | Purpose |
|------|-------|---------|
| `shared_config.R` | ~580 | Config constructors: `llm_args()`, `interpretation_args()`, `output_args()`, builders |
| `shared_visualization.R` | ~250 | `psychinterpreter_colors()`, `theme_psychinterpreter()` (color palettes and ggplot2 theme) |
| `shared_utils.R` | ~156 | Validation, routing, helper functions |
| `shared_text.R` | ~107 | Text wrapping, word counting utilities |

### Factor Analysis Implementation (7 files, 10 methods)

**Purpose**: FA-specific S3 method implementations

**Core Methods (8 required)**:
| File | Lines | Purpose |
|------|-------|---------|
| `fa_model_data.R` | ~627 | S3 methods: `build_model_data.{fa,psych,principal,lavaan,SingleGroupClass}` |
| `fa_prompt_builder.R` | ~356 | S3 methods: `build_system_prompt.fa()`, `build_main_prompt.fa()` |
| `fa_json.R` | ~225 | S3 methods: `validate_parsed_result.fa()`, `extract_by_pattern.fa()`, `create_default_result.fa()` |
| `fa_diagnostics.R` | ~197 | S3 method: `create_diagnostics.fa()` with `find_cross_loadings()`, `find_no_loadings()` |
| `fa_report.R` | ~1084 | S3 method: `build_report.fa_interpretation()` with modular section builders |

**Additional Methods (2 optional but recommended)**:
| File | Lines | Purpose |
|------|-------|---------|
| `fa_export.R` | ~136 | S3 method: `export_interpretation.fa_interpretation()` with format conversion |
| `fa_visualization.R` | ~266 | S3 method: `plot.fa_interpretation()`, `create_factor_plot()` wrapper |

### Future Model Types (Planned)

**Gaussian Mixture (GM)**: Not implemented
- `gm_model_data.R`, `gm_prompts.R`, `gm_json.R`, `gm_diagnostics.R`, `gm_report.R`, `gm_visualization.R`

**Item Response Theory (IRT)**: Not implemented
- `irt_model_data.R`, `irt_prompts.R`, `irt_json.R`, `irt_diagnostics.R`, `irt_report.R`, `irt_visualization.R`

**Cognitive Diagnosis Models (CDM)**: Not implemented
- `cdm_model_data.R`, `cdm_prompts.R`, `cdm_json.R`, `cdm_diagnostics.R`, `cdm_report.R`, `cdm_visualization.R`

**Implementation Note**: Extensibility infrastructure already in place with commented placeholders. See `dev/templates/` and `dev/MODEL_IMPLEMENTATION_GUIDE.md` for implementation instructions.

## 1.3 S3 Method System

Each S3 generic is exported with `#' @export`, and individual S3 methods are also exported with `#' @export` following standard R package practices.

### Required S3 Methods per Model Type

Each model type (FA, GM, IRT, CDM) must implement these 8 methods:

1. **`build_model_data.{class}()`** - Extract & validate model data from fitted objects
2. **`build_system_prompt.{model}()`** - Constructs expert system prompt
3. **`build_main_prompt.{model}()`** - Constructs user prompt with data
4. **`validate_parsed_result.{model}()`** - Validates LLM JSON response
5. **`extract_by_pattern.{model}()`** - Pattern-based extraction fallback
6. **`create_default_result.{model}()`** - Default results if parsing fails
7. **`create_diagnostics.{model}()`** - Model-specific diagnostics
8. **`build_report.{model}_interpretation()`** - Report generation

### Current Implementations

- **Factor Analysis (FA)**: All 8 methods implemented ✓
- **Gaussian Mixture (GM)**: Not implemented
- **Item Response Theory (IRT)**: Not implemented
- **Cognitive Diagnosis Models (CDM)**: Not implemented

## 1.4 Interpretation Workflow

The `interpret()` function is implemented as a **plain function with named arguments**, not an S3 generic. This design prevents positional dispatch confusion and provides clear parameter validation. Internally, it uses S3 dispatch via `interpret_model()` methods for fitted model objects.

```
User calls interpret(fit_results, variable_info, ...)
        ↓
1. Parameter validation & config building
   - Build llm_args, interpretation_args, output_args from parameters
   - Validate required parameters
        ↓
2. Route to interpret_model.{class}() OR interpret_core() directly
   - If fitted model: S3 dispatch on fit_results class
   - If structured list: validate and extract components
        ↓
3. interpret_core(fit_results, ...) [universal orchestrator]
        ↓
   STEP 0: build_model_data.{class}(fit_results, ...) → Extract & validate model data
        ↓
   STEP 1: Validate inputs
        ↓
   STEP 2: build_system_prompt.{model}() → System prompt (S3 dispatch)
        ↓
   STEP 3: Initialize or use existing chat session
        ↓
   STEP 4: build_main_prompt.{model}() → User prompt with data (S3 dispatch)
        ↓
   STEP 5: LLM API call (via ellmer) → Get JSON response
        ↓
   STEP 6: parse_llm_response.{model}() → Parse JSON (S3 dispatch)
      - validate_parsed_result.{model}()
      - extract_by_pattern.{model}() [if JSON parsing fails]
      - create_default_result.{model}() [ultimate fallback]
        ↓
   STEP 7: Update token tracking
        ↓
   STEP 8: create_diagnostics.{model}() → Cross-loadings, etc. (S3 dispatch)
        ↓
   STEP 9: Assemble interpretation object
        ↓
   STEP 10: build_report.{model}_interpretation() → Generate report (S3 dispatch)
        ↓
   STEP 11: Print report (unless silent)
        ↓
4. Return interpretation object with token tracking
```

## 1.5 Adding a New Model Type

Complete templates and implementation guide are available:
- **📖 Implementation Guide**: `dev/MODEL_IMPLEMENTATION_GUIDE.md` - Comprehensive step-by-step guide
- **📝 Code Templates**: `dev/templates/` - Ready-to-use templates for all 8 required S3 methods
- **✅ Implementation Checklist**: `dev/templates/IMPLEMENTATION_CHECKLIST.md` - Track your progress

**Quick Start**: Copy templates from `dev/templates/`, replace placeholders, implement model-specific logic. See templates README for details.

---

Example: Adding Gaussian Mixture (GM) support

### Step 1: Create Model-Specific Files

```
R/gm_model_data.R       - S3 method: build_model_data.gm() for extracting GM data
R/gm_prompt_builder.R   - S3 methods: build_system_prompt.gm(), build_main_prompt.gm()
R/gm_json.R             - S3 methods: validate_parsed_result.gm(), extract_by_pattern.gm(), create_default_result.gm()
R/gm_diagnostics.R      - S3 method: create_diagnostics.gm()
R/gm_report.R           - S3 method: build_report.gm_interpretation()
```

**Note**: No need for `gm_interpret.R` - all interpretations route through `interpret_core()`

### Step 2: Implement build_model_data.gm() S3 Method

```r
#' @export
build_model_data.gm <- function(fit_results, variable_info, model_type = NULL,
                                 gm_args = NULL, ...) {
  # Extract GM-specific parameters
  dots <- list(...)

  # Extract from fit_results (could be a mclust object, list, etc.)
  means <- extract_means(fit_results)
  covariances <- extract_covariances(fit_results)
  probabilities <- extract_probabilities(fit_results)

  # Build and return standardized model_data structure
  list(
    means = means,
    covariances = covariances,
    probabilities = probabilities,
    n_clusters = ncol(means),
    model_type = "gm",
    # ... other GM-specific fields
  )
}
```

### Step 3: Implement Remaining 7 Required S3 Methods

```r
#' @export
build_system_prompt.gm <- function(model_type, model_data, variable_info, ...) {
  "You are an expert in Gaussian Mixture modeling..."
}

#' @export
build_main_prompt.gm <- function(model_type, model_data, variable_info, ...) {
  # Format cluster parameters, covariance matrices, etc.
  # Use model_data$means, model_data$covariances, etc.
}

#' @export
validate_parsed_result.gm <- function(parsed_result, model_data, ...) {
  # Validate GM-specific response structure
}

#' @export
extract_by_pattern.gm <- function(response, model_data, ...) {
  # Pattern-based extraction fallback for GM
}

#' @export
create_default_result.gm <- function(model_data, ...) {
  # Default result structure for GM
}

#' @export
create_diagnostics.gm <- function(model_type, model_data, variable_info, ...) {
  # GM-specific diagnostics (cluster overlap, separation, etc.)
}

#' @export
build_report.gm_interpretation <- function(interpretation, ...) {
  # Format GM interpretation report
}
```

### Step 4: Update handle_raw_data_interpret() (if using structured lists)

```r
# In utils_interpret.R
handle_raw_data_interpret <- function(x, variable_info, model_type, chat_session,
                                      llm_args = NULL, gm_args = NULL, ...) {
  effective_model_type <- if (!is.null(chat_session)) {
    chat_session$model_type
  } else {
    model_type
  }

  switch(effective_model_type,
    fa = {
      # ... existing FA code
    },
    gm = {  # ADD THIS
      # Call interpret_core with structured list
      interpret_core(
        fit_results = list(
          means = x,  # Or whatever structure makes sense
          ...
        ),
        variable_info = variable_info,
        model_type = "gm",
        chat_session = chat_session,
        llm_args = llm_args,
        gm_args = gm_args,  # Note: create gm_args() config function
        ...
      )
    },
    irt = cli::cli_abort("Not yet implemented"),
    cdm = cli::cli_abort("Not yet implemented")
  )
}
```

### Step 5: Create GM Config Constructor (Optional but Recommended)

```r
# In R/shared_config.R
#' @export
gm_args <- function(n_clusters = NULL,
                    covariance_type = c("full", "diagonal", "spherical"),
                    ...) {
  # Validate and build GM-specific config
  structure(
    list(
      n_clusters = n_clusters,
      covariance_type = match.arg(covariance_type),
      ...
    ),
    class = c("gm_args", "list")
  )
}
```

### Step 6: Add interpret_model.{class}() Methods (Optional)

If your model type has specific fitted model classes (like mclust for GM):

```r
# In R/core_interpret_dispatch.R
#' @export
interpret_model.Mclust <- function(model, variable_info, ...) {
  validate_chat_session_for_model_type(chat_session, "gm")

  result <- interpret_core(
    fit_results = model,
    variable_info = variable_info,
    model_type = "gm",
    ...
  )

  stopifnot(inherits(result, "gm_interpretation"))
  return(result)
}
```

### Step 7: Done!

Core infrastructure (`interpret_core()`, JSON parsing, token tracking) requires no changes. The S3 dispatch system automatically handles your new model type through the generic methods you implemented.

**For detailed implementation**: See `dev/MODEL_IMPLEMENTATION_GUIDE.md` for:
- Complete code templates with placeholders
- Model-specific customization points
- Testing strategies and fixture patterns
- Common pitfalls and troubleshooting
- Estimated time: 32-50 hours for full implementation

---

# 2. Token Tracking System

## 2.1 Overview

The package implements a **dual-tier token tracking system** to accurately monitor LLM API usage. This architecture separates cumulative session-level totals from individual interpretation costs, while tracking system prompts separately. This design handles system prompt caching behavior and prevents negative token accumulation from provider inconsistencies.

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

## 2.4 The Solution: chat_local + normalize_token_count() Helper

The implementation uses a `chat_local` variable consistently throughout `core_interpret.R` to properly isolate token tracking for each interpretation:

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

# 4. Calculate delta with normalize_token_count() helper
# Normalizes to non-negative numeric scalars, handling NULL/NA/empty values
delta_input <- normalize_token_count(tokens_after$input - tokens_before$input)
delta_output <- normalize_token_count(tokens_after$output - tokens_before$output)

# 5. Update cumulative counters (only if using persistent chat_session)
if (!is.null(chat_session)) {
  chat_session$total_input_tokens <- chat_session$total_input_tokens + delta_input
  chat_session$total_output_tokens <- chat_session$total_output_tokens + delta_output
}

# 6. Per-run reporting (CONDITIONAL system prompt inclusion)
# - Temporary session: Include system prompt (it's part of THIS run)
# - Persistent session: Exclude system prompt (sent previously)
tokens_per_message <- chat_local$get_tokens(include_system_prompt = is.null(chat_session))

# 7. Fallback if per-message extraction fails
if (run_input_tokens == 0 && delta_input > 0) {
  run_input_tokens <- delta_input
}
if (run_output_tokens == 0 && delta_output > 0) {
  run_output_tokens <- delta_output
}
```

## 2.5 Code Locations

- **class_chat_session.R**: Token tracking initialization, storage, print method
- **core_interpret.R** (lines 172-260): Full token tracking implementation
  - `chat_local` variable creation
  - Token capture before/after LLM call
  - Delta calculation with `normalize_token_count()` helper
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

**Location**: `R/s3_parsing.R` (generics) and `R/fa_json.R` (FA implementation)
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

- **R/shared_config.R**: Validation in `output_args()` constructor
- **R/core_interpret.R**: Stored in params, passed to `build_report()`
- **R/fa_report.R** (lines 38-639): Conditional logic branching on format
  - Markdown-specific logic
  - Text-specific logic
- **R/s3_export.R**: Converts export format to output_format

### Future Enhancement: CLI Format

A "cli" format could be added using R's `cli` package features. This would require updating validation logic, adding format-specific rendering in `R/report_fa.R`, and corresponding tests and documentation.

## 3.5 Word Limit Enforcement

Targets 80-100% of `word_limit` parameter:
- System prompt includes explicit word targets
- Post-processing validates and **informs** (via `cli::cli_inform()`) if exceeded
- Helper function `count_words()` in `utils_text_processing.R`

## 3.6 Silent Parameter System

The silent parameter uses integer values for granular control:

| Value | Behavior |
|-------|----------|
| **0** (or FALSE) | Show report + messages |
| **1** | Show messages only, suppress report |
| **2** (or TRUE) | Completely silent (no report, no messages) |

**Backward Compatibility**:
- `silent = FALSE` → converted to 0
- `silent = TRUE` → converted to 2

**Implementation**: 3 core files (core_interpret.R, core_interpret_dispatch.R, s3_export.R)

---

# 4. Development Reference

## 4.1 Code Style Guidelines

### Required
- **Roxygen2 documentation** for all exported functions
- **Explicit namespacing**: Use `package::function()` (e.g., `dplyr::mutate()`)
- **CLI messaging**: Use `cli` package (`cli_alert_info`, `cli_abort`, `cli_inform`)
- **Pipe operator**: Base R `|>` (not magrittr `%>%`)
- **Parameter validation**: Extensive validation with informative errors at function start

### Naming Conventions

#### File Naming Scheme

**Format**: `{prefix}_{description}.R`

All R files in the package follow a **prefix-first naming convention** to clearly indicate their purpose and abstraction level. This makes the codebase easier to navigate and establishes clear patterns for future extensions.

**Prefix Categories**:

| Prefix | Purpose | Contains | Example Files |
|--------|---------|----------|---------------|
| `core_` | Core infrastructure | Package orchestration, dispatch, constants | `core_interpret.R`, `core_interpret_dispatch.R`, `core_constants.R` |
| `s3_` | S3 generic definitions | Generic function declarations (define the interface) | `s3_model_data.R`, `s3_prompt_builder.R`, `s3_json_parser.R` |
| `class_` | S3 class definitions | Constructors, validators, print methods | `class_chat_session.R`, `class_interpretation.R` |
| `{model}_` | Model-specific implementations | S3 methods for specific model types | `fa_model_data.R`, `fa_prompt_builder.R`, `fa_json.R` |
| `shared_` | Shared utilities | Utility functions used across all models (NO S3) | `shared_config.R`, `shared_visualization.R`, `shared_utils.R` |

**Important Distinctions**:

- **`s3_*.R`** files contain S3 **generic** function declarations
  - Example: `s3_prompt_builder.R` defines `build_system_prompt()` generic
  - These define the **interface** that model-specific methods must implement

- **`{model}_*.R`** files contain S3 **method** implementations
  - Example: `fa_prompt_builder.R` implements `build_system_prompt.fa()`
  - These provide **model-specific behavior** for the generics

- **`shared_*.R`** files contain regular **utility** functions (NOT S3)
  - Example: `shared_visualization.R` provides `psychinterpreter_colors()`, `theme_psychinterpreter()`
  - These are plain functions used by all model types, NOT S3 methods
  - Do not confuse with `s3_*` files which define generics

**Examples**:

```r
✅ CORRECT:
core_constants.R              # Package constants (VALID_MODEL_TYPES)
s3_prompt_builder.R           # Defines build_system_prompt() generic
fa_prompt_builder.R           # Implements build_system_prompt.fa()
shared_visualization.R        # psychinterpreter_colors() utility function
class_chat_session.R          # chat_session class definition

❌ INCORRECT:
constants.R                   # Missing prefix (unclear category)
generic_export.R              # Use s3_export.R (consistent naming)
fa_utilities.R                # Use fa_utils.R (matches shared_utils.R pattern)
utils.R                       # Too vague - use shared_utils.R or specific prefix
helpers.R                     # Too vague - use appropriate prefix
```

**Rationale**:
- Consistent prefixing improves scanability when navigating `R/` directory
- Clear abstraction levels (core vs model-specific vs shared vs S3 definitions)
- Scales well for multiple model types (GM, IRT, CDM)
- Follows established R package patterns while maintaining clarity

**For detailed implementation plan**: See `dev/FILE_NAMING_ANALYSIS.md` and `dev/RENAME_IMPLEMENTATION_PLAN.md`

#### Function and Variable Naming

- **Functions**: snake_case (e.g., `build_model_data()`, `psychinterpreter_colors()`)
- **S3 methods**: `method.class()` format (e.g., `build_system_prompt.fa()`, `plot.fa_interpretation()`)
- **S3 generics**: snake_case (e.g., `build_system_prompt()`, `create_diagnostics()`)
- **Internal functions**: Prefix with `.` (e.g., `.internal_helper()`, `.validate_structure()`)
- **Variables**: snake_case (e.g., `model_data`, `factor_summaries`, `n_factors`)

## 4.2 Test Development Guidelines

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

## 4.3 Common Development Tasks

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
interpret(..., echo = "all")  # View LLM prompts/responses

# Implementing New Model Types
# 1. Read the implementation guide
# 2. Copy templates from dev/templates/
# 3. Replace placeholders with your model specifics
# 4. Implement model-specific logic (marked with TODO)
# 5. Follow implementation checklist for progress tracking
```

**See Also**:
- `dev/MODEL_IMPLEMENTATION_GUIDE.md` - Complete implementation guide
- `dev/templates/` - Code templates for all required files
- `dev/templates/IMPLEMENTATION_CHECKLIST.md` - Track your progress

## 4.4 Git Commit Guidelines

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

## 4.5 Known Limitations

1. **Only FA Implemented**: GM, IRT, CDM models not yet supported
2. **ellmer Dependency**: Requires ellmer package for LLM communication
3. **Token Counting Variability**: Some providers (Ollama) don't report tokens accurately
4. **System Prompt Caching**: Provider-specific behavior may affect token counts

## 4.6 Package Statistics

To get current package statistics, run:

```r
# Count R source files
length(list.files("R/", pattern = "\\.R$"))

# Count total lines of R code
sum(sapply(list.files("R/", pattern = "\\.R$", full.names = TRUE),
          function(x) length(readLines(x, warn = FALSE))))

# Count test files
length(list.files("tests/testthat", pattern = "^test-.*\\.R$"))

# Count exports
exports <- readLines("NAMESPACE")
length(grep("^export\\(", exports))
length(grep("^S3method\\(", exports))

# Count archived files (if archive exists outside package)
if (dir.exists("../psychinterpreter_archive")) {
  length(list.files("../psychinterpreter_archive", pattern = "\\.R$"))
}
```

---

**Last Updated**: 2025-11-11
**Maintainer**: Update when making architectural changes
