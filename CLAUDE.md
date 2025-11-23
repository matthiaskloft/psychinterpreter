# Generic Guidance

Read AGENT.md for all a quick reference for a generic agent when helping users with the **psychinterpreter** R package. 
There you will find the contents you would typically find in CLAUDE.md.



# Claude-Specific Guidance
This document contains guidance specific to using the `psychinterpreter` package with Anthropic's Claude models.

## API Configuration

Set your Anthropic API key as an environment variable:

```r
# Set API keys as environment variables
Sys.setenv(ANTHROPIC_API_KEY = "your-key")   # Anthropic
```

## Model Names

When using Claude models, you will typically use a model name like `"claude-3-opus-20240229"` in the `llm_model` argument.
