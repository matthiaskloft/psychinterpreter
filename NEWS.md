# psychinterpreter 0.1.0

Initial release of psychinterpreter - automated interpretation of exploratory factor analysis using Large Language Models.

## Core Features

- **Universal interpretation interface**: `interpret()` function with S3 dispatch system
- **Token-efficient sessions**: `chat_session()` saves ~40-60% tokens for multiple analyses
- **Flexible input handling**: Supports `psych::fa()`, `lavaan::efa()`, `mirt::mirt()`, and custom data structures
- **Color-blind friendly visualizations**: `plot()` method with Okabe-Ito palette
- **Export functionality**: Save interpretations as text or markdown files
- **Diagnostic utilities**: `find_cross_loadings()` and `find_no_loadings()`

## LLM Provider Support

All providers supported by the `ellmer` package, including OpenAI, Anthropic, Ollama, Google Gemini, and Azure OpenAI.

## Technical Highlights

- S3 generic architecture: `interpret()` → `interpret_core()` → `build_analysis_data.fa()`
- Dual-tier token tracking (per-run and cumulative)
- Environment-based session storage for proper reference semantics
- Multi-tier JSON parsing with automatic fallback handling
- Comprehensive test suite (169 tests)

## Documentation

- Getting started vignette
- Developer guide with architecture details
- Testing guidelines and templates for future model types
