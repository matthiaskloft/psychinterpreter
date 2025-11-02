# psychinterpreter (development version)

## New Features

### Core Functionality
- Added `interpret_fa()` for LLM-powered factor analysis interpretation
- Implemented `chat_fa()` for persistent chat sessions to reduce token costs
- Added `is.chat_fa()` and `reset.chat_fa()` for session management

### Visualization
- Implemented `plot.fa_interpretation()` S3 method for factor loading heatmaps
- Added `create_factor_plot()` as backward-compatible wrapper
- Plots now use LLM-generated suggested factor names automatically

### Export & Utilities
- Added `export_interpretation()` supporting CSV, JSON, RDS, and TXT formats
- Implemented `find_cross_loadings()` to detect variables with multiple significant loadings
- Implemented `find_no_loadings()` to detect orphaned variables

### Print Methods
- Added `print.fa_interpretation()` for formatted console output
- Added `print.chat_fa()` to display session information and token usage

## Improvements

### Token Tracking
- Implemented dual-tier token tracking system using separate `get_tokens()` calls:
  - Per-run tokens: Uses `include_system_prompt = FALSE` to extract actual message content (accurate for all providers)
  - Cumulative tokens: Uses `include_system_prompt = TRUE` with safe delta calculation (prevents negative accumulation)
- Fixed issue where input tokens showed as 0 with Ollama provider
- Fixed issue where system prompt was incorrectly included in per-run token counts
- Added token usage display in reports and session summaries
- See `dev/token_tracking_fix_v3.md` for implementation details

### Chat Session Management
- Converted `chat_fa` objects to use environment-based storage for reference semantics
- Counter increments (`n_interpretations`) now persist correctly across function calls
- Added cumulative token tracking fields (`total_input_tokens`, `total_output_tokens`)

### Documentation
- Added comprehensive roxygen2 documentation for all exported functions
- Created getting started vignette (`vignettes/articles/01-Basic_Usage.qmd`)
- Added CLAUDE.md with detailed developer guidance

### Package Infrastructure
- Added VignetteBuilder configuration for pkgdown
- Set up _pkgdown.yml for website deployment
- Updated README with installation instructions, examples, and feature highlights
- Configured .Rbuildignore to exclude development files and build artifacts

## Bug Fixes

- Fixed negative token counts with providers that cache system prompts (e.g., Ollama)
- Fixed `n_interpretations` counter not persisting across `interpret_fa()` calls
- Fixed vignette configuration warnings in R CMD check
- Fixed plot to use suggested factor names instead of generic "Factor 1", "Factor 2", etc.

## Technical Details

### Dependencies
- Requires R >= 4.1.0
- Core dependencies: ellmer, dplyr, tidyr, cli, jsonlite
- Optional: ggplot2 (visualization), testthat (testing), knitr, rmarkdown (vignettes)

### Supported LLM Providers
- OpenAI (GPT models)
- Anthropic (Claude models)
- Ollama (local models)
- Google Gemini
- Azure OpenAI

## Known Issues

- Cumulative input token counts may be approximate with providers that cache system prompts (Ollama)
- Per-run tokens (`results$run_tokens`) provide accurate counts for all providers

---

# psychinterpreter 0.0.0.9000

* Initial development version
* Package structure initialized
* Basic functionality implemented
