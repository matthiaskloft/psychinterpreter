# LLM Prompt Templates and Patterns

**Last Updated**: 2025-11-21
**Purpose**: Document LLM prompt templates used in psychinterpreter

## Overview

The psychinterpreter package uses carefully crafted prompts to guide LLMs in interpreting psychometric analysis results. This document outlines the prompt structure and design principles.

## Prompt Architecture

Each analysis type implements two key prompt builders:
- **System Prompt**: Establishes expert persona and output format requirements
- **Main Prompt**: Provides analysis-specific data and instructions

## Factor Analysis Prompts

**Implementation**: `R/fa_prompt_builder.R`

**System Prompt** (`build_system_prompt.fa()`):
- Establishes psychometric expert persona
- Specifies JSON output format requirements
- Defines factor interpretation guidelines
- Sets word limit constraints

**Main Prompt** (`build_main_prompt.fa()`):
- Presents factor loadings matrix
- Includes variable descriptions
- Provides factor correlation matrix (oblique rotations)
- Adds model fit statistics
- Includes user-provided context (additional_info)

## Gaussian Mixture Prompts

**Implementation**: `R/gm_prompt_builder.R`

**System Prompt** (`build_system_prompt.gm()`):
- Establishes psychometric/latent profile analysis expert
- Specifies JSON output for cluster interpretations
- Defines cluster naming and profiling guidelines
- Sets word limit constraints

**Main Prompt** (`build_main_prompt.gm()`):
- Presents cluster means/profiles
- Includes variable descriptions
- Provides cluster sizes and proportions
- Adds uncertainty/overlap information
- Includes variance information (if requested)
- Includes user-provided context

## Prompt Design Principles

### 1. Expert Persona
System prompts establish domain expertise to improve response quality:
- Psychometric knowledge for FA
- Latent profile analysis expertise for GM
- Encourages appropriate technical terminology

### 2. Structured Output
JSON format requirements ensure parseable responses:
- `component_summaries`: Array of interpretations
- `suggested_names`: Array of short, descriptive labels
- Consistent structure across model types

### 3. Word Limits
Explicit word limits control response verbosity:
- Default: 150 words per component
- Minimum: 20 words (for testing)
- Maximum: 500 words
- Specified in system prompt for emphasis

### 4. Context Awareness
Prompts include rich context for informed interpretations:
- Variable descriptions (required for FA, recommended for GM)
- Model fit statistics
- Factor correlations (FA) or cluster overlap (GM)
- User-provided additional information

### 5. Iterative Refinement
Prompt templates have been refined based on:
- Testing with multiple LLM providers (OpenAI, Anthropic, Ollama)
- JSON parsing success rates
- Interpretation quality assessment
- Token efficiency measurements

## Testing Prompts

To view actual prompts sent to the LLM:

```r
# Enable prompt echo
interpretation <- interpret(
  fit_results = model,
  variable_info = var_info,
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud",
  echo = "all"  # Shows system prompt, main prompt, and LLM response
)
```

## Prompt Customization

### Custom System Prompt

Override default system prompt for institution-specific requirements:

```r
custom_prompt <- "You are an expert in organizational psychology..."

chat <- chat_session(
  analysis_type = "fa",
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud",
  system_prompt = custom_prompt  # Override default
)
```

### Additional Context

Add study-specific context via `additional_info`:

```r
interpretation <- interpret(
  fit_results = model,
  variable_info = var_info,
  additional_info = "Study context: personality assessment in organizational setting",
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud"
)
```

## Future Model Types

When implementing IRT or CDM support:
1. Follow FA/GM prompt structure
2. Establish appropriate expert persona
3. Define model-specific JSON output structure
4. Include relevant statistical context
5. Test with multiple providers

See `dev/templates/TEMPLATE_prompt_builder.R` for prompt implementation template.

---

**For implementation details**: See `R/fa_prompt_builder.R` and `R/gm_prompt_builder.R`
**For testing patterns**: See `dev/TESTING_GUIDELINES.md` Section on LLM Testing
