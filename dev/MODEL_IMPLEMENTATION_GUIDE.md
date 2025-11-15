# Model Implementation Guide

**Purpose**: Step-by-step guide for implementing new model types in the psychinterpreter package.

**Last Updated**: 2025-11-12

**Status**: Template ready for GM, IRT, and CDM implementations

---

## Quick Start

**Prefer code-first learning?** See [`/dev/templates/`](templates/) for ready-to-copy template files with placeholders. Use the templates together with this guide for best results:

- **Templates** provide exact code to copy
- **This Guide** provides conceptual background, troubleshooting, and common patterns

**Recommended approach**: Skim this Overview section, then use templates with the implementation checklist, referring back to this guide for explanations and troubleshooting as needed.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Implementation Checklist](#implementation-checklist)
4. [Step-by-Step Guide](#step-by-step-guide)
5. [Method Implementation Details](#method-implementation-details)
6. [Testing Strategy](#testing-strategy)
7. [Common Patterns](#common-patterns)
8. [Troubleshooting](#troubleshooting)

---

## Overview

### Architecture Summary

The package uses an S3 generic dispatch system with a universal orchestrator:

```
interpret() [user-facing API]
    ↓
interpret_model.{class}() [class-based routing - OPTIONAL]
    ↓
interpret_core() [universal orchestrator - NEVER MODIFY]
    ↓
build_analysis_data.{class}() [STEP 0: Extract analysis data]
    ↓
build_system_prompt.{analysis}() [STEP 4: System prompt]
build_main_prompt.{analysis}() [STEP 6: User prompt]
    ↓
[LLM API call - handled by interpret_core]
    ↓
validate_parsed_result.{analysis}() [STEP 8: Validate JSON]
extract_by_pattern.{analysis}() [STEP 8: Fallback extraction]
create_default_result.{analysis}() [STEP 8: Last resort]
    ↓
create_fit_summary.{analysis}() [STEP 10: Fit summary & diagnostics]
    ↓
build_report.{analysis}_interpretation() [STEP 11: Format report]
```

### What You Need to Implement

**8 Core S3 Methods (Required)** across **5 new files**:

| Method | Purpose | File |
|--------|---------|------|
| `build_analysis_data.{class}()` | Extract data from fitted models | `{analysis}_model_data.R` |
| `build_system_prompt.{analysis}()` | Create LLM system prompt | `{analysis}_prompt_builder.R` |
| `build_main_prompt.{analysis}()` | Create LLM user prompt | `{analysis}_prompt_builder.R` |
| `validate_parsed_result.{analysis}()` | Validate JSON structure | `{analysis}_json.R` |
| `extract_by_pattern.{analysis}()` | Pattern-based extraction fallback | `{analysis}_json.R` |
| `create_default_result.{analysis}()` | Default values if parsing fails | `{analysis}_json.R` |
| `create_fit_summary.{analysis}()` | Analysis-specific fit summary and diagnostics | `{analysis}_diagnostics.R` |
| `build_report.{analysis}_interpretation()` | Format user-facing report | `{analysis}_report.R` |

**3 Additional S3 Methods (Optional but Recommended)**:

| Method | Purpose | File |
|--------|---------|------|
| `validate_list_structure.{analysis}()` | Validate structured list input | `s3_list_validation.R` (add to existing) |
| `export_interpretation.{analysis}_interpretation()` | Export reports to txt/md files | `{analysis}_export.R` |
| `plot.{analysis}_interpretation()` | Visualize analysis results | `{analysis}_visualization.R` |

**Note**: `validate_list_structure.{analysis}()` enables users to pass structured lists (e.g., `list(loadings = ...)` for FA) directly to `interpret()`. See `validate_list_structure.fa()` in `R/s3_list_validation.R` for reference implementation.

**Plus**: Configuration object constructor (`interpretation_args_{analysis}()`) in `shared_config.R`

---

## Prerequisites

### Understanding the FA Implementation

Before implementing a new model type, **thoroughly read these FA implementation files**:

1. **`R/fa_model_data.R`** (436 lines) - Data extraction pattern
   - Shows how to handle multiple input types (fitted models, matrices, lists)
   - Parameter extraction and validation
   - Standardized output structure

2. **`R/fa_prompt_builder.R`** (342 lines) - Prompt construction
   - System prompt with expert persona
   - Structured user prompt sections
   - Parameter-driven formatting

3. **`R/fa_json.R`** (226 lines) - JSON parsing
   - Validation rules
   - Pattern-based extraction fallback
   - Default value generation

4. **`R/fa_diagnostics.R`** (178 lines) - Diagnostic checks
   - Cross-loading detection
   - Missing loading detection
   - Diagnostic message formatting

5. **`R/fa_report.R`** (838 lines) - Report generation
   - Modular helper functions (~60-130 lines each)
   - Section formatting
   - Markdown vs text formatting

### Key Concepts

**1. analysis_data Structure**

The output of `build_analysis_data.{class}()` MUST be a named list containing:
- Analysis-specific data (loadings, means, probabilities, etc.)
- Analysis type identifier: `analysis_type = "fa"` or `"gm"` etc.
- Analysis-specific parameters (cutoff, n_emergency, covariance_type, etc.)

**2. Analysis Type vs Class Dispatch**

- **Analysis type**: String identifier ("fa", "gm", "irt", "cdm") - used for most S3 dispatch
- **Class**: R object class (psych, fa, Mclust, mirt) - used only in `build_analysis_data()` and optional `interpret_model()`

**3. Parameter Flow**

```
User call with {analysis}_args or individual params
    ↓
build_{analysis}_args() merges sources
    ↓
interpret_core() extracts common params
    ↓
build_analysis_data.{class}() extracts analysis-specific params from {analysis}_args
    ↓
Analysis-specific params stored in analysis_data
    ↓
interpret_core() extracts params from analysis_data to pass to prompt builders
```

**Why?** Prevents parameter duplication and keeps prompt builders as pure functions.

---

## Implementation Checklist

Use this checklist when implementing a new analysis type (replace `{analysis}` with "gm", "irt", or "cdm"):

### Phase 1: Setup

- [ ] Create `dev/templates/{analysis}/` directory
- [ ] Copy template files from `dev/templates/` (see next section)
- [ ] Choose analysis abbreviation: "gm", "irt", or "cdm"
- [ ] Identify primary fitted model class(es): e.g., `Mclust`, `SingleGroupClass`
- [ ] Document expected analysis_data structure

### Phase 2: Core Files (No LLM needed)

- [ ] **`R/{analysis}_model_data.R`**
  - [ ] `build_analysis_data.{primary_class}()` method
  - [ ] `build_{analysis}_model_data_internal()` helper
  - [ ] Additional `build_analysis_data.{other_class}()` methods if needed
  - [ ] Parameter extraction and validation
  - [ ] Unit tests (no LLM required)

- [ ] **`R/shared_config.R`** modifications
  - [ ] `{analysis}_args()` constructor
  - [ ] Parameter validation in constructor
  - [ ] `build_{analysis}_args()` builder function
  - [ ] Documentation

### Phase 3: Prompt Building (Requires LLM testing)

- [ ] **`R/{analysis}_prompt_builder.R`**
  - [ ] `build_system_prompt.{analysis}()` - expert persona, guidelines
  - [ ] `build_main_prompt.{analysis}()` - data formatting, sections
  - [ ] Helper functions for formatting analysis-specific data
  - [ ] Test prompts with sample data

### Phase 4: JSON Parsing

- [ ] **`R/{analysis}_json.R`**
  - [ ] `validate_parsed_result.{analysis}()` - structure validation
  - [ ] `extract_by_pattern.{analysis}()` - regex fallback
  - [ ] `create_default_result.{analysis}()` - default values
  - [ ] Test with various JSON structures (valid, malformed, partial)

### Phase 5: Diagnostics

- [ ] **`R/{analysis}_diagnostics.R`**
  - [ ] `create_fit_summary.{analysis}()` - main function
  - [ ] Analysis-specific diagnostic checks
  - [ ] Message formatting
  - [ ] Unit tests

### Phase 6: Report Generation

- [ ] **`R/{analysis}_report.R`**
  - [ ] `build_report.{analysis}_interpretation()` - orchestrator
  - [ ] Helper functions for each report section (~60-130 lines each)
  - [ ] Text and Markdown formatting support
  - [ ] Test report generation

### Phase 7: Integration

- [ ] **Modify `R/core_constants.R`**
  - [ ] Uncomment "{analysis}" in VALID_ANALYSIS_TYPES array (line ~6)
  - [ ] This enables validation across the package

- [ ] **Modify `R/core_interpret_dispatch.R`**
  - [ ] Uncomment {analysis}_args parameter in interpret() signature
  - [ ] Uncomment build_{analysis}_args() call
  - [ ] Uncomment {analysis}_args in interpret_model() and handle_raw_data_interpret() calls

- [ ] **Modify `R/shared_utils.R`**
  - [ ] Uncomment {analysis}_args parameter in handle_raw_data_interpret()
  - [ ] Uncomment {analysis} case in switch statement

- [ ] **Modify `R/shared_config.R`**
  - [ ] Uncomment {analysis}_args() constructor
  - [ ] Uncomment build_{analysis}_args() builder function

- [ ] **Optional: Modify `R/shared_utils.R`**
  - [ ] Add {analysis} case to `handle_raw_data_interpret()` switch (lines ~45-85)

- [ ] **Optional: Add to `R/core_interpret_dispatch.R`**
  - [ ] Create `interpret_model.{class}()` method if needed

### Phase 8: Testing

- [ ] Create `tests/testthat/fixtures/{analysis}/` directory
- [ ] Create fixture generation script: `tests/testthat/fixtures/{analysis}/make-{analysis}-fixture.R`
- [ ] **Test file 1**: `test-{analysis}_model_data.R` (no LLM)
  - [ ] Test data extraction from fitted models
  - [ ] Test parameter validation
  - [ ] Test edge cases

- [ ] **Test file 2**: `test-{analysis}_prompt.R` (no LLM)
  - [ ] Test prompt building with sample data
  - [ ] Test parameter effects on prompts

- [ ] **Test file 3**: `test-{analysis}_json.R` (no LLM)
  - [ ] Test valid JSON parsing
  - [ ] Test malformed JSON fallback
  - [ ] Test default value generation

- [ ] **Test file 4**: `test-{analysis}_diagnostics.R` (no LLM)
  - [ ] Test diagnostic calculations

- [ ] **Test file 5**: `test-{analysis}_report.R` (minimal LLM)
  - [ ] Use cached interpretation fixture
  - [ ] Test text vs markdown formatting

- [ ] **Test file 6**: `test-interpret_{analysis}.R` (minimal LLM)
  - [ ] ONE comprehensive end-to-end test with `word_limit = 20`
  - [ ] Add `skip_on_ci()`
  - [ ] Cache result for other tests

### Phase 9: Documentation

- [ ] Add roxygen2 documentation to all exported functions
- [ ] Run `devtools::document()`
- [ ] Create vignette: `vignettes/{analysis}_interpretation.Rmd` or `.Qmd`
- [ ] Update `CLAUDE.md` with {analysis} examples
- [ ] Update `dev/DEVELOPER_GUIDE.md` section 4.2 (Package History)

### Phase 10: Final Checks

- [ ] `devtools::check()` passes with no errors/warnings
- [ ] All tests pass: `devtools::test()`
- [ ] Documentation builds without errors
- [ ] Example usage works in README (if applicable)

---

## Step-by-Step Guide

### Step 1: Create Analysis Data Extractor

**File**: `R/{analysis}_model_data.R`

**Purpose**: Extract and standardize data from fitted model objects.

#### 1.1 Main S3 Method

```r
#' Build analysis data for {ANALYSIS} interpretation
#'
#' @param fit_results Fitted {ANALYSIS} object from package {pkg}
#' @param variable_info Data frame with variable names and descriptions
#' @param analysis_type Analysis type identifier (should be "{analysis}")
#' @param {analysis}_args Configuration object from {analysis}_args()
#' @param ... Additional arguments (for parameter extraction)
#'
#' @return List with standardized {ANALYSIS} data structure
#' @export
build_analysis_data.{PrimaryClass} <- function(fit_results,
                                             variable_info,
                                             analysis_type = "{analysis}",
                                             {analysis}_args = NULL,
                                             ...) {

  # Call internal helper to avoid S3 method naming conflicts
  build_{analysis}_model_data_internal(
    fit_results = fit_results,
    variable_info = variable_info,
    analysis_type = analysis_type,
    {analysis}_args = {analysis}_args,
    ...
  )
}
```

**Pattern from FA**: See `fa_model_data.R:11-23` for `build_analysis_data.psych()`

#### 1.2 Internal Helper Function

```r
#' Internal helper to build {ANALYSIS} analysis data
#'
#' @keywords internal
build_{analysis}_model_data_internal <- function(fit_results,
                                               variable_info,
                                               analysis_type = "{analysis}",
                                               {analysis}_args = NULL,
                                               ...) {

  # STEP 1: Extract analysis-specific parameters
  # Pattern from fa_model_data.R:26-48

  dots <- list(...)

  # Build config from multiple sources (precedence: {analysis}_args > ... > defaults)
  config <- build_{analysis}_args(
    {analysis}_args = {analysis}_args,
    dots = dots
  )

  # Extract parameters from config
  param1 <- config$param1  # Example: covariance_type for GM
  param2 <- config$param2  # Example: n_clusters for GM

  # STEP 2: Validate parameters
  # Pattern from fa_model_data.R:50-72

  # Validate param1
  if (!is.null(param1)) {
    if (!param1 %in% c("option1", "option2")) {
      cli::cli_abort(c(
        "x" = "Invalid param1: {param1}",
        "i" = "Must be one of: 'option1', 'option2'"
      ))
    }
  }

  # STEP 3: Extract data from fitted model
  # This is MODEL-SPECIFIC - extract relevant components

  # Example for GM:
  # means <- fit_results$parameters$mean
  # covariances <- fit_results$parameters$variance$sigma
  # probabilities <- fit_results$z

  # Example for IRT:
  # item_params <- coef(fit_results, simplify = TRUE)
  # ability_estimates <- fscores(fit_results)

  # STEP 4: Validate variable_info
  # Pattern from fa_model_data.R:74-118

  if (!is.data.frame(variable_info)) {
    cli::cli_abort(c(
      "x" = "variable_info must be a data frame",
      "i" = "Got: {class(variable_info)[1]}"
    ))
  }

  required_cols <- c("variable", "description")
  missing_cols <- setdiff(required_cols, names(variable_info))

  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "x" = "variable_info missing required columns: {missing_cols}",
      "i" = "Required: {required_cols}"
    ))
  }

  # Check variable count matches model
  n_variables <- nrow(variable_info)
  n_model_vars <- ... # Extract from fitted model

  if (n_variables != n_model_vars) {
    cli::cli_abort(c(
      "x" = "Number of variables mismatch",
      "i" = "variable_info has {n_variables} rows",
      "i" = "Model has {n_model_vars} variables"
    ))
  }

  # STEP 5: Process and format model data
  # This is MODEL-SPECIFIC

  # Example for GM: Create cluster summaries
  # cluster_summaries <- lapply(1:n_clusters, function(k) {
  #   list(
  #     cluster = k,
  #     mean = means[, k],
  #     covariance = covariances[, , k],
  #     probability = mean(probabilities[, k])
  #   )
  # })

  # STEP 6: Return standardized structure
  # Pattern from fa_model_data.R:255-265

  structure(
    list(
      # Core analysis data (ANALYSIS-SPECIFIC)
      data_field1 = ...,  # e.g., means, item_params
      data_field2 = ...,  # e.g., covariances, ability_estimates

      # Metadata
      n_components = ...,  # e.g., n_clusters, n_factors, n_items
      n_variables = n_variables,
      analysis_type = analysis_type,

      # Analysis-specific parameters (used later in prompts)
      param1 = param1,
      param2 = param2
    ),
    class = c("{analysis}_model_data", "analysis_data", "list")
  )
}
```

**Key Points**:
- Use `build_{analysis}_args()` to merge parameter sources
- Validate all parameters with clear error messages
- Extract data from fitted model object
- Return standardized list structure with `analysis_type` field

#### 1.3 Additional Class Methods (if needed)

If the analysis type has multiple fitted object classes, create additional methods:

```r
#' @export
build_analysis_data.OtherClass <- function(fit_results,
                                        variable_info,
                                        analysis_type = "{analysis}",
                                        {analysis}_args = NULL,
                                        ...) {

  # Convert to standard format, then call internal helper
  # Pattern from fa_model_data.R:282-298 (build_analysis_data.fa)

  converted_data <- ... # Extract from OtherClass object

  build_{analysis}_model_data_internal(
    fit_results = converted_data,
    variable_info = variable_info,
    analysis_type = analysis_type,
    {analysis}_args = {analysis}_args,
    ...
  )
}
```

**Pattern from FA**:
- `build_analysis_data.psych()` - line 11
- `build_analysis_data.fa()` - line 282
- `build_analysis_data.principal()` - line 300
- `build_analysis_data.lavaan()` - line 318
- `build_analysis_data.SingleGroupClass()` - line 382

---

### Step 2: Create Configuration Object

**File**: `R/shared_config.R` (modify existing)

**Purpose**: Create constructor and builder for analysis-specific parameters.

#### 2.1 Constructor Function

Add to `shared_config.R`:

```r
#' Create {ANALYSIS} configuration object
#'
#' @param param1 Description of param1
#' @param param2 Description of param2
#' @param ... Additional parameters
#'
#' @return {ANALYSIS} configuration object
#' @export
#'
#' @examples
#' # Create {ANALYSIS} configuration
#' config <- {analysis}_args(param1 = "value1", param2 = "value2")
{analysis}_args <- function(param1 = NULL,
                          param2 = NULL,
                          ...) {

  # Validate param1
  if (!is.null(param1)) {
    if (!param1 %in% c("option1", "option2")) {
      cli::cli_abort(c(
        "x" = "Invalid param1: {param1}",
        "i" = "Must be one of: 'option1', 'option2'"
      ))
    }
  }

  # Validate param2
  if (!is.null(param2)) {
    if (!is.numeric(param2) || param2 < 1) {
      cli::cli_abort(c(
        "x" = "param2 must be a positive number",
        "i" = "Got: {param2}"
      ))
    }
  }

  # Create config object
  config <- list(
    param1 = param1,
    param2 = param2,
    ...
  )

  structure(
    config,
    class = c("{analysis}_args", "analysis_config", "list")
  )
}
```

**Pattern from FA**: See `shared_config.R` for `interpretation_args(analysis_type, ...)` - analysis-type-aware configuration

#### 2.2 Builder Function

Add to `shared_config.R`:

```r
#' Build {ANALYSIS} arguments from multiple sources
#'
#' @param {analysis}_args Configuration object from {analysis}_args()
#' @param dots List of additional arguments (from ...)
#'
#' @return Merged configuration
#' @keywords internal
build_{analysis}_args <- function({analysis}_args = NULL, dots = list()) {

  # Default values
  defaults <- list(
    param1 = "default_value1",
    param2 = 3  # Example default
  )

  # Extract from {analysis}_args if provided
  if (!is.null({analysis}_args) && inherits({analysis}_args, "{analysis}_args")) {
    args_list <- as.list({analysis}_args)
  } else {
    args_list <- list()
  }

  # Extract from dots
  param_names <- c("param1", "param2")
  dots_params <- dots[names(dots) %in% param_names]

  # Merge (precedence: {analysis}_args > dots > defaults)
  merged <- defaults
  merged[names(dots_params)] <- dots_params
  merged[names(args_list)] <- args_list

  # Create final config
  do.call({analysis}_args, merged)
}
```

**Pattern from FA**: See `shared_config.R` for `build_interpretation_args()` - handles all analysis types

---

### Step 3: Build System Prompt

**File**: `R/{analysis}_prompt_builder.R`

**Purpose**: Create LLM system prompt defining expert persona and guidelines.

```r
#' Build system prompt for {ANALYSIS} interpretation
#'
#' @param analysis_type Analysis type identifier (should be "{analysis}")
#' @param ... Additional arguments (ignored)
#'
#' @return Character string with system prompt
#' @export
build_system_prompt.{analysis} <- function(analysis_type, ...) {

  # Define expert persona and guidelines
  # Pattern from fa_prompt_builder.R:23-41

  paste0(
    "You are an expert in {ANALYSIS_FULL_NAME} and psychological measurement.\n\n",

    "Your task is to interpret {ANALYSIS} results by analyzing {WHAT_YOU_ANALYZE}.\n\n",

    "Guidelines:\n",
    "1. Base interpretations ONLY on the provided {DATA_TYPE} and variable descriptions\n",
    "2. Identify meaningful patterns in the {DATA_STRUCTURE}\n",
    "3. Provide clear, concise labels for each {COMPONENT}\n",
    "4. Focus on psychological/theoretical constructs, not statistical jargon\n",
    "5. If a {COMPONENT} has {AMBIGUOUS_CONDITION}, label it as 'Undefined' or use emergency rules\n",
    "6. Ensure labels are distinct and theoretically meaningful\n",
    "7. Respond ONLY with valid JSON matching the exact format specified\n"
  )
}
```

**Examples**:
- **FA**: "expert in exploratory factor analysis", "interpret factor analysis results"
- **GM**: "expert in Gaussian mixture modeling", "interpret cluster solutions"
- **IRT**: "expert in item response theory", "interpret item parameters"

**Pattern from FA**: See `fa_prompt_builder.R:23-41`

---

### Step 4: Build Main Prompt

**File**: `R/{analysis}_prompt_builder.R`

**Purpose**: Format analysis data into LLM user prompt with structured sections.

```r
#' Build main user prompt for {ANALYSIS} interpretation
#'
#' @param analysis_data Analysis data from build_analysis_data.{class}()
#' @param variable_info Data frame with variable information
#' @param word_limit Maximum words per {COMPONENT} interpretation
#' @param additional_info Optional context string
#' @param param1 Analysis-specific parameter 1
#' @param param2 Analysis-specific parameter 2
#' @param ... Additional arguments (ignored)
#'
#' @return Character string with formatted user prompt
#' @export
build_main_prompt.{analysis} <- function(analysis_data,
                                       variable_info,
                                       word_limit = 150,
                                       additional_info = NULL,
                                       param1 = NULL,
                                       param2 = NULL,
                                       ...) {

  # Extract data from analysis_data
  data_field1 <- analysis_data$data_field1
  data_field2 <- analysis_data$data_field2
  n_components <- analysis_data$n_components

  # SECTION 1: Context and task
  # Pattern from fa_prompt_builder.R:78-93

  context <- paste0(
    "Please interpret the following {ANALYSIS} results.\n\n",
    "You have {n_components} {COMPONENTS} to interpret.\n\n"
  )

  # Add additional_info if provided
  if (!is.null(additional_info) && nchar(additional_info) > 0) {
    context <- paste0(
      context,
      "Additional context:\n",
      additional_info, "\n\n"
    )
  }

  # SECTION 2: Variable descriptions
  # Pattern from fa_prompt_builder.R:95-106

  var_section <- "Variables:\n"
  for (i in seq_len(nrow(variable_info))) {
    var_section <- paste0(
      var_section,
      "- ", variable_info$variable[i], ": ",
      variable_info$description[i], "\n"
    )
  }
  var_section <- paste0(var_section, "\n")

  # SECTION 3: Analysis-specific data
  # THIS IS ANALYSIS-SPECIFIC - format your data appropriately

  # Example for GM: Format cluster means
  # data_section <- "{ANALYSIS} Results:\n\n"
  # for (k in 1:n_components) {
  #   data_section <- paste0(
  #     data_section,
  #     "Cluster ", k, ":\n",
  #     format_cluster_stats(means[, k], covariances[, , k]),
  #     "\n"
  #   )
  # }

  # Example for IRT: Format item parameters
  # data_section <- "Item Parameters:\n\n"
  # data_section <- paste0(data_section, format_item_table(item_params), "\n")

  data_section <- ... # YOUR IMPLEMENTATION

  # SECTION 4: Output format specification
  # Pattern from fa_prompt_builder.R:297-341

  output_format <- paste0(
    "Provide your interpretation as a JSON object with this EXACT structure:\n\n",
    "{\n",
    '  "{component_1}": "Brief interpretation here (max ', word_limit, ' words)",\n',
    '  "{component_2}": "Brief interpretation here (max ', word_limit, ' words)",\n',
    "  ...\n",
    "}\n\n",
    "Requirements:\n",
    "- Use ONLY the {COMPONENT} identifiers as keys\n",
    "- Keep each interpretation under ", word_limit, " words\n",
    "- Base interpretations solely on the provided data\n",
    "- Respond with valid JSON only - no additional text\n"
  )

  # Combine all sections
  paste0(context, var_section, data_section, output_format)
}
```

**Key Points**:
- Accept analysis-specific parameters explicitly (param1, param2, etc.)
- Format data sections clearly for LLM readability
- Specify exact JSON output format with examples
- Include word_limit in instructions

**Pattern from FA**: See `fa_prompt_builder.R:68-341`

---

### Step 5: Implement JSON Parsing

**File**: `R/{analysis}_json.R`

**Purpose**: Validate, extract, and provide defaults for LLM responses.

#### 5.1 Validate Parsed Result

```r
#' Validate parsed JSON for {ANALYSIS} results
#'
#' @param parsed_result Parsed JSON object (list)
#' @param analysis_data Analysis data from build_analysis_data.{class}()
#' @param ... Additional arguments (ignored)
#'
#' @return Logical - TRUE if valid, FALSE otherwise
#' @export
validate_parsed_result.{analysis} <- function(parsed_result, analysis_data, ...) {

  # Pattern from fa_json.R:22-94

  # Check 1: Is it a list?
  if (!is.list(parsed_result)) {
    return(FALSE)
  }

  # Check 2: Does it have expected keys?
  expected_keys <- ... # Extract from analysis_data (e.g., cluster names, item IDs)
  actual_keys <- names(parsed_result)

  if (length(actual_keys) == 0) {
    return(FALSE)
  }

  # Check 3: Are all values character strings?
  all_char <- all(vapply(parsed_result, is.character, logical(1)))
  if (!all_char) {
    return(FALSE)
  }

  # Check 4: Are keys valid?
  valid_keys <- all(actual_keys %in% expected_keys)
  if (!valid_keys) {
    return(FALSE)
  }

  TRUE
}
```

#### 5.2 Extract by Pattern (Fallback)

```r
#' Extract {ANALYSIS} interpretations using pattern matching
#'
#' @param response Raw LLM response string
#' @param analysis_data Analysis data from build_analysis_data.{class}()
#' @param ... Additional arguments (ignored)
#'
#' @return List with extracted interpretations or NULL if failed
#' @export
extract_by_pattern.{analysis} <- function(response, analysis_data, ...) {

  # Pattern from fa_json.R:130-208

  # Get expected keys
  expected_keys <- ... # Extract from analysis_data

  # Try to extract using regex patterns
  # Example: Look for "{component_1}": "interpretation text"

  result <- list()

  for (key in expected_keys) {
    # Pattern: "key": "value"
    pattern <- sprintf('"%s"\\s*:\\s*"([^"]+)"', key)
    match <- regmatches(response, regexec(pattern, response))[[1]]

    if (length(match) > 1) {
      result[[key]] <- match[2]
    }
  }

  # Return NULL if no matches found
  if (length(result) == 0) {
    return(NULL)
  }

  result
}
```

#### 5.3 Create Default Result

```r
#' Create default {ANALYSIS} interpretation
#'
#' @param analysis_data Analysis data from build_analysis_data.{class}()
#' @param ... Additional arguments (ignored)
#'
#' @return List with default interpretations
#' @export
create_default_result.{analysis} <- function(analysis_data, ...) {

  # Pattern from fa_json.R:210-226

  # Get component identifiers
  component_ids <- ... # Extract from analysis_data

  # Create default interpretations
  result <- list()
  for (id in component_ids) {
    result[[id]] <- "Unable to generate interpretation due to parsing errors. Please review the raw LLM response."
  }

  result
}
```

**Pattern from FA**: See `fa_json.R:22-226`

---

### Step 6: Create Diagnostics

**File**: `R/{analysis}_diagnostics.R`

**Purpose**: Perform analysis-specific diagnostic checks and generate warnings.

```r
#' Create diagnostics for {ANALYSIS} interpretation
#'
#' @param analysis_data Analysis data from build_analysis_data.{class}()
#' @param interpretation Interpretation result from LLM
#' @param ... Additional arguments (ignored)
#'
#' @return List with diagnostic information
#' @export
create_fit_summary.{analysis} <- function(analysis_type, analysis_data, ...) {

  # Pattern from fa_diagnostics.R:12-178

  # Initialize diagnostics
  diagnostics <- list(
    has_warnings = FALSE,
    warnings = character(0),
    info = list()
  )

  # DIAGNOSTIC CHECK 1: Analysis-specific issue
  # Example for GM: Check for overlapping clusters
  # Example for IRT: Check for poor item fit
  # Example for FA: Check for cross-loadings

  issue1_detected <- ... # YOUR CHECK

  if (issue1_detected) {
    diagnostics$has_warnings <- TRUE
    diagnostics$warnings <- c(
      diagnostics$warnings,
      "Warning message about issue 1"
    )
    diagnostics$info$issue1_details <- ... # Details
  }

  # DIAGNOSTIC CHECK 2: Another analysis-specific issue

  issue2_detected <- ... # YOUR CHECK

  if (issue2_detected) {
    diagnostics$has_warnings <- TRUE
    diagnostics$warnings <- c(
      diagnostics$warnings,
      "Warning message about issue 2"
    )
  }

  # Return diagnostics
  diagnostics
}
```

**Helper Functions** (optional):

```r
#' Detect specific diagnostic issue
#'
#' @keywords internal
detect_{issue}_{analysis} <- function(analysis_data) {
  # Implementation
}
```

**Pattern from FA**: See `fa_diagnostics.R`:
- `create_fit_summary.fa()` - line 181
- `find_cross_loadings()` - line 40 (exported helper)
- `find_no_loadings()` - line 118 (exported helper)

---

### Step 7: Build Report

**File**: `R/{analysis}_report.R`

**Purpose**: Format interpretation into user-facing report (text or markdown).

#### 7.1 Main Report Builder

```r
#' Build report for {ANALYSIS} interpretation
#'
#' @param interpretation fa_interpretation object (NOTE: class will be {analysis}_interpretation)
#' @param ... Additional arguments (ignored)
#'
#' @return Character string with formatted report
#' @export
build_report.{analysis}_interpretation <- function(interpretation, ...) {

  # Pattern from fa_report.R:28-838

  # Extract components
  analysis_data <- interpretation$analysis_data
  llm_result <- interpretation$interpretation
  diagnostics <- interpretation$diagnostics
  output_format <- interpretation$output_format

  # Build report sections using helper functions

  # Section 1: Header
  header <- build_report_header_{analysis}(
    analysis_data = analysis_data,
    llm_provider = interpretation$llm_provider,
    llm_model = interpretation$llm_model,
    output_format = output_format
  )

  # Section 2: Component interpretations
  interpretations_section <- build_{component}_interpretations_{analysis}(
    llm_result = llm_result,
    analysis_data = analysis_data,
    output_format = output_format
  )

  # Section 3: Additional data (if applicable)
  # Example for FA: correlations
  # Example for GM: cluster statistics
  # Example for IRT: item statistics

  additional_section <- build_additional_data_section_{analysis}(
    analysis_data = analysis_data,
    output_format = output_format
  )

  # Section 4: Diagnostics
  diagnostics_section <- build_diagnostics_section_{analysis}(
    diagnostics = diagnostics,
    output_format = output_format
  )

  # Combine sections
  report_parts <- c(
    header,
    interpretations_section,
    additional_section,
    diagnostics_section
  )

  # Remove NULL sections
  report_parts <- Filter(Negate(is.null), report_parts)

  # Combine with appropriate spacing
  if (output_format == "markdown") {
    paste(report_parts, collapse = "\n\n")
  } else {
    paste(report_parts, collapse = "\n\n")
  }
}
```

#### 7.2 Helper Functions

**Keep each helper ~60-130 lines focused on one section**:

```r
#' Build report header for {ANALYSIS}
#'
#' @keywords internal
build_report_header_{analysis} <- function(analysis_data,
                                         llm_provider,
                                         llm_model,
                                                output_format) {

  # Pattern from fa_report.R:132-226

  n_components <- analysis_data$n_components
  n_variables <- analysis_data$n_variables

  if (output_format == "markdown") {
    paste0(
      "# {ANALYSIS} Interpretation Results\n\n",
      "**Number of {COMPONENTS}:** ", n_components, "\n",
      "**Number of Variables:** ", n_variables, "\n",
      "**LLM Provider:** ", llm_provider, "\n",
      "**LLM Model:** ", llm_model, "\n"
    )
  } else {
    paste0(
      "{ANALYSIS} INTERPRETATION RESULTS\n",
      "========================================\n\n",
      "Number of {COMPONENTS}: ", n_components, "\n",
      "Number of Variables: ", n_variables, "\n",
      "LLM Provider: ", llm_provider, "\n",
      "LLM Model: ", llm_model, "\n"
    )
  }
}

#' Build component interpretations section
#'
#' @keywords internal
build_{component}_interpretations_{analysis} <- function(llm_result,
                                                       analysis_data,
                                                       output_format) {

  # Pattern from fa_report.R:321-475 (build_factor_names_section)

  component_ids <- names(llm_result)

  sections <- character(length(component_ids))

  for (i in seq_along(component_ids)) {
    id <- component_ids[i]
    interpretation <- llm_result[[id]]

    if (output_format == "markdown") {
      sections[i] <- paste0(
        "### ", id, "\n",
        interpretation
      )
    } else {
      sections[i] <- paste0(
        id, ":\n",
        interpretation
      )
    }
  }

  if (output_format == "markdown") {
    paste0("## {COMPONENT} Interpretations\n\n", paste(sections, collapse = "\n\n"))
  } else {
    paste0("{COMPONENT} INTERPRETATIONS\n", paste(sections, collapse = "\n\n"))
  }
}

#' Build diagnostics section
#'
#' @keywords internal
build_diagnostics_section_{analysis} <- function(diagnostics, output_format) {

  # Pattern from fa_report.R:695-838

  if (!diagnostics$has_warnings) {
    return(NULL)
  }

  warnings_text <- paste(diagnostics$warnings, collapse = "\n")

  if (output_format == "markdown") {
    paste0(
      "## Diagnostic Warnings\n\n",
      warnings_text
    )
  } else {
    paste0(
      "DIAGNOSTIC WARNINGS\n",
      "========================================\n\n",
      warnings_text
    )
  }
}
```

**Pattern from FA**: See `fa_report.R`:
- `build_report.fa_interpretation()` - line 28 (orchestrator)
- `build_report_header()` - line 132
- `build_factor_names_section()` - line 321
- `build_correlations_section()` - line 477
- `build_diagnostics_section()` - line 695

---

### Step 8: Uncomment Extensibility Placeholders

The package has extensibility infrastructure with commented placeholders for new analysis
types. Instead of adding new code, you **uncomment existing code**.

#### 8.1 Uncomment in `R/core_constants.R`

**Location**: Line ~6

**Change**: Uncomment "{analysis}" in VALID_ANALYSIS_TYPES constant

```r
# Before:
VALID_ANALYSIS_TYPES <- c("fa") # , "gm", "irt", "cdm")

# After (for GM):
VALID_ANALYSIS_TYPES <- c("fa", "gm") # , "irt", "cdm")
```

This enables validation across the entire package.

#### 8.2 Uncomment in `R/core_interpret_dispatch.R`

**Locations**: Lines ~175, ~200-202, ~328-330, ~366-368

**Changes**:
1. Uncomment {analysis}_args parameter in interpret() signature
2. Uncomment build_{analysis}_args() call
3. Uncomment {analysis}_args in interpret_model() call
4. Uncomment {analysis}_args in handle_raw_data_interpret() call

#### 8.3 Uncomment in `R/shared_utils.R`

**Locations**: Lines ~25-27 (parameters), lines ~61-78 (switch cases)

**Changes**:
1. Uncomment {analysis}_args parameter in handle_raw_data_interpret() signature
2. Uncomment {analysis} case in switch statement

```r
# Uncomment parameter (line ~25-27):
handle_raw_data_interpret <- function(x, variable_info, analysis_type,
                                      chat_session, llm_args = NULL,
                                      interpretation_args = NULL,
                                      gm_args = NULL,   # UNCOMMENT for GM
                                      # irt_args = NULL,  # Uncomment for IRT
                                      # cdm_args = NULL,  # Uncomment for CDM
                                      output_args = NULL, ...) {

# Uncomment case in switch (lines ~61-78):
  switch(effective_analysis_type,
    fa = {
      interpret_core(...)
    },
    gm = {  # UNCOMMENT THIS ENTIRE CASE for GM
      interpret_core(
        fit_results = list(...),  # Your analysis-specific structure
        variable_info = variable_info,
        analysis_type = "gm",
        chat_session = chat_session,
        llm_args = llm_args,
        gm_args = gm_args,
        output_args = output_args,
        ...
      )
    }
    # ... uncomment irt, cdm cases as needed
  )
}
```

#### 8.4 Uncomment in `R/shared_config.R`

**Locations**: Lines ~307-381 (constructor), lines ~549-621 (builder)

**Changes**:
1. Uncomment {analysis}_args() constructor function
2. Uncomment build_{analysis}_args() builder function

These are already written as templates - just uncomment the entire functions.

#### 8.5 Optional: Add to `R/core_interpret_dispatch.R`

**Only if fitted model classes need special routing**:

```r
#' @export
interpret_model.{SpecialClass} <- function(fit_results, ...) {

  # Delegate to interpret_core via build_analysis_data dispatch
  # Pattern from core_interpret_dispatch.R:195-198

  interpret_core(
    fit_results = fit_results,
    analysis_type = "{analysis}",
    ...
  )
}
```

---

## Method Implementation Details

### build_analysis_data.{class}()

**Purpose**: Extract and standardize data from fitted model objects.

**Inputs**:
- `fit_results`: Fitted model object (e.g., `Mclust`, `mirt`)
- `variable_info`: Data frame with variable names and descriptions
- `analysis_type`: String identifier ("{analysis}")
- `{analysis}_args`: Configuration object
- `...`: Additional parameters

**Outputs**: List with structure:
```r
list(
  # Core data fields (analysis-specific)
  data_field1 = ...,
  data_field2 = ...,

  # Metadata
  n_components = ...,
  n_variables = ...,
  analysis_type = "{analysis}",

  # Analysis-specific parameters
  param1 = ...,
  param2 = ...
)
```

**Key Responsibilities**:
1. Extract parameters from `{analysis}_args` or `...`
2. Validate parameters
3. Extract data from fitted model
4. Validate variable_info structure and alignment
5. Format data into standardized structure
6. Return list with class `c("{analysis}_model_data", "analysis_data", "list")`

**FA Example**: `fa_model_data.R:24-265`

---

### build_system_prompt.{analysis}()

**Purpose**: Create LLM system prompt defining expert role and guidelines.

**Inputs**:
- `analysis_type`: String identifier
- `...`: Additional arguments (ignored)

**Outputs**: Character string with system prompt

**Key Elements**:
1. Expert persona definition
2. Task description
3. Clear guidelines (7-10 rules)
4. JSON format requirement

**FA Example**: `fa_prompt_builder.R:23-41`

---

### build_main_prompt.{analysis}()

**Purpose**: Format analysis data into structured LLM user prompt.

**Inputs**:
- `analysis_data`: Output from `build_analysis_data.{class}()`
- `variable_info`: Data frame
- `word_limit`: Integer
- `additional_info`: Optional string
- Analysis-specific parameters (param1, param2, etc.)
- `...`: Additional arguments (ignored)

**Outputs**: Character string with formatted prompt

**Structure**:
1. Context and task description
2. Additional info (if provided)
3. Variable descriptions
4. Analysis-specific data (formatted for readability)
5. JSON output format specification with example

**FA Example**: `fa_prompt_builder.R:68-341`

---

### validate_parsed_result.{analysis}()

**Purpose**: Validate LLM JSON response structure.

**Inputs**:
- `parsed_result`: Parsed JSON (list)
- `analysis_data`: Analysis data for reference
- `...`: Additional arguments (ignored)

**Outputs**: Logical (TRUE/FALSE)

**Checks**:
1. Is it a list?
2. Does it have expected keys?
3. Are values character strings?
4. Are keys valid?

**FA Example**: `fa_json.R:22-94`

---

### extract_by_pattern.{analysis}()

**Purpose**: Extract interpretations using regex if JSON parsing fails.

**Inputs**:
- `response`: Raw LLM response string
- `analysis_data`: Analysis data for expected keys
- `...`: Additional arguments (ignored)

**Outputs**: List with extractions or NULL if failed

**Approach**:
1. Get expected component keys from analysis_data
2. Use regex to find "{key}": "value" patterns
3. Extract values for each key
4. Return NULL if no matches

**FA Example**: `fa_json.R:130-208`

---

### create_default_result.{analysis}()

**Purpose**: Generate default interpretations if all parsing fails.

**Inputs**:
- `analysis_data`: Analysis data for component keys
- `...`: Additional arguments (ignored)

**Outputs**: List with default interpretations

**Approach**:
1. Get component identifiers
2. Create generic "Unable to interpret" messages for each
3. Return list

**FA Example**: `fa_json.R:210-226`

---

### create_fit_summary.{analysis}()

**Purpose**: Generate analysis-specific fit summary and perform diagnostic checks.

**Inputs**:
- `analysis_type`: String identifier
- `analysis_data`: Analysis data
- `...`: Additional arguments (ignored)

**Outputs**: List with structure:
```r
list(
  has_warnings = FALSE,  # or TRUE
  warnings = character(0),  # or vector of warning messages
  info = list()  # Additional diagnostic information
)
```

**Approach**:
1. Initialize diagnostics list
2. Perform analysis-specific checks
3. Add warnings and info as issues detected
4. Return diagnostics

**FA Example**: `fa_diagnostics.R:181-282`

---

### build_report.{analysis}_interpretation()

**Purpose**: Format interpretation into user-facing report.

**Inputs**:
- `interpretation`: Interpretation object (class `{analysis}_interpretation`)
- `...`: Additional arguments (ignored)

**Outputs**: Character string with formatted report

**Structure** (use helper functions):
1. Header with metadata
2. Component interpretations
3. Additional data sections (analysis-specific)
4. Diagnostics warnings

**Approach**:
1. Extract components from interpretation object
2. Call helper functions for each section
3. Combine sections with appropriate spacing
4. Handle markdown vs text formatting

**FA Example**: `fa_report.R:28-838` with helpers at lines 132, 321, 477, 695

---

## Testing Strategy

### Test File Organization

Create **6 test files** for comprehensive coverage:

1. **`test-{analysis}_model_data.R`** - Data extraction (no LLM)
2. **`test-{analysis}_prompt.R`** - Prompt building (no LLM)
3. **`test-{analysis}_json.R`** - JSON parsing (no LLM)
4. **`test-{analysis}_diagnostics.R`** - Diagnostics (no LLM)
5. **`test-{analysis}_report.R`** - Report formatting (minimal LLM, use cached)
6. **`test-interpret_{analysis}.R`** - End-to-end integration (minimal LLM)

### Fixture Setup

**Location**: `tests/testthat/fixtures/{analysis}/`

**Files**:
- `make-{analysis}-fixture.R` - Script to generate cached interpretation
- `{analysis}_interpretation.rds` - Cached interpretation result
- `sample_{analysis}_data.rds` - Sample analysis data for testing

**Example fixture generator**:

```r
# tests/testthat/fixtures/gm/make-gm-fixture.R

library(psychinterpreter)
library(mclust)  # or appropriate package

# Generate sample data
set.seed(123)
data <- ... # Create sample dataset

# Fit model
fit <- Mclust(data, G = 3)

# Create variable info
var_info <- data.frame(
  variable = paste0("var", 1:ncol(data)),
  description = paste("Description for variable", 1:ncol(data))
)

# Generate interpretation (ONCE, with minimal word_limit)
interpretation <- interpret(
  fit_results = fit,
  variable_info = var_info,
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud",
  word_limit = 20  # MINIMUM for token efficiency
)

# Save fixture
saveRDS(interpretation, "tests/testthat/fixtures/gm/gm_interpretation.rds")

# Also save analysis_data for other tests
analysis_data <- build_analysis_data(fit, var_info, analysis_type = "gm")
saveRDS(analysis_data, "tests/testthat/fixtures/gm/sample_gm_data.rds")
```

### Test Patterns

#### Pattern 1: Data Extraction Tests (No LLM)

```r
# tests/testthat/test-gm_model_data.R

test_that("build_analysis_data.Mclust extracts means correctly", {

  # Arrange
  fit <- ... # Create test fitted object
  var_info <- data.frame(
    variable = c("var1", "var2"),
    description = c("Desc 1", "Desc 2")
  )

  # Act
  result <- build_analysis_data(fit, var_info, analysis_type = "gm")

  # Assert
  expect_s3_class(result, "gm_model_data")
  expect_true(!is.null(result$means))
  expect_equal(result$n_clusters, 3)
})

test_that("build_analysis_data.Mclust validates parameters", {

  fit <- ... # Test object
  var_info <- data.frame(variable = "var1", description = "Desc")

  # Invalid parameter should error
  expect_error(
    build_analysis_data(fit, var_info, analysis_type = "gm",
                     gm_args = gm_args(covariance_type = "invalid")),
    "Invalid covariance_type"
  )
})
```

#### Pattern 2: Prompt Building Tests (No LLM)

```r
# tests/testthat/test-gm_prompt.R

test_that("build_system_prompt.gm creates valid prompt", {

  prompt <- build_system_prompt("gm")

  expect_type(prompt, "character")
  expect_true(grepl("Gaussian mixture", prompt, ignore.case = TRUE))
  expect_true(grepl("JSON", prompt))
})

test_that("build_main_prompt.gm includes cluster data", {

  analysis_data <- readRDS("fixtures/gm/sample_gm_data.rds")
  var_info <- data.frame(variable = "var1", description = "Desc 1")

  prompt <- build_main_prompt(analysis_data, var_info, word_limit = 20)

  expect_type(prompt, "character")
  expect_true(grepl("Cluster", prompt))
  expect_true(grepl("var1", prompt))
})
```

#### Pattern 3: JSON Parsing Tests (No LLM)

```r
# tests/testthat/test-gm_json.R

test_that("validate_parsed_result.gm accepts valid structure", {

  analysis_data <- readRDS("fixtures/gm/sample_gm_data.rds")

  valid_result <- list(
    Cluster_1 = "Interpretation 1",
    Cluster_2 = "Interpretation 2",
    Cluster_3 = "Interpretation 3"
  )

  expect_true(validate_parsed_result(valid_result, analysis_data, analysis_type = "gm"))
})

test_that("extract_by_pattern.gm extracts from malformed JSON", {

  analysis_data <- readRDS("fixtures/gm/sample_gm_data.rds")

  response <- 'Here are the results: {"Cluster_1": "Interpretation", "Cluster_2": "Another"}'

  result <- extract_by_pattern(response, analysis_data, analysis_type = "gm")

  expect_type(result, "list")
  expect_true("Cluster_1" %in% names(result))
})
```

#### Pattern 4: Integration Test (Minimal LLM)

```r
# tests/testthat/test-interpret_gm.R

test_that("GM interpretation works end-to-end", {

  skip_on_ci()  # LLM test

  # Arrange
  fit <- ... # Create test data
  var_info <- data.frame(variable = "var1", description = "Desc 1")

  # Act
  result <- interpret(
    fit_results = fit,
    variable_info = var_info,
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20  # MINIMUM
  )

  # Assert
  expect_s3_class(result, "gm_interpretation")
  expect_true(!is.null(result$interpretation))
  expect_type(result$report, "character")

  # Save for other tests
  saveRDS(result, "fixtures/gm/gm_interpretation.rds")
})
```

#### Pattern 5: Report Tests (Use Cached)

```r
# tests/testthat/test-gm_report.R

test_that("build_report.gm_interpretation creates text report", {

  # Use cached interpretation (no LLM call)
  interpretation <- readRDS("fixtures/gm/gm_interpretation.rds")
  interpretation$output_format <- "text"

  report <- build_report(interpretation)

  expect_type(report, "character")
  expect_true(grepl("GM INTERPRETATION", report))
})

test_that("build_report.gm_interpretation creates markdown report", {

  interpretation <- readRDS("fixtures/gm/gm_interpretation.rds")
  interpretation$output_format <- "markdown"

  report <- build_report(interpretation)

  expect_type(report, "character")
  expect_true(grepl("# ", report))  # Markdown heading
})
```

### Testing Guidelines

**From TESTING_GUIDELINES.md**:

1. **Minimize LLM tests**: Only ONE end-to-end test per model type
2. **Use word_limit = 20**: Minimum allowed for token efficiency
3. **Cache results**: Generate fixture ONCE, reuse for all report/print tests
4. **skip_on_ci()**: Add to all LLM tests
5. **Test S3 dispatch**: Test method dispatch separately from LLM calls
6. **Edge cases**: Test validation, error handling, edge cases WITHOUT LLM

---

## Common Patterns

### Pattern 1: Parameter Extraction

**Location**: `build_{analysis}_model_data_internal()` (first 30 lines)

**Code**:
```r
dots <- list(...)

config <- build_{analysis}_args(
  {analysis}_args = {analysis}_args,
  dots = dots
)

param1 <- config$param1
param2 <- config$param2
```

**Why**: Merges parameters from multiple sources (config object, ..., defaults) consistently.

**FA Example**: `fa_model_data.R:26-48`

---

### Pattern 2: Validation with cli Messages

**Location**: Throughout validation sections

**Code**:
```r
if (!valid_condition) {
  cli::cli_abort(c(
    "x" = "Error message",
    "i" = "Helpful context",
    "i" = "Expected: {expected_value}"
  ))
}
```

**Why**: Clear, formatted error messages for users.

**FA Example**: `fa_model_data.R:50-118`

---

### Pattern 3: Section Building in Prompts

**Location**: `build_main_prompt.{analysis}()`

**Code**:
```r
# Build each section separately
section1 <- "Section 1 content\n\n"
section2 <- "Section 2 content\n\n"
section3 <- "Section 3 content\n\n"

# Combine
paste0(section1, section2, section3)
```

**Why**: Readable, maintainable prompt construction.

**FA Example**: `fa_prompt_builder.R:78-341`

---

### Pattern 4: Modular Report Helpers

**Location**: `build_report.{analysis}_interpretation()` and helpers

**Code**:
```r
# Main orchestrator
build_report.{analysis}_interpretation <- function(interpretation, ...) {
  header <- build_report_header_{analysis}(...)
  section1 <- build_section1_{analysis}(...)
  section2 <- build_section2_{analysis}(...)
  diagnostics <- build_diagnostics_section_{analysis}(...)

  report_parts <- c(header, section1, section2, diagnostics)
  report_parts <- Filter(Negate(is.null), report_parts)

  paste(report_parts, collapse = "\n\n")
}

# Helper functions (~60-130 lines each)
build_report_header_{analysis} <- function(...) { ... }
build_section1_{analysis} <- function(...) { ... }
```

**Why**:
- Each helper is independently testable
- ~60-130 lines per function (readable)
- Easy to modify individual sections
- Removes NULL sections automatically

**FA Example**: `fa_report.R:28-838`

---

### Pattern 5: Markdown vs Text Formatting

**Location**: All report helper functions

**Code**:
```r
if (output_format == "markdown") {
  paste0(
    "## Section Title\n\n",
    "**Bold text**\n",
    content
  )
} else {
  paste0(
    "SECTION TITLE\n",
    "========================================\n\n",
    content
  )
}
```

**Why**: Consistent formatting across both output types.

**FA Example**: `fa_report.R:132-226` (build_report_header)

---

### Pattern 6: Multi-tier JSON Fallback

**Location**: `s3_json_parser.R` calls analysis-specific methods

**Code**:
```r
# Tier 1: Clean and parse
cleaned <- clean_json_response(response)
parsed <- jsonlite::fromJSON(cleaned, simplifyVector = FALSE)
if (validate_parsed_result(parsed, analysis_data, analysis_type)) {
  return(parsed)
}

# Tier 2: Parse original
parsed <- jsonlite::fromJSON(response, simplifyVector = FALSE)
if (validate_parsed_result(parsed, analysis_data, analysis_type)) {
  return(parsed)
}

# Tier 3: Pattern extraction
extracted <- extract_by_pattern(response, analysis_data, analysis_type)
if (!is.null(extracted)) {
  return(extracted)
}

# Tier 4: Default values
create_default_result(analysis_data, analysis_type)
```

**Why**: Defensive parsing handles small/local models with imperfect JSON.

**FA Example**: `s3_json_parser.R:85-122`

---

## Troubleshooting

### Issue: "Error: analysis_type must be specified"

**Cause**: Using structured list without specifying analysis_type

**Solution**: Always specify analysis_type when using list input
```r
interpret(
  fit_results = list(means = means_matrix),
  variable_info = var_info,
  analysis_type = "gm"  # REQUIRED
)
```

---

### Issue: "Documented arguments not in usage"

**Cause**: Roxygen2 documentation out of sync

**Solution**: Run `devtools::document()` after modifying function signatures

---

### Issue: Parameter not found in analysis_data

**Cause**: Forgot to extract parameter in `build_{analysis}_model_data_internal()`

**Solution**: Ensure parameters are extracted from config and stored in returned list
```r
config <- build_{analysis}_args({analysis}_args = {analysis}_args, dots = dots)
param1 <- config$param1  # Extract

# ... later in return statement
list(
  ...,
  param1 = param1  # Include in analysis_data
)
```

---

### Issue: Tests taking too long

**Causes & Solutions**:
1. **Too many LLM tests**: Limit to ONE end-to-end test, use cached fixtures for others
2. **High word_limit**: Use `word_limit = 20` in tests (minimum allowed)
3. **Large fixtures**: Use minimal sample data for LLM tests
4. **Running on CI**: Add `skip_on_ci()` to LLM tests

---

### Issue: Prompt builder receives NULL parameters

**Cause**: Parameters not extracted from analysis_data in `interpret_core()`

**Solution**: Add parameter extraction in `interpret_core()` for your analysis type (similar to FA pattern at lines 96-108)

```r
# In interpret_core()
param1 <- NULL
param2 <- NULL

if (!is.null(analysis_data$param1)) {
  param1 <- analysis_data$param1
  param2 <- analysis_data$param2
}

# Pass to prompt builder
main_prompt <- build_main_prompt(
  analysis_data = analysis_data,
  variable_info = variable_info,
  word_limit = word_limit,
  param1 = param1,
  param2 = param2,
  analysis_type = analysis_type
)
```

---

### Issue: JSON validation fails with valid structure

**Cause**: Expected keys not correctly extracted from analysis_data

**Solution**: Debug expected keys in `validate_parsed_result.{analysis}()`:
```r
# Temporarily add debugging
expected_keys <- ... # Extract from analysis_data
message("Expected keys: ", paste(expected_keys, collapse = ", "))
message("Actual keys: ", paste(names(parsed_result), collapse = ", "))
```

---

### Issue: Report formatting looks wrong

**Cause**: Missing newlines or incorrect spacing

**Solution**:
1. Test markdown vs text separately
2. Check that helpers return strings with consistent trailing newlines
3. Use `cat(report)` to visualize formatting
4. Compare against FA report output

---

## Next Steps After Implementation

1. **Test thoroughly**: Run `devtools::test()` and `devtools::check()`
2. **Create vignette**: Show usage examples
3. **Update CLAUDE.md**: Add examples and common pitfalls
4. **Update DEVELOPER_GUIDE.md**: Document implementation in section 4.2
5. **Consider visualization**: Create plot method if applicable (like `plot.fa_interpretation()`)
6. **Add to README**: Update with new model type support

---

## Additional Resources

**Developer Guide**: `dev/DEVELOPER_GUIDE.md`
- Section 1.3: Architecture overview
- Section 1.7: S3 method requirements
- Section 4.2: Package history
- Section 4.4: Phase 2 refactoring details

**Testing Guidelines**: `dev/TESTING_GUIDELINES.md`
- Testing patterns
- Fixture usage
- Token efficiency

**FA Implementation** (reference):
- `R/fa_model_data.R` - 436 lines
- `R/fa_prompt_builder.R` - 342 lines
- `R/fa_json.R` - 226 lines
- `R/fa_diagnostics.R` - 178 lines
- `R/fa_report.R` - 838 lines

**Code Templates**: `dev/templates/` (see next section)

---

**Last Updated**: 2025-11-12
**Maintainer**: Update when adding new model types or discovering new patterns
