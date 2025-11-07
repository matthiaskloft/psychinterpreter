# CLAUDE.md

This file provides guidance to Claude Code when working with the **psychinterpreter** R package.

## Package Overview

**psychinterpreter** automates interpretation of exploratory factor analysis (EFA) results using Large Language Models via the `ellmer` package. It interfaces with OpenAI, Anthropic, Ollama, Gemini, and Azure to generate human-readable factor names and interpretations.

**📁 Architecture Documentation**: For detailed technical architecture, see [dev/ARCHITECTURE.md](dev/ARCHITECTURE.md)

## Core Architecture

### LLM-Powered Interpretation Pipeline

1. **Factor Analysis Preparation** (R/fa_diagnostics.R):
   - Analyzes loadings against configurable cutoffs
   - Identifies significant loadings per factor
   - Applies "emergency rule" for weak factors (uses top N variables if none exceed cutoff)
   - Detects cross-loadings and orphaned variables

2. **LLM Communication** (R/fa_interpret.R, ~645 lines):
   - Constructs structured prompts with psychometric context
   - Processes ALL factors in a single LLM call (batch optimization)
   - Includes factor correlations for oblique rotations
   - Supports persistent chat sessions via `chat_session` objects to save tokens

3. **Report Generation** (R/report_fa.R):
   - Builds reports in text or markdown format
   - Includes interpretations, cross-loadings, and diagnostics
   - Text wrapping for console output
   - S3 method `build_report.fa_interpretation()` integrates with core system

### Persistent Chat Sessions

**Key innovation**: `chat_session` objects (R/base_chat_session.R) are reusable LLM sessions that preserve the system prompt.
- Single analysis: Creates temporary session
- Multiple analyses: Create one `chat_session`, pass to multiple `interpret()` calls
- Saves ~40-60% tokens per additional analysis by reusing system prompt

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
- Helper function `count_words()` in utils_text_processing.R
- **Note**: Changed from warning to message (2025-11-03) to reduce test noise

### JSON Parsing Strategy

Multi-tiered fallback for robust LLM response handling:
1. Try parsing cleaned JSON (remove extra text, fix formatting)
2. Fall back to original response
3. Pattern-based extraction if JSON parsing fails (via S3 method `extract_by_pattern.fa()`)
4. Default values if all methods fail (via S3 method `create_default_result.fa()`)

Critical for handling small/local models with imperfect JSON output. See R/generic_json_parser.R and R/fa_json.R.

### System Prompt Architecture

The psychometric expert system prompt is defined in **ONE location**:
- `R/fa_prompt_builder.R` via S3 method `build_system_prompt.fa()`
- Used by both single-use and persistent sessions
- **Single source of truth** - no duplication

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

**Active R Files (15 files, ~4,654 lines total):**

```
R/
├── Core Infrastructure (5 files, ~1,054 lines)
│   ├── generic_interpret.R      # Main interpretation orchestration (392 lines)
│   ├── generic_json_parser.R    # Multi-tier JSON parsing with S3 (200 lines)
│   ├── generic_prompt_builder.R # S3 generics for prompts (83 lines)
│   ├── base_chat_session.R      # Chat session management (287 lines)
│   └── base_interpretation.R    # Base interpretation objects (92 lines)
│
├── Factor Analysis Implementation (7 files, ~3,154 lines)
│   ├── fa_interpret.R           # Main FA interpretation function (645 lines)
│   ├── fa_prompt_builder.R      # FA prompts (S3 methods, 340 lines)
│   ├── fa_json.R                # FA JSON parsing (S3 methods, 232 lines)
│   ├── fa_diagnostics.R         # Diagnostics + S3 method (199 lines)
│   ├── interpret_methods.R      # S3 methods for psych/lavaan/mirt (744 lines)
│   ├── interpret_helpers.R      # Validation and routing (156 lines)
│   └── report_fa.R              # Report building + S3 method (838 lines)
│
└── Utilities (3 files, ~446 lines)
    ├── export_functions.R       # Export to txt/md (132 lines)
    ├── utils_text_processing.R  # Text wrapping, word counting (107 lines)
    └── visualization.R          # S3 plot method, heatmaps (207 lines)

R/archive/  # 8 redundant/old files (not loaded)
```

**Tests:**

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

### The interpret() Generic: Four Usage Patterns

The `interpret()` function is the main entry point for all interpretations, supporting four flexible dispatch patterns:

#### Pattern 1: Model Objects (Automatic Extraction)

```r
# Automatically extracts loadings from fitted models
fa_result <- psych::fa(data, nfactors = 3)
interpretation <- interpret(fa_result,
                           variable_info = var_descriptions,
                           llm_provider = "anthropic",
                           llm_model = "claude-haiku-4-5-20251001")

# Also works with lavaan, mirt, etc.
efa_result <- lavaan::efa(data, nfactors = 3)
interpretation <- interpret(efa_result, variable_info = var_descriptions)
```

#### Pattern 2: Raw Data with model_type

```r
# For custom loadings matrices or manual extraction
loadings <- as.data.frame(unclass(fa_model$loadings))

interpretation <- interpret(loadings,
                           variable_info = var_descriptions,
                           model_type = "fa",
                           llm_provider = "anthropic",
                           llm_model = "claude-haiku-4-5-20251001")
```

#### Pattern 3: Persistent Chat Session (Most Token-Efficient)

```r
# Create session once
chat <- chat_session(model_type = "fa",
                    provider = "anthropic",
                    model = "claude-haiku-4-5-20251001")

# Use session as first argument - saves system prompt tokens
result1 <- interpret(chat, loadings1, var_info1)
result2 <- interpret(chat, loadings2, var_info2)  # Reuses system prompt
result3 <- interpret(chat, loadings3, var_info3)

print(chat)  # Check cumulative tokens
```

#### Pattern 4: Raw Data with chat_session Parameter

```r
# Combine raw data with persistent session
interpretation <- interpret(loadings,
                           variable_info = var_descriptions,
                           chat_session = chat)
# model_type automatically inherited from chat session
```

**Pattern Recommendation:**
- **Single analysis**: Pattern 1 (model objects) - simplest
- **Multiple analyses**: Pattern 3 (chat session) - most efficient
- **Custom data**: Pattern 2 or 4 depending on whether you need multi-analysis

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

### Token-Efficient Multi-Analysis Workflow (Legacy)

**Note:** `chat_fa()` is deprecated. Use `chat_session()` with the interpret() generic (see Pattern 3 above) for new code.

```r
# Legacy approach - still works but deprecated
chat <- chat_fa("anthropic", "claude-haiku-4-5-20251001")

# Interpret multiple analyses
results1 <- interpret_fa(loadings1, var_info1, chat_session = chat)
results2 <- interpret_fa(loadings2, var_info2, chat_session = chat)
results3 <- interpret_fa(loadings3, var_info3, chat_session = chat)

# Check token usage
print(chat)  # Shows cumulative tokens and n_interpretations
```

```r
# Modern approach - recommended
chat <- chat_session(model_type = "fa",
                    provider = "anthropic",
                    model = "claude-haiku-4-5-20251001")

# Use with interpret() generic
results1 <- interpret(chat, loadings1, var_info1)
results2 <- interpret(chat, loadings2, var_info2)
results3 <- interpret(chat, loadings3, var_info3)

print(chat)  # Shows cumulative tokens
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

Report generation in `build_fa_report()` (report_fa.R:~18) supports:
- `output_format`: "text" or "markdown"
- `heading_level`: For markdown hierarchy
- `suppress_heading`: For embedding in documents

The S3 method `build_report.fa_interpretation()` (report_fa.R:~805) integrates with the generic system.

## Recent Key Updates

### 2025-11-07
- ✓ **Major Code Cleanup**: Identified and removed all redundant code
  - Removed 3 duplicate R source files: fa_report_functions.R (804 lines), fa_wrapper_methods.R (556 lines), fa_utilities.R (165 lines)
  - Total redundant code eliminated: ~1,559 lines
  - Archive now contains 8 old/redundant files for reference
- ✓ **Documentation Overhaul**:
  - Deleted outdated dev/STATUS.md (referenced non-existent refactoring)
  - Deleted redundant dev/FILE_STRUCTURE.md (duplicated CLAUDE.md)
  - Created comprehensive dev/ARCHITECTURE.md (technical reference)
  - Updated CLAUDE.md to accurately reflect current package state
- ✓ **Single Source of Truth**: All components now have exactly one definition
  - System prompts: Only in fa_prompt_builder.R (was duplicated in interpret_fa.R)
  - Report building: Only in report_fa.R (was duplicated in fa_report_functions.R)
  - Interpret methods: Only in interpret_methods.R (was duplicated in fa_wrapper_methods.R)
  - Diagnostic functions: Only in fa_diagnostics.R (was duplicated in fa_utilities.R)
- ✓ **Cleaner Package Structure**: 15 active R files (down from 18), better organized
  - Core infrastructure: 5 files (~1,054 lines)
  - FA implementation: 7 files (~3,154 lines)
  - Utilities: 3 files (~446 lines)

### 2025-11-05
- ✓ **hide_low_loadings parameter**: Added `hide_low_loadings` parameter to `interpret_fa()`. When TRUE, only variables with loadings at or above the cutoff are included in data sent to the LLM, reducing token usage and focusing interpretation on significant loadings.
- ✓ **n_emergency = 0 support**: `n_emergency` parameter now accepts 0. When set to 0, factors with no significant loadings are labeled as "undefined" with "NA" interpretations, providing explicit handling of weak/undefined factors instead of forcing interpretation of weak loadings.
- ✓ **Emergency rule indicator**: Factor names from the emergency rule (when no loadings exceed cutoff) now automatically receive a "(n.s.)" suffix to clearly indicate non-significant loadings were used for interpretation.

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

- ~~interpret() needs to be able to dispatch methods for all interpretations~~ **COMPLETED (2025-11-07)**
  - ✓ Supports model objects with automatic extraction
  - ✓ Supports raw data with model_type specification
  - ✓ Supports chat_session as first argument
  - ✓ Supports raw data with chat_session parameter
  - ✓ Full validation of model, chat_session, and model_type consistency
  - ✓ interpret() is now the primary package interface

- ~~identify redundant old R scripts and move them to archive~~ **COMPLETED (2025-11-07)**
  - ✓ Archived R/fa_chat.R (replaced by base_chat_session.R)
  - ✓ Archived R/utils_export.R (duplicate of export_functions.R)
  - ✓ Archived R/fa_utilities.R (duplicate of fa_diagnostics.R minus S3 method)
  - ✓ Archived R/fa_wrapper_methods.R (old interpret() dispatch, replaced by interpret_methods.R)
  - ✓ Archived R/fa_report_functions.R (duplicate of report_fa.R minus S3 method)
  - ✓ Total: 8 archived files, 3 redundant files removed from active codebase

- ~~analyze current package logic, improve it where necessary, and document in the end. synthesize or Remove redundant documentation in dev/~~ **COMPLETED (2025-11-07)**
  - ✓ Analyzed package architecture and identified all redundancies
  - ✓ Removed 3 duplicate R source files (saved ~1,559 lines of redundant code)
  - ✓ Deleted outdated dev/STATUS.md (referenced non-existent refactoring)
  - ✓ Deleted redundant dev/FILE_STRUCTURE.md (duplicated CLAUDE.md content)
  - ✓ Created comprehensive dev/ARCHITECTURE.md (technical architecture reference)
  - ✓ Updated CLAUDE.md to reflect current package state
  - ✓ Single source of truth for all components (no more duplicates)
  
- tests are lengthy, analyze for potential improvements in run time and token usage

- conduct interactive code review

- Change silent argument to integer (0 = report + messages, 1 = messages, 2 = show nothing)

- Implement a summary method. Shows the chat details and suggested names for "fa"
  
- Implement gaussian_mixture class
  
  
  
## Known Issues

None currently.


## Version & License

- **Version**: 0.0.0.9000 (development)
- **R requirement**: >= 4.1.0
- **License**: MIT + file LICENSE
- put development related markdowns into dev/
