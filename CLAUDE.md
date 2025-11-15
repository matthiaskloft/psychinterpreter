# CLAUDE.md

**Purpose**: Quick reference for Claude Code when helping users with the **psychinterpreter** R package.

**For technical/architectural details**: See [dev/DEVELOPER_GUIDE.md](dev/DEVELOPER_GUIDE.md)

**Status**: Stable (2025-11-15) - Namespace refactoring completed for clarity

**Current API** (as of 2025-11-15):
- Main entry point: `interpret()` - Universal interpretation function
- Configuration objects: `llm_args()`, `interpretation_args(analysis_type, ...)`, `output_args()`
- Architecture: interpret() → interpret_model.{class}() → build_analysis_data.{class}()
- S3 generics: build_analysis_data(), build_system_prompt(), build_main_prompt(), export_interpretation()

---

## Quick Reference

**What It Does**: Automates interpretation of exploratory factor analysis (EFA) results using Large Language Models via the `ellmer` package.

**Main Entry Points**:
- `interpret()` - Universal generic (ONLY public API for interpretations)
- `chat_session()` - Create persistent LLM session (saves ~40-60% tokens for multiple analyses)

**Standards for Examples/Tests**:
- Always use `llm_provider = "ollama"` and `llm_model = "gpt-oss:20b-cloud"`
- For LLM tests: `word_limit = 20` (minimum allowed) for token efficiency

**Documentation Structure**:
- **CLAUDE.md** (this file): Usage guide and quick reference for Claude Code sessions
- **dev/DEVELOPER_GUIDE.md**: Technical architecture and implementation details for maintainers
- **dev/TESTING_GUIDELINES.md**: Testing standards and patterns
- **dev/templates/**: Ready-to-copy code templates for implementing new model types (GM, IRT, CDM)
- **dev/MODEL_IMPLEMENTATION_GUIDE.md**: Step-by-step guide for new model type implementation
- **dev/OPEN_ISSUES.md**: Current issues, future work, and priorities

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
var_info <- data.frame(
  variable = c("var1", "var2", ...),
  description = c("Description of variable 1", "Description of variable 2", ...)
)

# 3. Get interpretation
interpretation <- interpret(
  fit_results = fa_result,
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
  analysis_type = "fa",
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud"
)

# Reuse for multiple interpretations
result1 <- interpret(chat_session = chat, fit_results = fa1, variable_info = vars1)
result2 <- interpret(chat_session = chat, fit_results = fa2, variable_info = vars2)
result3 <- interpret(chat_session = chat, fit_results = fa3, variable_info = vars3)

# Check cumulative token usage
print(chat)
```

---

# Usage Patterns

The `interpret()` function accepts different input types. **All arguments must be named** to prevent confusion.

## Pattern 1: Fitted Model Objects (Recommended)

```r
# Automatically extracts loadings from model objects
interpret(
  fit_results = psych::fa(...),        # Or lavaan::efa(), mirt::mirt(), etc.
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
# Both loadings and Phi can be matrices or data.frames
interpret(
  fit_results = list(
    loadings = loadings_matrix,
    Phi = correlation_matrix          # Optional (for oblique rotations)
  ),
  variable_info = var_info,
  analysis_type = "fa",               # REQUIRED for lists
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud"
)
```

## Pattern 3: With Chat Session (Token-Efficient)

```r
# Create session once
chat <- chat_session(analysis_type = "fa", llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")

# Use with any fit_results type
interpret(chat_session = chat, fit_results = fa_result, variable_info = var_info)
interpret(chat_session = chat, fit_results = loadings_list, variable_info = var_info)  # Structured list works too
```

## Pattern 4: Using Configuration Objects (Advanced)

The package supports a **dual interface pattern** for maximum flexibility: you can pass parameters either directly or through configuration objects.

```r
# Create configuration objects for reusable settings
interp_config <- interpretation_args(
  analysis_type = "fa",
  cutoff = 0.3,
  n_emergency = 3,
  hide_low_loadings = FALSE
)

llm_config <- llm_args(
  word_limit = 100,
  additional_info = "Study context: personality assessment"
)

output_config <- output_args(
  output_format = "markdown",
  silent = FALSE
)

# Use configuration objects
interpret(
  fit_results = fa_result,
  variable_info = var_info,
  interpretation_args = interp_config,
  llm_args = llm_config,
  output_args = output_config,
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud"
)

# Or mix config objects with direct parameters
interpret(
  fit_results = fa_result,
  variable_info = var_info,
  interpretation_args = interp_config,  # Use config for interpretation settings
  llm_provider = "ollama",               # Direct parameters for LLM
  llm_model = "gpt-oss:20b-cloud",
  word_limit = 150                       # Direct parameter OVERRIDES llm_args
)
```

### Parameter Precedence Rules

When both configuration objects and direct parameters are provided:

1. **Direct parameters always take precedence**: `word_limit = 150` overrides `llm_args = llm_args(word_limit = 100)`
2. **Configuration objects provide defaults**: If no direct parameter is specified, uses value from config object
3. **Package defaults as fallback**: If neither is provided, uses package defaults

**Example**:
```r
# llm_config specifies word_limit = 100
llm_config <- llm_args(word_limit = 100)

interpret(
  ...,
  llm_args = llm_config,  # word_limit = 100
  word_limit = 150        # This takes precedence! Final word_limit = 150
)
```

**When to use configuration objects**:
- Reusing settings across multiple analyses
- Sharing configurations in team workflows
- Programmatically building complex configurations
- Cleaner code when passing many parameters

**When to use direct parameters**:
- Simple, one-off analyses
- Quick overrides of config object values
- Learning the package (more explicit)

**Pattern selection guide**:
- **Single analysis**: Pattern 1 (fitted model) - simplest
- **Multiple analyses**: Pattern 3 (chat session) - most efficient
- **Custom data**: Pattern 2 (structured list)
- **Reusable settings**: Pattern 4 (configuration objects) - most flexible

---

# Common Workflows

## Debugging LLM Issues

```r
# View full prompts and responses
interpret(..., echo = "all")

# Check JSON parsing with raw response (same function)
interpret(..., echo = "all")
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

## Creating Visualizations

```r
# Create color-blind friendly heatmap
interpretation <- interpret(...)
plot(interpretation)  # Uses blue-orange diverging scale

# Customize cutoff for highlighting
plot(interpretation, cutoff = 0.4)

# Save to file
library(ggplot2)
p <- plot(interpretation)
ggsave("loadings_heatmap.png", p, width = 10, height = 8, dpi = 300)

# Further customize with ggplot2
p + labs(title = "My Custom Title") +
    theme(plot.title = element_text(size = 16))

# Use package theme for other plots
library(ggplot2)
ggplot(data, aes(x, y)) +
  geom_point() +
  theme_psychinterpreter()  # Apply package theme

# Access color palettes directly
colors <- psychinterpreter_colors("diverging")    # Blue-white-orange
cat_cols <- psychinterpreter_colors("categorical") # Okabe-Ito palette
```

## Working with Weak Factors

```r
# Emergency rule: use top N loadings if none exceed cutoff
interpret(..., n_emergency = 2)  # Use top 2 loadings (default)
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
# ❌ INCORRECT - positional arguments
interpret(chat, loadings, var_info)

# ✅ CORRECT - named arguments
interpret(chat_session = chat, fit_results = loadings, variable_info = var_info)
```

## 2. Missing analysis_type for Structured Lists

```r
# ❌ INCORRECT
interpret(
  fit_results = list(loadings = loadings_matrix),
  variable_info = var_info
)

# ✅ CORRECT
interpret(
  fit_results = list(loadings = loadings_matrix),
  variable_info = var_info,
  analysis_type = "fa"
)
```

## 3. Not Reusing Chat Sessions

```r
# ❌ INEFFICIENT - creates new session each time (~2x token cost)
result1 <- interpret(fit_results = fa1, variable_info = vars1, llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")
result2 <- interpret(fit_results = fa2, variable_info = vars2, llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")

# ✅ EFFICIENT - reuse session (saves ~40-60% tokens)
chat <- chat_session(analysis_type = "fa", llm_provider = "ollama", llm_model = "gpt-oss:20b-cloud")
result1 <- interpret(chat_session = chat, fit_results = fa1, variable_info = vars1)
result2 <- interpret(chat_session = chat, fit_results = fa2, variable_info = vars2)
```

## 4. Wrong Pipe Operator in Package Code

```r
# ❌ INCORRECT - magrittr pipe
data %>% dplyr::filter(x > 0)

# ✅ CORRECT - base R pipe
data |> dplyr::filter(x > 0)
```

## 5. additional_info Parameter Location

```r
# ❌ INCORRECT - additional_info inside fit_results list
interpret(
  fit_results = list(loadings = loadings, additional_info = "Context"),
  variable_info = var_info, analysis_type = "fa"
)

# ✅ CORRECT - additional_info as separate parameter
interpret(
  fit_results = list(loadings = loadings),
  variable_info = var_info,
  additional_info = "Context",  # Separate parameter
  analysis_type = "fa"
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
interpret(fit_results = list(loadings = loadings), variable_info = var_info,
          analysis_type = "fa", llm_provider = "ollama", word_limit = 150)  # Default, wastes tokens

# ✅ EFFICIENT
interpret(fit_results = list(loadings = loadings), variable_info = var_info,
          analysis_type = "fa", llm_provider = "ollama", word_limit = 20)   # Minimum allowed
```

---

# Troubleshooting

## "Error: analysis_type must be specified"

**Cause**: Using structured list without specifying analysis_type

**Solution**:
```r
interpret(
  fit_results = list(loadings = loadings_matrix),
  variable_info = var_info,
  analysis_type = "fa"
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
interpret(..., echo = "all")
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

**Solution**: Current version uses `normalize_token_count()` helper to prevent negatives and handle NULL/NA values

---

# Active TODOs

- **Optimize tests further**: coverage and efficiency

- **Implement gaussian_mixture class** - Requires 8 S3 methods + 2 optional methods (see dev/DEVELOPER_GUIDE.md)

---

# Quick Reference Tables

## Key Functions

| Function | Purpose |
|----------|----------|
| `interpret()` | Universal interpretation function (recommended) |
| `chat_session()` | Create persistent LLM session |
| `export_interpretation()` | Export to txt/md files |
| `plot.fa_interpretation()` | Visualize factor loadings with color-blind friendly palette |
| `create_factor_plot()` | Create factor loading heatmap (standalone wrapper) |
| `theme_psychinterpreter()` | Custom ggplot2 theme for publication-ready plots |
| `psychinterpreter_colors()` | Get color-blind friendly palettes |
| `find_cross_loadings()` | Identify cross-loading variables |
| `find_no_loadings()` | Identify orphaned variables |
| `llm_args()` | Create LLM configuration object |
| `interpretation_args()` | Create model-specific interpretation configuration |
| `output_args()` | Create output configuration object |

## Key Parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `silent` | 0, 1, 2 | 0 | 0=report+messages, 1=messages only, 2=silent |
| `output_format` | "text", "markdown" | "text" | Report format |
| `word_limit` | 20-500 | 150 | Max words per factor interpretation |
| `n_emergency` | 0-10 | 2 | Top N loadings for weak factors (0=undefined) |
| `hide_low_loadings` | TRUE/FALSE | FALSE | Hide non-significant loadings in prompt |
| `echo` | "all", "none" | "none" | Show LLM prompts/responses |

## Package Files

**See dev/DEVELOPER_GUIDE.md section 2.2 for detailed file structure**

| Category | Key Files |
|----------|-------------|
| **Core** | core_interpret_dispatch.R, core_interpret.R, core_constants.R |
| **S3 Generics** | s3_model_data.R, s3_prompt_builder.R, s3_json_parser.R, s3_export.R |
| **Classes** | class_chat_session.R, class_interpretation.R |
| **Shared Utilities** | shared_config.R, shared_utils.R, shared_text.R, shared_visualization.R |
| **FA Implementation** | fa_model_data.R, fa_prompt_builder.R, fa_json.R, fa_diagnostics.R, fa_report.R, fa_visualization.R |
| **Tests** | tests/testthat/ (25 test files, 347+ tests) |

## Development Commands

```r
devtools::document()                                      # Regenerate documentation
devtools::test()                                          # Run all tests
testthat::test_file("tests/testthat/test-interpret_fa.R") # Run single test file
devtools::check()                                         # R CMD check
devtools::load_all()                                      # Load for development
```

- After implementing new code, run tests and fix failures
- After implementing new functions or changing parameters, update roxygen docs and run `devtools::document()`
- After adding, removing, or renaming functions, update _pkgdown.yml if needed
- After major changes, run `devtools::check()` to ensure package integrity


## Code Style (Brief)

- **Roxygen2** for all exported functions
- **Explicit namespacing**: `package::function()`
- **CLI messaging**: Use `cli::cli_*()` functions
- **Pipe**: Base R `|>` (not `%>%`)
- **Naming**: snake_case for functions, S3 methods as `method.class()`

**For detailed style guide**: See dev/DEVELOPER_GUIDE.md section 5.1

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
2. Update "Last Updated" date in both files
3. Document significant architectural changes in DEVELOPER_GUIDE.md if needed

## When to Update dev/DEVELOPER_GUIDE.md

Update the developer guide when making **architectural or implementation changes**:
- Changes to S3 dispatch system
- Token tracking implementation modifications
- New model type implementations (GM, IRT, CDM)
- File structure reorganization
- Design decision changes
- Code style updates

**Include technical details** - flow diagrams, code locations (file:line), implementation rationale

## Document Maintenance Guidelines

1. **Clear separation**: CLAUDE.md = usage guide, DEV GUIDE = technical reference
2. **Cross-reference**: Link between documents rather than duplicating content
3. **Update dates**: Change "Last Updated" when making significant edits
4. **Keep current**: Delete obsolete sections, update examples to match current API
5. **Documentation over history**: Focus on current state rather than historical changes

---

**Last Updated**: 2025-11-15
**Maintainer**: Update when making significant user-facing changes
- as long as the package is in version 0.0.0.9000, backwards-compatibility can be ignored in development since the package is not officially released
- use kable() and kable_styling() for .Qmd articles
- when adding or editing functions, remember to update the references in the pkgdown.yml
