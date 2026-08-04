# psychinterpreter (development version)

## Bug fixes

- Gaussian mixture cluster separation no longer reports `0` for pairs whose
  averaged covariance is singular. The intended fallback was discarded by an
  assignment inside a `tryCatch()` error handler, so well-separated clusters
  could be reported as completely overlapping. Such pairs now yield `NA` and are
  reported as "separation unavailable" rather than being counted as overlapping.
  A Euclidean fallback is deliberately not substituted, because it is not
  comparable with the Mahalanobis threshold used downstream.
- The structured-list route for Gaussian mixture models
  (`interpret(fit_results = list(...), analysis_type = "gm")`) no longer fails
  with `object 'variable_info' not found`, and no longer resolves that name
  against the caller's global environment.
- `stats::loadings()` is now imported and fully qualified, fixing extraction
  from `lavaan::efa()` models.
- JSON block extraction from LLM responses now uses a PCRE pattern; the previous
  pattern never matched under R's default regex engine.

## Breaking changes

- The minimum supported R version is now **4.4.0** (was 4.2.0). The package uses
  `%||%`, which is only available in base R from 4.4.0 onward.

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
