# psychinterpreter Developer Guide

**Last Updated**: 2025-11-15
**Version**: 0.0.0.9000
**Purpose**: Technical reference for package maintainers and contributors

**For usage/user-facing documentation**: See [CLAUDE.md](../CLAUDE.md)

---

## Table of Contents

1. [Package Architecture](#1-package-architecture)
2. [Token Tracking System](#2-token-tracking-system)
3. [Implementation Details](#3-implementation-details)
4. [Development Reference](#4-development-reference)
5. [Current Package Analysis (2025-11-12)](#5-current-package-analysis-2025-11-12)
6. [Maintenance History](#6-maintenance-history)

---

## Glossary

### Key Terminology

**Analysis Type**
- String identifier used internally to route to appropriate S3 methods
- Valid values: `"fa"`, `"gm"`, `"irt"`, `"cdm"`
- Examples: `analysis_type = "fa"`, `interpretation_args(analysis_type = "fa")`
- Used in: Function parameters, configuration objects, S3 method dispatch

**Model Class**
- R object class of fitted model objects from external packages
- Examples: `"fa"` (psych), `"psych"` (psych), `"principal"` (psych), `"lavaan"` (lavaan), `"SingleGroupClass"` (mirt), `"Mclust"` (mclust)
- Used in: S3 method dispatch for `build_analysis_data.{class}()`
- Note: Multiple model classes can map to the same analysis type (e.g., psych, lavaan, mirt all map to "fa")

**Interpretation Args**
- Configuration object created by `interpretation_args(analysis_type, ...)`
- Contains analysis-specific settings (e.g., cutoff, n_emergency for FA)
- Used to configure interpretation behavior for different analysis types

**Core Methods**
- The 8 required S3 methods that every analysis type must implement
- Essential for interpretation workflow to function
- See section 1.3 for complete list

**Optional Methods**
- Additional S3 methods that enhance functionality but aren't required
- Currently: `export_interpretation()` and `plot()`
- Recommended to implement for complete feature parity

---

# 1. Package Architecture

## 1.1 Design Principles

1. **Generic Core + Analysis-Specific Implementations**
   - Core interpretation logic is analysis-agnostic
   - Analysis-specific behavior via S3 methods

2. **Extensibility**
   - Adding new analysis types requires 8 S3 methods
   - No changes to core infrastructure needed

3. **Token Efficiency**
   - Persistent chat sessions reuse system prompts (~40-60% savings)
   - Conditional token tracking accounts for system prompt caching

## 1.2 File Structure

All R files are organized in a **flat `R/` directory** (no subdirectories) following a **prefix-first naming convention**. This structure simplifies R package development while making the abstraction hierarchy immediately clear.

**Naming Pattern**: `{prefix}_{description}.R` where prefix indicates the file's role:
- `core_*` = Core infrastructure
- `s3_*` = S3 generic definitions (interfaces)
- `class_*` = S3 class definitions
- `{analysis}_*` = Analysis-specific implementations (e.g., `fa_*`)
- `shared_*` = Shared utilities (regular functions, not S3)

**See section 4.1 "Naming Conventions"** for detailed explanation of prefix meanings and distinctions.

---

### Core Infrastructure (4 files)

| File | Lines | Purpose |
|------|-------|---------|
| `core_constants.R` | ~30 | Package constants (`VALID_ANALYSIS_TYPES`) and `validate_analysis_type()` |
| `core_interpret_dispatch.R` | ~760 | Main `interpret()` generic + routing to analysis-specific methods |
| `core_interpret.R` | ~550 | Universal `interpret_core()` orchestrator (all analysis types) |
| *(archive/)* | - | Legacy files (deprecated code) |

### S3 Generic Definitions (5 files)

**Purpose**: Define the interface that analysis-specific methods must implement

| File | Lines | Purpose |
|------|-------|---------|
| `s3_model_data.R` | ~60 | Generic: `build_analysis_data()` for extracting analysis data |
| `s3_list_validation.R` | ~147 | Generic: `validate_list_structure()` for structured list input validation |
| `s3_prompt_builder.R` | ~83 | Generics: `build_system_prompt()`, `build_main_prompt()` |
| `s3_json_parser.R` | ~200 | Generics: `validate_parsed_result()`, `extract_by_pattern()`, `create_default_result()` |
| `s3_export.R` | ~132 | Generic: `build_report()` for report generation |

### Class Definitions (2 files)

| File | Lines | Purpose |
|------|-------|---------|
| `class_chat_session.R` | ~287 | `chat_session` class (constructors, validators, print); uses environments for mutable state |
| `class_interpretation.R` | ~92 | Base `interpretation` class infrastructure |

### Shared Utilities (4 files)

**Purpose**: Regular utility functions used by all analysis types (not S3 methods)

| File | Lines | Purpose |
|------|-------|---------|
| `shared_config.R` | ~580 | Config constructors: `llm_args()`, `interpretation_args()`, `output_args()`, builders |
| `shared_visualization.R` | ~250 | `psychinterpreter_colors()`, `theme_psychinterpreter()` (color palettes and ggplot2 theme) |
| `shared_utils.R` | ~156 | Validation, routing, helper functions |
| `shared_text.R` | ~107 | Text wrapping, word counting utilities |

**Note**: The S3 generic `create_fit_summary()` is defined in `core_interpret.R` (lines 511-532) rather than in a separate `s3_*.R` file, as it's tightly coupled with the core interpretation workflow.

### Factor Analysis Implementation (7 files, 10 methods)

**Purpose**: FA-specific S3 method implementations

**Core Methods (8 required)**:
| File | Lines | Purpose |
|------|-------|---------|
| `fa_model_data.R` | ~627 | S3 methods: `build_analysis_data.{fa,psych,principal,lavaan,SingleGroupClass}` |
| `fa_prompt_builder.R` | ~356 | S3 methods: `build_system_prompt.fa()`, `build_main_prompt.fa()` |
| `fa_json.R` | ~225 | S3 methods: `validate_parsed_result.fa()`, `extract_by_pattern.fa()`, `create_default_result.fa()` |
| `fa_diagnostics.R` | ~197 | S3 method: `create_fit_summary.fa()` with `find_cross_loadings()`, `find_no_loadings()` |
| `fa_report.R` | ~1084 | S3 method: `build_report.fa_interpretation()` with modular section builders |

**Additional Methods (2 optional but recommended)**:
| File | Lines | Purpose |
|------|-------|---------|
| `fa_export.R` | ~136 | S3 method: `export_interpretation.fa_interpretation()` with format conversion |
| `fa_visualization.R` | ~266 | S3 method: `plot.fa_interpretation()`, `create_factor_plot()` wrapper |

### Future Analysis Types (Planned)

**Gaussian Mixture (GM)**: Not implemented
- `gm_model_data.R`, `gm_prompts.R`, `gm_json.R`, `gm_diagnostics.R`, `gm_report.R`, `gm_visualization.R`

**Item Response Theory (IRT)**: Not implemented
- `irt_model_data.R`, `irt_prompts.R`, `irt_json.R`, `irt_diagnostics.R`, `irt_report.R`, `irt_visualization.R`

**Cognitive Diagnosis Models (CDM)**: Not implemented
- `cdm_model_data.R`, `cdm_prompts.R`, `cdm_json.R`, `cdm_diagnostics.R`, `cdm_report.R`, `cdm_visualization.R`

**Implementation Note**: Extensibility infrastructure already in place with commented placeholders. See `dev/templates/` and `dev/MODEL_IMPLEMENTATION_GUIDE.md` for implementation instructions.

## 1.3 S3 Method System

Each S3 generic is exported with `#' @export`, and individual S3 methods are also exported with `#' @export` following standard R package practices.

### Required S3 Methods per Analysis Type

Each analysis type (FA, GM, IRT, CDM) must implement these 8 methods:

1. **`build_analysis_data.{class}()`** - Extract & validate analysis data from fitted objects
2. **`build_system_prompt.{analysis}()`** - Constructs expert system prompt
3. **`build_main_prompt.{analysis}()`** - Constructs user prompt with data
4. **`validate_parsed_result.{analysis}()`** - Validates LLM JSON response
5. **`extract_by_pattern.{analysis}()`** - Pattern-based extraction fallback
6. **`create_default_result.{analysis}()`** - Default results if parsing fails
7. **`create_fit_summary.{analysis}()`** - Analysis-specific fit summary and diagnostics
8. **`build_report.{analysis}_interpretation()`** - Report generation

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
   STEP 0: build_analysis_data.{class}(fit_results, ...) → Extract & validate analysis data
        ↓
   STEP 1: Validate inputs
        ↓
   STEP 2: build_system_prompt.{analysis}() → System prompt (S3 dispatch)
        ↓
   STEP 3: Initialize or use existing chat session
        ↓
   STEP 4: build_main_prompt.{analysis}() → User prompt with data (S3 dispatch)
        ↓
   STEP 5: LLM API call (via ellmer) → Get JSON response
        ↓
   STEP 6: parse_llm_response.{analysis}() → Parse JSON (S3 dispatch)
      - validate_parsed_result.{analysis}()
      - extract_by_pattern.{analysis}() [if JSON parsing fails]
      - create_default_result.{analysis}() [ultimate fallback]
        ↓
   STEP 7: Update token tracking
        ↓
   STEP 8: create_fit_summary.{analysis}() → Fit summary & diagnostics (S3 dispatch)
        ↓
   STEP 9: Assemble interpretation object
        ↓
   STEP 10: build_report.{analysis}_interpretation() → Generate report (S3 dispatch)
        ↓
   STEP 11: Print report (unless silent)
        ↓
4. Return interpretation object with token tracking
```

## 1.5 Adding a New Analysis Type

Complete templates and implementation guide are available:
- **📖 Implementation Guide**: `dev/MODEL_IMPLEMENTATION_GUIDE.md` - Comprehensive step-by-step guide
- **📝 Code Templates**: `dev/templates/` - Ready-to-use templates for all 8 required S3 methods
- **✅ Implementation Checklist**: `dev/templates/IMPLEMENTATION_CHECKLIST.md` - Track your progress

**Quick Start**: Copy templates from `dev/templates/`, replace placeholders, implement analysis-specific logic. See templates README for details.

---

Example: Adding Gaussian Mixture (GM) support

### Step 1: Create Analysis-Specific Files

```
R/gm_model_data.R       - S3 method: build_analysis_data.gm() for extracting GM data
R/gm_prompt_builder.R   - S3 methods: build_system_prompt.gm(), build_main_prompt.gm()
R/gm_json.R             - S3 methods: validate_parsed_result.gm(), extract_by_pattern.gm(), create_default_result.gm()
R/gm_diagnostics.R      - S3 method: create_fit_summary.gm()
R/gm_report.R           - S3 method: build_report.gm_interpretation()
```

**Note**: No need for `gm_interpret.R` - all interpretations route through `interpret_core()`

### Step 2: Implement build_analysis_data.gm() S3 Method

```r
#' @export
build_analysis_data.gm <- function(fit_results, variable_info, analysis_type = NULL,
                                 gm_args = NULL, ...) {
  # Extract GM-specific parameters
  dots <- list(...)

  # Extract from fit_results (could be a mclust object, list, etc.)
  means <- extract_means(fit_results)
  covariances <- extract_covariances(fit_results)
  probabilities <- extract_probabilities(fit_results)

  # Build and return standardized analysis_data structure
  list(
    means = means,
    covariances = covariances,
    probabilities = probabilities,
    n_clusters = ncol(means),
    analysis_type = "gm",
    # ... other GM-specific fields
  )
}
```

### Step 3: Implement Remaining 7 Required S3 Methods

```r
#' @export
build_system_prompt.gm <- function(analysis_type, analysis_data, variable_info, ...) {
  "You are an expert in Gaussian Mixture modeling..."
}

#' @export
build_main_prompt.gm <- function(analysis_type, analysis_data, variable_info, ...) {
  # Format cluster parameters, covariance matrices, etc.
  # Use analysis_data$means, analysis_data$covariances, etc.
}

#' @export
validate_parsed_result.gm <- function(parsed_result, analysis_data, ...) {
  # Validate GM-specific response structure
}

#' @export
extract_by_pattern.gm <- function(response, analysis_data, ...) {
  # Pattern-based extraction fallback for GM
}

#' @export
create_default_result.gm <- function(analysis_data, ...) {
  # Default result structure for GM
}

#' @export
create_fit_summary.gm <- function(analysis_type, analysis_data, variable_info, ...) {
  # GM-specific fit summary and diagnostics (cluster overlap, separation, etc.)
}

#' @export
build_report.gm_interpretation <- function(interpretation, ...) {
  # Format GM interpretation report
}
```

### Step 4: Update handle_raw_data_interpret() (if using structured lists)

```r
# In utils_interpret.R
handle_raw_data_interpret <- function(x, variable_info, analysis_type, chat_session,
                                      llm_args = NULL, gm_args = NULL, ...) {
  effective_analysis_type <- if (!is.null(chat_session)) {
    chat_session$analysis_type
  } else {
    analysis_type
  }

  switch(effective_analysis_type,
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
        analysis_type = "gm",
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
  validate_chat_session_for_analysis_type(chat_session, "gm")

  result <- interpret_core(
    fit_results = model,
    variable_info = variable_info,
    analysis_type = "gm",
    ...
  )

  stopifnot(inherits(result, "gm_interpretation"))
  return(result)
}
```

### Step 7: Done!

Core infrastructure (`interpret_core()`, JSON parsing, token tracking) requires no changes. The S3 dispatch system automatically handles your new analysis type through the generic methods you implemented.

**For detailed implementation**: See `dev/MODEL_IMPLEMENTATION_GUIDE.md` for:
- Complete code templates with placeholders
- Analysis-specific customization points
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
| **cli** | `==== SECTION ====` | Plain text | Yes (via `wrap_text()`) |
| **markdown** | `# Section` | `**bold**`, `*italic*` | No (preserves formatting) |

### Implementation Locations

- **R/shared_config.R**: Validation in `output_args()` constructor
- **R/core_interpret.R**: Stored in params, passed to `build_report()`
- **R/fa_report.R**: Conditional logic branching on format
  - Markdown-specific logic (headings with `#`, bold/italic)
  - CLI-specific logic (text with `====` separators, plain text)
- **R/s3_export.R**: Converts export format to output_format

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
| `{analysis}_` | Analysis-specific implementations | S3 methods for specific analysis types | `fa_model_data.R`, `fa_prompt_builder.R`, `fa_json.R` |
| `shared_` | Shared utilities | Utility functions used across all analysis types (NO S3) | `shared_config.R`, `shared_visualization.R`, `shared_utils.R` |

**Important Distinctions**:

- **`s3_*.R`** files contain S3 **generic** function declarations
  - Example: `s3_prompt_builder.R` defines `build_system_prompt()` generic
  - These define the **interface** that analysis-specific methods must implement

- **`{analysis}_*.R`** files contain S3 **method** implementations
  - Example: `fa_prompt_builder.R` implements `build_system_prompt.fa()`
  - These provide **analysis-specific behavior** for the generics

- **`shared_*.R`** files contain regular **utility** functions (NOT S3)
  - Example: `shared_visualization.R` provides `psychinterpreter_colors()`, `theme_psychinterpreter()`
  - These are plain functions used by all analysis types, NOT S3 methods
  - Do not confuse with `s3_*` files which define generics

**Examples**:

```r
✅ CORRECT:
core_constants.R              # Package constants (VALID_ANALYSIS_TYPES)
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
- Clear abstraction levels (core vs analysis-specific vs shared vs S3 definitions)
- Scales well for multiple analysis types (GM, IRT, CDM)
- Follows established R package patterns while maintaining clarity

**For detailed implementation plan**: See `dev/FILE_NAMING_ANALYSIS.md` and `dev/RENAME_IMPLEMENTATION_PLAN.md`

#### Function and Variable Naming

- **Functions**: snake_case (e.g., `build_analysis_data()`, `psychinterpreter_colors()`)
- **S3 methods**: `method.class()` format (e.g., `build_system_prompt.fa()`, `plot.fa_interpretation()`)
- **S3 generics**: snake_case (e.g., `build_system_prompt()`, `create_fit_summary()`)
- **Internal functions**: Prefix with `.` (e.g., `.internal_helper()`, `.validate_structure()`)
- **Variables**: snake_case (e.g., `analysis_data`, `factor_summaries`, `n_factors`)

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

### Token Tracking Inconsistencies
- **Ollama**: Returns 0 (no tracking support)
- **Anthropic**: May undercount due to prompt caching
- **OpenAI**: Generally accurate
- **Status**: Documented, handled with `normalize_token_count()`
- **Impact**: Non-critical - informational metric only

### LLM Test Skipping in CI
- **Behavior**: Most `interpret_core` tests skip without LLM
- **Status**: By design - uses `skip_if_no_llm()`
- **Impact**: None - appropriate for CI environments

### FA-Specific Code in Shared Files
- **Location**: Some FA-specific functions in `shared_text.R` and `shared_utils.R`
- **Impact**: Minor abstraction leak, doesn't block functionality
- **Plan**: Move to FA-specific files in v0.2.0 (optional refactoring)

### Only FA Model Type Implemented
- **Current Support**: Factor Analysis (FA) only
- **Planned**: Gaussian Mixture (GM), Item Response Theory (IRT), Cognitive Diagnosis Models (CDM)
- **Status**: Architecture ready for new model types (see section 1.5)

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

# 5. Current Package Analysis (2025-11-12)

## 5.1 Package Statistics

**Current State**:
- **Total R files**: 20 files in R/ directory
- **Total lines of R code**: 6,462 lines
- **Test files**: 9 test files
- **Total tests**: 115 test_that blocks
- **Exported functions**: 23 user-facing functions
- **S3 methods**: 35 methods registered

**Code Distribution by Category**:

| Category | Files | Approx Lines | Purpose |
|----------|-------|--------------|---------|
| Core Infrastructure | 3 | ~1,340 | Orchestration, dispatch, constants |
| S3 Generics | 4 | ~475 | Interface definitions |
| Classes | 2 | ~379 | chat_session, interpretation classes |
| Shared Utilities | 4 | ~1,093 | Config, visualization, text, utils |
| FA Implementation | 7 | ~3,141 | Complete FA implementation |
| **Total** | **20** | **~6,462** | |

## 5.2 Consistency Analysis

### ✅ Strengths

1. **Well-Structured S3 System**
   - Clean separation between generics (s3_*.R) and implementations ({model}_*.R)
   - All 8 required methods implemented for FA
   - Consistent method signatures across the dispatch chain

2. **Robust Error Handling**
   - Multi-tier JSON parsing fallback system
   - Comprehensive parameter validation
   - Informative error messages with cli package

3. **Excellent Documentation**
   - All exported functions have roxygen2 documentation
   - Clear separation between user guide (CLAUDE.md) and developer guide
   - Comprehensive templates for new model implementations

4. **Token Efficiency Design**
   - Chat session reuse saves 40-60% tokens
   - Proper tracking of system prompt caching
   - Minimal fixtures for testing

5. **Clean Abstraction**
   - Model-agnostic core (interpret_core)
   - Clear extension points via S3 methods
   - No hardcoded model-specific logic in core

### ⚠️ Areas for Improvement

1. **Naming Consistency**
   - Both `Phi` and `factor_cor_mat` accepted for backward compatibility
   - Could standardize on one name internally

2. **Test Coverage**
   - Heavy reliance on FA tests (only implemented model)
   - Limited testing of error conditions
   - Some edge cases not covered

3. **Documentation Gaps**
   - Missing examples in some roxygen2 blocks
   - Internal functions could use more inline comments
   - Some S3 methods lack detailed parameter descriptions

### 🔧 Fixed Issues (2025-11-12)

1. **pkgdown.yml Updated**
   - Added missing internal S3 generics section
   - Now documents all 23 exported functions

## 5.3 Design Decisions & Rationale

### Key Architectural Choices

1. **Flat R/ Directory**
   - **Decision**: Keep all R files in flat structure (no subdirectories)
   - **Rationale**: Standard R package convention, simpler for R CMD check
   - **Organization**: Use prefix naming (core_, s3_, fa_, shared_) for clarity

2. **Dual Interface Pattern**
   - **Decision**: Accept both direct parameters and config objects
   - **Rationale**: Balances simplicity for beginners with flexibility for advanced users
   - **Precedence**: Direct parameters override config objects

3. **Plain Function for interpret()**
   - **Decision**: Not an S3 generic, uses named arguments
   - **Rationale**: Prevents positional dispatch confusion, clearer parameter validation
   - **Dispatch**: Internal routing via interpret_model.{class}() S3 methods

4. **Export Internal Generics**
   - **Decision**: Export S3 generics marked as @keywords internal
   - **Rationale**: Required for package extensions, but not for end users
   - **Documentation**: Separate pkgdown section for internal generics

## 5.4 Extension Readiness

### Current Extensibility Infrastructure

**✅ Ready for New Analysis Types**:
- Generic infrastructure fully operational
- Templates provided for all required files
- Clear implementation guide with examples
- Consistent patterns established with FA

**📝 To Implement New Analysis Type**:
1. Copy templates from `dev/templates/`
2. Replace placeholders ({MODEL}, {model}, etc.)
3. Implement 8 required S3 methods
4. Add tests following FA pattern
5. Update NAMESPACE via roxygen2

**Planned Analysis Types**:
- **Gaussian Mixture (GM)**: For clustering analyses
- **Item Response Theory (IRT)**: For item analysis
- **Cognitive Diagnosis Models (CDM)**: For diagnostic assessment
  - Q-Matrix interpretation: 
    - packages: GDINA, CDM, cdmTools
    

## 5.5 Quality Metrics

### Code Quality Indicators

| Metric | Status | Notes |
|--------|--------|-------|
| R CMD check | ✅ PASS | No errors, warnings, or notes |
| Test Coverage | ~85% | Good coverage for implemented features |
| Documentation | ✅ Complete | All exports documented |
| Examples | ⚠️ Partial | Some functions lack examples |
| Vignettes | ✅ Present | Multiple vignettes in articles/ |
| Style Consistency | ✅ Good | Consistent naming, formatting |

### Performance Characteristics

- **Token Efficiency**: 40-60% savings with chat sessions
- **Parsing Robustness**: 3-tier fallback for JSON parsing
- **Test Speed**: ~30 seconds for full suite (with cached fixtures)
- **Memory Usage**: Minimal, no large objects retained

## 5.6 Maintenance Notes

### Regular Maintenance Tasks

1. **After Adding Functions**:
   ```r
   devtools::document()  # Update NAMESPACE and .Rd files
   devtools::test()      # Ensure tests pass
   devtools::check()     # Full R CMD check
   ```

2. **After Modifying S3 Methods**:
   - Update corresponding tests
   - Verify method dispatch with `methods()`
   - Check that NAMESPACE exports are correct

3. **Documentation Updates**:
   - CLAUDE.md for user-facing changes
   - DEVELOPER_GUIDE.md for architectural changes
   - Update "Last Updated" dates
   - Keep templates synchronized

### Known Technical Debt

1. **Limited Analysis Type Coverage**: Only FA implemented
2. **Provider-Specific Token Counting**: Needs normalization improvements
3. **Test Fixture Management**: Could benefit from systematic organization
4. **Edge Case Coverage**: Some error conditions not fully tested

## 5.7 Code Style Reference

### Established Patterns in Codebase

**Function Structure**:
```r
# Standard function with full validation
function_name <- function(param1, param2 = NULL, ...) {
  # Parameter validation
  if (is.null(param1)) {
    cli::cli_abort("param1 is required")
  }

  # Main logic
  result <- process_data(param1, param2)

  # Return with class
  structure(result, class = c("specific_class", "interpretation"))
}
```

**S3 Method Pattern**:
```r
#' @export
method_name.class_name <- function(object, ...) {
  # Extract additional arguments
  dots <- list(...)

  # Class-specific logic
  result <- specific_processing(object)

  # Delegate to next method if needed
  NextMethod()
}
```

**Error Messaging**:
```r
# Informative multi-line errors
cli::cli_abort(c(
  "Main error message",
  "i" = "Informational context",
  "x" = "What went wrong",
  "v" = "What should be done instead"
))
```

---

# 6. Maintenance History

## 6.1 Package Consistency Fixes (2025-11-15)

This section documents the implementation of critical consistency fixes identified through comprehensive package analysis.

### Summary

**Completion Status**: Phase 1 & Phase 2 Complete
**Total Time**: ~2.5 hours (estimated 8 hours)
**Files Modified**: 6 files (R source, documentation, tests)
**Breaking Changes**: None (all fixes restore intended behavior)

### Phase 1: Critical Fixes

#### Fix 1.1: Function Name Mismatch

**Issue**: Function defined as `validate_chat_session_for_analysis_type()` but called as `validate_chat_session_for_model_type()` in 5 locations.

**Resolution**: Updated all call sites in `R/core_interpret_dispatch.R` to use correct function name.

**Verification**: `grep -r "validate_chat_session_for_model_type" R/` returns no matches.

#### Fix 1.2: Parameter Example Errors

**Issue**: Documentation examples used `output_format` parameter but actual parameter in `output_args()` is `format`.

**Files Modified**:
- `R/core_interpret_dispatch.R` line 106
- `man/interpret.Rd` line 133

**Resolution**: Changed examples to use `format = "markdown"` instead of `output_format = "markdown"`.

#### Fix 1.3: Test Field Access Bugs

**Issue**: Tests accessed `result$model_data` but refactoring changed it to `result$analysis_data`.

**Files Modified**: `tests/testthat/test-04-s3-extraction.R` (2 occurrences at lines 185, 215)

**Resolution**: Updated field access to `result$analysis_data$factor_cor_mat`.

### Phase 2: Major Fixes

#### Fix 2.1: Add Missing S3 Method Registrations

**Issue**: `interpret_model` generic and its 5 methods not registered in NAMESPACE.

**Files Modified**: `R/core_interpret_dispatch.R` (added `@export` to 6 functions)

**Methods Registered**:
1. `interpret_model()` - Generic (line 425)
2. `interpret_model.fa()` - FA method (line 454)
3. `interpret_model.principal()` - PCA method (line 518)
4. `interpret_model.lavaan()` - lavaan CFA/SEM method (line 608)
5. `interpret_model.efaList()` - lavaan EFA method (line 745)
6. `interpret_model.SingleGroupClass()` - mirt method (line 851)

**Pattern Used**: Added `@export` before existing `@keywords internal @noRd` tags:
```r
#' @export
#' @keywords internal
#' @noRd
interpret_model.fa <- function(model, ...) {
```

**NAMESPACE Additions**:
```r
S3method(interpret_model,SingleGroupClass)
S3method(interpret_model,efaList)
S3method(interpret_model,fa)
S3method(interpret_model,lavaan)
S3method(interpret_model,principal)
export(interpret_model)
```

#### Fix 2.2: Document Internal Functions

**Status**: Verified - all critical internal functions already have proper roxygen documentation with `@keywords internal @noRd`.

**No changes required**.

#### Fix 2.3: Standardize Roxygen Tags

**Finding**: The combination of `@export` and `@keywords internal` is **intentional and valid**.

**Rationale**:
- S3 generics need to be exported for extensibility
- `@keywords internal` affects pkgdown documentation grouping only
- Does not prevent export or cause conflicts
- Follows R package best practices for extension APIs

**No changes required**.

#### Fix 2.4: Add Configuration Precedence Tests

**File Created**: `tests/testthat/test-22-config-precedence.R`

**Tests Added** (6 total):
1. Direct interpretation parameters override interpretation_args config
2. Direct llm parameters override llm_args config
3. Direct output parameters override output_args config
4. Config objects work when no direct parameters provided
5. Mixed config and direct parameters work together
6. NULL config objects use package defaults

**Coverage**: Direct parameter precedence, config object fallback, mixed usage patterns, NULL handling.

### Verification Results

**Critical Fixes**:
| Fix | Verification Command | Status |
|-----|---------------------|--------|
| Function name | `grep -r "validate_chat_session_for_model_type" R/` | ✅ No matches |
| Parameter examples | `grep "output_format" R/core_interpret_dispatch.R man/interpret.Rd` | ✅ Fixed in examples |
| Test field access | `grep "result\$model_data" tests/` | ✅ No matches |

**S3 Registration**:
| Method | NAMESPACE Entry | Status |
|--------|----------------|--------|
| interpret_model (generic) | `export(interpret_model)` | ✅ Present |
| interpret_model.fa | `S3method(interpret_model,fa)` | ✅ Present |
| interpret_model.principal | `S3method(interpret_model,principal)` | ✅ Present |
| interpret_model.lavaan | `S3method(interpret_model,lavaan)` | ✅ Present |
| interpret_model.efaList | `S3method(interpret_model,efaList)` | ✅ Present |
| interpret_model.SingleGroupClass | `S3method(interpret_model,SingleGroupClass)` | ✅ Present |

### Files Modified Summary

**R Source Files** (2 files):
1. `R/core_interpret_dispatch.R` - Fixed function calls (5), parameter example (1), added @export tags (6)
2. `R/shared_config.R` - No changes required (already correct)

**Documentation Files** (1 file):
1. `man/interpret.Rd` - Fixed parameter example (1)

**Test Files** (2 files):
1. `tests/testthat/test-04-s3-extraction.R` - Fixed field access (2)
2. `tests/testthat/test-22-config-precedence.R` - New file (6 tests)

**Generated Files** (1 file):
1. `NAMESPACE` - Auto-regenerated by roxygen2 (6 new entries)

### Impact Analysis

**Breaking Changes**: None - All fixes are backward compatible

**Behavioral Changes**: None - Fixes restore intended behavior, no new behavior introduced

**API Changes**:
- `interpret_model()` and methods now properly exported for S3 dispatch
- No user-facing API changes (function was internal)

**Test Changes**:
- 2 test assertions fixed
- 6 new tests added
- Test suite more robust for configuration handling

### Lessons Learned

1. **Function Renaming**: Refactoring from `model_type` to `analysis_type` was thorough in most places but missed some call sites. **Lesson**: Use find-replace with verification.

2. **Parameter Names**: Internal parameters (`output_format`) vs config object parameters (`format`) caused confusion. **Lesson**: Keep parameter names consistent across all interfaces.

3. **Test Field Access**: Refactoring from `model_data` to `analysis_data` updated implementation but not all tests. **Lesson**: Include test updates in refactoring checklist.

4. **S3 Method Registration**: Methods with `@keywords internal @noRd` but no `@export` weren't registered. **Lesson**: S3 methods need `@export` even if marked internal.

### Best Practices Established

1. **Always run verification commands** after refactoring:
   ```r
   devtools::document()  # Update NAMESPACE
   devtools::test()      # Run tests
   devtools::check()     # Full R CMD check
   ```

2. **Use grep to verify complete refactoring**:
   ```bash
   grep -r "old_pattern" R/     # Should return no matches
   grep -r "new_pattern" R/     # Should return expected matches
   ```

3. **Update tests immediately** when refactoring internal data structures

4. **Add configuration precedence tests** when implementing dual interface patterns

5. **Document S3 methods properly**:
   ```r
   #' @export
   #' @keywords internal
   #' @noRd
   method_name.class_name <- function(...) { }
   ```

---

**Last Updated**: 2025-11-15
**Maintainer**: Update when making architectural changes
