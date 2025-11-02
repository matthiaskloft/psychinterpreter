# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Package Overview

**psychinterpreter** is an R package that automates the interpretation of exploratory factor analysis (EFA) and cluster analysis results using Large Language Models (LLMs) via the `ellmer` package. It interfaces with various LLM providers (OpenAI, Anthropic, Ollama, Gemini, Azure) to generate human-readable factor names and interpretations based on loading patterns and variable descriptions.

## Core Architecture

### LLM-Powered Interpretation Pipeline

The package uses a sophisticated multi-stage pipeline:

1. **Factor Analysis Preparation** (R/fa_utilities.R):
   - Analyzes factor loadings against configurable cutoffs
   - Identifies significant loadings per factor
   - Applies "emergency rule" for weak factors (uses top N variables if none exceed cutoff)
   - Detects cross-loadings and orphaned variables

2. **Prompt Engineering & LLM Communication** (R/interpret_fa.R):
   - Constructs structured prompts with psychometric context
   - Uses compact vector format for efficient token usage
   - Processes ALL factors in a single LLM call (batch processing optimization)
   - Includes factor correlations for oblique rotations
   - Supports persistent chat sessions via `chat_fa` objects to avoid resending system prompts

3. **Report Generation** (R/fa_report_functions.R):
   - Builds comprehensive reports in text or markdown format
   - Includes factor interpretations, cross-loadings, and diagnostic information
   - Configurable heading levels for document integration
   - Text wrapping for console output

### Persistent Chat Sessions

Key innovation for cost/efficiency optimization:

- **`chat_fa` objects** (R/chat_fa.R): Reusable LLM sessions that preserve system prompt
- Single analysis: Creates temporary session
- Multiple analyses: Create one `chat_fa`, pass to multiple `interpret_fa()` calls
- Saves ~500+ tokens per additional analysis by not resending system prompt

### Key Design Patterns

**Single Responsibility**: Each R file handles one aspect:
- `interpret_fa.R`: Main interpretation logic and LLM coordination
- `chat_fa.R`: Chat session management
- `fa_utilities.R`: Data analysis utilities (cross-loadings, no-loadings detection)
- `utils.R`: Text processing helpers (word counting, text wrapping)
- `fa_report_functions.R`: Report building and formatting
- `export_functions.R`: Multi-format export (CSV, JSON, RDS, TXT)
- `visualization.R`: S3 plot method and ggplot2-based heatmap visualizations

**S3 Methods**: Package implements custom methods for standard R generics:
- `print.fa_interpretation()`: Formatted console output with text wrapping
- `print.chat_fa()`: Session info and token usage display
- `plot.fa_interpretation()`: Factor loading heatmap visualization
- Backward-compatible wrappers: `create_factor_plot()` calls `plot()` method

**Provider Abstraction**: Uses `ellmer` package's unified interface for LLM providers. Switch providers by changing parameters, not code.

**Structured Output**: LLM returns JSON with factor names as keys, parsed with fallback extraction methods for robustness.

## Common Development Commands

### Building & Checking
```r
# Generate documentation from roxygen2 comments
roxygen2::roxygenise()

# Run R CMD check
devtools::check()

# Install package locally
devtools::install()

# Load for development
devtools::load_all()
```

### Testing
```r
# Run all tests
devtools::test()

# Run specific test file
testthat::test_file("tests/testthat/test-interpret_fa.R")
```

### Documentation
```r
# Build package documentation
devtools::document()

# Preview help for function
?interpret_fa
```

## LLM Provider Configuration

API keys must be set as environment variables before using the package:

```r
# OpenAI
Sys.setenv(OPENAI_API_KEY = "your-key")

# Anthropic
Sys.setenv(ANTHROPIC_API_KEY = "your-key")

# For Ollama (local), no key needed
```

Provider-specific chat initialization handled by `ellmer` package through switch statement in interpret_fa.R:587-766.

## Important Implementation Details

### JSON Parsing Strategy (interpret_fa.R:1015-1161)

Multi-tiered fallback approach for robust LLM response handling:
1. Try parsing cleaned JSON (remove extra text, fix formatting issues)
2. Fall back to original response
3. Pattern-based extraction if JSON parsing fails
4. Default values if all methods fail

Critical for handling small/local models that may produce imperfect JSON.

### Word Limit Enforcement

The package targets 80-100% of `word_limit` parameter for interpretations:
- System prompt includes explicit word targets
- Post-processing validates and warns if exceeded
- Helper function `count_words()` in utils.R

### Factor Correlation Integration

When `factor_cor_mat` provided (for oblique rotations):
- Included in LLM prompt for relationship context
- Helps LLM understand discriminant vs. convergent validity
- Displayed in report sections (both summary and per-factor)

### Emergency Rule Logic (interpret_fa.R:600-617)

If a factor has zero loadings above cutoff:
- Uses top `n_emergency` highest absolute loadings instead
- Clearly marked in output with WARNING
- Prevents empty factor interpretations

## Code Style Conventions

- **Roxygen2 documentation**: Required for all exported functions
- **Examples limit**: Maximum 2 examples per function in documentation
- **Explicit namespacing**: Use `package::function()` notation (e.g., `dplyr::mutate()`)
- **CLI messaging**: Use `cli` package for user-facing messages (cli_alert_info, cli_abort, cli_warn)
- **Pipe operator**: Uses base R `|>` pipe (not magrittr `%>%`)
- **Parameter validation**: Extensive validation with informative error messages at function start

## Dependencies

### Imports (Required)
- `ellmer`: LLM communication layer
- `dplyr`, `tidyr`: Data manipulation
- `cli`: User messaging
- `jsonlite`: JSON parsing

### Suggests (Optional)
- `ggplot2`: Visualization (plot() method and create_factor_plot())
- `testthat`: Testing framework

## Exported Functions

The package exports 12 functions plus 3 S3 methods:

**Main Functions:**
- `interpret_fa()` - Core factor interpretation with LLM
- `chat_fa()` - Create persistent chat session
- `is.chat_fa()` - Check if object is chat_fa
- `reset.chat_fa()` - Reset chat session

**Utilities:**
- `find_cross_loadings()` - Detect cross-loading variables
- `find_no_loadings()` - Detect variables with no significant loadings
- `export_interpretation()` - Export results to multiple formats
- `create_factor_plot()` - Standalone plotting function (wrapper)

**S3 Methods:**
- `print.fa_interpretation()` - Print interpretation results
- `print.chat_fa()` - Print chat session info
- `plot.fa_interpretation()` - Visualize factor loadings

## Testing Strategy

Currently no tests implemented (tests/ directory doesn't exist). When adding tests:
- Use `testthat` framework (already in DESCRIPTION Suggests)
- Skip tests requiring API keys unless credentials available
- Create fixtures for factor loading matrices and variable descriptions
- Test both single-analysis and persistent chat session workflows

## File Organization

```
R/
├── interpret_fa.R          # Main interpretation function (~1270 lines)
├── chat_fa.R               # Persistent chat session management
├── fa_utilities.R          # Cross-loading & no-loading detection
├── utils.R                 # Word counting, text wrapping
├── fa_report_functions.R   # Report building, print methods
├── export_functions.R      # Export to CSV/JSON/RDS/TXT
└── visualization.R         # ggplot2 heatmap creation

dev/
└── PACKAGE_MIGRATION_PLAN.md  # Historical migration documentation

vignettes/
└── articles/
    └── 01-Basic_Usage.qmd   # Example usage with BFI dataset
```

## Common Workflows

### Visualizing Factor Analysis Results

```r
# Get interpretation results
results <- interpret_fa(loadings, variable_info, silent = TRUE)

# Use S3 plot method (recommended)
plot(results)

# Or use backward-compatible function
create_factor_plot(results)

# Save plot
p <- plot(results)
ggsave("loadings.png", p, width = 10, height = 8)

# Customize plot
plot(results) +
  ggplot2::labs(title = "Custom Title") +
  ggplot2::theme(axis.text.y = ggplot2::element_text(size = 6))
```

### Adding New LLM Provider Support

1. `ellmer` package handles provider abstraction - no changes needed to psychinterpreter
2. Users simply specify provider name and model in function calls

### Modifying System Prompt

The psychometric expert system prompt is defined in TWO locations:
- `interpret_fa.R:294-330` (single-use sessions)
- `chat_fa.R:57-73` (persistent sessions)

**CRITICAL**: Keep both prompts synchronized when making changes.

### Adding New Output Formats

1. Add format to `export_interpretation()` switch statement (export_functions.R:93)
2. Implement format-specific export logic
3. Update function documentation with new format description

### Extending Report Formats

Report generation in `build_fa_report()` (fa_report_functions.R:18) supports:
- `output_format`: "text" or "markdown"
- `heading_level`: For markdown hierarchy integration
- `suppress_heading`: For embedding in existing documents

Add new formats by extending the conditional logic at line 39 (markdown) and 244 (text).

## Debugging Tips

### Enable LLM Prompt/Response Visibility
```r
interpret_fa(..., echo = "all")  # Shows prompts and responses
```

### Check Token Usage
```r
chat <- chat_fa("anthropic", "claude-haiku-4-5-20251001")
result <- interpret_fa(..., chat_session = chat)
print(chat)  # Displays token counts
```

### Validate JSON Response Parsing
Look for warnings from interpret_fa.R:1044 about batch JSON parsing failures. Consider using larger models if small models produce invalid JSON.

## Version History

- **0.0.0.9000**: Development version
- R version requirement: >= 4.1.0

## License

MIT + file LICENSE


## TODOs and known issues

- interpret_fa(): local input token usage not correctly tracked
- interpret_fa(): session_chat and provider/model need to be disambiguated for potential conflict
- add tests/ directory with testthat tests
- export functions need debugging and reduction to useful formats, i.e., .txt and .md

