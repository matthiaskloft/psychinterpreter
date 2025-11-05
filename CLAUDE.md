# CLAUDE.md

This file provides guidance to Claude Code when working with the **psychinterpreter** R package.

## Package Overview

**psychinterpreter** automates interpretation of exploratory factor analysis (EFA) results using Large Language Models via the `ellmer` package. It interfaces with OpenAI, Anthropic, Ollama, Gemini, and Azure to generate human-readable factor names and interpretations.

## Core Architecture

### LLM-Powered Interpretation Pipeline

1. **Factor Analysis Preparation** (R/fa_utilities.R):
   - Analyzes loadings against configurable cutoffs
   - Identifies significant loadings per factor
   - Applies "emergency rule" for weak factors (uses top N variables if none exceed cutoff)
   - Detects cross-loadings and orphaned variables

2. **LLM Communication** (R/interpret_fa.R, ~1350 lines):
   - Constructs structured prompts with psychometric context
   - Processes ALL factors in a single LLM call (batch optimization)
   - Includes factor correlations for oblique rotations
   - Supports persistent chat sessions via `chat_fa` objects to save tokens

3. **Report Generation** (R/fa_report_functions.R):
   - Builds reports in text or markdown format
   - Includes interpretations, cross-loadings, and diagnostics
   - Text wrapping for console output

### Persistent Chat Sessions

**Key innovation**: `chat_fa` objects (R/chat_fa.R) are reusable LLM sessions that preserve the system prompt.
- Single analysis: Creates temporary session
- Multiple analyses: Create one `chat_fa`, pass to multiple `interpret_fa()` calls
- Saves ~500+ tokens per additional analysis

### S3 Methods for Common FA Packages

The `interpret()` generic (R/interpret_methods.R) auto-extracts loadings from:
- `psych::fa()` and `psych::principal()` results
- `lavaan::cfa()`, `lavaan::sem()`, and `lavaan::efa()` results
- `mirt::mirt()` results

## Key Implementation Details

### Emergency Rule Logic

If a factor has zero loadings above cutoff:
- Uses top `n_emergency` highest absolute loadings instead
- Clearly marked with WARNING in output
- Prevents empty factor interpretations

### Word Limit Enforcement

Targets 80-100% of `word_limit` parameter:
- System prompt includes explicit word targets
- Post-processing validates and **informs** (via `cli::cli_inform()`) if exceeded
- Helper function `count_words()` in utils.R
- **Note**: Changed from warning to message (2025-11-03) to reduce test noise

### JSON Parsing Strategy

Multi-tiered fallback for robust LLM response handling:
1. Try parsing cleaned JSON (remove extra text, fix formatting)
2. Fall back to original response
3. Pattern-based extraction if JSON parsing fails
4. Default values if all methods fail

Critical for handling small/local models with imperfect JSON output.

### System Prompt Synchronization

The psychometric expert system prompt is defined in **TWO locations**:
- `interpret_fa.R` (lines ~294-330): Single-use sessions
- `chat_fa.R` (lines ~57-73): Persistent sessions

**CRITICAL**: Keep both prompts synchronized when making changes.

## Exported Functions and Methods

**9 exported functions:**
- `interpret_fa()` - Core factor interpretation with LLM
- `interpret()` - S3 generic for common FA packages
- `chat_fa()`, `is.chat_fa()`, `reset.chat_fa()` - Session management
- `find_cross_loadings()`, `find_no_loadings()` - Diagnostic utilities
- `export_interpretation()` - Export to txt/md formats
- `create_factor_plot()` - Plotting wrapper

**10 S3 methods:**
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

## Code Style Conventions

- **Roxygen2 documentation**: Required for all exported functions
- **Explicit namespacing**: Use `package::function()` (e.g., `dplyr::mutate()`)
- **CLI messaging**: Use `cli` package (`cli_alert_info`, `cli_abort`, `cli_inform`)
- **Pipe operator**: Base R `|>` (not magrittr `%>%`)
- **Parameter validation**: Extensive validation with informative errors at function start

## Testing

**70 tests** across 7 files following [R Packages 2e](https://r-pkgs.org/testing-design.html) best practices:

**Test files:**
- `test-chat_fa.R` - Chat session management and token tracking
- `test-export_functions.R` - Export to txt/md formats
- `test-fa_utilities.R` - Cross-loading and no-loading detection
- `test-interpret_fa.R` - Core interpretation logic, emergency rules
- `test-interpret_methods.R` - S3 methods for psych/lavaan/mirt
- `test-print_methods.R` - Print methods
- `test-visualization.R` - Plot methods and heatmap generation

**Test infrastructure:**
- Uses `testthat 3.0` framework
- Fixtures stored in `tests/testthat/fixtures/` as `.rds` files
- Helper functions in `helper.R` use `test_path()` for portability
- LLM-requiring tests skip automatically on CI (GitHub Actions)
- Token-efficient fixtures: `minimal_*` fixtures use `word_limit = 20` (minimum allowed)

**Three fixture sets:**
1. **Standard fixtures**: 5 variables × 3 factors (~400-500 tokens)
2. **Minimal fixtures**: 3 variables × 2 factors (~150-200 tokens, 60-70% reduction)
3. **Correlational fixtures**: Realistic FA data with proper factor structure (eliminates Heywood case warnings)

## File Organization

```
R/
├── interpret_fa.R          # Main interpretation function (~1350 lines)
├── chat_fa.R               # Persistent chat session management
├── interpret_methods.R     # S3 methods for psych/lavaan/mirt
├── fa_utilities.R          # Cross-loading & no-loading detection
├── utils.R                 # Word counting, text wrapping
├── fa_report_functions.R   # Report building, print methods
├── export_functions.R      # Export to txt/md formats
└── visualization.R         # S3 plot method and heatmap creation

tests/testthat/
├── fixtures/               # Test data as .rds files
│   ├── sample_*.rds        # Standard fixtures (5 vars × 3 factors)
│   ├── minimal_*.rds       # Token-efficient fixtures (3 vars × 2 factors)
│   ├── correlational_*.rds # Realistic FA data (6 vars × 2 factors)
│   └── make-*.R            # Regeneration scripts
├── helper.R                # Test helper functions
└── test-*.R                # 7 test files (70 tests total)
```

## Common Development Commands

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

## Common Workflows

### Using S3 Methods with FA Packages

```r
# psych package
fa_result <- psych::fa(data, nfactors = 3)
interpretation <- interpret(fa_result,
                           variable_info = var_descriptions,
                           llm_provider = "anthropic",
                           llm_model = "claude-haiku-4-5-20251001")

# lavaan package
efa_result <- lavaan::efa(data, nfactors = 3)
interpretation <- interpret(efa_result, variable_info = var_descriptions)

# mirt package
mirt_result <- mirt::mirt(data, 2, itemtype = "2PL")
interpretation <- interpret(mirt_result, variable_info = var_descriptions)
```

### Visualizing Results

```r
# Get interpretation
results <- interpret_fa(loadings, variable_info)

# Plot with S3 method (recommended)
plot(results)

# Or use backward-compatible wrapper
create_factor_plot(results)

# Save and customize
p <- plot(results) +
  ggplot2::labs(title = "Custom Title") +
  ggplot2::theme(axis.text.y = ggplot2::element_text(size = 8))
ggsave("loadings.png", p, width = 10, height = 8)
```

### Token-Efficient Multi-Analysis Workflow

```r
# Create persistent session (saves system prompt)
chat <- chat_fa("anthropic", "claude-haiku-4-5-20251001")

# Interpret multiple analyses
results1 <- interpret_fa(loadings1, var_info1, chat_session = chat)
results2 <- interpret_fa(loadings2, var_info2, chat_session = chat)
results3 <- interpret_fa(loadings3, var_info3, chat_session = chat)

# Check token usage
print(chat)  # Shows cumulative tokens and n_interpretations
```

## Debugging Tips

```r
# Enable LLM prompt/response visibility
interpret_fa(..., echo = "all")

# Check token usage
chat <- chat_fa("anthropic", "claude-haiku-4-5-20251001")
result <- interpret_fa(..., chat_session = chat)
print(chat)  # Displays token counts

# Validate JSON parsing
# Look for messages about word limit exceedances or JSON parsing issues
```

## LLM Provider Configuration

API keys must be set as environment variables:

```r
Sys.setenv(OPENAI_API_KEY = "your-key")      # OpenAI
Sys.setenv(ANTHROPIC_API_KEY = "your-key")   # Anthropic
# Ollama (local): no key needed
```

## Extending the Package

### Adding New Output Formats to export_interpretation()

1. Add format to switch statement (export_functions.R:~93)
2. Implement format-specific logic
3. Update documentation

### Modifying Report Formats

Report generation in `build_fa_report()` (fa_report_functions.R:~18) supports:
- `output_format`: "text" or "markdown"
- `heading_level`: For markdown hierarchy
- `suppress_heading`: For embedding in documents

## Recent Key Updates

### 2025-11-04
- ✓ **System prompt token tracking**: Fixed token tracking for persistent chat sessions. System prompt tokens are now correctly captured on first use (when first message is sent) rather than at initialization. Added `system_prompt_captured` flag to track whether tokens have been extracted.

### 2025-11-03
- ✓ **Token tracking fix**: Dual-tier system prevents negative accumulation
- ✓ **S3 method system**: `interpret()` generic for psych/lavaan/mirt packages
- ✓ **Export simplification**: Only txt/md formats (removed CSV/JSON/RDS)
- ✓ **Test fixtures**: Three sets (standard, minimal, correlational) for comprehensive testing
- ✓ **Word limit messaging**: Changed from `cli_warn()` to `cli_inform()` for less noise
- ✓ **Parameter limits relaxed**: `word_limit` minimum 20→20, `max_line_length` max 200→300

## Future Features

- Additional interpretation classes:
  - Cluster analysis
  - IRT models (item diagnostics focus)
  - CDM models (q-matrix interpretation)
  
  
## TODOs

- Token tracking fix implemented
  - docs, code comments, and tests reviewed and updated to reflect behavior
  - NOTE: `system_prompt` tokens are not reliably reported by the `ellmer` wrapper for some providers (this appears to be an upstream bug). For accuracy and to avoid double-counting or negative accumulation, `psychinterpreter` intentionally does NOT add `system_prompt` tokens to the package-level cumulative token counters. Instead, per-run tokens are computed from roles reported by `ellmer::chat$get_tokens()` (user/assistant). If you need provider-specific system-prompt token counts, call `chat$chat$get_tokens(include_system_prompt = TRUE)` directly but be aware results may be inconsistent across providers.
  
- prepare package class system for future classes which may include "gm" (gaussian mixture model), "irt" (item response theory), and "cdm" (cognitive diagnosis models)
  - analyze potential refactoring and modularization of existing codebase to improve maintainability and scalability
  - rename and refactor code base
  
## Known Issues

None currently.


## Version & License

- **Version**: 0.0.0.9000 (development)
- **R requirement**: >= 4.1.0
- **License**: MIT + file LICENSE
