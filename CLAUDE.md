# CLAUDE.md

**Purpose**: Quick reference for Claude Code when helping users with the **psychinterpreter** R package.

**For technical/architectural details**: See [dev/DEVELOPER_GUIDE.md](dev/DEVELOPER_GUIDE.md)

**Status**: Stable (2025-11-22) - Variable labeling functionality added

**Current API** (as of 2025-11-22):
- Main entry points: `interpret()` (interpretations), `label_variables()` (variable labels)
- Configuration objects: `llm_args()`, `interpretation_args()`, `labeling_args()`, `output_args()`
- Architecture:
  - Interpretations: interpret() → interpret_model.{class}() → build_analysis_data.{class}()
  - Labels: label_variables() → build_system_prompt.label() → build_main_prompt.label()
- S3 generics: build_analysis_data(), build_system_prompt(), build_main_prompt(), export_interpretation()
- Parameter extraction: extract_model_parameters(), validate_model_requirements()

**Recent Updates** (2025-11-22):
- **NEW**: Variable labeling functionality with `label_variables()`, `reformat_labels()`, `export_labels()`
- Two-phase architecture: Semantic Generation (LLM) → Format Processing (post-processing)
- Supports short (1-3 words), phrase (4-7 words), acronym (3-5 chars), and custom labels
- Extensive formatting options: case transformations, separators, abbreviation, article/preposition removal
- Test coverage: 60+ tests for labeling functionality

---

## Quick Reference

**What It Does**: Automates interpretation of psychometric analysis results AND generates concise variable labels using Large Language Models via the `ellmer` package.

**Main Entry Points**:
- `interpret()` - Universal generic for interpreting psychometric models (FA, GM, etc.)
- `label_variables()` - Generate short, descriptive labels from variable descriptions
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

## Variable Labeling

Generate short, descriptive labels for variables using LLMs.

```r
library(psychinterpreter)

# 1. Prepare variable descriptions
var_info <- data.frame(
  variable = c("q1", "q2", "q3"),  # Optional - will auto-generate V1, V2, V3 if omitted
  description = c(
    "How satisfied are you with your job?",
    "Rate your work-life balance",
    "Years of experience in your field"
  )
)

# 2. Generate labels (one-shot)
labels <- label_variables(
  variable_info = var_info,
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud",
  label_type = "short"  # 1-3 words (default)
)

# 3. View results
print(labels)
# ── Variable Labels Report ──
#
# ── Labeling Details ──
# • Label type: short
# • Variables labeled: 3
#
# ── Generated Labels ──
# Variable  Label
# --------  ----------------
# q1        Job Satisfaction
# q2        Work Balance
# q3        Experience Years

# 4. Reformat without calling LLM again
labels_snake <- reformat_labels(labels, case = "snake")
labels_camel <- reformat_labels(labels, case = "camel")
labels_abbrev <- reformat_labels(labels, abbreviate = TRUE, max_words = 2)

# 5. Export to file
export_labels(labels, "variable_labels.csv")  # CSV (default)
export_labels(labels, "variable_labels.xlsx", format = "xlsx")  # Excel
```

### Label Types

- **short** (1-3 words): `"Job Satisfaction"`, `"Work Balance"` [default]
- **phrase** (4-7 words): `"Satisfaction with Current Job Position"`
- **acronym** (3-5 chars): `"JOBSAT"`, `"WRKBAL"`
- **custom**: Use `max_words` parameter for exact control

### Formatting Options

```r
labels <- label_variables(
  variable_info = var_info,
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud",
  label_type = "short",

  # Semantic generation (LLM instructions)
  max_words = 2,              # Override label_type preset
  style_hint = "technical",   # Guide LLM style (e.g., "simple", "academic")

  # Format processing (post-processing)
  case = "snake",             # "lower", "upper", "title", "snake", "camel", "constant"
  sep = "_",                  # Separator between words
  remove_articles = TRUE,     # Remove "a", "an", "the"
  remove_prepositions = TRUE, # Remove "of", "in", "at", etc.
  abbreviate = TRUE,          # Apply rule-based abbreviation
  max_chars = 20              # Maximum character length
)
```

### Token-Efficient Multi-Labeling

```r
# Create session for labeling
chat <- chat_session(
  analysis_type = "label",
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud"
)

# Reuse for multiple label generation tasks
labels1 <- label_variables(chat_session = chat, variable_info = vars1)
labels2 <- label_variables(chat_session = chat, variable_info = vars2)
labels3 <- label_variables(chat_session = chat, variable_info = vars3)

# Check cumulative usage
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
- **Factor Analysis**: `psych::fa()`, `psych::principal()`, `lavaan::efa()`, `mirt::mirt()`
- **SEM/CFA**: `lavaan::cfa()`, `lavaan::sem()`
- **Gaussian Mixture**: `mclust::Mclust()`

## Pattern 2: Structured List

```r
# For custom data structures
# Both loadings and factor_cor_mat can be matrices or data.frames
interpret(
  fit_results = list(
    loadings = loadings_matrix,
    factor_cor_mat = correlation_matrix  # Optional (for oblique rotations)
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
  format = "markdown",
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

## Discovering Available Parameters

```r
# Show common parameters for all models (llm_args + output_args)
show_interpret_args()

# Show all parameters for Factor Analysis (includes FA-specific interpretation_args)
show_interpret_args("fa")

# Show all parameters for Gaussian Mixture Models (includes GM-specific interpretation_args)
show_interpret_args("gm")

# Capture parameter data programmatically
params_df <- show_interpret_args("fa")
print(params_df)
```

The function displays CLI-formatted output with:
- **Parameter name** and type (character, integer, numeric, logical)
- **Default value** from the centralized parameter registry
- **Valid range** (for numeric) or **allowed values** (for categorical)
- **Description** of what the parameter controls

Parameters are organized by configuration group (llm_args, output_args, interpretation_args).

## Customizing Output

```r
# Control verbosity
interpret(..., silent = 0)  # Show report + messages (default)
interpret(..., silent = 1)  # Messages only, no report
interpret(..., silent = 2)  # Completely silent

# Output formats (use format parameter in output_args or directly)
interpret(..., output_args = output_args(format = "cli"))       # Default: CLI-formatted text
interpret(..., output_args = output_args(format = "markdown"))  # Markdown format
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

## Working with Weak Factors (FA)

```r
# Emergency rule: use top N loadings if none exceed cutoff
interpret(..., n_emergency = 2)  # Use top 2 loadings (default)
interpret(..., n_emergency = 0)  # Label weak factors as "undefined"

# Hide non-significant loadings to save tokens
interpret(..., hide_low_loadings = TRUE)
```

## Working with Gaussian Mixture Models (GM)

```r
library(mclust)

# Fit Gaussian Mixture Model
data_scaled <- scale(data)
gmm_model <- Mclust(data_scaled, G = 1:5)

# Get interpretation
gm_result <- interpret(
  fit_results = gmm_model,
  variable_info = var_info,
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud",
  weight_by_uncertainty = TRUE,  # Weight by assignment certainty
  plot_type = "auto"              # Auto-select visualization
)

# Multiple visualization types
plot(gm_result, plot_type = "heatmap")    # Cluster means heatmap
plot(gm_result, plot_type = "parallel")   # Parallel coordinates
plot(gm_result, plot_type = "radar")      # Radar/spider plots
plot(gm_result, plot_type = "all")        # All visualizations

# Visualize cluster variances (NEW in 0.0.0.9000)
# The 'what' parameter controls which data to visualize:
# - "means" (default): Cluster means (standardized values)
# - "variances": Within-cluster standard deviations
# - "ratio": Between/within variance ratios (discrimination power)

# Show within-cluster variability
plot(gm_result, plot_type = "heatmap", what = "variances")    # Variance heatmap
plot(gm_result, plot_type = "parallel", what = "variances")   # Variance parallel plot
plot(gm_result, plot_type = "radar", what = "variances")      # Variance radar plot

# Show discrimination power (which variables best separate clusters)
plot(gm_result, plot_type = "heatmap", what = "ratio")       # Ratio heatmap
plot(gm_result, plot_type = "parallel", what = "ratio")      # Ratio parallel plot
plot(gm_result, plot_type = "radar", what = "ratio")         # Ratio radar plot

# All visualizations for variance
plot(gm_result, plot_type = "all", what = "variances")        # All variance plots

# Data centering options (NEW in 0.0.0.9000)
# The 'centering' parameter helps highlight cluster differences by removing baseline effects
# Only applies when what="means" (not for variances or ratios)

# Center each variable by its mean across clusters (removes variable-specific baselines)
plot(gm_result, plot_type = "heatmap", centering = "variable")    # Variable-centered heatmap
plot(gm_result, plot_type = "parallel", centering = "variable")   # Variable-centered parallel plot
plot(gm_result, plot_type = "radar", centering = "variable")      # Variable-centered radar plot

# Center all values by the grand mean (common reference point)
plot(gm_result, plot_type = "heatmap", centering = "global")      # Global-centered heatmap
plot(gm_result, plot_type = "parallel", centering = "global")     # Global-centered parallel plot
plot(gm_result, plot_type = "radar", centering = "global")        # Global-centered radar plot

# GM-specific parameters
interpret(
  fit_results = gmm_model,
  variable_info = var_info,
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud",
  min_cluster_size = 10,              # Minimum viable cluster size
  separation_threshold = 0.4,         # Overlap detection threshold
  profile_variables = c("var1", "var2", "var3"),  # Focus on subset
  weight_by_uncertainty = TRUE        # Consider assignment uncertainty
)
```

## Working with Variable Labels

```r
# Generate labels with different formats
var_info <- data.frame(
  description = c(
    "How satisfied are you with your job?",
    "Rate your work-life balance",
    "Years of experience"
  )
)

# Short labels (1-3 words)
labels_short <- label_variables(
  var_info,
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud",
  label_type = "short"
)

# Snake case for programming
labels_snake <- reformat_labels(labels_short, case = "snake")
# Result: "job_satisfaction", "work_balance", "experience_years"

# Abbreviated for plots
labels_abbrev <- reformat_labels(
  labels_short,
  abbreviate = TRUE,
  max_words = 2,
  max_chars = 12
)

# Using configuration objects (dual-tier architecture)
label_config <- labeling_args(
  label_type = "short",
  case = "snake",
  remove_articles = TRUE
)

llm_config <- llm_args(
  echo = "none"
)

labels <- label_variables(
  var_info,
  labeling_args = label_config,
  llm_args = llm_config,
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud"
)

# Direct parameters override config objects
labels <- label_variables(
  var_info,
  labeling_args = label_config,  # says case = "snake"
  case = "camel",                 # This takes precedence!
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud"
)
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

- **Implement IRT class** - Item Response Theory models (see dev/DEVELOPER_GUIDE.md)

- **Implement CDM class** - Cognitive Diagnostic Models (see dev/DEVELOPER_GUIDE.md)

---

# Quick Reference Tables

## Key Functions

| Function | Purpose |
|----------|----------|
| `interpret()` | Universal interpretation function (recommended) |
| `label_variables()` | Generate concise labels from variable descriptions |
| `reformat_labels()` | Reapply formatting to existing labels without LLM call |
| `export_labels()` | Export labels to CSV/Excel |
| `chat_session()` | Create persistent LLM session |
| `show_interpret_args()` | Show available parameters with defaults for interpret() |
| `export_interpretation()` | Export to txt/md files |
| `plot.fa_interpretation()` | Visualize factor loadings with color-blind friendly palette |
| `plot.gm_interpretation()` | Visualize cluster profiles (heatmap/parallel/radar) |
| `create_factor_plot()` | Create factor loading heatmap (standalone wrapper) |
| `create_cluster_profile_plot()` | Create cluster profile plot (standalone wrapper) |
| `theme_psychinterpreter()` | Custom ggplot2 theme for publication-ready plots |
| `psychinterpreter_colors()` | Get color-blind friendly palettes |
| `find_cross_loadings()` | Identify cross-loading variables (FA) |
| `find_no_loadings()` | Identify orphaned variables (FA) |
| `find_overlapping_clusters()` | Identify overlapping clusters (GM) |
| `find_distinguishing_variables_gm()` | Identify key variables per cluster (GM) |
| `llm_args()` | Create LLM configuration object |
| `interpretation_args()` | Create model-specific interpretation configuration |
| `labeling_args()` | Create labeling configuration object |
| `output_args()` | Create output configuration object |

## Key Parameters

### Common Parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `silent` | 0, 1, 2 | 0 | 0=report+messages, 1=messages only, 2=silent |
| `format` | "cli", "markdown" | "cli" | Report format (in output_args) |
| `word_limit` | 20-500 | 150 | Max words per interpretation |
| `echo` | "all", "none" | "none" | Show LLM prompts/responses |

### FA-Specific Parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `cutoff` | 0-1 | 0.3 | Minimum loading threshold |
| `n_emergency` | 0-10 | 2 | Top N loadings for weak factors (0=undefined) |
| `hide_low_loadings` | TRUE/FALSE | FALSE | Hide non-significant loadings in prompt |
| `sort_loadings` | TRUE/FALSE | TRUE | Sort variables by loading strength |

### GM-Specific Parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `min_cluster_size` | 1-100 | 5 | Minimum meaningful cluster size |
| `separation_threshold` | 0-1 | 0.3 | Overlap detection threshold |
| `weight_by_uncertainty` | TRUE/FALSE | FALSE | Weight by assignment certainty |
| `plot_type` | "auto", "heatmap", "parallel", "radar", "all" | "auto" | Visualization format |
| `what` | "means", "variances", "ratio" | "means" | Data to visualize (means/variances/discrimination) |
| `centering` | "none", "variable", "global" | "none" | Center data (variable-wise/grand mean, means only) |
| `profile_variables` | character vector | NULL | Focus on specific variables |

### Labeling-Specific Parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| **Semantic Generation (LLM Instructions)** ||||
| `label_type` | "short", "phrase", "acronym", "custom" | "short" | Label style: short (1-3 words), phrase (4-7 words), acronym (3-5 chars) |
| `max_words` | integer or NULL | NULL | Exact word count (overrides label_type) - LLM instruction |
| `style_hint` | character or NULL | NULL | Style guidance (e.g., "technical", "simple", "academic") |
| **Format Processing (Post-processing)** ||||
| `sep` | character | " " | Separator between words (e.g., " ", "_", "") |
| `case` | "original", "lower", "upper", "title", "sentence", "snake", "camel", "constant" | "original" | Case transformation |
| `remove_articles` | TRUE/FALSE | FALSE | Remove "a", "an", "the" |
| `remove_prepositions` | TRUE/FALSE | FALSE | Remove "of", "in", "at", etc. |
| `abbreviate` | TRUE/FALSE | FALSE | Apply rule-based abbreviation to long words |
| `max_chars` | integer or NULL | NULL | Maximum character length for labels |

## Package Files

**See dev/DEVELOPER_GUIDE.md section 2.2 for detailed file structure**

| Category | Key Files |
|----------|-------------|
| **Core** | core_interpret_dispatch.R, core_interpret.R, core_label_variables.R, core_constants.R |
| **S3 Generics** | s3_model_data.R, s3_prompt_builder.R, s3_json_parser.R, s3_export.R, s3_label_builder.R, s3_label_parser.R |
| **Classes** | class_chat_session.R, class_interpretation.R |
| **Shared Utilities** | shared_config.R, shared_utils.R, shared_text.R, shared_visualization.R |
| **Config Objects** | labeling_args.R (labeling configuration) |
| **FA Implementation** | fa_model_data.R, fa_prompt_builder.R, fa_json.R, fa_diagnostics.R, fa_report.R, fa_visualization.R |
| **Label Implementation** | core_label_variables.R, s3_label_builder.R, s3_label_parser.R, label_utils.R, labeling_args.R |
| **Tests** | tests/testthat/ (26 test files, 407+ tests) |

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

**Last Updated**: 2025-11-22
**Maintainer**: Update when making significant user-facing changes
**Latest Change**: Added `label_variables()` functionality for generating short, descriptive variable labels with LLMs. Includes two-phase architecture (Semantic Generation → Format Processing), multiple label types (short/phrase/acronym/custom), extensive formatting options (case transformations, separators, abbreviation, article/preposition removal), reformatting capability, and chat session support for token efficiency.
- as long as the package is in version 0.0.0.9000, backwards-compatibility can be ignored in development since the package is not officially released
- use DT::datatable() for .Qmd articles
- when adding or editing functions, remember to update the references in the pkgdown.yml
- whenever it is feasible and may save time, use subagents