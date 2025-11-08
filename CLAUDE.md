# CLAUDE.md

This file provides guidance to Claude Code when working with the **psychinterpreter** R package.

---

## Quick Reference

**Package Purpose**: Automates interpretation of exploratory factor analysis (EFA) results using Large Language Models via the `ellmer` package.

**Main Entry Points**:
- `interpret()` - Universal generic (recommended for all uses)
- `interpret_fa()` - Direct FA interpretation
- `chat_session()` - Create persistent LLM session (token-efficient for multiple analyses)

**Documentation**:
- **CLAUDE.md** (this file): Usage guide, workflows, and quick reference
- **dev/DEVELOPER_GUIDE.md**: Technical architecture and deep implementation details

**Test/Example Standards**:
- Always use `provider = "ollama"` and `model = "gpt-oss:20b-cloud"`
- For LLM tests: `word_limit = 20` (minimum allowed) for token efficiency

---

## Table of Contents

1. [Package Overview](#package-overview)
2. [Quick Start Guide](#quick-start-guide)
3. [Usage Patterns](#usage-patterns)
4. [File Organization](#file-organization)
5. [Development Workflow](#development-workflow)
6. [Testing Guidelines](#testing-guidelines)
7. [Common Pitfalls](#common-pitfalls)
8. [Troubleshooting](#troubleshooting)
9. [TODOs & Future Work](#todos--future-work)

---

# Package Overview

## What It Does

**psychinterpreter** automates interpretation of exploratory factor analysis (EFA) results using Large Language Models. It interfaces with OpenAI, Anthropic, Ollama, Gemini, and Azure to generate human-readable factor names and interpretations.

## Core Features

1. **LLM-Powered Interpretation** (R/fa_interpret.R, ~645 lines):
   - Constructs structured prompts with psychometric context
   - Processes ALL factors in a single LLM call (batch optimization)
   - Includes factor correlations for oblique rotations
   - Supports persistent chat sessions to save tokens (~40-60% savings)

2. **Factor Analysis Preparation** (R/fa_diagnostics.R):
   - Analyzes loadings against configurable cutoffs
   - Identifies significant loadings per factor
   - Applies "emergency rule" for weak factors (uses top N variables if none exceed cutoff)
   - Detects cross-loadings and orphaned variables

3. **Report Generation** (R/report_fa.R):
   - Builds reports in text or markdown format
   - Includes interpretations, cross-loadings, and diagnostics
   - Text wrapping for console output
   - S3 method `build_report.fa_interpretation()` integrates with core system

4. **S3 Methods for Common Packages**:
   - `psych::fa()` and `psych::principal()`
   - `lavaan::cfa()`, `lavaan::sem()`, and `lavaan::efa()`
   - `mirt::mirt()`

## Key Architectural Points

- **S3 Dispatch System**: Generic `interpret()` function with model-specific S3 methods
- **Persistent Chat Sessions**: Reusable LLM sessions that preserve system prompts (R/base_chat_session.R)
- **Dual-Tier Token Tracking**: Cumulative (session-level) + per-run tracking
- **Extensible Design**: Adding new model types requires implementing 7 S3 methods

**📁 For detailed architecture**: See [dev/DEVELOPER_GUIDE.md](dev/DEVELOPER_GUIDE.md)

---

# Quick Start Guide

## Installation

```r
# Install from GitHub (adjust path as needed)
devtools::install_github("username/psychinterpreter")
```

## Basic Usage

```r
library(psychinterpreter)

# 1. Run factor analysis
fa_result <- psych::fa(data, nfactors = 3)

# 2. Prepare variable descriptions
var_info <- c(
  "var1" = "Description of variable 1",
  "var2" = "Description of variable 2",
  # ...
)

# 3. Get interpretation
interpretation <- interpret(
  model_fit = fa_result,
  variable_info = var_info,
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud"
)

# 4. View results
print(interpretation)
plot(interpretation)
```

## Token-Efficient Multiple Analyses

```r
# Create session once
chat <- chat_session(
  model_type = "fa",
  provider = "ollama",
  model = "gpt-oss:20b-cloud"
)

# Use for multiple interpretations (saves ~40-60% tokens)
result1 <- interpret(chat_session = chat, model_fit = fa1, variable_info = vars1)
result2 <- interpret(chat_session = chat, model_fit = fa2, variable_info = vars2)
result3 <- interpret(chat_session = chat, model_fit = fa3, variable_info = vars3)

# Check token usage
print(chat)
```

---

# Usage Patterns

The `interpret()` function is the main entry point. All arguments are **named** to prevent positional confusion.
For usage patterns see the roxygen docs in R/interpret_method_dispatch.R

**Key Points:**
- All arguments are **named** - no positional confusion
- `model_fit` accepts: fitted models, matrices, data.frames, or structured lists
- `additional_info` is a separate parameter, not part of model_fit list
- Chat sessions work with any model_fit type

**Pattern Recommendations:**
- **Single analysis**: Pattern 1 (fitted model) - simplest
- **Multiple analyses**: Pattern 4 (chat session) - most efficient
- **Custom data**: Pattern 2 (raw matrix) or Pattern 3 (structured list)

## Visualizing Results

```r
# S3 plot method (recommended)
plot(interpretation)

# Or backward-compatible wrapper
create_factor_plot(interpretation)

# Customize and save
p <- plot(interpretation) +
  ggplot2::labs(title = "Factor Loadings") +
  ggplot2::theme(axis.text.y = ggplot2::element_text(size = 8))
ggsave("loadings.png", p, width = 10, height = 8)
```

## Exporting Results

```r
# Export to text file
export_interpretation(interpretation, "results.txt", format = "txt")

# Export to markdown
export_interpretation(interpretation, "results.md", format = "md")
```

---

# File Organization

## Active R Files (15 files, ~4,654 lines)

### Core Infrastructure (5 files, ~1,054 lines)
- `generic_interpret.R` (392) - Main interpretation orchestration
- `generic_json_parser.R` (200) - Multi-tier JSON parsing with S3
- `generic_prompt_builder.R` (83) - S3 generics for prompts
- `base_chat_session.R` (287) - Chat session management
- `base_interpretation.R` (92) - Base interpretation objects

### Factor Analysis Implementation (7 files, ~3,154 lines)
- `fa_interpret.R` (645) - Main FA interpretation function
- `fa_prompt_builder.R` (340) - FA prompts (S3 methods)
- `fa_json.R` (232) - FA JSON parsing (S3 methods)
- `fa_diagnostics.R` (199) - Diagnostics + S3 method
- `interpret_methods.R` (744) - S3 methods for psych/lavaan/mirt
- `interpret_helpers.R` (156) - Validation and routing
- `report_fa.R` (838) - Report building + S3 method

### Utilities (3 files, ~446 lines)
- `export_functions.R` (132) - Export to txt/md
- `utils_text_processing.R` (107) - Text wrapping, word counting
- `visualization.R` (207) - S3 plot method, heatmaps

### Archive (8 files, not loaded)
Old implementations kept for reference in `R/archive/`

## Test Structure

```
tests/testthat/
├── fixtures/fa/            # Factor analysis test data
│   ├── sample_*.rds        # Standard fixtures (5 vars × 3 factors)
│   ├── minimal_*.rds       # Token-efficient (3 vars × 2 factors)
│   ├── correlational_*.rds # Realistic FA data (6 vars × 2 factors)
│   └── make-*.R            # Regeneration scripts
├── helper.R                # Test helper functions
└── test-*.R                # 7 test files (70+ tests total)
```

---

# Development Workflow

## Common Commands

```r
# Documentation
devtools::document()         # Generate docs from roxygen2 comments

# Testing
devtools::test()             # Run all tests
testthat::test_file("tests/testthat/test-interpret_fa.R")  # Single file

# Checking
devtools::check()            # Run R CMD check
devtools::install()          # Install locally
devtools::load_all()         # Load for development
```

## Debugging

```r
# Enable LLM prompt/response visibility
interpret_fa(..., echo = "all")

# Or with interpret() generic
interpret(
  model_fit = ...,
  variable_info = ...,
  echo = "all"
)

# Check token usage
chat <- chat_session(model_type = "fa", provider = "ollama", model = "gpt-oss:20b-cloud")
result <- interpret(
  chat_session = chat,
  model_fit = loadings,
  variable_info = var_info
)
print(chat)  # Displays token counts
```

## LLM Provider Configuration

API keys must be set as environment variables:

```r
Sys.setenv(OPENAI_API_KEY = "your-key")      # OpenAI
Sys.setenv(ANTHROPIC_API_KEY = "your-key")   # Anthropic
# Ollama (local): no key needed
```

## Code Style Conventions

**Required:**
- **Roxygen2 documentation** for all exported functions
- **Explicit namespacing**: Use `package::function()` (e.g., `dplyr::mutate()`)
- **CLI messaging**: Use `cli` package (`cli_alert_info`, `cli_abort`, `cli_inform`)
- **Pipe operator**: Base R `|>` (not magrittr `%>%`)
- **Parameter validation**: Extensive validation with informative errors at function start

**Naming Conventions:**
- **Files**: `generic_*` (core), `fa_*` (FA-specific), `base_*` (infrastructure), `utils_*` (utilities)
- **Functions**: snake_case
- **S3 methods**: `method.class()` format
- **Internal functions**: Prefix with `.` (e.g., `.internal_helper()`)

---

# Testing Guidelines

- See dev/TESTING_GUIDELINES.md for specific testing guidelines
- After making changes to the code base, always run the full test suite. Fix errors and warnings if necessary.


---

# Common Pitfalls

## 1. Positional Argument Confusion

**Problem**: Calling `interpret()` with positional arguments instead of named arguments

```r
# ❌ WRONG - positional arguments
interpret(chat, loadings, var_info)

# ✅ CORRECT - named arguments
interpret(
  chat_session = chat,
  model_fit = loadings,
  variable_info = var_info
)
```

## 2. Missing model_type for Raw Data

**Problem**: Forgetting to specify `model_type` when using raw matrices/data.frames

```r
# ❌ WRONG - missing model_type
interpret(
  model_fit = loadings_matrix,
  variable_info = var_info
)

# ✅ CORRECT - include model_type
interpret(
  model_fit = loadings_matrix,
  variable_info = var_info,
  model_type = "fa"
)
```

## 3. Not Using Chat Sessions for Multiple Analyses

**Problem**: Creating new sessions for each interpretation (wastes tokens)

```r
# ❌ INEFFICIENT - creates new session each time
result1 <- interpret(model_fit = fa1, variable_info = vars1, llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")
result2 <- interpret(model_fit = fa2, variable_info = vars2, llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")
result3 <- interpret(model_fit = fa3, variable_info = vars3, llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")

# ✅ EFFICIENT - reuse session (saves ~40-60% tokens)
chat <- chat_session(model_type = "fa", provider = "ollama", model = "gpt-oss:20b-cloud")
result1 <- interpret(chat_session = chat, model_fit = fa1, variable_info = vars1)
result2 <- interpret(chat_session = chat, model_fit = fa2, variable_info = vars2)
result3 <- interpret(chat_session = chat, model_fit = fa3, variable_info = vars3)
```

## 4. Using Magrittr Pipe Instead of Base Pipe

**Problem**: Using `%>%` instead of `|>` in package code

```r
# ❌ WRONG - magrittr pipe
data %>% dplyr::filter(x > 0)

# ✅ CORRECT - base R pipe
data |> dplyr::filter(x > 0)
```

## 5. Forgetting to Document After Roxygen2 Changes

**Problem**: Modifying roxygen2 comments but not regenerating documentation

```r
# After modifying roxygen2 comments in R files:
devtools::document()  # ✅ ALWAYS run this
```

## 6. Including additional_info in model_fit List

**Problem**: Treating `additional_info` as part of the model_fit list

```r
# ❌ WRONG - additional_info inside model_fit
interpret(
  model_fit = list(
    loadings = loadings_matrix,
    Phi = phi_matrix,
    additional_info = "Some context"  # Wrong!
  ),
  variable_info = var_info,
  model_type = "fa"
)

# ✅ CORRECT - additional_info as separate parameter
interpret(
  model_fit = list(
    loadings = loadings_matrix,
    Phi = phi_matrix
  ),
  variable_info = var_info,
  additional_info = "Some context",  # Separate parameter
  model_type = "fa"
)
```

## 7. Testing with High word_limit

**Problem**: Using high word_limit in tests (wastes tokens and time)

```r
# ❌ INEFFICIENT - high word limit
interpret_fa(loadings, var_info, word_limit = 150)  # Default

# ✅ EFFICIENT - minimum word limit for tests
interpret_fa(loadings, var_info, word_limit = 20)  # Minimum allowed
```

---

# Troubleshooting

## Issue: "Error: model_type must be specified"

**Cause**: Using raw data (matrix/data.frame) without specifying model_type

**Solution**: Add `model_type = "fa"` parameter
```r
interpret(
  model_fit = loadings,
  variable_info = var_info,
  model_type = "fa"  # Add this
)
```

## Issue: "Error: Documented arguments not in usage"

**Cause**: Roxygen2 documentation out of sync with function signature

**Solution**: Regenerate documentation
```r
devtools::document()
```

## Issue: Tests Taking Too Long

**Cause**: Too many LLM tests or using high word_limit

**Solution**:
1. Use cached interpretations instead of LLM calls
2. Set `word_limit = 20` in LLM tests
3. Use `minimal_*` fixtures instead of `sample_*` fixtures
4. Skip LLM tests on CI with `skip_on_ci()`

## Issue: Negative Token Counts

**Cause**: System prompt caching issue (should be fixed in current version)

**Solution**: Update to latest version (token tracking uses `max(0, delta)` protection)

## Issue: JSON Parsing Failures

**Cause**: LLM returned malformed JSON

**Solution**: Package has multi-tier fallback:
1. Cleaned JSON parsing
2. Pattern-based extraction
3. Default values

Check output with `echo = "all"` to see raw LLM response:
```r
interpret_fa(..., echo = "all")
```

## Issue: Word Limit Messages

**Cause**: LLM response exceeded word_limit parameter

**Solution**: This is informational (uses `cli_inform()`, not an error). Options:
1. Increase `word_limit` parameter
2. Ignore if acceptable
3. Check interpretation quality

---

# TODOs & Future Work

## Completed TODOs

- ✅ **interpret() generic dispatch** (2025-11-07)
  - Supports model objects with automatic extraction
  - Supports raw data with model_type specification
  - Supports chat_session as first argument
  - Full validation of model, chat_session, and model_type consistency

- ✅ **Code cleanup and archiving** (2025-11-07)
  - Archived 8 redundant/old files
  - Removed 3 duplicate R source files (~1,559 lines)
  - Established single source of truth for all components

- ✅ **Documentation overhaul** (2025-11-07)
  - Deleted outdated dev/STATUS.md and dev/FILE_STRUCTURE.md
  - Created comprehensive dev/DEVELOPER_GUIDE.md
  - Updated CLAUDE.md to reflect current package state

- ✅ **Test suite optimization** (2025-11-07)
  - Fixture caching (40x speedup)
  - Reduced LLM calls from 33+ to ~7
  - Separated data extraction from LLM interpretation tests

- ✅ **LLM testing strategy implementation** (2025-11-08)
  - Integrated into dev/TESTING_GUIDELINES.md
  - Current targets: 2 tests per model class using generic API, S3 methods without LLM calls, 1 test for chat sessions
  - Test files follow pattern: test-interpret_fa.R, test-interpret_api.R, test-chat_fa.R

- ✅ **Silent parameter enhancement** (2025-11-08)
  - Changed from boolean to integer (0, 1, 2) for granular output control
  - 0 = report + messages, 1 = messages only, 2 = completely silent
  - Full backward compatibility (TRUE→1, FALSE→0)
  - Updated: fa_interpret.R, generic_interpret.R, interpret_method_dispatch.R, generic_export.R
  - Documentation regenerated for all affected functions

- ✅ **_pkgdown.yml audit and update** (2025-11-08)
  - Added missing functions: chat_session(), is.chat_session(), reset.chat_session(), is.interpretation(), print.chat_session()
  - Created new "Chat Session Management" section
  - Reorganized reference structure for better navigation

- ✅ **Fix chat session model_type message** (2025-11-08)
  - Fixed spurious message "ℹ The inherited chat session model_type ("fa") was used instead of the passed interpretation model_type"
  - Message now only appears when there's an actual mismatch between passed model_type and chat_session's model_type
  - Prevents confusing message when model_type is automatically inferred from fitted model objects

- ✅ **Fix silent parameter behavior** (2025-11-08)
  - Fixed bug where `silent = 0` and `silent = 1` both showed the report
  - Changed TRUE conversion from `TRUE -> 1` to `TRUE -> 2` for complete silence
  - Now works correctly:
    - `silent = 0` or `FALSE`: Show report + messages
    - `silent = 1`: Show messages only, suppress report
    - `silent = 2` or `TRUE`: Completely silent (no report, no messages)
  - Updated 4 core files: generic_interpret.R, fa_interpret.R, interpret_method_dispatch.R, generic_export.R
  - All 70 tests passing

## Active TODOs
- in interpret(), system_prompt and interpretation_guidelines are not specific to the class but are available arguments for all classes. Relocate them accordingly in the docs and in the argument order, maybe after llm specific arguments.
- revisit the LLM call guidelines in the TEST_GUIDELINES.md


### High Priority

1. **Update class-specific interpret functions documentation**
   - Sync interpret_fa() roxygen docs with interpret() generic
   - Ensure all parameters consistently documented
   - Verify examples are current

### Medium Priority

2. **Conduct interactive code review**
   - Scope: generic_interpret.R, fa_interpret.R, base_chat_session.R
   - Review architecture decisions
   - Identify potential improvements
   - Document best practices

3. **Screen package for inconsistent and redundant code**
   - Last audit: 2025-11-07 (removed 3 duplicate files)
   - Check for logic duplication in core functions
   - Consider using automated code analysis tools

4. **Implement summary method**
   - For chat_session objects: Show session stats and token usage
   - For fa_interpretation objects: Show suggested factor names only
   - Quick overview without full report

5. **Analyze tests for runtime/token improvements**
   - Tests are optimized but may have further opportunities
   - Review fixture usage patterns
   - Consider additional caching strategies

### Low Priority

6. **Implement gaussian_mixture class**
   - Add GM interpretation support
   - Requires 7 S3 methods (see dev/DEVELOPER_GUIDE.md section 1.8)

7. **Implement IRT interpretation class**
   - Focus on item diagnostics
   - Support mirt package outputs

8. **Implement CDM interpretation class**
   - Focus on q-matrix interpretation
   - Support GDINA package outputs

---

# Key Implementation Details

## Emergency Rule Logic

If a factor has zero loadings above cutoff:
- Uses top `n_emergency` highest absolute loadings instead
- Clearly marked with WARNING in output
- Factor names get "(n.s.)" suffix to indicate non-significant loadings
- Can set `n_emergency = 0` to label as "undefined" instead

## Word Limit Enforcement

Targets 80-100% of `word_limit` parameter:
- System prompt includes explicit word targets
- Post-processing validates and **informs** (via `cli::cli_inform()`) if exceeded
- Helper function `count_words()` in utils_text_processing.R
- Changed from warning to message (2025-11-03) to reduce noise

## JSON Parsing Strategy

Multi-tiered fallback for robust LLM response handling:
1. Try parsing cleaned JSON (remove extra text, fix formatting)
2. Fall back to original response
3. Pattern-based extraction if JSON parsing fails (via S3 method `extract_by_pattern.fa()`)
4. Default values if all methods fail (via S3 method `create_default_result.fa()`)

Critical for handling small/local models with imperfect JSON output.
See R/generic_json_parser.R and R/fa_json.R.

## System Prompt Architecture

The psychometric expert system prompt is defined in **ONE location**:
- `R/fa_prompt_builder.R` via S3 method `build_system_prompt.fa()`
- Used by both single-use and persistent sessions
- **Single source of truth** - no duplication

## Token Tracking System

**Dual-tier system** prevents negative accumulation:
- **Cumulative** (session-level): `chat_session$total_input_tokens`, `chat_session$total_output_tokens`
- **Per-run** (interpretation-level): `interpretation$run_tokens`
- **System prompt**: Tracked separately in `chat_session$system_prompt_tokens`

**Key feature**: Conditional system prompt inclusion
- Temporary session: System prompt included in run_tokens
- Persistent session: System prompt excluded from run_tokens (sent previously)

See dev/DEVELOPER_GUIDE.md section 2 for full details.

---

# Recent Changes

## 2025-11-08: Silent Parameter Enhancement & Documentation Updates

- **Silent Parameter Refactor**:
  - Changed from boolean to integer (0, 1, 2) for granular output control
  - 0 = show report and messages, 1 = messages only, 2 = completely silent
  - Full backward compatibility maintained (TRUE→1, FALSE→0)
  - Updated 4 core R files with comprehensive roxygen documentation

- **_pkgdown.yml Improvements**:
  - Added 5 missing exported functions to reference
  - Created dedicated "Chat Session Management" section
  - Reorganized structure for better navigation

- **CLAUDE.md Cleanup**:
  - Removed duplicate TODOs between Active and prioritized sections
  - Moved completed items to "Completed TODOs" section
  - Renumbered and reorganized for clarity

## 2025-11-07: Test Suite Optimization & Code Cleanup

- **Test Suite Optimization**:
  - Fixture caching: 40x speedup (97.6% time reduction)
  - LLM testing strategy: 33+ calls → ~7 calls
  - Separated data extraction from LLM interpretation tests

- **Major Code Cleanup**:
  - Removed 3 duplicate R files (~1,559 lines)
  - Archive contains 8 old/redundant files
  - Established single source of truth for all components

- **Documentation Overhaul**:
  - Created comprehensive dev/DEVELOPER_GUIDE.md
  - Deleted outdated dev/STATUS.md and dev/FILE_STRUCTURE.md
  - Refactored CLAUDE.md for maximum utility

## 2025-11-05: Enhanced Parameters

- **hide_low_loadings parameter**: Hide non-significant loadings to reduce token usage
- **n_emergency = 0 support**: Allow undefined factors instead of forcing interpretation
- **Emergency rule indicator**: "(n.s.)" suffix on factor names from emergency rule

## 2025-11-04: Token Tracking Fix

- Fixed system prompt token capture for persistent chat sessions
- Added `system_prompt_captured` flag

## 2025-11-03: Major Refactoring

- Dual-tier token tracking system
- `interpret()` generic for psych/lavaan/mirt packages
- Export simplification (txt/md only)
- Three test fixture sets
- Word limit messaging improvement

---

# Package Information

## Exported Functions (9)

- `interpret_fa()` - Core factor interpretation with LLM
- `interpret()` - S3 generic for common FA packages
- `chat_fa()`, `is.chat_fa()`, `reset.chat_fa()` - Session management (deprecated, use `chat_session()`)
- `find_cross_loadings()`, `find_no_loadings()` - Diagnostic utilities
- `export_interpretation()` - Export to txt/md formats
- `create_factor_plot()` - Plotting wrapper

## Exported S3 Methods (10+)

- `interpret.fa()`, `interpret.principal()`, `interpret.lavaan()`, `interpret.efaList()`, `interpret.SingleGroupClass()`, `interpret.psych()`, `interpret.default()`
- `print.fa_interpretation()`, `print.chat_fa()`
- `plot.fa_interpretation()`

## Dependencies

**Imports (required):**
- `ellmer` - LLM communication
- `dplyr`, `tidyr` - Data manipulation
- `ggplot2` - Visualization
- `cli` - User messaging
- `jsonlite` - JSON parsing

**Suggests (optional):**
- `psych`, `lavaan`, `mirt` - For S3 method support
- `testthat` - Testing framework
- `knitr`, `rmarkdown` - Vignettes

## Version & License

- **Version**: 0.0.0.9000 (development)
- **R requirement**: >= 4.1.0
- **License**: MIT + file LICENSE

## Known Issues

None currently.


---

**Last Updated**: 2025-11-08
**Maintainer**: Update when making significant changes
