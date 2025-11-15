
<!-- README.md is generated from README.Rmd. Please edit that file -->

# psychinterpreter <img src="man/figures/logo.png" align="right" height="139" alt="" />

<!-- badges: start -->

[![R-CMD-check](https://github.com/matthiaskloft/psychinterpreter/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/matthiaskloft/psychinterpreter/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/matthiaskloft/psychinterpreter/graph/badge.svg)](https://app.codecov.io/gh/matthiaskloft/psychinterpreter)
<!-- badges: end -->

**LLM-powered interpretation of factor and cluster analyses.**

**Disclaimer:** This package is in early development and should be used
with caution. Always review and validate LLM-generated interpretations.

## Features

- 🤖 **LLM-Powered Interpretation**: Generate human-readable factor
  names and interpretations using state-of-the-art language models via
  the [‘ellmer’](https://ellmer.tidyverse.org/) package
- 🔌 **Seamless Integration**: S3 methods for popular packages - just
  pass your fitted model objects directly
  - `psych::fa()` and `psych::principal()` results
  - `lavaan::cfa()`, `lavaan::sem()`, and `lavaan::efa()` results
  - `mirt::mirt()` multidimensional IRT results
  - Auto-extracts loadings and factor correlations
- 📊 **Comprehensive Reports**: Automatically generate detailed reports
  in text or markdown format
- 📈 **Visualizations**: Create publication-ready heatmaps of factor
  loadings with suggested factor names
- 💾 **Multi-Format Export**: Export results to TXT and MD formats
- 🎯 **Provider Agnostic**: Works with OpenAI, Anthropic, Google Gemini,
  Azure, Ollama, and more via [‘ellmer’](https://ellmer.tidyverse.org/)
- 🔄 **Persistent Chat Sessions**: Reuse LLM sessions across multiple
  analyses to save tokens and reduce costs

## Installation

You can install the development version of psychinterpreter from GitHub:

``` r
# install.packages("devtools")
devtools::install_github("https://github.com/matthiaskloft/psychinterpreter")
```

## Quick Start

### Simple S3 Method (Recommended)

``` r
library(psychinterpreter)
library(psych)

# Run factor analysis
fa_result <- fa(bfi[, 1:25], nfactors = 5, rotate = "oblimin")

# Create variable information
var_info <- data.frame(variable = rownames(bfi.dictionary[1:25, ]),
                       description = bfi.dictionary$Item[1:25])

# Interpret directly from model object
results <- interpret(
  fa_result,
  variable_info = var_info,
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud"
)
```

### Manual Approach

For more control or custom loadings matrices:

``` r
# Extract loadings manually
loadings <- fa_result$loadings

# Use structured list with analysis_type
results <- interpret(
  fit_results = list(loadings = loadings),
  variable_info = var_info,
  analysis_type = "fa",
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud"
)
```

### Efficient Multi-Analysis Workflows

Use persistent chat sessions to save tokens when analyzing multiple
datasets:

``` r
# Create reusable chat session
chat <- chat_session(
  analysis_type = "fa",
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud"
)

# Run multiple interpretations (saves ~40-60% tokens)
result1 <- interpret(
  chat_session = chat,
  fit_results = fa_result1,
  variable_info = var_info1,
  silent = 2
)
result2 <- interpret(
  chat_session = chat,
  fit_results = fa_result2,
  variable_info = var_info2
)
result3 <- interpret(
  chat_session = chat,
  fit_results = fa_result3,
  variable_info = var_info3
)

# Check cumulative token usage
print(chat)
```

## Documentation

- **Website:** <https://matthiaskloft.github.io/psychinterpreter/>

- **Articles:**

  - [Getting Started
    Guide](https://matthiaskloft.github.io/psychinterpreter/articles/01-Getting_Started.html)
  - [Usage Patterns for
    `interpret()`](https://matthiaskloft.github.io/psychinterpreter/articles/02-Usage_Patterns.html)

## Contributing

- [Open an
  Issue](https://github.com/matthiaskloft/psychinterpreter/issues):
  Basic usage of the package

## Citation

If you use psychinterpreter in your research, please cite:

Kloft, M. (2025). psychinterpreter: LLM-powered interpretation of factor
and cluster analyses. R package version 0.0.0.9000.
