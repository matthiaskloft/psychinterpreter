# CLAUDE.md

**Purpose**: Quick reference for Claude Code when helping users with the **psychinterpreter** R package.

**For technical/architectural details**: See [dev/DEVELOPER_GUIDE.md](dev/DEVELOPER_GUIDE.md)

---

## Quick Reference

**What It Does**: Automates interpretation of exploratory factor analysis (EFA) results using Large Language Models via the `ellmer` package.

**Main Entry Points**:
- `interpret()` - Universal generic (recommended for all uses)
- `interpret_fa()` - Direct FA interpretation function
- `chat_session()` - Create persistent LLM session (saves ~40-60% tokens for multiple analyses)

**Standards for Examples/Tests**:
- Always use `provider = "ollama"` and `model = "gpt-oss:20b-cloud"`
- For LLM tests: `word_limit = 20` (minimum allowed) for token efficiency

**Documentation Structure**:
- **CLAUDE.md** (this file): Usage guide and quick reference for Claude Code sessions
- **dev/DEVELOPER_GUIDE.md**: Technical architecture and implementation details for maintainers
- **dev/TESTING_GUIDELINES.md**: Testing standards and patterns

---

## Table of Contents

1. [Basic Usage](#basic-usage)
2. [Usage Patterns](#usage-patterns)
3. [Common Workflows](#common-workflows)
4. [Common Pitfalls](#common-pitfalls)
5. [Troubleshooting](#troubleshooting)
6. [Active TODOs](#active-todos)
7. [Quick Reference Tables](#quick-reference-tables)

---

# Basic Usage

## Installation

```r
devtools::install_github("username/psychinterpreter")
```

## Single Analysis

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

# 4. View and export results
print(interpretation)                                    # Print report
plot(interpretation)                                     # Visualize loadings
export_interpretation(interpretation, "results.md", "md") # Export
```

## Multiple Analyses (Token-Efficient)

```r
# Create session once (saves ~40-60% tokens)
chat <- chat_session(
  model_type = "fa",
  provider = "ollama",
  model = "gpt-oss:20b-cloud"
)

# Reuse for multiple interpretations
result1 <- interpret(chat_session = chat, model_fit = fa1, variable_info = vars1)
result2 <- interpret(chat_session = chat, model_fit = fa2, variable_info = vars2)
result3 <- interpret(chat_session = chat, model_fit = fa3, variable_info = vars3)

# Check cumulative token usage
print(chat)
```

---

# Usage Patterns

The `interpret()` function accepts different input types. **All arguments are named** to prevent confusion.

## Pattern 1: Fitted Model Objects (Recommended)

```r
# Automatically extracts loadings from model objects
interpret(
  model_fit = psych::fa(...),        # Or lavaan::efa(), mirt::mirt(), etc.
  variable_info = var_info,
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud"
)
```

**Supported model types**:
- `psych::fa()`, `psych::principal()`
- `lavaan::cfa()`, `lavaan::sem()`, `lavaan::efa()`
- `mirt::mirt()`

## Pattern 2: Structured List

```r
# For custom data structures
interpret(
  model_fit = list(
    loadings = loadings_matrix,
    Phi = correlation_matrix          # Optional (for oblique rotations)
  ),
  variable_info = var_info,
  model_type = "fa",                  # REQUIRED for lists
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud"
)
```

## Pattern 3: With Chat Session (Token-Efficient)

```r
# Create session once
chat <- chat_session(model_type = "fa", provider = "ollama", model = "gpt-oss:20b-cloud")

# Use with any model_fit type
interpret(chat_session = chat, model_fit = fa_result, variable_info = var_info)
interpret(chat_session = chat, model_fit = loadings_list, variable_info = var_info)  # Structured list works too
```

**When to use each**:
- **Single analysis**: Pattern 1 (fitted model) - simplest
- **Multiple analyses**: Pattern 3 (chat session) - most efficient
- **Custom data**: Pattern 2 (structured list)

---

# Common Workflows

## Debugging LLM Issues

```r
# View full prompts and responses
interpret(..., echo = "all")

# Check JSON parsing with raw response
interpret_fa(..., echo = "all")
```

## Customizing Output

```r
# Control verbosity
interpret(..., silent = 0)  # Show report + messages (default)
interpret(..., silent = 1)  # Messages only, no report
interpret(..., silent = 2)  # Completely silent

# Output formats
interpret(..., output_format = "text")      # Default: plain text
interpret(..., output_format = "markdown")  # Markdown format
```

## Working with Weak Factors

```r
# Emergency rule: use top N loadings if none exceed cutoff
interpret(..., n_emergency = 3)  # Use top 3 loadings (default)
interpret(..., n_emergency = 0)  # Label weak factors as "undefined"

# Hide non-significant loadings to save tokens
interpret(..., hide_low_loadings = TRUE)
```

## API Configuration

```r
# Set API keys as environment variables
Sys.setenv(OPENAI_API_KEY = "your-key")      # OpenAI
Sys.setenv(ANTHROPIC_API_KEY = "your-key")   # Anthropic
# Ollama (local): no key needed
```

---

# Common Pitfalls

## 1. Positional vs Named Arguments

```r
# ❌ WRONG - positional arguments
interpret(chat, loadings, var_info)

# ✅ CORRECT - named arguments
interpret(chat_session = chat, model_fit = loadings, variable_info = var_info)
```

## 2. Missing model_type for Structured Lists

```r
# ❌ WRONG
interpret(
  model_fit = list(loadings = loadings_matrix),
  variable_info = var_info
)

# ✅ CORRECT
interpret(
  model_fit = list(loadings = loadings_matrix),
  variable_info = var_info,
  model_type = "fa"
)
```

## 3. Not Reusing Chat Sessions

```r
# ❌ INEFFICIENT - creates new session each time (~2x token cost)
result1 <- interpret(model_fit = fa1, variable_info = vars1, llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")
result2 <- interpret(model_fit = fa2, variable_info = vars2, llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")

# ✅ EFFICIENT - reuse session (saves ~40-60% tokens)
chat <- chat_session(model_type = "fa", provider = "ollama", model = "gpt-oss:20b-cloud")
result1 <- interpret(chat_session = chat, model_fit = fa1, variable_info = vars1)
result2 <- interpret(chat_session = chat, model_fit = fa2, variable_info = vars2)
```

## 4. Wrong Pipe Operator in Package Code

```r
# ❌ WRONG - magrittr pipe
data %>% dplyr::filter(x > 0)

# ✅ CORRECT - base R pipe
data |> dplyr::filter(x > 0)
```

## 5. additional_info Parameter Location

```r
# ❌ WRONG - additional_info inside model_fit list
interpret(
  model_fit = list(loadings = loadings, additional_info = "Context"),
  variable_info = var_info, model_type = "fa"
)

# ✅ CORRECT - additional_info as separate parameter
interpret(
  model_fit = list(loadings = loadings),
  variable_info = var_info,
  additional_info = "Context",  # Separate parameter
  model_type = "fa"
)
```

## 6. Forgetting Documentation Regeneration

```r
# After modifying roxygen2 comments in R files:
devtools::document()  # ✅ ALWAYS run this
```

## 7. High word_limit in Tests

```r
# ❌ INEFFICIENT
interpret_fa(loadings, var_info, word_limit = 150)  # Default, wastes tokens in tests

# ✅ EFFICIENT
interpret_fa(loadings, var_info, word_limit = 20)   # Minimum allowed
```

---

# Troubleshooting

## "Error: model_type must be specified"

**Cause**: Using structured list without specifying model_type

**Solution**:
```r
interpret(
  model_fit = list(loadings = loadings_matrix),
  variable_info = var_info,
  model_type = "fa"
)
```

## "Error: Documented arguments not in usage"

**Cause**: Roxygen2 documentation out of sync

**Solution**:
```r
devtools::document()
```

## Tests Taking Too Long

**Causes & Solutions**:
1. Too many LLM tests → Use cached interpretations instead
2. High word_limit → Set `word_limit = 20` in tests
3. Large fixtures → Use `minimal_*` fixtures for LLM tests
4. Running on CI → Add `skip_on_ci()` to LLM tests

## JSON Parsing Failures

**Cause**: LLM returned malformed JSON

**Package handles automatically** via multi-tier fallback:
1. Cleaned JSON parsing
2. Pattern-based extraction
3. Default values

**To debug**: Use `echo = "all"` to see raw LLM response
```r
interpret_fa(..., echo = "all")
```

## Word Limit Messages

**Cause**: LLM response exceeded `word_limit` parameter

**This is informational** (not an error). Options:
1. Increase `word_limit` if needed
2. Ignore if output quality is acceptable
3. Review interpretation for verbosity

## Negative/Zero Token Counts

**Cause**: Provider-specific behavior
- **Ollama**: No token tracking support (returns 0)
- **Anthropic**: Caches system prompts (may undercount)
- **OpenAI**: Generally accurate

**Solution**: Current version uses `max(0, delta)` protection to prevent negatives

---

# Active TODOs

## High Priority

1. **Update interpret_fa() documentation**
   - Sync roxygen docs with interpret() generic
   - Ensure all parameters consistently documented

## Medium Priority

2. **Code review** - Review generic_interpret.R, fa_interpret.R, base_chat_session.R for improvements

3. **Screen for redundant code** - Check for logic duplication in core functions

4. **Implement summary() method**
   - For chat_session: Show stats and token usage
   - For fa_interpretation: Show factor names only

5. **Optimize tests further** - Review fixture usage and caching strategies

## Low Priority

6. **Implement gaussian_mixture class** - Requires 7 S3 methods (see dev/DEVELOPER_GUIDE.md)

7. **Implement IRT interpretation class** - Item diagnostics support

8. **Implement CDM interpretation class** - Q-matrix interpretation support

---

# Quick Reference Tables

## Key Functions

| Function | Purpose |
|----------|---------|
| `interpret()` | Universal interpretation function (recommended) |
| `interpret_fa()` | Direct FA interpretation |
| `chat_session()` | Create persistent LLM session |
| `export_interpretation()` | Export to txt/md files |
| `plot.fa_interpretation()` | Visualize factor loadings |
| `find_cross_loadings()` | Identify cross-loading variables |
| `find_no_loadings()` | Identify orphaned variables |

## Key Parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `silent` | 0, 1, 2 | 0 | 0=report+messages, 1=messages only, 2=silent |
| `output_format` | "text", "markdown" | "text" | Report format |
| `word_limit` | 20-500 | 150 | Max words per factor interpretation |
| `n_emergency` | 0-10 | 3 | Top N loadings for weak factors (0=undefined) |
| `hide_low_loadings` | TRUE/FALSE | FALSE | Hide non-significant loadings in prompt |
| `echo` | "all", "none" | "none" | Show LLM prompts/responses |

## Package Files

**See dev/DEVELOPER_GUIDE.md section 1.3 for detailed file structure**

| Category | Key Files |
|----------|-----------|
| **Core** | generic_interpret.R, base_chat_session.R |
| **FA Implementation** | fa_interpret.R, fa_prompt_builder.R, interpret_methods.R |
| **Utilities** | export_functions.R, visualization.R, utils_text_processing.R |
| **Tests** | tests/testthat/ (7 test files, 70+ tests) |

## Development Commands

```r
devtools::document()                                      # Regenerate documentation
devtools::test()                                          # Run all tests
testthat::test_file("tests/testthat/test-interpret_fa.R") # Run single test file
devtools::check()                                         # R CMD check
devtools::load_all()                                      # Load for development
```

## Code Style (Brief)

- **Roxygen2** for all exported functions
- **Explicit namespacing**: `package::function()`
- **CLI messaging**: Use `cli::cli_*()` functions
- **Pipe**: Base R `|>` (not `%>%`)
- **Naming**: snake_case for functions, S3 methods as `method.class()`

**For detailed style guide**: See dev/DEVELOPER_GUIDE.md section 5.7

---

# Maintaining Documentation

## When to Update CLAUDE.md

Update this file when making **user-facing changes**:
- New user-facing functions or parameters
- Changes to usage patterns or workflows
- New common pitfalls discovered
- Changes to troubleshooting recommendations
- Adding new Active TODOs

**Keep concise** - focus on "how to use", not "how it works internally"

**When completing TODOs**:
1. Remove from "Active TODOs" section in CLAUDE.md
2. Add to DEVELOPER_GUIDE.md section 4.2 (Package History) with date and details
3. Update "Last Updated" date in both files

## When to Update dev/DEVELOPER_GUIDE.md

Update the developer guide when making **architectural or implementation changes**:
- Changes to S3 dispatch system
- Token tracking implementation modifications
- New model type implementations (GM, IRT, CDM)
- File structure reorganization
- Design decision changes
- Code style updates
- Package history entries (completed TODOs, major refactors, bug fixes)

**Include technical details** - flow diagrams, code locations (file:line), implementation rationale

## Document Maintenance Guidelines

1. **Clear separation**: CLAUDE.md = usage guide, DEV GUIDE = technical reference
2. **Cross-reference**: Link between documents rather than duplicating content
3. **Update dates**: Change "Last Updated" when making significant edits
4. **Version TODOs**: When completing TODOs from CLAUDE.md, move them to DEV GUIDE section 4 (Package History) with dates
5. **Keep current**: Delete obsolete sections, update examples to match current API

---

**Last Updated**: 2025-11-09
**Maintainer**: Update when making significant user-facing changes
- as long as the package is in version 0.0.0.9000, backwards-compatibility can be ignored in development since the package is not officially released