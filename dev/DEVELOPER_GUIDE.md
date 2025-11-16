# psychinterpreter Developer Guide

**Last Updated**: 2025-11-16
**Version**: 0.0.0.9000
**Purpose**: Technical reference for package maintainers and contributors
**Status**: Critical bugs fixed, production-ready

**For usage/user-facing documentation**: See [CLAUDE.md](../CLAUDE.md)

---

## Table of Contents

1. [Quick Start for Developers](#1-quick-start-for-developers)
2. [Package Architecture](#2-package-architecture)
3. [Token Tracking System](#3-token-tracking-system)
4. [Implementation Details](#4-implementation-details)
5. [Development Reference](#5-development-reference)
   - 5.1 [Code Style Guidelines](#51-code-style-guidelines)
   - 5.2 [Naming Conventions](#52-naming-conventions)
   - 5.3 [Critical Bug Fixes and Lessons Learned](#53-critical-bug-fixes-and-lessons-learned)

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
- See section 2.3 for complete list

**Optional Methods**
- Additional S3 methods that enhance functionality but aren't required
- Currently: `export_interpretation()` and `plot()`
- Recommended to implement for complete feature parity

---

# 1. Quick Start for Developers

## 1.1 Documentation Overview

### Core Documentation

| File | Purpose | Audience |
|------|---------|----------|
| **DEVELOPER_GUIDE.md** (this file) | Complete technical architecture and implementation details | Package maintainers |
| **TESTING_GUIDELINES.md** | Test suite organization, patterns, and best practices | Test developers |
| **OPEN_ISSUES.md** | Current issues, future work, and refactoring decisions | All developers |

### Implementation Guides

| File | Purpose | Audience |
|------|---------|----------|
| **MODEL_IMPLEMENTATION_GUIDE.md** | Step-by-step guide for adding new model types (GM, IRT, CDM) | New implementers |
| **FIXES_IMPLEMENTATION_SUMMARY.md** | Summary of consistency fixes (Phase 1 & 2 - 2025-11-15) | Maintainers |

### Reference

| File | Purpose |
|------|---------|
| **prompts.md** | LLM prompt templates and patterns |

## 1.2 Quick Navigation

### I want to...

**Understand the package architecture**
→ Read Section 2 of this guide

**Add a new model type (GM, IRT, CDM)**
→ Follow `MODEL_IMPLEMENTATION_GUIDE.md`
→ Use templates in `templates/` directory

**Write or modify tests**
→ Follow `TESTING_GUIDELINES.md`

**Know what needs to be done**
→ Check `OPEN_ISSUES.md`

**Understand recent fixes**
→ Read `FIXES_IMPLEMENTATION_SUMMARY.md`

## 1.3 Package Statistics

- **R Files**: 22
- **Lines of Code**: ~6,930
- **Test Files**: 25
- **Tests**: ~347+
- **Test Coverage**: ~92%
- **LLM Tests**: 14-15 (~4% of total)

## 1.4 Development Workflow

### Before Making Changes

1. Read relevant documentation above
2. Check `OPEN_ISSUES.md` for related work
3. Review `TESTING_GUIDELINES.md` for test patterns

### After Making Changes

1. Run tests: `devtools::test()`
2. Update documentation: `devtools::document()`
3. Check package: `devtools::check()`
4. Update relevant docs in `dev/`
5. Update `OPEN_ISSUES.md` if completing an issue

### Adding New Model Types

1. Follow `MODEL_IMPLEMENTATION_GUIDE.md` exactly
2. Copy templates from `templates/` directory
3. Implement 8 required S3 methods
4. Add tests following patterns in `TESTING_GUIDELINES.md`
5. Update `OPEN_ISSUES.md` to mark as complete

## 1.5 Getting Help

- **Architecture questions**: See Section 2-4 of this guide
- **Implementation questions**: See `MODEL_IMPLEMENTATION_GUIDE.md`
- **Testing questions**: See `TESTING_GUIDELINES.md`
- **What to work on**: See `OPEN_ISSUES.md`

## 1.6 Document Maintenance

When updating these docs:

- Update "Last Updated" date at top of file
- Keep documentation current with code
- Cross-reference related sections
- Document decisions in `OPEN_ISSUES.md`
- Remove obsolete information

---

# 2. Package Architecture

## 2.1 Design Principles

1. **Generic Core + Analysis-Specific Implementations**
   - Core interpretation logic is analysis-agnostic
   - Analysis-specific behavior via S3 methods

2. **Extensibility**
   - Adding new analysis types requires 8 S3 methods
   - No changes to core infrastructure needed

3. **Token Efficiency**
   - Persistent chat sessions reuse system prompts (~40-60% savings)
   - Conditional token tracking accounts for system prompt caching

## 2.2 File Structure

All R files are organized in a **flat `R/` directory** (no subdirectories) following a **prefix-first naming convention**. This structure simplifies R package development while making the abstraction hierarchy immediately clear.

**Naming Pattern**: `{prefix}_{description}.R` where prefix indicates the file's role:
- `core_*` = Core infrastructure
- `s3_*` = S3 generic definitions (interfaces)
- `class_*` = S3 class definitions
- `{analysis}_*` = Analysis-specific implementations (e.g., `fa_*`)
- `shared_*` = Shared utilities (regular functions, not S3)

**See section 5.2 "Naming Conventions"** for detailed explanation of prefix meanings and distinctions.

---

### Core Infrastructure (4 files)

| File | Lines | Purpose |
|------|-------|---------|
| `core_constants.R` | ~30 | Package constants (`VALID_ANALYSIS_TYPES`) and `validate_analysis_type()` |
| `core_interpret_dispatch.R` | ~760 | Main `interpret()` generic + routing to analysis-specific methods |
| `core_interpret.R` | ~550 | Universal `interpret_core()` orchestrator (all analysis types) |
| *(archive/)* | - | Legacy files (deprecated code) |

### S3 Generic Definitions (6 files)

**Purpose**: Define the interface that analysis-specific methods must implement

| File | Lines | Purpose |
|------|-------|---------|
| `s3_model_data.R` | ~60 | Generic: `build_analysis_data()` for extracting analysis data |
| `s3_list_validation.R` | ~200 | Generic: `validate_list_structure()` for structured list input validation |
| `s3_parameter_extraction.R` | ~200 | Generics: `extract_model_parameters()`, `validate_model_requirements()` for model-specific parameter extraction and requirement validation |
| `s3_prompt_builder.R` | ~83 | Generics: `build_system_prompt()`, `build_main_prompt()` |
| `s3_json_parser.R` | ~200 | Generics: `validate_parsed_result()`, `extract_by_pattern()`, `create_default_result()` |
| `s3_export.R` | ~82 | Generic: `export_interpretation()` for export functionality |

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

### Factor Analysis Implementation (7 files, 11 methods)

**Purpose**: FA-specific S3 method implementations

**Core Methods (8 required)**:
| File | Lines | Purpose |
|------|-------|---------|
| `fa_model_data.R` | ~680 | S3 methods: `build_analysis_data.{fa,psych,principal,lavaan,SingleGroupClass,matrix,data.frame,list}` |
| `fa_prompt_builder.R` | ~356 | S3 methods: `build_system_prompt.fa()`, `build_main_prompt.fa()` |
| `fa_json.R` | ~225 | S3 methods: `validate_parsed_result.fa()`, `extract_by_pattern.fa()`, `create_default_result.fa()` |
| `fa_diagnostics.R` | ~197 | S3 method: `create_fit_summary.fa()` with `find_cross_loadings()`, `find_no_loadings()` |
| `fa_report.R` | ~1084 | S3 methods: `build_report.fa_interpretation()`, `print.fa_interpretation()` with modular section builders |

**Additional Methods (3 optional but recommended)**:
| File | Lines | Purpose |
|------|-------|---------|
| `fa_export.R` | ~136 | S3 method: `export_interpretation.fa_interpretation()` with format conversion |
| `fa_visualization.R` | ~266 | S3 method: `plot.fa_interpretation()`, `create_factor_plot()` wrapper |

**Note**: The `print.fa_interpretation()` method is implemented in `fa_report.R` and handles console output formatting. It delegates to `build_report.fa_interpretation()` for report generation.

### Future Analysis Types (Planned)

**Gaussian Mixture (GM)**: Not implemented
- `gm_model_data.R`, `gm_prompts.R`, `gm_json.R`, `gm_diagnostics.R`, `gm_report.R`, `gm_visualization.R`

**Item Response Theory (IRT)**: Not implemented
- `irt_model_data.R`, `irt_prompts.R`, `irt_json.R`, `irt_diagnostics.R`, `irt_report.R`, `irt_visualization.R`

**Cognitive Diagnosis Models (CDM)**: Not implemented
- `cdm_model_data.R`, `cdm_prompts.R`, `cdm_json.R`, `cdm_diagnostics.R`, `cdm_report.R`, `cdm_visualization.R`

**Implementation Note**: Extensibility infrastructure already in place with commented placeholders. See `dev/templates/` and `dev/MODEL_IMPLEMENTATION_GUIDE.md` for implementation instructions.

## 2.3 S3 Method System

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

## 2.4 Interpretation Workflow

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

## 2.5 Adding a New Analysis Type

Complete templates and implementation guide are available:
- **📖 Implementation Guide**: `dev/MODEL_IMPLEMENTATION_GUIDE.md` - Comprehensive step-by-step guide
- **📝 Code Templates**: `dev/templates/` - Ready-to-use templates for all 8 required S3 methods
- **✅ Implementation Checklist**: `dev/templates/IMPLEMENTATION_CHECKLIST.md` - Track your progress

### Quick Implementation Steps

1. **Copy templates** from `dev/templates/` directory
2. **Create analysis-specific files** (e.g., `gm_model_data.R`, `gm_prompt_builder.R`, `gm_json.R`, `gm_diagnostics.R`, `gm_report.R`)
3. **Implement 8 required S3 methods**:
   - `build_analysis_data.{class}()` - Extract and validate analysis data
   - `build_system_prompt.{analysis}()` - Expert system prompt
   - `build_main_prompt.{analysis}()` - User prompt with data
   - `validate_parsed_result.{analysis}()` - Validate LLM response
   - `extract_by_pattern.{analysis}()` - Pattern-based extraction fallback
   - `create_default_result.{analysis}()` - Default results if parsing fails
   - `create_fit_summary.{analysis}()` - Fit summary and diagnostics
   - `build_report.{analysis}_interpretation()` - Report generation
4. **Create config constructor** (optional): `{analysis}_args()` function in `shared_config.R`
5. **Add interpret_model.{class}() methods** (optional): For fitted model classes in `core_interpret_dispatch.R`
6. **Update NAMESPACE**: Run `devtools::document()`
7. **Add tests**: Follow patterns in `TESTING_GUIDELINES.md`

**No changes needed** to core infrastructure - `interpret_core()`, JSON parsing, and token tracking work automatically via S3 dispatch.

**For detailed implementation**: See `dev/MODEL_IMPLEMENTATION_GUIDE.md` for complete code templates, customization points, testing strategies, and troubleshooting. Estimated time: 32-50 hours for full implementation.

---

# 3. Token Tracking System

## 3.1 Overview

The package implements a **dual-tier token tracking system** to accurately monitor LLM API usage. This architecture separates cumulative session-level totals from individual interpretation costs, while tracking system prompts separately. This design handles system prompt caching behavior and prevents negative token accumulation from provider inconsistencies.

## 3.2 Two Tracking Tiers

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

## 3.3 The System Prompt Caching Problem

**Issue**: LLM providers cache system prompts to reduce costs. In persistent sessions:
- First call: System prompt tokens counted
- Subsequent calls: System prompt tokens NOT counted (cached)

**Consequence**: Naive delta calculations can produce negative values:
```r
# Without protection:
delta = tokens_after - tokens_before  # May be negative if system prompt was cached!
```

## 3.4 The Solution: chat_local + normalize_token_count() Helper

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

## 3.5 Code Locations

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

## 3.6 Expected Behavior

### print(interpretation) - Per-Run Tokens
- **Temporary session**: Includes system prompt + user prompt + assistant response
- **Persistent session**: Excludes system prompt, only user prompt + response

### print(chat_session) - Cumulative Tokens
- **Total Input**: Sum of all user prompts (excludes system prompt)
- **Total Output**: Sum of all assistant responses
- **System Prompt**: One-time cost tracked separately

## 3.7 Provider-Specific Caveats

- **Ollama**: No token tracking support (returns 0)
- **Anthropic**: Caches system prompts aggressively (may undercount input)
- **OpenAI**: Generally accurate token reporting
- **Output tokens**: Typically accurate across all providers

---

# 4. Implementation Details

## 4.1 JSON Parsing Strategy

Multi-tiered fallback for robust LLM response handling:

1. **Try parsing cleaned JSON** (remove extra text, fix formatting)
2. **Fall back to original response**
3. **Pattern-based extraction** if JSON parsing fails (via S3 method `extract_by_pattern.fa()`)
4. **Default values** if all methods fail (via S3 method `create_default_result.fa()`)

**Location**: `R/s3_parsing.R` (generics) and `R/fa_json.R` (FA implementation)
**Rationale**: Critical for handling small/local models with imperfect JSON output

## 4.2 System Prompt Architecture

The psychometric expert system prompt is defined in **ONE location**:
- `R/fa_prompt_builder.R` via S3 method `build_system_prompt.fa()`
- Used by both single-use and persistent sessions
- **Single source of truth** - no duplication

## 4.3 Emergency Rule Logic

If a factor has zero loadings above cutoff:
- Uses top `n_emergency` highest absolute loadings instead
- Clearly marked with WARNING in output
- Factor names get "(n.s.)" suffix to indicate non-significant loadings
- Can set `n_emergency = 0` to label as "undefined" instead

**Implementation**: `R/fa_diagnostics.R`

## 4.4 Output Format System

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

## 4.5 Word Limit Enforcement

Targets 80-100% of `word_limit` parameter:
- System prompt includes explicit word targets
- Post-processing validates and **informs** (via `cli::cli_inform()`) if exceeded
- Helper function `count_words()` in `utils_text_processing.R`

## 4.6 Silent Parameter System

The silent parameter uses integer values for granular control:

| Value | Behavior |
|-------|----------|
| **0** (or FALSE) | Show report + messages |
| **1** | Show messages only, suppress report |
| **2** (or TRUE) | Completely silent (no report, no messages) |

**Implementation**: 3 core files (core_interpret.R, core_interpret_dispatch.R, s3_export.R)

---

# 5. Development Reference

## 5.1 Code Style Guidelines

### Required
- **Roxygen2 documentation** for all exported functions
- **Explicit namespacing**: Use `package::function()` (e.g., `dplyr::mutate()`)
- **CLI messaging**: Use `cli` package (`cli_alert_info`, `cli_abort`, `cli_inform`)
- **Pipe operator**: Base R `|>` (not magrittr `%>%`)
- **Parameter validation**: Extensive validation with informative errors at function start

## 5.2 Naming Conventions

### File Naming Scheme

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

### Function and Variable Naming

- **Functions**: snake_case (e.g., `build_analysis_data()`, `psychinterpreter_colors()`)
- **S3 methods**: `method.class()` format (e.g., `build_system_prompt.fa()`, `plot.fa_interpretation()`)
- **S3 generics**: snake_case (e.g., `build_system_prompt()`, `create_fit_summary()`)
- **Internal functions**: Prefix with `.` (e.g., `.internal_helper()`, `.validate_structure()`)
- **Variables**: snake_case (e.g., `analysis_data`, `factor_summaries`, `n_factors`)

## 5.3 Test Development Guidelines

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

## 5.4 Common Development Tasks

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

## 5.5 Git Commit Guidelines

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

## 5.6 Known Limitations

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
- **Status**: Architecture ready for new model types (see section 2.5)

## 5.7 Package Statistics

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

## 5.3 Recent Improvements and Refactorings

### Technical Debt Resolution (2025-11-16)

**Status**: ✅ 5 of 5 items completed via parallel execution

#### 1. FA-Specific Functions Moved to Dedicated File

**Problem**: FA-specific utility functions were in `shared_text.R`, creating abstraction leak

**Solution Implemented**:
- Created `R/fa_utils.R` (86 lines) with:
  - `format_loading()` - formats loading values with consistent precision
  - `add_emergency_suffix()` - adds "(n.s.)" suffix to weak factor names
- Removed 76 lines from `shared_text.R`
- `shared_text.R` now contains only truly shared utilities:
  - `count_words()`, `wrap_text()`, `normalize_token_count()`

**Impact**:
- Better code organization and separation of concerns
- Clear pattern for future model types (GM, IRT, CDM)
- Easier maintenance and navigation

**Usage Analysis**:
- `format_loading()`: Used 11 times across FA files
- `add_emergency_suffix()`: Used 2 times in fa_json.R

#### 2. Switch Statement Refactored to S3 Dispatch

**Problem**: Hardcoded switch statement in `handle_raw_data_interpret()` for routing analysis types

**Solution Implemented**:
- Created S3 generic `build_structured_list()` in `s3_model_data.R` (+26 lines)
- Implemented `build_structured_list.fa()` method in `fa_model_data.R` (+13 lines)
- Refactored `handle_raw_data_interpret()` from 57 lines to 32 lines (44% reduction)

**Code Comparison**:
```r
# BEFORE (switch statement)
switch(effective_analysis_type,
  fa = {
    # 15 lines of FA-specific code
  },
  gm = cli::cli_abort(...),
  irt = cli::cli_abort(...),
  cdm = cli::cli_abort(...)
)

# AFTER (S3 dispatch)
fit_results <- build_structured_list(
  x = x,
  analysis_type = effective_analysis_type,
  ...
)
interpret_core(fit_results = fit_results, ...)
```

**Benefits**:
- New model types require ZERO core changes, just add new S3 methods
- Consistent with package's S3 dispatch pattern
- Better type safety and error handling
- 44% code reduction in routing logic

---

### do.call() Parameter Override Bug (2025-11-16)

**Severity**: HIGH - Caused test failures and incorrect parameter passing
**Status**: ✅ FIXED

#### Problem Description

When using `do.call()` to call functions with `...` parameters, named arguments in the `dots` list were overriding explicitly set parameters.

**Example of the bug**:
```r
dots <- list(variable_info = var_info, analysis_type = var_info)  # Mistake in ...

do.call(some_function, c(
  list(
    analysis_type = "fa",  # Correctly set
    variable_info = var_info
  ),
  dots  # But this contains analysis_type = var_info, which OVERRIDES above!
))
```

In R's `do.call()`, when the same parameter name appears multiple times, **the last occurrence wins**. This caused `analysis_type` to receive `variable_info` (a data.frame) instead of `"fa"` (a string).

**Impact**:
- `analysis_data$analysis_type` contained wrong value (data.frame instead of "fa")
- `create_fit_summary()` received data.frame as class name
- R's `structure()` cannot use data.frame as a class attribute
- Tests failed with "attempt to set invalid 'class' attribute"

#### Solution Applied

Filter `dots` to remove any parameters that are explicitly set before merging:

```r
# CORRECT pattern for do.call with ...
my_function <- function(param1, param2, ...) {
  dots <- list(...)

  # Filter out parameters that we're setting explicitly
  dots_filtered <- dots[!names(dots) %in% c("param1", "param2", "other_explicit_params")]

  do.call(target_function, c(
    list(
      param1 = param1,
      param2 = param2
    ),
    dots_filtered
  ))
}
```

#### Files Modified

**R/core_interpret.R** (1 change):
- Line ~457: Added `dots_filtered` for `create_fit_summary()` call

**R/fa_model_data.R** (6 changes):
- Line ~284: `build_analysis_data.list()`
- Line ~329: `build_analysis_data.matrix()`
- Line ~360: `build_analysis_data.data.frame()`
- Line ~429: `build_analysis_data.psych()`
- Line ~477: `build_analysis_data.lavaan()`
- Line ~549: `build_analysis_data.SingleGroupClass()`

#### Testing Results

**Before Fix**: `[ FAIL 10+ | WARN 0 | SKIP 11 | PASS 556 ]`
**After Fix**: `[ FAIL 0 | WARN 0 | SKIP 11 | PASS 607 ]`

All failures related to parameter override resolved.

#### Key Lessons

**R's do.call() Behavior:**
1. Named arguments in `...` override positional arguments
2. **Last occurrence wins** when same name appears multiple times
3. **Always filter `dots` before merging** with explicit parameters

**Code Review Checklist:**
- [ ] Check all `do.call()` uses with `c(list(...), dots)`
- [ ] Ensure `dots` is filtered before merging
- [ ] Add validation for critical parameters
- [ ] Test with config objects that might contain duplicate names

### 3. Parameter Metadata Centralization (2025-11-16)

**Status**: ✅ Completed via parallel subagent execution

**Problem**: Parameter definitions were duplicated across validation code, config objects, and documentation, causing:
- Inconsistent defaults (word_limit: 100/150/100, max_line_length: 80/120)
- ~200 lines of duplicated validation code
- Difficult to add new parameters

**Solution**: Created `PARAMETER_REGISTRY` as centralized source of truth for all 17 parameters.

#### Implementation

**Files Created**:
- `R/core_parameter_registry.R` (625 lines) - Complete parameter registry with metadata
- `tests/testthat/test-28-parameter-registry.R` (533 lines) - Comprehensive test suite (400 tests)

**Helper Functions**:
- `get_param_default(param_name)` - Retrieve default values
- `validate_param(param_name, value, throw_error)` - Single parameter validation
- `validate_params(param_list, throw_error)` - Batch validation
- `get_params_by_group(config_group, model_type)` - Filter by config
- `get_registry_param_names(config_group)` - List parameter names

**Files Modified**:
- `R/shared_config.R` - Config constructors refactored (-181 lines of validation)
- `R/aaa_model_type_dispatch.R` - Fixed forward reference issue (dispatch table → function)

**Registry Structure**:
```r
PARAMETER_REGISTRY <- list(
  word_limit = list(
    default = 150,               # Single source of truth
    type = "integer",
    range = c(20, 500),
    config_group = "llm_args",
    model_specific = NULL,
    required = FALSE,
    validation_fn = function(value) { ... },
    description = "Maximum words for LLM interpretations"
  ),
  # ... 16 more parameters
)
```

#### Key Achievements

1. **Eliminated Duplication**:
   - Removed ~200 lines of duplicated validation code
   - Single source of truth for defaults, ranges, validation

2. **Resolved Conflicts**:
   - `word_limit`: Now consistently 150 (was 100/150/100)
   - `max_line_length`: Now consistently 80 (was 80/120)

3. **Improved Maintainability**:
   - Adding new parameters: Single registry entry
   - Changing defaults: One location
   - Consistent error messages via validation functions

4. **Comprehensive Testing**:
   - 400 new tests for registry functionality
   - All existing tests pass with new system
   - Total test count: 747+ (all passing)

#### Future Benefits

- **Programmatic documentation**: Can generate parameter tables from registry
- **API consistency**: All validation uses same rules
- **Easy extensions**: Adding GM/IRT/CDM parameters is trivial
- **Type safety**: Validation functions ensure correct types

**Reference**: See `dev/archive/PARAMETER_CENTRALIZATION_PLAN.md` for complete implementation plan.

---

### 4. Model Type Dispatch System (2025-11-16)

**Status**: ✅ Completed via parallel subagent execution

**Problem**: Model type checking used scattered `inherits()` calls across 8+ locations, making it difficult to:
- Add new model types (required updates in multiple files)
- Maintain consistent validation logic
- Track which model classes are supported

**Solution**: Created centralized model dispatch system in `R/aaa_model_type_dispatch.R` (383 lines).

#### Implementation

**New Dispatch Infrastructure**:
- `get_model_dispatch_table()`: Maps model classes to analysis types, validators, and extractors
- `is_supported_model()`: O(1) model type checking
- `get_model_info()`: Retrieves dispatch metadata for model objects
- `validate_model_structure()`: Unified validation routing

**Model-Specific Functions** (6 validators + 6 extractors):
- `validate_psych_model()` / `extract_psych_loadings()`: psych::fa(), psych::principal()
- `validate_lavaan_model()` / `extract_lavaan_loadings()`: lavaan::cfa(), lavaan::sem()
- `validate_efalist_model()` / `extract_efalist_loadings()`: lavaan::efa()
- `validate_mirt_model()` / `extract_mirt_loadings()`: mirt::mirt()

**Dispatch Table Structure**:
```r
get_model_dispatch_table <- function() {
  list(
    fa = list(
      analysis_type = "fa",
      package = "psych",
      validator_name = "validate_psych_model",
      extractor_name = "extract_psych_loadings"
    ),
    # ... 5 more model types
  )
}
```

#### Key Benefits

1. **Centralized Configuration**: All model metadata in one dispatch table
2. **Easy Extensions**: Adding new models = 1 dispatch entry + 2 functions
3. **Eliminated Duplication**: Removed 8+ scattered `inherits()` checks
4. **Better Maintainability**: Single source of truth for supported models
5. **Type Safety**: Consistent validation across all model types

**Files Modified**:
- `R/core_interpret_dispatch.R`: Uses `is_supported_model()` instead of manual checks
- `R/fa_model_data.R`: Uses dispatch table extractors

**Testing**: 46 new tests in `tests/testthat/test-29-dispatch-tables.R`

**Reference**: See `dev/archive/DISPATCH_TABLE_SUMMARY.md` (Model Type Dispatch section) for details.

---

### 5. Analysis Type Routing Dispatch (2025-11-16)

**Status**: ✅ Completed via parallel subagent execution

**Problem**: Analysis type routing used if/else chains in 3+ locations, creating:
- Duplicated routing logic across files
- Difficulty adding new analysis types (GM, IRT, CDM)
- Inconsistent parameter validation

**Solution**: Created centralized dispatch tables in `R/shared_config.R` and `R/fa_export.R`.

#### Analysis Type Dispatch (`shared_config.R`)

**Three Dispatch Tables**:
1. `.ANALYSIS_TYPE_DISPLAY_NAMES`: Maps type codes to human-readable names
2. `.VALID_INTERPRETATION_PARAMS`: Maps types to valid parameter names
3. `.INTERPRETATION_ARGS_DISPATCH`: Maps types to constructor functions

**Helper Functions**:
- `.dispatch_lookup()`: Generic dispatch table lookup with fallback
- `.get_analysis_type_display_name()`: Retrieves display name for type
- `.get_valid_interpretation_params()`: Retrieves valid parameters for type

**Usage Example**:
```r
# OLD: if/else chains scattered across functions
if (analysis_type == "fa") {
  params <- c("cutoff", "n_emergency", ...)
} else if (analysis_type == "gm") {
  params <- c("n_components", ...)
}

# NEW: Centralized dispatch
params <- .get_valid_interpretation_params(analysis_type)
```

#### Export Format Dispatch (`fa_export.R`)

**Dispatch Table**: `export_format_dispatch_table()`
- Maps format names ("txt", "md") to configurations
- Contains extension, output format, post-processor function

**Helper Functions**:
- `get_export_format_config()`: Validates and retrieves format config
- `process_export_file_path()`: Handles extension processing
- `apply_export_format()`: Applies format-specific transformations

#### Output Format Dispatch (`fa_report.R`)

**Dispatch Table**: `.format_dispatch_table()`
- Maps output formats ("cli", "markdown") to formatting functions
- Contains header, table, and list formatters

**Impact**: Reduced 15 format conditionals to 2 (87% reduction)

#### Key Benefits

1. **Eliminated If/Else Chains**: 100% elimination of analysis type conditionals
2. **Centralized Routing**: All routing logic in dispatch tables
3. **Easy Extensions**: Adding formats/types = 1 dispatch table entry
4. **Code Reduction**: 87% reduction in format conditionals
5. **Self-Documenting**: Dispatch tables serve as configuration documentation

**Files Modified**:
- `R/shared_config.R`: Analysis type routing (+3 dispatch tables)
- `R/fa_export.R`: Export format routing (+1 dispatch table, +4 helpers)
- `R/fa_report.R`: Output format routing (+1 dispatch table, -13 conditionals)

**Reference**: See `dev/archive/DISPATCH_TABLE_SUMMARY.md` for complete details.

---

### 6. Refactoring Summary and Impact (2025-11-16)

#### Overall Achievements

**Code Quality**:
- Switch statements eliminated: 2 → 0 (100%)
- Format conditionals reduced: 15 → 2 (87%)
- If/else chains eliminated: 3 → 0 (100%)
- Scattered model checks: 8+ → 1 centralized dispatch table

**Testing**:
- Tests added: 446 new tests
- Final test count: 1010 passing (0 failures)
- Coverage increase: Comprehensive dispatch table testing

**Code Organization**:
- New files created: `R/aaa_model_type_dispatch.R`, `R/core_parameter_registry.R`, `R/fa_utils.R`
- Lines of validation removed: ~200 lines
- Total files modified: 23 files

#### Architecture Transformation

**Before**: Scattered conditional logic
```
├── fa_report.R: if (format == "cli") ... else [x15 occurrences]
├── shared_config.R: if (analysis_type == "fa") ... else [x3 chains]
└── core_interpret_dispatch.R: inherits() checks [x8 locations]
```

**After**: Centralized dispatch tables
```
├── Dispatch Tables (6 total)
│   ├── get_model_dispatch_table()
│   ├── .ANALYSIS_TYPE_DISPLAY_NAMES
│   ├── .VALID_INTERPRETATION_PARAMS
│   ├── .INTERPRETATION_ARGS_DISPATCH
│   ├── export_format_dispatch_table()
│   └── .format_dispatch_table()
│
├── Helper Functions (12 reusable)
└── Clean Business Logic (simplified)
```

#### Extensibility Gains

**Adding New Analysis Type** (e.g., Gaussian Mixture):
- **Before**: Modify 6+ files, add 15+ conditionals
- **After**: Update 3 dispatch tables, create 1 constructor function

**Adding New Output Format** (e.g., HTML):
- **Before**: Add 15+ if/else conditions across multiple functions
- **After**: Add 1 dispatch table entry with formatters

**Adding New Model Type** (e.g., new package):
- **Before**: Update 8+ inherits() checks across files
- **After**: Add 1 dispatch entry + validator + extractor

#### Future-Proofing

All completed refactorings establish patterns for planned extensions:
- ✅ GM/IRT/CDM analysis types: Use analysis type dispatch pattern
- ✅ HTML/PDF export: Use export format dispatch pattern
- ✅ New model packages: Use model type dispatch pattern
- ✅ New parameters: Use parameter registry pattern

#### Documentation

**Created** (archived in `dev/archive/`):
- `DISPATCH_TABLE_SUMMARY.md`: Complete refactoring overview
- `PARAMETER_CENTRALIZATION_PLAN.md`: Parameter registry implementation

**Updated**:
- This section (DEVELOPER_GUIDE.md Section 5.3)
- `OPEN_ISSUES.md`: Technical debt status
- `CLAUDE.md`: Dispatch pattern references

### 5.3 Critical Bug Fixes and Lessons Learned

#### CLI Error Message Handling in Parameter Validation (2025-11-16)

**Problem**: When `validate_params()` threw validation errors, CLI was unable to evaluate expressions in error messages, causing:
```
Error: Could not evaluate cli `{}` expression: `value`.
```

**Root Cause**:
- Validation functions return messages with CLI formatting expressions (e.g., `{.arg heading_level}`)
- These messages were passed directly to `cli::cli_abort()`
- CLI tried to evaluate these expressions in a scope where referenced variables didn't exist
- This caused test failures when `expect_error()` tried to match error message patterns

**Solution** (in `R/core_parameter_registry.R:572-588`):
```r
if (!result$valid) {
  all_valid <- FALSE
  if (throw_error) {
    # Pre-format the validation message to resolve any CLI expressions
    # This prevents issues when result$message contains expressions like {.arg x}
    # that reference variables not in the current scope
    formatted_message <- cli::format_inline(result$message)

    # Combine messages into single string so tests can find the full error text
    # We keep the CLI formatting for nice display but ensure e$message contains
    # all the information needed for test assertions
    cli::cli_abort(
      "Validation failed for parameter: {.arg {param_name}}. {formatted_message}",
      .envir = environment()
    )
  }
}
```

**Key Lessons**:
1. **Pre-format messages with variable references**: Use `cli::format_inline()` to resolve CLI expressions before passing to `cli_abort()`
2. **Combine error parts for testability**: When using `cli_abort()`, only the first element goes into `e$message`. Combine parts if tests need to match patterns
3. **Explicit environment specification**: Use `.envir = environment()` to ensure variables are evaluated in the correct scope
4. **Test both display and content**: Ensure error messages both display correctly AND contain expected text in `e$message` for test assertions

**Testing Impact**:
- Fixed failing tests in `test-01-validation.R`
- Ensured `expect_error(..., "pattern")` can match validation details
- Maintained nice CLI formatting in error displays

**Related Documentation**:
- [cli documentation on error handling](https://cli.r-lib.org/reference/cli_abort.html)
- [cli documentation on testing](https://cli.r-lib.org/reference/test_that_cli.html)

---

**Last Updated**: 2025-11-16
**Maintainer**: Update when making architectural changes
