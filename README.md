# psychinterpreter <img src="man/figures/logo.png" align="right" height="139" alt="" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/matthiaskloft/psychinterpreter/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/matthiaskloft/psychinterpreter/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->


Automate the interpretation of exploratory factor analysis (EFA) and cluster analysis results using Large Language Models (LLMs) via the [ellmer](https://ellmer.tidyverse.org/) package.

## Features

- 🤖 **LLM-Powered Interpretation**: Generate human-readable factor names and interpretations using state-of-the-art language models
- 🔄 **Persistent Chat Sessions**: Reuse LLM sessions across multiple analyses to save tokens and reduce costs
- 📊 **Comprehensive Reports**: Automatically generate detailed reports in text or markdown format
- 📈 **Visualizations**: Create publication-ready heatmaps of factor loadings with suggested factor names
- 💾 **Multi-Format Export**: Export results to CSV, JSON, RDS, or TXT formats
- 🎯 **Provider Agnostic**: Works with OpenAI, Anthropic, Ollama, Gemini, and Azure

## Installation

You can install the development version of psychinterpreter from GitHub:

```r
# install.packages("devtools")
devtools::install_github()
```

## Quick Start

```r
library(psychinterpreter)

# Run factor analysis (using psych package or similar)
fa_result <- psych::fa(data, nfactors = 5, rotate = "oblimin")

# Extract loadings
loadings <- fa_result$loadings

# Create variable information data frame
var_info <- data.frame(
  variable = rownames(loadings),
  description = c("Variable 1 description", ...)
)

# Interpret with LLM (requires API key set in environment)
Sys.setenv(ANTHROPIC_API_KEY = "your-key-here")

results <- interpret_fa(
  loadings = loadings,
  var_info = var_info,
  llm_provider = "anthropic",
  llm_model = "claude-haiku-4-5-20251001"
)

# View results
print(results)

# Visualize loadings with suggested factor names
plot(results)

# Export to multiple formats
export_interpretation(results, "my_results", format = "csv")
```

## Efficient Multi-Analysis Workflows

Use persistent chat sessions to save tokens when analyzing multiple datasets:

```r
# Create reusable chat session
chat <- chat_fa("anthropic", "claude-haiku-4-5-20251001")

# Run multiple interpretations
result1 <- interpret_fa(loadings1, var_info1, chat_session = chat)
result2 <- interpret_fa(loadings2, var_info2, chat_session = chat)
result3 <- interpret_fa(loadings3, var_info3, chat_session = chat)

# Check token usage
print(chat)
```

## Supported LLM Providers

Configure your API keys as environment variables:

```r
# OpenAI
Sys.setenv(OPENAI_API_KEY = "your-key")

# Anthropic
Sys.setenv(ANTHROPIC_API_KEY = "your-key")

# Ollama (local, no key needed)
# Just install and run Ollama

# Gemini
Sys.setenv(GEMINI_API_KEY = "your-key")

# Azure OpenAI
Sys.setenv(AZURE_OPENAI_API_KEY = "your-key")
```

## Documentation

- [Getting Started Guide](https://matthiaskloft.github.io/psychinterpreter/articles/01-Basic_Usage.html)
- [Function Reference](https://matthiaskloft.github.io/psychinterpreter/reference/index.html)

## Key Functions

- `interpret_fa()` - Main interpretation function
- `chat_fa()` - Create persistent chat session
- `plot.fa_interpretation()` - Visualize factor loadings
- `export_interpretation()` - Export results to multiple formats
- `find_cross_loadings()` - Detect cross-loading variables
- `find_no_loadings()` - Detect variables with no significant loadings

## Citation

If you use psychinterpreter in your research, please cite:

```
Kloft, M. (2025). psychinterpreter: LLM-powered interpretation of factor and cluster analyses. R package version 0.0.0.9000. https://github.com/matthiaskloft/psychinterpreter
```

## License

MIT + file LICENSE

## Contributing

- [Open an Issue](https://github.com/matthiaskloft/psychinterpreter/issues)

