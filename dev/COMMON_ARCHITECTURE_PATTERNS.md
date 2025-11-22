# Common Architecture Patterns Across Model Types

**Purpose**: Documents shared architectural patterns between FA and GM implementations to guide future model type development.

**Last Updated**: 2025-11-22

**Status**: Stable - Based on analysis of FA and GM implementations

---

## Table of Contents

1. [Overview](#overview)
2. [File Structure Pattern](#file-structure-pattern)
3. [S3 Method Dispatch Pattern](#s3-method-dispatch-pattern)
4. [Data Structure Pattern](#data-structure-pattern)
5. [Parameter Extraction Pattern](#parameter-extraction-pattern)
6. [Prompt Construction Pattern](#prompt-construction-pattern)
7. [JSON Response Pattern](#json-response-pattern)
8. [Validation and Fallback Pattern](#validation-and-fallback-pattern)
9. [Report Generation Pattern](#report-generation-pattern)
10. [Diagnostic Pattern](#diagnostic-pattern)
11. [Integration Points](#integration-points)

---

## Overview

The psychinterpreter package uses a **highly consistent architecture** across model types. Both FA and GM implementations follow identical patterns with only model-specific data varying. This document extracts those common patterns to simplify future implementations.

**Key Principle**: If you can implement one model type, you can implement any model type by following these patterns.

---

## File Structure Pattern

### Standard File Organization

Every model type uses 7-8 core files:

| File | Purpose | Lines | Required? |
|------|---------|-------|-----------|
| `{model}_model_data.R` | Extract & validate data from fitted objects | 400-600 | ✓ Yes |
| `{model}_prompt_builder.R` | Build system and user prompts | 300-400 | ✓ Yes |
| `{model}_json.R` | Parse and validate LLM JSON responses | 200-300 | ✓ Yes |
| `{model}_diagnostics.R` | Model-specific diagnostic checks | 200-400 | ✓ Yes |
| `{model}_report.R` | Format user-facing reports | 400-800 | ✓ Yes |
| `{model}_visualization.R` | Create plots | 300-600 | Optional |
| `{model}_export.R` | Export functionality | 100-200 | Optional |
| `{model}_utils.R` | Helper functions | Variable | Optional |

### Naming Convention

- **Prefix**: Always `{model}_` where `{model}` is lowercase abbreviation (fa, gm, irt, cdm)
- **Suffix**: Functional descriptor (model_data, prompt_builder, json, etc.)
- **Classes**: Primary fitted object class (psych, Mclust, SingleGroupClass, etc.)

---

## S3 Method Dispatch Pattern

### Core S3 Methods (Required)

Every model type implements these S3 methods:

```r
# 1. Data Extraction (model_data.R)
build_analysis_data.{CLASS}(fit_results, variable_info, analysis_type, interpretation_args, ...)

# 2. System Prompt (prompt_builder.R)
build_system_prompt.{model}(analysis_type, word_limit, ...)

# 3. User Prompt (prompt_builder.R)
build_main_prompt.{model}(analysis_type, analysis_data, word_limit, additional_info, ...)

# 4. JSON Validation (json.R)
validate_parsed_result.{model}(parsed, analysis_type, analysis_data, ...)

# 5. Fallback Extraction (json.R)
extract_by_pattern.{model}(response, analysis_type, analysis_data, ...)

# 6. Default Results (json.R)
create_default_result.{model}(analysis_type, ...)

# 7. Diagnostics (diagnostics.R)
create_fit_summary.{model}(analysis_type, analysis_data, ...)
```

### Dispatch Flow

```
interpret()
  → build_analysis_data.{CLASS}()
      → build_{model}_analysis_data_internal()
  → build_system_prompt.{model}()
  → build_main_prompt.{model}()
  → [LLM call via ellmer]
  → validate_parsed_result.{model}()
      → [if fails] extract_by_pattern.{model}()
      → [if fails] create_default_result.{model}()
  → create_fit_summary.{model}()
  → format_interpretation_report.{model}()
```

### Multiple Fitted Object Classes

If multiple packages produce the same model type, create aliases:

```r
# Example from FA
build_analysis_data.psych <- function(...) { ... }
build_analysis_data.fa <- build_analysis_data.psych
build_analysis_data.principal <- build_analysis_data.psych
build_analysis_data.lavaan <- function(...) { ... }  # Different extraction logic
```

---

## Data Structure Pattern

### Standardized `analysis_data` Structure

All `build_{model}_analysis_data_internal()` functions return a list with this structure:

```r
list(
  # === UNIVERSAL METADATA (all models) ===
  analysis_type = "fa",           # Model type identifier
  n_components = 3,                # Number of factors/clusters/items
  n_variables = 10,                # Number of variables
  variable_names = c("v1", ...),   # Variable names (character vector)
  component_names = c("F1", ...),  # Component names (character vector)

  # === MODEL-SPECIFIC DATA ===
  # FA example:
  loadings_df = <data.frame>,      # Variable loadings
  factor_summaries = <list>,       # Summary per factor
  factor_cor_mat = <matrix>,       # Factor correlations (optional)

  # GM example:
  means = <matrix>,                # Cluster means
  covariances = <array>,           # Cluster covariances
  proportions = <numeric>,         # Cluster sizes
  uncertainty = <numeric>,         # Assignment uncertainty

  # === MODEL-SPECIFIC PARAMETERS ===
  # FA example:
  cutoff = 0.3,
  n_emergency = 2,
  hide_low_loadings = FALSE,

  # GM example:
  min_cluster_size = 5,
  separation_threshold = 0.3,
  weight_by_uncertainty = FALSE,

  # === CLASS ===
  class = c("{model}_analysis_data", "analysis_data", "list")
)
```

### Key Observations

1. **First 5 fields are universal** - Every model has analysis_type, n_components, n_variables, variable_names, component_names
2. **Model data is model-specific** - Different statistical structures per model type
3. **Parameters are embedded** - Interpretation parameters stored in analysis_data for use in prompts
4. **Classed for dispatch** - Enables S3 method dispatch in later steps

---

## Parameter Extraction Pattern

### Triple-Tier Extraction

Both FA and GM use identical pattern for extracting parameters:

```r
# Step 1: Extract from interpretation_args (highest priority)
# Step 2: Fall back to ... (dots)
# Step 3: Fall back to get_param_default() (package default)

param <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
  interpretation_args$param
} else {
  dots$param
}
if (is.null(param)) param <- get_param_default("param")
```

### Parameter Types

Three distinct parameter categories (never mix):

1. **Analysis-specific** → `interpretation_args`
   - FA: cutoff, n_emergency, hide_low_loadings, sort_loadings
   - GM: min_cluster_size, separation_threshold, weight_by_uncertainty, plot_type

2. **LLM settings** → `llm_args`
   - word_limit, llm_provider, llm_model, additional_info, echo

3. **Output settings** → `output_args`
   - format, silent, heading_level, suppress_heading, max_line_length

### Registry Integration

Both models use centralized parameter registry:

```r
# Register parameter (done once in aaa_param_registry.R)
.register_param(
  name = "cutoff",
  default = 0.3,
  type = "numeric",
  range = c(0, 1),
  description = "Minimum loading threshold"
)

# Use in code
cutoff <- get_param_default("cutoff")

# Validate
validated <- validate_params(list(cutoff = cutoff), throw_error = TRUE)
```

---

## Prompt Construction Pattern

### System Prompt Structure

Both FA and GM use identical template:

```r
build_system_prompt.{model} <- function(analysis_type, word_limit = 100, ...) {
  paste0(
    "# ROLE\n",
    "You are an expert psychometrician specializing in {model_full_name}.\n\n",

    "# TASK\n",
    "{task description with numbered steps}\n\n",

    "# KEY DEFINITIONS\n",
    "- **Term 1**: Definition\n",
    "- **Term 2**: Definition\n",
    "...\n"
  )
}
```

### User Prompt Structure

Both FA and GM use identical 6-section structure:

```r
build_main_prompt.{model} <- function(analysis_type, analysis_data, word_limit, additional_info, ...) {

  prompt <- ""

  # Section 1: INTERPRETATION GUIDELINES
  prompt <- paste0(prompt, build_guidelines_section(word_limit))

  # Section 2: ADDITIONAL CONTEXT (if provided)
  if (!is.null(additional_info)) {
    prompt <- paste0(prompt, "# ADDITIONAL CONTEXT\n", additional_info, "\n\n")
  }

  # Section 3: MODEL INFORMATION
  prompt <- paste0(prompt, build_model_info_section(analysis_data))

  # Section 4: VARIABLE DESCRIPTIONS
  prompt <- paste0(prompt, build_variable_section(analysis_data, variable_info))

  # Section 5: DATA SECTION (model-specific)
  prompt <- paste0(prompt, build_data_section(analysis_data))

  # Section 6: OUTPUT FORMAT
  prompt <- paste0(prompt, build_output_instructions(analysis_data, word_limit))

  return(prompt)
}
```

### Helper Functions

Both models use modular helper functions:

- `build_variable_section_{model}()` - Format variable descriptions
- `build_data_section_{model}()` - Format model data (loadings/cluster profiles)
- `build_output_instructions_{model}()` - JSON format example
- Additional model-specific helpers as needed

---

## JSON Response Pattern

### Expected Structure

Both models expect identical JSON structure from LLM:

```json
{
  "Component_1": {
    "name": "Short Name",
    "interpretation": "Detailed interpretation text..."
  },
  "Component_2": {
    "name": "Another Name",
    "interpretation": "More interpretation..."
  }
}
```

- **Keys**: Component names (Factor_1, Cluster_1, etc.)
- **Values**: Objects with "name" and "interpretation" fields
- **Names**: 2-4 words maximum
- **Interpretations**: Target 80-100% of word_limit

### Validation Logic

Both models implement identical validation:

```r
validate_parsed_result.{model} <- function(parsed, analysis_type, analysis_data, ...) {
  # 1. Check if list
  if (!is.list(parsed)) return(NULL)

  # 2. Check expected keys present
  expected_keys <- analysis_data$component_names
  if (!all(expected_keys %in% names(parsed))) return(NULL)

  # 3. Check each component has "name" and "interpretation"
  for (key in expected_keys) {
    if (!all(c("name", "interpretation") %in% names(parsed[[key]]))) {
      return(NULL)
    }
  }

  # 4. Extract and return standardized structure
  return(list(
    component_summaries = ...,
    suggested_names = ...
  ))
}
```

---

## Validation and Fallback Pattern

### Three-Tier Fallback System

Both models use identical fallback hierarchy:

```r
# Tier 1: Standard JSON parsing
parsed <- jsonlite::fromJSON(response)
result <- validate_parsed_result.{model}(parsed, analysis_type, analysis_data)
if (!is.null(result)) return(result)

# Tier 2: Pattern-based extraction
result <- extract_by_pattern.{model}(response, analysis_type, analysis_data)
if (!is.null(result)) return(result)

# Tier 3: Default values
return(create_default_result.{model}(analysis_type, analysis_data))
```

### Pattern Extraction

Both models use regex patterns to extract from malformed JSON:

```r
extract_by_pattern.{model} <- function(response, analysis_type, analysis_data, ...) {
  # Try multiple patterns in order of reliability
  patterns <- c(
    # Pattern 1: Full JSON object
    '"Component_N"\\s*:\\s*\\{\\s*"name"\\s*:\\s*"([^"]+)"\\s*,\\s*"interpretation"\\s*:\\s*"([^"]+)"',
    # Pattern 2: Just interpretation
    '"Component_N"\\s*:\\s*"([^"]+)"',
    # Pattern 3: Markdown-style
    '\\*\\*Component N\\*\\*\\s*:?\\s*([^\n]+)'
  )

  # Apply patterns and extract
  # Return standardized result or NULL if extraction fails
}
```

---

## Report Generation Pattern

### Report Structure

Both models produce reports with identical structure:

```r
# 1. Header
"== {MODEL_NAME} INTERPRETATION =="

# 2. Model Information
"Analysis Type: {model}"
"Components: {n_components}"
"Variables: {n_variables}"

# 3. Component Summaries
for each component:
  "## {component_name}: {suggested_name}"
  "{interpretation_text}"

# 4. Diagnostics
diagnostic_section()

# 5. Token Usage
"Tokens Used: {tokens}"
```

### Format Variations

Both support CLI and Markdown formats:

```r
format_interpretation_report.{model} <- function(interpretation, format = "cli", ...) {
  if (format == "cli") {
    return(format_cli_report(interpretation))
  } else if (format == "markdown") {
    return(format_markdown_report(interpretation))
  }
}
```

---

## Diagnostic Pattern

### Fit Summary Structure

Both models return diagnostic lists with identical structure:

```r
create_fit_summary.{model} <- function(analysis_type, analysis_data, ...) {
  list(
    # Model statistics
    statistics = list(
      n_components = ...,
      n_variables = ...,
      # model-specific stats
    ),

    # Warnings (potential issues)
    warnings = c(
      "Warning 1: description",
      "Warning 2: description"
    ),

    # Notes (informational)
    notes = c(
      "Note 1: description",
      "Note 2: description"
    ),

    # Model-specific diagnostics
    # FA: cross_loadings, no_loadings
    # GM: overlapping_clusters, distinguishing_variables
  )
}
```

### Common Diagnostic Types

1. **Quality checks**: e.g., weak factors, small clusters
2. **Structural issues**: e.g., cross-loadings, cluster overlap
3. **Data quality**: e.g., missing loadings, high uncertainty
4. **Informational**: e.g., model fit statistics, recommendations

---

## Integration Points

### Registry Integration

All models must register in three places:

```r
# 1. Parameter Registry (aaa_param_registry.R)
.register_param("param_name", default = value, type = "type", ...)

# 2. Dispatch Tables (shared_config.R)
.ANALYSIS_TYPE_DISPLAY_NAMES <- c(
  fa = "Factor Analysis",
  gm = "Gaussian Mixture",
  {model} = "{Display Name}"
)

.VALID_INTERPRETATION_PARAMS <- list(
  {model} = c("param1", "param2", ...)
)

.INTERPRETATION_ARGS_DISPATCH <- list(
  {model} = interpretation_args_{model}
)

# 3. Model Type Dispatch (aaa_model_type_dispatch.R)
get_model_dispatch_table() returns:
  {CLASS} = list(
    analysis_type = "{model}",
    package = "{package}",
    validator_name = "validate_{model}_model",
    extractor_name = "extract_{model}_data"
  )
```

### Configuration Objects

All models implement `interpretation_args_{model}()`:

```r
interpretation_args_{model} <- function(
  analysis_type = "{model}",
  param1 = NULL,
  param2 = NULL,
  ...
) {
  # Extract defaults from registry
  param1 <- param1 %||% get_param_default("param1")
  param2 <- param2 %||% get_param_default("param2")

  # Validate
  validated <- validate_params(
    list(param1 = param1, param2 = param2),
    throw_error = TRUE
  )

  # Return classed list
  structure(
    validated,
    class = c("interpretation_args_{model}", "interpretation_args", "list")
  )
}
```

---

## Summary: Implementation Checklist

When implementing a new model type, follow this pattern:

### Phase 1: Setup
- [ ] Register parameters in `aaa_param_registry.R`
- [ ] Add model to dispatch tables in `shared_config.R`
- [ ] Create `interpretation_args_{model}()` in `shared_config.R`
- [ ] Add model type dispatch in `aaa_model_type_dispatch.R`

### Phase 2: Core Files (follow templates)
- [ ] `{model}_model_data.R` - Data extraction
- [ ] `{model}_prompt_builder.R` - Prompt construction
- [ ] `{model}_json.R` - JSON parsing
- [ ] `{model}_diagnostics.R` - Fit summary
- [ ] `{model}_report.R` - Report formatting

### Phase 3: Optional Files
- [ ] `{model}_visualization.R` - Plotting
- [ ] `{model}_export.R` - Export functionality
- [ ] `{model}_utils.R` - Helpers

### Phase 4: Testing & Documentation
- [ ] Test files for each component
- [ ] Roxygen documentation
- [ ] Update CLAUDE.md with usage examples
- [ ] Update _pkgdown.yml

---

**Conclusion**: The psychinterpreter architecture is highly modular and consistent. Following these patterns makes adding new model types straightforward and ensures maintainability.

