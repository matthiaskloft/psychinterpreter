# Refactoring Plan: Multi-Model Support for psychinterpreter

**Version**: 1.0
**Date**: 2025-11-03
**Status**: Planning

---

## Executive Summary

This document outlines a comprehensive refactoring plan to evolve **psychinterpreter** from a factor analysis (FA) specific package to a general-purpose psychometric interpretation framework supporting multiple model types: Factor Analysis (FA), Gaussian Mixture Models (GM), Item Response Theory (IRT), and Cognitive Diagnosis Models (CDM).

**Current state**: Package is tightly coupled to FA-specific terminology, prompts, and data structures
**Target state**: Modular, extensible architecture with model-agnostic core and model-specific plugins
**Approach**: Phased refactoring with backward compatibility maintained throughout

---

## Table of Contents

1. [Current Architecture Analysis](#1-current-architecture-analysis)
2. [FA-Specific Components Inventory](#2-fa-specific-components-inventory)
3. [Target Model Types & Requirements](#3-target-model-types--requirements)
4. [Proposed Architecture](#4-proposed-architecture)
5. [Refactoring Phases](#5-refactoring-phases)
6. [Backward Compatibility Strategy](#6-backward-compatibility-strategy)
7. [Implementation Timeline](#7-implementation-timeline)
8. [Testing Strategy](#8-testing-strategy)
9. [Risk Assessment](#9-risk-assessment)

---

## 1. Current Architecture Analysis

### 1.1 Core Components

```
psychinterpreter (FA-specific)
│
├── LLM Communication Layer (via ellmer)
│   ├── chat_fa.R - Persistent chat sessions
│   └── interpret_fa.R - Single-use sessions + interpretation logic
│
├── Data Processing Layer
│   ├── fa_utilities.R - Cross-loading & no-loading detection
│   └── interpret_methods.R - S3 methods for psych/lavaan/mirt
│
├── Output Layer
│   ├── fa_report_functions.R - Report building & printing
│   ├── export_functions.R - Export to txt/md
│   └── visualization.R - Heatmap plots
│
└── Support Layer
    └── utils.R - Word counting, text wrapping
```

### 1.2 Key Strengths

✓ **Modular LLM communication** - Already abstracted via ellmer
✓ **S3 method dispatch** - Extensible pattern for new model types
✓ **Robust JSON parsing** - Multi-tier fallback system
✓ **Token efficiency** - Persistent chat sessions save tokens
✓ **Comprehensive testing** - 70 tests across 7 files

### 1.3 Key Constraints

✗ **FA-specific naming** - Functions, classes, files all use "fa" prefix
✗ **FA-specific prompts** - System and user prompts hardcoded for factor analysis
✗ **FA-specific data structures** - Loadings, variance explained, factor correlations
✗ **FA-specific utilities** - Cross-loadings, no-loadings detection
✗ **FA-specific terminology** - Reports use "factor", "loading", "variance explained"

---

## 2. FA-Specific Components Inventory

### 2.1 Function Names (9 exported)

| Current Name | FA-Specific? | Proposed Generic Name |
|---|---|---|
| `interpret_fa()` | ✓ | `interpret_model()` |
| `chat_fa()` | ✓ | `chat_session()` |
| `is.chat_fa()` | ✓ | `is.chat_session()` |
| `reset.chat_fa()` | ✓ | `reset.chat_session()` |
| `interpret()` | ✗ | Keep as-is (generic) |
| `find_cross_loadings()` | ✓ | `find_cross_indicators()` or model-specific |
| `find_no_loadings()` | ✓ | `find_orphan_indicators()` or model-specific |
| `export_interpretation()` | ✗ | Keep as-is |
| `create_factor_plot()` | ✓ | `create_interpretation_plot()` |

### 2.2 S3 Classes (2 primary)

| Current Class | FA-Specific? | Proposed Generic Class |
|---|---|---|
| `fa_interpretation` | ✓ | `interpretation` (base class) |
| `chat_fa` | ✓ | `chat_session` (base class) |

**Proposed Class Hierarchy:**
```
interpretation (base)
  ├── fa_interpretation
  ├── gm_interpretation
  ├── irt_interpretation
  └── cdm_interpretation

chat_session (base)
  ├── fa_chat_session
  ├── gm_chat_session
  ├── irt_chat_session
  └── cdm_chat_session
```

### 2.3 File Structure

| Current File | Lines | FA-Specific? | Proposed Action |
|---|---|---|---|
| `interpret_fa.R` | ~1350 | ✓ High | Split: `interpret_core.R` + `interpret_fa.R` |
| `chat_fa.R` | ~180 | ✓ High | Rename: `chat_session.R` + model-specific subclasses |
| `fa_utilities.R` | ~150 | ✓ Medium | Split: `utilities.R` + `fa_diagnostics.R` |
| `fa_report_functions.R` | ~200 | ✓ High | Split: `report_builder.R` + `fa_report.R` |
| `interpret_methods.R` | ~500 | ✗ | Keep, add new model methods |
| `export_functions.R` | ~150 | ✗ | Keep as-is |
| `visualization.R` | ~200 | ✓ Low | Minor updates for generic terminology |
| `utils.R` | ~100 | ✗ | Keep as-is |

### 2.4 Prompt System (Critical Component)

#### System Prompt (Lines 290-324 in interpret_fa.R, Lines 62-78 in chat_fa.R)

**Current FA-specific elements:**
- "expert psychometrician specializing in exploratory factor analysis"
- "Loading", "Factor correlation", "Variance explained"
- "Convergent validity", "Discriminant validity"
- "Factor interpretation", "Factor Relationships"

**Abstraction needed:**
```r
# Generic system prompt builder
build_system_prompt <- function(model_type, word_limit, ...) {
  UseMethod("build_system_prompt")
}

build_system_prompt.fa <- function(model_type, word_limit, ...) {
  # Current FA prompt
}

build_system_prompt.irt <- function(model_type, word_limit, ...) {
  # IRT-specific prompt: item parameters, person abilities, DIF
}

build_system_prompt.cdm <- function(model_type, word_limit, ...) {
  # CDM-specific prompt: q-matrix, attribute profiles, mastery
}

build_system_prompt.gm <- function(model_type, word_limit, ...) {
  # GM-specific prompt: cluster means, covariances, membership
}
```

#### User Prompt (Lines 750-950 in interpret_fa.R)

**Current FA-specific sections:**
1. Variable descriptions (generic ✓)
2. Factor loadings (FA-specific ✗)
3. Variance explained (FA-specific ✗)
4. Factor correlations (FA-specific ✗)
5. JSON output format (model-specific ✗)

**Abstraction needed:**
```r
# Generic user prompt builder
build_user_prompt <- function(model_type, model_data, variable_info, ...) {
  UseMethod("build_user_prompt")
}

build_user_prompt.fa <- function(model_type, model_data, variable_info, ...) {
  # Build FA-specific prompt with loadings, variance, correlations
}

build_user_prompt.irt <- function(model_type, model_data, variable_info, ...) {
  # Build IRT-specific prompt with parameters, abilities, fit
}

# ... etc.
```

---

## 3. Target Model Types & Requirements

### 3.1 Factor Analysis (FA) - **EXISTING**

**Current Implementation**: Fully functional

**Key Components:**
- Loadings matrix (variables × factors)
- Factor correlations (oblique rotations)
- Variance explained per factor
- Cross-loadings detection
- Orphaned variables detection

**Interpretation Focus:**
- Construct identification
- Convergent/discriminant validity
- Factor relationships
- Loading patterns

---

### 3.2 Gaussian Mixture Models (GM) - **NEW**

**Input Data:**
- Cluster means (variables × clusters)
- Cluster covariances (optional)
- Cluster membership probabilities
- Within/between cluster variance
- Cluster sizes (n per cluster)

**LLM Prompt Requirements:**
```
ROLE: Expert in cluster analysis and mixture modeling
TASK: Interpret cluster profiles and identify meaningful subgroups

KEY DEFINITIONS:
- Cluster mean: Average value of variable within cluster
- Membership probability: Likelihood of observation belonging to cluster
- Within-cluster variance: Variability within homogeneous subgroups
- Between-cluster separation: Distinctiveness of cluster profiles

INTERPRETATION GUIDELINES:
- Profile interpretation: Describe typical member of each cluster
- Discriminating features: Variables that differentiate clusters
- Cluster coherence: Internal consistency and homogeneity
- Cluster relationships: Similarities/differences between clusters
```

**Output Format:**
```json
{
  "Cluster1": {
    "name": "High Performers",
    "interpretation": "...",
    "discriminating_features": ["var1", "var2"]
  }
}
```

**Diagnostic Utilities:**
- `find_discriminating_variables()` - Variables that separate clusters
- `find_overlapping_clusters()` - Clusters with high membership overlap

---

### 3.3 Item Response Theory (IRT) - **NEW**

**Input Data:**
- Item parameters (discrimination, difficulty, guessing)
- Model type (1PL, 2PL, 3PL, graded response, etc.)
- Item fit statistics (infit, outfit)
- Item information functions (optional)
- Person ability distribution (optional)

**LLM Prompt Requirements:**
```
ROLE: Expert psychometrician specializing in item response theory
TASK: Interpret item functioning and identify measurement issues

KEY DEFINITIONS:
- Discrimination (a): Item's ability to differentiate between ability levels
- Difficulty (b): Ability level at which 50% probability of correct response
- Item fit: How well item conforms to IRT model assumptions
- DIF: Differential item functioning across groups

INTERPRETATION GUIDELINES:
- Item quality: Assess discrimination and difficulty appropriateness
- Measurement precision: Which ability ranges are well-measured
- Problem items: Low discrimination, extreme difficulty, poor fit
- Content coverage: Ability range coverage and construct representation
```

**Output Format:**
```json
{
  "Item1": {
    "name": "Easy Recognition Item",
    "interpretation": "...",
    "quality_assessment": "Good discrimination, appropriate difficulty",
    "concerns": []
  }
}
```

**Diagnostic Utilities:**
- `find_misfit_items()` - Items with poor fit statistics
- `find_redundant_items()` - Items with similar parameters
- `find_dif_items()` - Items showing differential functioning

---

### 3.4 Cognitive Diagnosis Models (CDM) - **NEW**

**Input Data:**
- Q-matrix (items × attributes)
- Attribute mastery profiles
- Item parameters (slip, guessing)
- Attribute correlations
- Classification accuracy

**LLM Prompt Requirements:**
```
ROLE: Expert in cognitive diagnosis and learning analytics
TASK: Interpret attribute patterns and diagnostic item quality

KEY DEFINITIONS:
- Q-matrix: Binary matrix indicating required attributes per item
- Attribute mastery: Binary indicator of skill acquisition
- Slip: Probability of incorrect response despite mastery
- Guessing: Probability of correct response without mastery

INTERPRETATION GUIDELINES:
- Attribute interpretation: Describe cognitive skills measured
- Item diagnosticity: How well items discriminate mastery
- Attribute relationships: Dependencies and hierarchies
- Profile patterns: Common mastery/non-mastery combinations
```

**Output Format:**
```json
{
  "Attribute1": {
    "name": "Algebraic Reasoning",
    "interpretation": "...",
    "measured_by": ["item1", "item2", "item5"],
    "relationships": "Prerequisite for Attribute2"
  }
}
```

**Diagnostic Utilities:**
- `find_undiagnostic_items()` - Items that don't discriminate mastery
- `find_attribute_conflicts()` - Inconsistent attribute requirements

---

## 4. Proposed Architecture

### 4.1 Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     USER-FACING LAYER                       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ interpret() - S3 Generic Dispatcher                  │   │
│  │   ├── interpret.fa() / interpret.principal()        │   │
│  │   ├── interpret.mclust() / interpret.Mclust()       │   │
│  │   ├── interpret.mirt() / interpret.SingleGroupClass()   │
│  │   └── interpret.gdina() / interpret.GDINA()         │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  Legacy wrappers (deprecated in v1.0.0):                   │
│  - interpret_fa() → interpret.default(model, type="fa")    │
│  - chat_fa() → chat_session(type="fa")                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   MODEL-SPECIFIC LAYER                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Model Type Classes (S3)                             │   │
│  │   ├── fa_model - Factor analysis                    │   │
│  │   ├── gm_model - Gaussian mixture                   │   │
│  │   ├── irt_model - Item response theory              │   │
│  │   └── cdm_model - Cognitive diagnosis               │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  Model-Specific Methods (S3):                              │
│  - build_system_prompt.{model_type}                        │
│  - build_user_prompt.{model_type}                          │
│  - extract_model_data.{model_type}                         │
│  - build_report.{model_type}                               │
│  - create_diagnostics.{model_type}                         │
│  - create_plot.{model_type}                                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    MODEL-AGNOSTIC CORE                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Core Infrastructure (R/core/)                       │   │
│  │   ├── interpret_core.R - Main interpretation engine│   │
│  │   ├── chat_session.R - Generic chat management     │   │
│  │   ├── prompt_builder.R - Generic prompt framework  │   │
│  │   ├── json_parser.R - Multi-tier JSON parsing      │   │
│  │   └── report_builder.R - Generic report framework  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Shared Utilities (R/utils/)                         │   │
│  │   ├── utils.R - Word counting, text wrapping        │   │
│  │   ├── validation.R - Parameter validation           │   │
│  │   └── export.R - Export to txt/md/etc.              │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    EXTERNAL DEPENDENCIES                    │
│     ellmer (LLM) | dplyr/tidyr | ggplot2 | cli | jsonlite  │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 New File Structure

```
R/
├── core/                           # Model-agnostic infrastructure
│   ├── interpret_core.R            # Main interpretation engine
│   ├── chat_session.R              # Generic chat session management
│   ├── prompt_builder.R            # Generic prompt construction framework
│   ├── json_parser.R               # Multi-tier JSON parsing
│   └── report_builder.R            # Generic report construction framework
│
├── models/                         # Model-specific implementations
│   ├── fa/
│   │   ├── interpret_fa.R          # FA-specific interpretation
│   │   ├── prompt_fa.R             # FA system/user prompt builders
│   │   ├── report_fa.R             # FA report formatting
│   │   ├── diagnostics_fa.R        # Cross-loadings, orphaned vars
│   │   └── methods_fa.R            # S3 methods for psych/lavaan/mirt
│   │
│   ├── gm/
│   │   ├── interpret_gm.R          # GM-specific interpretation
│   │   ├── prompt_gm.R             # GM system/user prompt builders
│   │   ├── report_gm.R             # GM report formatting
│   │   ├── diagnostics_gm.R        # Discriminating vars, overlap
│   │   └── methods_gm.R            # S3 methods for mclust/flexmix
│   │
│   ├── irt/
│   │   ├── interpret_irt.R         # IRT-specific interpretation
│   │   ├── prompt_irt.R            # IRT system/user prompt builders
│   │   ├── report_irt.R            # IRT report formatting
│   │   ├── diagnostics_irt.R       # Misfit, redundancy, DIF
│   │   └── methods_irt.R           # S3 methods for mirt/TAM/eRm
│   │
│   └── cdm/
│       ├── interpret_cdm.R         # CDM-specific interpretation
│       ├── prompt_cdm.R            # CDM system/user prompt builders
│       ├── report_cdm.R            # CDM report formatting
│       ├── diagnostics_cdm.R       # Undiagnostic items, conflicts
│       └── methods_cdm.R           # S3 methods for CDM/GDINA
│
├── utils/                          # Shared utilities
│   ├── validation.R                # Parameter validation
│   ├── text_utils.R                # Word counting, wrapping
│   └── export.R                    # Export functions
│
├── visualization.R                 # Generic plotting S3 methods
└── deprecated.R                    # Legacy function wrappers
```

### 4.3 Core S3 Class System

```r
# ============================================================================
# BASE CLASSES
# ============================================================================

# Generic interpretation result
# S3 class: c("interpretation", "list")
interpretation <- list(
  model_type = "character",           # "fa", "gm", "irt", "cdm"
  model_data = "list",                # Model-specific data
  component_summaries = "list",       # Factor/cluster/item/attribute summaries
  suggested_names = "list",           # LLM-generated names
  interpretations = "list",           # LLM-generated interpretations
  llm_info = "list",                  # Provider, model, tokens
  chat = "chat_session",              # Chat session object
  diagnostics = "list",               # Model-specific diagnostics
  report = "character",               # Formatted report
  elapsed_time = "numeric",           # Processing time
  params = "list"                     # Analysis parameters
)

# Generic chat session
# S3 class: c("chat_session", "list")
chat_session <- list(
  model_type = "character",           # "fa", "gm", "irt", "cdm"
  chat_object = "ellmer_chat",        # Underlying ellmer chat
  system_prompt = "character",        # Model-specific system prompt
  n_interpretations = "integer",      # Number of interpretations run
  cumulative_tokens = "list",         # input/output token counts
  metadata = "list"                   # Creation time, etc.
)

# ============================================================================
# MODEL-SPECIFIC SUBCLASSES (Inherit from base + add specifics)
# ============================================================================

# FA interpretation
# S3 class: c("fa_interpretation", "interpretation", "list")
fa_interpretation <- c(
  interpretation,                     # All base fields
  list(
    loadings = "matrix",              # FA-specific
    factor_correlations = "matrix",   # FA-specific
    variance_explained = "numeric",   # FA-specific
    cross_loadings = "data.frame",    # FA-specific diagnostic
    orphan_variables = "data.frame"   # FA-specific diagnostic
  )
)

# GM interpretation
# S3 class: c("gm_interpretation", "interpretation", "list")
gm_interpretation <- c(
  interpretation,                     # All base fields
  list(
    cluster_means = "matrix",         # GM-specific
    cluster_covariances = "array",    # GM-specific (optional)
    cluster_sizes = "integer",        # GM-specific
    membership_probabilities = "matrix",  # GM-specific
    discriminating_vars = "data.frame",   # GM-specific diagnostic
    cluster_overlap = "data.frame"        # GM-specific diagnostic
  )
)

# IRT interpretation
# S3 class: c("irt_interpretation", "interpretation", "list")
irt_interpretation <- c(
  interpretation,                     # All base fields
  list(
    item_parameters = "data.frame",   # IRT-specific (a, b, c/g)
    item_fit = "data.frame",          # IRT-specific (infit, outfit)
    model_type = "character",         # IRT-specific (1PL, 2PL, etc.)
    misfit_items = "data.frame",      # IRT-specific diagnostic
    redundant_items = "data.frame",   # IRT-specific diagnostic
    dif_items = "data.frame"          # IRT-specific diagnostic (optional)
  )
)

# CDM interpretation
# S3 class: c("cdm_interpretation", "interpretation", "list")
cdm_interpretation <- c(
  interpretation,                     # All base fields
  list(
    q_matrix = "matrix",              # CDM-specific
    attribute_profiles = "data.frame", # CDM-specific
    item_parameters = "data.frame",   # CDM-specific (slip, guess)
    attribute_correlations = "matrix", # CDM-specific
    undiagnostic_items = "data.frame", # CDM-specific diagnostic
    attribute_conflicts = "data.frame" # CDM-specific diagnostic
  )
)
```

### 4.4 S3 Method Dispatch Pattern

```r
# ============================================================================
# GENERIC interpret() - Already exists
# ============================================================================
interpret <- function(model, variable_info, ...) {
  UseMethod("interpret")
}

# ============================================================================
# MODEL-AGNOSTIC CORE - New unified entry point
# ============================================================================
interpret.default <- function(model, variable_info, model_type = NULL, ...) {
  # Auto-detect model_type from class if not specified
  if (is.null(model_type)) {
    model_type <- detect_model_type(model)
  }

  # Extract model data using model-specific method
  model_data <- extract_model_data(model, model_type)

  # Call core interpretation engine
  interpret_core(
    model_data = model_data,
    model_type = model_type,
    variable_info = variable_info,
    ...
  )
}

# ============================================================================
# MODEL-SPECIFIC EXTRACTORS
# ============================================================================
extract_model_data <- function(model, model_type) {
  UseMethod("extract_model_data", structure(list(), class = model_type))
}

extract_model_data.fa <- function(model, model_type) {
  # Extract loadings, correlations, variance from psych/lavaan/mirt objects
  # Current logic from interpret_methods.R
}

extract_model_data.gm <- function(model, model_type) {
  # Extract means, covariances, memberships from mclust/flexmix objects
}

extract_model_data.irt <- function(model, model_type) {
  # Extract parameters, fit from mirt/TAM/eRm objects
}

extract_model_data.cdm <- function(model, model_type) {
  # Extract q-matrix, profiles, parameters from CDM/GDINA objects
}

# ============================================================================
# PROMPT BUILDERS (S3 dispatch on model_type)
# ============================================================================
build_system_prompt <- function(model_type, word_limit, ...) {
  UseMethod("build_system_prompt", structure(list(), class = model_type))
}

build_user_prompt <- function(model_type, model_data, variable_info, ...) {
  UseMethod("build_user_prompt", structure(list(), class = model_type))
}

# ============================================================================
# REPORT BUILDERS (S3 dispatch on model_type)
# ============================================================================
build_report <- function(interpretation, output_format = "text", ...) {
  UseMethod("build_report", interpretation)
}

build_report.fa_interpretation <- function(interpretation, output_format, ...) {
  # Current build_fa_report() logic
}

# ============================================================================
# PRINT METHODS (S3 dispatch on interpretation class)
# ============================================================================
print.interpretation <- function(x, ...) {
  # Generic print for all interpretation types
  cat(x$report, "\n")
}

print.fa_interpretation <- function(x, max_line_length = 120, ...) {
  # Current FA-specific print with line wrapping
}

# ============================================================================
# PLOT METHODS (S3 dispatch on interpretation class)
# ============================================================================
plot.interpretation <- function(x, ...) {
  UseMethod("plot", x)
}

plot.fa_interpretation <- function(x, ...) {
  # Current heatmap plot logic
}

plot.gm_interpretation <- function(x, ...) {
  # Cluster profile plot
}

plot.irt_interpretation <- function(x, ...) {
  # Item parameter plot
}

plot.cdm_interpretation <- function(x, ...) {
  # Q-matrix heatmap
}
```

---

## 5. Refactoring Phases

### Phase 0: Pre-Refactoring (Weeks 1-2)

**Goal**: Prepare codebase and infrastructure for refactoring

**Tasks**:
1. ✓ **Create this refactoring plan document** (DONE)
2. **Set up development branch**
   ```bash
   git checkout -b refactor/multi-model-support
   ```
3. **Comprehensive test coverage audit**
   - Ensure all current FA functionality has tests
   - Document any missing test coverage
   - Target: 95%+ coverage of exported functions
4. **Create deprecation documentation template**
   - Plan deprecation timeline (v0.2.0 soft, v1.0.0 hard)
   - Draft NEWS.md entries
   - Prepare lifecycle badges for Roxygen docs
5. **Benchmark current performance**
   - Token usage for standard FA analysis
   - Execution time for various FA sizes
   - Memory usage baseline

**Deliverables**:
- [ ] Test coverage report (>95% for exported functions)
- [ ] Performance baseline document
- [ ] Deprecation strategy document
- [ ] Development branch ready

---

### Phase 1: Core Infrastructure Abstraction (Weeks 3-6)

**Goal**: Extract model-agnostic components without breaking FA functionality

#### 1.1 Create Core Directory Structure

```r
R/
├── core/
│   ├── interpret_core.R       # NEW - Generic interpretation engine
│   ├── chat_session.R         # NEW - Refactored from chat_fa.R
│   ├── prompt_builder.R       # NEW - Generic prompt framework
│   ├── json_parser.R          # NEW - Extracted from interpret_fa.R
│   └── report_builder.R       # NEW - Generic report framework
```

**Implementation**:

```r
# R/core/interpret_core.R
#' Core Interpretation Engine (Model-Agnostic)
#'
#' Internal function that handles LLM communication and JSON parsing
#' for any model type. Model-specific logic delegated to S3 methods.
#'
#' @keywords internal
interpret_core <- function(model_data,
                          model_type,
                          variable_info,
                          llm_provider = "anthropic",
                          llm_model = NULL,
                          chat_session = NULL,
                          cutoff = 0.3,
                          word_limit = 100,
                          additional_info = NULL,
                          output_format = "text",
                          heading_level = 1,
                          suppress_heading = FALSE,
                          max_line_length = 120,
                          silent = FALSE,
                          echo = "none",
                          params = NULL,
                          ...) {

  # 1. Validate inputs (generic validation)
  validate_core_params(
    model_data, model_type, variable_info,
    llm_provider, llm_model, cutoff, word_limit, ...
  )

  # 2. Build system prompt (model-specific via S3)
  system_prompt <- build_system_prompt(
    model_type = model_type,
    word_limit = word_limit,
    ...
  )

  # 3. Initialize or use existing chat session
  if (is.null(chat_session)) {
    chat_session <- chat_session(
      model_type = model_type,
      provider = llm_provider,
      model = llm_model,
      system_prompt = system_prompt,
      params = params
    )
  }

  # 4. Build user prompt (model-specific via S3)
  user_prompt <- build_user_prompt(
    model_type = model_type,
    model_data = model_data,
    variable_info = variable_info,
    cutoff = cutoff,
    word_limit = word_limit,
    additional_info = additional_info,
    ...
  )

  # 5. Send to LLM and get response
  start_time <- Sys.time()
  response <- chat_session$chat_object$chat(user_prompt, echo = echo)
  elapsed_time <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  # 6. Parse JSON response (generic parsing with model-specific schema)
  parsed_result <- parse_llm_response(
    response = response,
    model_type = model_type,
    model_data = model_data,
    ...
  )

  # 7. Update chat session token tracking
  chat_session <- update_chat_session(chat_session, response)

  # 8. Build diagnostics (model-specific via S3)
  diagnostics <- create_diagnostics(
    model_type = model_type,
    model_data = model_data,
    cutoff = cutoff,
    variable_info = variable_info,
    ...
  )

  # 9. Assemble interpretation object
  interpretation <- structure(
    list(
      model_type = model_type,
      model_data = model_data,
      component_summaries = parsed_result$summaries,
      suggested_names = parsed_result$names,
      interpretations = parsed_result$interpretations,
      llm_info = list(
        provider = chat_session$chat_object$get_provider()@name,
        model = chat_session$chat_object$get_model()
      ),
      chat = chat_session,
      diagnostics = diagnostics,
      elapsed_time = elapsed_time,
      params = list(
        cutoff = cutoff,
        word_limit = word_limit,
        output_format = output_format,
        ...
      )
    ),
    class = c(paste0(model_type, "_interpretation"), "interpretation", "list")
  )

  # 10. Build report (model-specific via S3)
  interpretation$report <- build_report(
    interpretation = interpretation,
    output_format = output_format,
    heading_level = heading_level,
    suppress_heading = suppress_heading,
    ...
  )

  # 11. Print report unless silent
  if (!silent) {
    print(interpretation, max_line_length = max_line_length)
  }

  return(interpretation)
}
```

#### 1.2 Create Generic Chat Session

```r
# R/core/chat_session.R
#' Create Generic Chat Session for Any Model Type
#'
#' @param model_type Character. Model type: "fa", "gm", "irt", "cdm"
#' @param provider Character. LLM provider (via ellmer)
#' @param model Character. LLM model name (NULL for default)
#' @param system_prompt Character. Model-specific system prompt
#' @param params ellmer params object
#'
#' @export
chat_session <- function(model_type = "fa",
                        provider = "anthropic",
                        model = NULL,
                        system_prompt = NULL,
                        params = NULL) {

  # Validate model_type
  valid_types <- c("fa", "gm", "irt", "cdm")
  if (!model_type %in% valid_types) {
    cli::cli_abort(
      c("Invalid model_type: {.val {model_type}}",
        "i" = "Valid types: {.val {valid_types}}")
    )
  }

  # Build system prompt if not provided
  if (is.null(system_prompt)) {
    system_prompt <- build_system_prompt(
      model_type = model_type,
      word_limit = 100  # Default, will be overridden in interpret_core
    )
  }

  # Initialize ellmer chat
  if (is.null(params)) {
    params <- ellmer::params()
  }

  chat_obj <- ellmer::chat(
    provider = provider,
    model = model,
    system_prompt = system_prompt,
    params = params
  )

  # Create session object
  session <- structure(
    list(
      model_type = model_type,
      chat_object = chat_obj,
      system_prompt = system_prompt,
      n_interpretations = 0L,
      cumulative_tokens = list(input = 0, output = 0),
      metadata = list(
        created = Sys.time(),
        provider = provider,
        model = model
      )
    ),
    class = c(paste0(model_type, "_chat_session"), "chat_session", "list")
  )

  return(session)
}

#' @export
is.chat_session <- function(x) {
  inherits(x, "chat_session")
}

#' @export
reset.chat_session <- function(x, ...) {
  x$n_interpretations <- 0L
  x$cumulative_tokens <- list(input = 0, output = 0)
  x$chat_object <- ellmer::chat(
    provider = x$metadata$provider,
    model = x$metadata$model,
    system_prompt = x$system_prompt,
    params = ellmer::params()
  )
  return(x)
}

#' @export
print.chat_session <- function(x, ...) {
  cli::cli_h1("Chat Session: {x$model_type}")
  cli::cli_alert_info("Provider: {x$metadata$provider}")
  cli::cli_alert_info("Model: {x$chat_object$get_model()}")
  cli::cli_alert_info("Interpretations: {x$n_interpretations}")
  cli::cli_alert_info("Tokens - Input: {x$cumulative_tokens$input}, Output: {x$cumulative_tokens$output}")
  invisible(x)
}
```

#### 1.3 Create Prompt Builder Framework

```r
# R/core/prompt_builder.R
#' Generic Prompt Builders (S3 Dispatch)
#'
#' These functions dispatch to model-specific implementations
#' located in R/models/{model_type}/prompt_{model_type}.R
#'
#' @keywords internal

#' Build System Prompt
#' @export
build_system_prompt <- function(model_type, word_limit, ...) {
  UseMethod("build_system_prompt", structure(list(), class = model_type))
}

#' Build User Prompt
#' @export
build_user_prompt <- function(model_type, model_data, variable_info, ...) {
  UseMethod("build_user_prompt", structure(list(), class = model_type))
}

# Default methods (error messages)
#' @export
build_system_prompt.default <- function(model_type, word_limit, ...) {
  cli::cli_abort(
    c("No system prompt builder for model type: {.val {class(model_type)}}",
      "i" = "Available types: fa, gm, irt, cdm")
  )
}

#' @export
build_user_prompt.default <- function(model_type, model_data, variable_info, ...) {
  cli::cli_abort(
    c("No user prompt builder for model type: {.val {class(model_type)}}",
      "i" = "Available types: fa, gm, irt, cdm")
  )
}
```

#### 1.4 Extract JSON Parser

```r
# R/core/json_parser.R
#' Parse LLM JSON Response with Multi-Tier Fallback
#'
#' Implements the existing robust JSON parsing logic from interpret_fa.R
#' but in a model-agnostic way. Model-specific schema validation done
#' via S3 dispatch.
#'
#' @keywords internal
parse_llm_response <- function(response, model_type, model_data, ...) {

  # Tier 1: Try cleaning and parsing
  cleaned_response <- clean_json_response(response)
  parsed <- try_parse_json(cleaned_response)

  if (!is.null(parsed)) {
    return(validate_parsed_result(parsed, model_type, model_data))
  }

  # Tier 2: Try original response
  parsed <- try_parse_json(response)

  if (!is.null(parsed)) {
    return(validate_parsed_result(parsed, model_type, model_data))
  }

  # Tier 3: Pattern-based extraction (model-specific)
  parsed <- extract_by_pattern(response, model_type, model_data)

  if (!is.null(parsed)) {
    return(validate_parsed_result(parsed, model_type, model_data))
  }

  # Tier 4: Default fallback
  cli::cli_warn("JSON parsing failed, using default values")
  return(create_default_result(model_type, model_data))
}

#' Clean JSON Response
#' @keywords internal
clean_json_response <- function(response) {
  # Extract from code blocks
  response <- gsub("```json\\s*", "", response)
  response <- gsub("```\\s*$", "", response)

  # Remove markdown
  response <- gsub("^[^{]*", "", response)
  response <- gsub("[^}]*$", "", response)

  return(trimws(response))
}

#' Try Parsing JSON
#' @keywords internal
try_parse_json <- function(json_string) {
  tryCatch(
    jsonlite::fromJSON(json_string, simplifyVector = FALSE),
    error = function(e) NULL
  )
}

# Model-specific validation dispatched via S3
#' @export
validate_parsed_result <- function(parsed, model_type, model_data) {
  UseMethod("validate_parsed_result", structure(list(), class = model_type))
}

# Model-specific extraction dispatched via S3
#' @export
extract_by_pattern <- function(response, model_type, model_data) {
  UseMethod("extract_by_pattern", structure(list(), class = model_type))
}

# Model-specific defaults dispatched via S3
#' @export
create_default_result <- function(model_type, model_data) {
  UseMethod("create_default_result", structure(list(), class = model_type))
}
```

#### 1.5 Testing Strategy for Phase 1

**Test files to create**:
- `tests/testthat/test-interpret_core.R` - Core engine tests
- `tests/testthat/test-chat_session.R` - Generic chat session tests
- `tests/testthat/test-json_parser.R` - JSON parsing tests

**Approach**:
1. All existing FA tests MUST pass without modification
2. New generic functions tested with FA model_type initially
3. Mock LLM responses for deterministic testing
4. Integration tests ensure FA functionality unchanged

**Success Criteria**:
- [ ] All 70 existing tests pass
- [ ] 20+ new tests for core infrastructure
- [ ] Zero breaking changes to FA functionality
- [ ] Documentation updated

---

### Phase 2: FA-Specific Modularization (Weeks 7-9)

**Goal**: Move FA-specific logic to `R/models/fa/` without breaking existing API

#### 2.1 Create FA Model Directory

```r
R/models/fa/
├── prompt_fa.R          # FA system/user prompt builders
├── diagnostics_fa.R     # Cross-loadings, orphan variables
├── report_fa.R          # FA report formatting
├── methods_fa.R         # S3 methods for psych/lavaan/mirt
└── validation_fa.R      # FA-specific parameter validation
```

#### 2.2 Move FA Prompt Logic

```r
# R/models/fa/prompt_fa.R
#' Build System Prompt for Factor Analysis
#' @export
build_system_prompt.fa <- function(model_type, word_limit, ...) {
  # Current system prompt from interpret_fa.R lines 290-324
  paste0(
    "# ROLE\n",
    "You are an expert psychometrician specializing in exploratory factor analysis.\n\n",
    "# TASK\n",
    "Provide comprehensive factor analysis interpretation by: ...",
    # ... rest of current FA prompt
  )
}

#' Build User Prompt for Factor Analysis
#' @export
build_user_prompt.fa <- function(model_type, model_data, variable_info,
                                 cutoff, word_limit, additional_info = NULL, ...) {
  # Current user prompt logic from interpret_fa.R lines 786-950
  # Build sections:
  # 1. Interpretation guidelines
  # 2. Additional context
  # 3. Variable descriptions
  # 4. Factor loadings
  # 5. Variance explained
  # 6. Factor correlations
  # 7. Output format instructions
}
```

#### 2.3 Move FA Diagnostics

```r
# R/models/fa/diagnostics_fa.R
#' Create FA Diagnostics
#' @export
create_diagnostics.fa <- function(model_type, model_data, cutoff,
                                   variable_info, ...) {
  list(
    cross_loadings = find_cross_loadings(
      model_data$loadings,
      cutoff = cutoff
    ),
    orphan_variables = find_no_loadings(
      model_data$loadings,
      cutoff = cutoff
    )
  )
}

# Keep existing find_cross_loadings() and find_no_loadings()
# but mark as FA-specific in documentation
```

#### 2.4 Move FA Report Logic

```r
# R/models/fa/report_fa.R
#' Build Report for FA Interpretation
#' @export
build_report.fa_interpretation <- function(interpretation,
                                           output_format = "text",
                                           heading_level = 1,
                                           suppress_heading = FALSE,
                                           ...) {
  # Current build_fa_report() logic from fa_report_functions.R
}

#' Print FA Interpretation
#' @export
print.fa_interpretation <- function(x, max_line_length = 120, ...) {
  # Current print method logic
}
```

#### 2.5 Refactor interpret_fa() as Wrapper

```r
# R/deprecated.R (NEW FILE)
#' Interpret Factor Analysis Results (DEPRECATED)
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' This function is deprecated as of psychinterpreter v0.2.0.
#' Please use `interpret()` with FA model objects instead.
#'
#' @details
#' ## Lifecycle
#' - **v0.2.0** (2025-11): Soft deprecation, function still works but issues warning
#' - **v1.0.0** (2026-Q2): Hard deprecation, function removed
#'
#' ## Migration
#' ```r
#' # Old (deprecated)
#' interpret_fa(loadings, variable_info, ...)
#'
#' # New (recommended)
#' interpret(fa_object, variable_info, ...)
#' ```
#'
#' @export
interpret_fa <- function(loadings_df, variable_info, ...) {
  lifecycle::deprecate_warn(
    when = "0.2.0",
    what = "interpret_fa()",
    with = "interpret()",
    details = "Please use interpret() with FA model objects instead."
  )

  # Wrap in model_data structure
  model_data <- list(
    loadings = loadings_df,
    # Extract other FA data from ...
  )

  # Call core engine
  interpret_core(
    model_data = model_data,
    model_type = "fa",
    variable_info = variable_info,
    ...
  )
}

#' Create FA Chat Session (DEPRECATED)
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' This function is deprecated as of psychinterpreter v0.2.0.
#' Please use `chat_session(model_type = "fa")` instead.
#'
#' @export
chat_fa <- function(provider = "anthropic", model = NULL, params = NULL) {
  lifecycle::deprecate_warn(
    when = "0.2.0",
    what = "chat_fa()",
    with = "chat_session()",
    details = 'Use chat_session(model_type = "fa", ...) instead.'
  )

  chat_session(
    model_type = "fa",
    provider = provider,
    model = model,
    params = params
  )
}

#' @export
is.chat_fa <- function(x) {
  lifecycle::deprecate_warn(
    when = "0.2.0",
    what = "is.chat_fa()",
    with = "is.chat_session()"
  )
  is.chat_session(x) && x$model_type == "fa"
}

#' @export
reset.chat_fa <- function(x, ...) {
  lifecycle::deprecate_warn(
    when = "0.2.0",
    what = "reset.chat_fa()",
    with = "reset.chat_session()"
  )
  reset.chat_session(x, ...)
}
```

#### 2.6 Update NAMESPACE and Dependencies

```r
# DESCRIPTION
Imports:
  ellmer,
  dplyr,
  tidyr,
  ggplot2,
  cli,
  jsonlite,
  lifecycle    # NEW - for deprecation warnings

# Add to .Rbuildignore
^dev/REFACTORING_PLAN\.md$
```

#### 2.7 Testing Strategy for Phase 2

**Approach**:
1. All existing tests MUST still pass (backward compatibility)
2. Add deprecation warning expectations to test suite
3. Create duplicate tests using new `chat_session()` API
4. Ensure both old and new APIs produce identical results

**New test files**:
- `tests/testthat/test-deprecated.R` - Test deprecated functions still work

**Success Criteria**:
- [ ] All 70 existing tests pass with deprecation warnings
- [ ] New API produces identical results to old API
- [ ] Documentation updated with deprecation notices
- [ ] NEWS.md updated with deprecation timeline

---

### Phase 3: GM Model Implementation (Weeks 10-13)

**Goal**: Implement full support for Gaussian Mixture Models as proof-of-concept

#### 3.1 Create GM Model Files

```r
R/models/gm/
├── prompt_gm.R          # GM system/user prompt builders
├── diagnostics_gm.R     # Discriminating vars, cluster overlap
├── report_gm.R          # GM report formatting
├── methods_gm.R         # S3 methods for mclust/flexmix
└── validation_gm.R      # GM-specific parameter validation
```

#### 3.2 Implement GM Prompts

```r
# R/models/gm/prompt_gm.R
#' Build System Prompt for Gaussian Mixture Models
#' @export
build_system_prompt.gm <- function(model_type, word_limit, ...) {
  paste0(
    "# ROLE\n",
    "You are an expert in cluster analysis and mixture modeling, specializing in ",
    "interpreting Gaussian mixture models for behavioral and psychological data.\n\n",

    "# TASK\n",
    "Provide comprehensive cluster interpretation by: (1) identifying and naming ",
    "meaningful subgroups, (2) explaining cluster profiles and characteristics, ",
    "and (3) analyzing relationships and differences between clusters.\n\n",

    "# KEY DEFINITIONS\n",
    "- **Cluster mean**: Average value of a variable within a cluster\n",
    "- **Cluster profile**: Pattern of means across all variables for a cluster\n",
    "- **Membership probability**: Likelihood of observation belonging to cluster\n",
    "- **Within-cluster variance**: Variability within homogeneous subgroups\n",
    "- **Between-cluster separation**: Distinctiveness of cluster profiles\n",
    "- **Discriminating variable**: Variable that strongly differentiates clusters\n",
    "- **Cluster overlap**: Degree to which clusters have ambiguous boundaries\n\n",

    "# INTERPRETATION GUIDELINES\n\n",
    "## Cluster Naming\n",
    "- **Profile identification**: Identify the defining characteristics of each cluster\n",
    "- **Name creation**: Create 2-4 word names capturing cluster essence\n",
    "- **Theoretical grounding**: Base names on domain knowledge and context\n\n",

    "## Cluster Interpretation\n",
    "- **Profile description**: Describe typical member of each cluster\n",
    "- **Discriminating features**: Highlight variables that distinguish clusters\n",
    "- **Cluster coherence**: Assess internal consistency and homogeneity\n",
    "- **Cluster relationships**: Compare/contrast clusters on key dimensions\n",
    "- **Practical implications**: What do these subgroups mean in practice?\n\n",

    "## Output Requirements\n",
    "- **Word target (Interpretation)**: Aim for ",
    round(word_limit * 0.8), "-", word_limit,
    " words per interpretation (80%-100% of limit)\n",
    "- **Writing style**: Be concise, precise, and domain-appropriate\n"
  )
}

#' Build User Prompt for Gaussian Mixture Models
#' @export
build_user_prompt.gm <- function(model_type, model_data, variable_info,
                                 cutoff = NULL, word_limit,
                                 additional_info = NULL, ...) {

  n_clusters <- ncol(model_data$cluster_means)
  n_variables <- nrow(model_data$cluster_means)

  prompt <- ""

  # 1. Interpretation guidelines
  prompt <- paste0(
    prompt,
    "# INTERPRETATION GUIDELINES\n\n",
    "## Cluster Naming\n",
    "- Identify defining characteristics of each cluster\n",
    "- Create 2-4 word descriptive names\n",
    "- Ground names in domain knowledge\n\n",
    "## Cluster Interpretation\n",
    "- Describe typical cluster member profile\n",
    "- Identify discriminating variables\n",
    "- Assess cluster coherence and separation\n",
    "- Compare/contrast clusters\n\n",
    "## Output Requirements\n",
    "- **Word target**: ", round(word_limit * 0.8), "-", word_limit, " words\n",
    "- **Style**: Concise and domain-appropriate\n\n"
  )

  # 2. Additional context
  if (!is.null(additional_info) && nchar(additional_info) > 0) {
    prompt <- paste0(
      prompt,
      "# ADDITIONAL CONTEXT\n",
      additional_info, "\n\n"
    )
  }

  # 3. Variable descriptions
  prompt <- paste0(prompt, "# VARIABLE DESCRIPTIONS\n")
  for (i in 1:nrow(variable_info)) {
    prompt <- paste0(
      prompt,
      "- ", variable_info$variable[i], ": ",
      variable_info$description[i], "\n"
    )
  }
  prompt <- paste0(prompt, "\n")

  # 4. Cluster profiles (means)
  prompt <- paste0(
    prompt,
    "# CLUSTER PROFILES\n\n",
    "**Number of clusters**: ", n_clusters, "\n",
    "**Number of variables**: ", n_variables, "\n\n"
  )

  cluster_names <- colnames(model_data$cluster_means)

  for (i in 1:n_clusters) {
    cluster_name <- cluster_names[i]

    prompt <- paste0(
      prompt,
      "## ", cluster_name, "\n",
      "**Size**: ", model_data$cluster_sizes[i], " observations\n\n",
      "**Variable Means**:\n"
    )

    # Sort variables by absolute deviation from grand mean for this cluster
    cluster_means <- model_data$cluster_means[, i]
    grand_means <- rowMeans(model_data$cluster_means)
    deviations <- abs(cluster_means - grand_means)
    var_order <- order(deviations, decreasing = TRUE)

    for (j in var_order) {
      var_name <- rownames(model_data$cluster_means)[j]
      var_mean <- cluster_means[j]
      deviation <- cluster_means[j] - grand_means[j]

      prompt <- paste0(
        prompt,
        "  - ", var_name, ": ",
        sprintf("%.2f", var_mean),
        " (", ifelse(deviation > 0, "+", ""),
        sprintf("%.2f", deviation), " from grand mean)\n"
      )
    }
    prompt <- paste0(prompt, "\n")
  }

  # 5. Between-cluster comparisons (optional)
  if (!is.null(model_data$cluster_distances)) {
    prompt <- paste0(
      prompt,
      "# CLUSTER SEPARATION\n\n",
      "Pairwise Mahalanobis distances between cluster centers:\n"
    )
    # Add distance matrix
  }

  # 6. Output format
  prompt <- paste0(
    prompt,
    "# OUTPUT FORMAT\n\n",
    "Return a JSON object with this structure:\n\n",
    "```json\n{\n"
  )

  for (i in 1:n_clusters) {
    prompt <- paste0(
      prompt,
      '  "', cluster_names[i], '": {\n',
      '    "name": "2-4 word cluster name",\n',
      '    "interpretation": "', round(word_limit * 0.8), '-', word_limit, ' word interpretation"\n',
      '  }', ifelse(i < n_clusters, ',', ''), '\n'
    )
  }

  prompt <- paste0(prompt, "}\n```\n")

  return(prompt)
}
```

#### 3.3 Implement GM Diagnostics

```r
# R/models/gm/diagnostics_gm.R
#' Create GM Diagnostics
#' @export
create_diagnostics.gm <- function(model_type, model_data, variable_info, ...) {
  list(
    discriminating_vars = find_discriminating_variables(
      cluster_means = model_data$cluster_means,
      threshold = 1.0  # Standard deviations
    ),
    cluster_overlap = find_cluster_overlap(
      membership_probs = model_data$membership_probabilities,
      threshold = 0.3  # Ambiguous if max_prob < 0.7
    )
  )
}

#' Find Discriminating Variables
#'
#' Identifies variables that strongly differentiate between clusters.
#' Uses range of cluster means relative to pooled standard deviation.
#'
#' @param cluster_means Matrix of cluster means (variables × clusters)
#' @param threshold Numeric. Minimum standardized range to consider discriminating
#'
#' @return Data frame with discriminating variables and their ranges
#' @export
find_discriminating_variables <- function(cluster_means, threshold = 1.0) {

  n_vars <- nrow(cluster_means)
  results <- vector("list", n_vars)

  for (i in 1:n_vars) {
    var_means <- cluster_means[i, ]
    var_range <- max(var_means) - min(var_means)
    var_sd <- sd(var_means)
    standardized_range <- var_range / (var_sd + 1e-10)  # Avoid division by zero

    if (standardized_range >= threshold) {
      which_max <- which.max(var_means)
      which_min <- which.min(var_means)

      results[[i]] <- data.frame(
        variable = rownames(cluster_means)[i],
        range = var_range,
        standardized_range = standardized_range,
        highest_cluster = colnames(cluster_means)[which_max],
        highest_mean = var_means[which_max],
        lowest_cluster = colnames(cluster_means)[which_min],
        lowest_mean = var_means[which_min],
        stringsAsFactors = FALSE
      )
    }
  }

  results <- dplyr::bind_rows(results)

  if (nrow(results) > 0) {
    results <- results |>
      dplyr::arrange(dplyr::desc(standardized_range))
  }

  return(results)
}

#' Find Cluster Overlap
#'
#' Identifies observations with ambiguous cluster membership.
#'
#' @param membership_probs Matrix of membership probabilities (observations × clusters)
#' @param threshold Numeric. Maximum probability below which membership is ambiguous
#'
#' @return Data frame with overlapping observations
#' @export
find_cluster_overlap <- function(membership_probs, threshold = 0.3) {

  max_probs <- apply(membership_probs, 1, max)
  second_probs <- apply(membership_probs, 1, function(x) sort(x, decreasing = TRUE)[2])

  ambiguous <- which(max_probs < (1 - threshold))

  if (length(ambiguous) == 0) {
    return(data.frame(
      observation = integer(),
      primary_cluster = character(),
      primary_prob = numeric(),
      secondary_cluster = character(),
      secondary_prob = numeric(),
      stringsAsFactors = FALSE
    ))
  }

  results <- data.frame(
    observation = ambiguous,
    primary_cluster = colnames(membership_probs)[apply(membership_probs[ambiguous, , drop = FALSE], 1, which.max)],
    primary_prob = max_probs[ambiguous],
    secondary_cluster = colnames(membership_probs)[apply(membership_probs[ambiguous, , drop = FALSE], 1, function(x) which(x == sort(x, decreasing = TRUE)[2])[1])],
    secondary_prob = second_probs[ambiguous],
    stringsAsFactors = FALSE
  )

  return(results)
}
```

#### 3.4 Implement GM S3 Methods

```r
# R/models/gm/methods_gm.R
#' Extract Model Data from mclust Objects
#' @export
extract_model_data.Mclust <- function(model, model_type = "gm") {

  if (!requireNamespace("mclust", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg mclust} required for Mclust objects")
  }

  # Extract cluster means
  cluster_means <- t(model$parameters$mean)
  colnames(cluster_means) <- paste0("Cluster", 1:ncol(cluster_means))

  # Extract cluster sizes
  cluster_sizes <- table(model$classification)

  # Extract membership probabilities
  membership_probs <- model$z
  colnames(membership_probs) <- paste0("Cluster", 1:ncol(membership_probs))

  # Extract covariances (if available)
  cluster_covariances <- if (!is.null(model$parameters$variance$sigma)) {
    model$parameters$variance$sigma
  } else {
    NULL
  }

  list(
    cluster_means = cluster_means,
    cluster_sizes = as.integer(cluster_sizes),
    membership_probabilities = membership_probs,
    cluster_covariances = cluster_covariances,
    model_type = model$modelName,
    n_clusters = model$G,
    n_observations = nrow(model$data),
    bic = model$bic,
    loglik = model$loglik
  )
}

#' Interpret mclust Gaussian Mixture Model
#' @export
interpret.Mclust <- function(model, variable_info, ...) {
  model_data <- extract_model_data(model, model_type = "gm")

  interpret_core(
    model_data = model_data,
    model_type = "gm",
    variable_info = variable_info,
    ...
  )
}

# Similar methods for flexmix::flexmix objects
```

#### 3.5 Testing Strategy for Phase 3

**New test files**:
- `tests/testthat/test-gm-prompts.R` - GM prompt construction
- `tests/testthat/test-gm-diagnostics.R` - Discriminating vars, overlap
- `tests/testthat/test-gm-methods.R` - S3 methods for mclust
- `tests/testthat/test-gm-integration.R` - End-to-end GM interpretation

**Test fixtures**:
- `tests/testthat/fixtures/gm_iris.rds` - Simple 3-cluster iris example
- `tests/testthat/fixtures/gm_synthetic.rds` - Controlled synthetic data

**Success Criteria**:
- [ ] All FA tests still pass
- [ ] 30+ new tests for GM functionality
- [ ] GM interpretation matches expected format
- [ ] Documentation complete for GM support

---

### Phase 4: IRT Model Implementation (Weeks 14-17)

**Goal**: Implement Item Response Theory model support

#### 4.1 IRT Prompt Design

```r
# R/models/irt/prompt_irt.R
build_system_prompt.irt <- function(model_type, word_limit, ...) {
  paste0(
    "# ROLE\n",
    "You are an expert psychometrician specializing in item response theory (IRT) ",
    "and test development.\n\n",

    "# TASK\n",
    "Provide comprehensive item analysis by: (1) assessing item quality and ",
    "functioning, (2) identifying measurement precision across ability range, ",
    "and (3) flagging problematic items.\n\n",

    "# KEY DEFINITIONS\n",
    "- **Discrimination (a)**: Item's ability to differentiate between ability levels; ",
    "higher values indicate stronger differentiation\n",
    "- **Difficulty (b)**: Ability level at which 50% probability of correct response; ",
    "higher values indicate more difficult items\n",
    "- **Guessing (c/g)**: Probability of correct response at very low ability (3PL)\n",
    "- **Item fit**: How well item conforms to IRT model; infit/outfit values near 1.0 ideal\n",
    "- **DIF**: Differential item functioning across groups (bias detection)\n",
    "- **Information**: Measurement precision provided by item at each ability level\n\n",

    # ... rest of IRT prompt
  )
}
```

*(Detailed IRT implementation similar to GM, omitted for brevity)*

---

### Phase 5: CDM Model Implementation (Weeks 18-20)

**Goal**: Implement Cognitive Diagnosis Model support

*(Detailed CDM implementation similar to GM/IRT, omitted for brevity)*

---

### Phase 6: Polish & Release (Weeks 21-24)

**Goal**: Finalize documentation, testing, and prepare for release

#### 6.1 Comprehensive Documentation

- [ ] Update all Roxygen documentation
- [ ] Create migration guide vignette
- [ ] Update README with multi-model examples
- [ ] Create model-specific vignettes (FA, GM, IRT, CDM)
- [ ] Update CLAUDE.md with new architecture

#### 6.2 Website & Branding

- [ ] Update pkgdown site with new structure
- [ ] Create comparison table of model types
- [ ] Add gallery of example outputs
- [ ] Update logo/branding if needed

#### 6.3 Final Testing

- [ ] Comprehensive integration test suite
- [ ] Performance benchmarking (compare to Phase 0 baseline)
- [ ] Memory leak detection
- [ ] Cross-platform testing (Windows, Mac, Linux)

#### 6.4 Release Preparation

- [ ] Finalize NEWS.md with all changes
- [ ] Update DESCRIPTION version to 0.2.0
- [ ] CRAN submission preparation
- [ ] GitHub release with binaries

---

## 6. Backward Compatibility Strategy

### 6.1 Deprecation Timeline

| Version | Release | Deprecated Functions | Status | Action Required |
|---------|---------|---------------------|--------|-----------------|
| **0.1.0** | Current | None | Baseline | None |
| **0.2.0** | 2025-Q4 | `interpret_fa()`, `chat_fa()`, `is.chat_fa()`, `reset.chat_fa()` | Soft deprecation | Warnings issued, functions work |
| **0.3.0** | 2026-Q1 | Same as 0.2.0 | Loud deprecation | Every-session warnings |
| **1.0.0** | 2026-Q2 | Same as 0.2.0 | Hard deprecation | Functions removed or defunct |

### 6.2 Migration Path for Users

#### Current Code (v0.1.0)
```r
# Direct function call
result <- interpret_fa(
  loadings_df = loadings,
  variable_info = var_info,
  llm_provider = "anthropic",
  llm_model = "claude-haiku-4-5-20251001"
)

# Persistent chat
chat <- chat_fa("anthropic", "claude-haiku-4-5-20251001")
result1 <- interpret_fa(loadings1, var_info1, chat_session = chat)
result2 <- interpret_fa(loadings2, var_info2, chat_session = chat)
```

#### Transition Code (v0.2.0-0.3.0)
```r
# Both old and new work (old issues deprecation warning)
result_old <- interpret_fa(loadings, var_info, ...)  # Warning issued
result_new <- interpret(fa_object, var_info, ...)    # Recommended

# Persistent chat migration
chat_old <- chat_fa("anthropic", "claude-haiku-4-5-20251001")  # Warning
chat_new <- chat_session("fa", "anthropic", "claude-haiku-4-5-20251001")  # Recommended
```

#### New Code (v1.0.0+)
```r
# S3 method dispatch on model objects (recommended)
fa_model <- psych::fa(data, nfactors = 3)
result <- interpret(fa_model, variable_info = var_info)

# Generic chat session
chat <- chat_session(model_type = "fa", provider = "anthropic")
result1 <- interpret(fa_model1, var_info1, chat_session = chat)
result2 <- interpret(fa_model2, var_info2, chat_session = chat)

# Multi-model support
gm_model <- mclust::Mclust(data, G = 3)
result_gm <- interpret(gm_model, variable_info = var_info)

irt_model <- mirt::mirt(data, 1)
result_irt <- interpret(irt_model, variable_info = var_info)
```

### 6.3 Communication Plan

**v0.2.0 Release Notes** (Initial deprecation):
```markdown
## Deprecations

The following functions are now deprecated and will be removed in v1.0.0:
- `interpret_fa()` → Use `interpret()` instead
- `chat_fa()` → Use `chat_session(model_type = "fa")` instead
- `is.chat_fa()` → Use `is.chat_session()` instead
- `reset.chat_fa()` → Use `reset.chat_session()` instead

**Why?** We're expanding beyond factor analysis to support multiple model types
(Gaussian mixtures, IRT, CDM). The new `interpret()` generic provides a unified
interface for all models.

**Migration:** See `vignette("migration-guide")` for detailed instructions.

**Timeline:** Deprecated functions will continue to work with warnings until v1.0.0
(expected 2026-Q2).
```

**Blog Post / Announcement**:
- Explain vision for multi-model support
- Showcase new capabilities (GM, IRT, CDM)
- Provide migration examples
- Emphasize backward compatibility during transition

---

## 7. Implementation Timeline

```
Phase 0: Pre-Refactoring
├─ Week 1: Planning & documentation
└─ Week 2: Test coverage audit & benchmarking
   └─ Deliverable: Baseline established

Phase 1: Core Infrastructure (4 weeks)
├─ Week 3: Create core/ directory, interpret_core.R
├─ Week 4: Generic chat_session, prompt_builder
├─ Week 5: JSON parser extraction
└─ Week 6: Testing & integration
   └─ Deliverable: Model-agnostic core functional

Phase 2: FA Modularization (3 weeks)
├─ Week 7: Create models/fa/ structure
├─ Week 8: Move FA prompts & diagnostics
└─ Week 9: Deprecation wrappers & testing
   └─ Deliverable: FA works via new + old API

Phase 3: GM Implementation (4 weeks)
├─ Week 10: GM prompts & diagnostics
├─ Week 11: GM S3 methods (mclust)
├─ Week 12: GM testing
└─ Week 13: GM documentation
   └─ Deliverable: GM support functional

Phase 4: IRT Implementation (4 weeks)
├─ Week 14-15: IRT prompts & diagnostics
├─ Week 16: IRT S3 methods (mirt)
└─ Week 17: IRT testing & docs
   └─ Deliverable: IRT support functional

Phase 5: CDM Implementation (3 weeks)
├─ Week 18-19: CDM prompts & diagnostics
└─ Week 20: CDM testing & docs
   └─ Deliverable: CDM support functional

Phase 6: Polish & Release (4 weeks)
├─ Week 21: Comprehensive documentation
├─ Week 22: Website & vignettes
├─ Week 23: Final testing & benchmarking
└─ Week 24: CRAN submission prep & release
   └─ Deliverable: v0.2.0 released

TOTAL: 24 weeks (~6 months)
```

### 7.1 Milestones

| Milestone | Week | Deliverable | Success Criteria |
|-----------|------|-------------|------------------|
| **M1: Baseline** | 2 | Test coverage + performance baseline | >95% coverage, benchmarks documented |
| **M2: Core Complete** | 6 | Model-agnostic core functional | All FA tests pass via new core |
| **M3: FA Modular** | 9 | FA via new architecture | Old + new API both work |
| **M4: GM Support** | 13 | GM interpretation functional | mclust objects interpretable |
| **M5: IRT Support** | 17 | IRT interpretation functional | mirt objects interpretable |
| **M6: CDM Support** | 20 | CDM interpretation functional | GDINA objects interpretable |
| **M7: Release** | 24 | v0.2.0 on CRAN | All checks pass, docs complete |

---

## 8. Testing Strategy

### 8.1 Test Coverage Goals

| Component | Target Coverage | Current Status | Gap |
|-----------|----------------|----------------|-----|
| Core infrastructure | 95%+ | N/A (new) | New tests needed |
| FA functionality | 95%+ | ~90% | Incremental improvement |
| GM functionality | 90%+ | N/A (new) | New tests needed |
| IRT functionality | 90%+ | N/A (new) | New tests needed |
| CDM functionality | 90%+ | N/A (new) | New tests needed |
| S3 methods | 100% | ~85% | Incremental improvement |
| Deprecated functions | 100% | N/A (new) | New tests needed |

### 8.2 Test Structure

```
tests/testthat/
├── fixtures/
│   ├── fa/               # FA test data
│   │   ├── sample_*.rds
│   │   ├── minimal_*.rds
│   │   └── correlational_*.rds
│   ├── gm/               # GM test data
│   │   ├── iris_*.rds
│   │   └── synthetic_*.rds
│   ├── irt/              # IRT test data
│   │   └── mirt_*.rds
│   └── cdm/              # CDM test data
│       └── gdina_*.rds
│
├── helper.R              # Shared test utilities
│
├── test-core-interpret_core.R        # Core engine tests
├── test-core-chat_session.R          # Generic chat tests
├── test-core-prompt_builder.R        # Prompt framework tests
├── test-core-json_parser.R           # JSON parsing tests
│
├── test-fa-prompts.R                 # FA prompt construction
├── test-fa-diagnostics.R             # FA diagnostics
├── test-fa-methods.R                 # FA S3 methods
├── test-fa-integration.R             # FA end-to-end
│
├── test-gm-prompts.R                 # GM prompt construction
├── test-gm-diagnostics.R             # GM diagnostics
├── test-gm-methods.R                 # GM S3 methods
├── test-gm-integration.R             # GM end-to-end
│
├── test-irt-prompts.R                # IRT prompt construction
├── test-irt-diagnostics.R            # IRT diagnostics
├── test-irt-methods.R                # IRT S3 methods
├── test-irt-integration.R            # IRT end-to-end
│
├── test-cdm-prompts.R                # CDM prompt construction
├── test-cdm-diagnostics.R            # CDM diagnostics
├── test-cdm-methods.R                # CDM S3 methods
├── test-cdm-integration.R            # CDM end-to-end
│
├── test-deprecated.R                 # Deprecated function tests
├── test-export.R                     # Export functionality
├── test-visualization.R              # Plotting methods
└── test-utils.R                      # Utility functions

TOTAL: ~150-200 tests (up from current 70)
```

### 8.3 CI/CD Strategy

**GitHub Actions Workflows**:

1. **R-CMD-check** (on push, PR)
   - Test on Windows, macOS, Linux
   - R versions: release, devel, oldrel
   - Skip LLM-requiring tests on CI

2. **Test Coverage** (on push to main)
   - Calculate coverage with covr
   - Upload to Codecov
   - Fail if coverage drops below threshold

3. **Performance Benchmarking** (weekly)
   - Compare token usage to baseline
   - Compare execution time to baseline
   - Alert if regressions >10%

4. **Deprecation Warnings** (on PR)
   - Ensure deprecated functions issue warnings
   - Ensure new API produces identical results

---

## 9. Risk Assessment

### 9.1 Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **Breaking changes to FA API** | Low | High | Comprehensive test suite; backward compatibility wrappers |
| **LLM prompt quality degradation** | Medium | High | A/B testing of new vs old prompts; iterative refinement |
| **Performance regression** | Low | Medium | Benchmarking; profiling; optimization before release |
| **Increased token costs** | Low | Low | Token tracking; prompt optimization; cost monitoring |
| **S3 method conflicts** | Medium | Medium | Careful namespace management; explicit method registration |
| **Complex refactoring introduces bugs** | Medium | High | Phased approach; extensive testing; code review |

### 9.2 User Experience Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **Users confused by deprecation** | High | Low | Clear communication; migration guide; generous timeline |
| **Difficult migration path** | Low | Medium | Simple API; `interpret()` works for all models; examples |
| **Documentation gaps** | Medium | Medium | Vignettes for each model type; comprehensive examples |
| **Unexpected behavior changes** | Low | High | Identical results guarantee; extensive regression testing |

### 9.3 Project Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **Scope creep** | High | Medium | Strict phase boundaries; defer non-essential features |
| **Timeline overrun** | Medium | Low | Buffer weeks built in; prioritize FA→GM→IRT→CDM |
| **Maintainer burnout** | Low | High | Realistic timeline; phased approach; community involvement |
| **Low adoption of new models** | Medium | Low | Document use cases; provide compelling examples |

---

## 10. Success Metrics

### 10.1 Technical Metrics

**Phase 1-2 (Core + FA)**:
- [ ] All 70 existing tests pass
- [ ] 50+ new tests for core infrastructure
- [ ] Zero breaking changes to FA API
- [ ] <5% performance regression
- [ ] 95%+ test coverage

**Phase 3-5 (GM + IRT + CDM)**:
- [ ] 100+ new tests for new model types
- [ ] Each model type has 3+ documented examples
- [ ] Prompt quality validated by domain experts
- [ ] Token usage comparable to FA (within 20%)

**Phase 6 (Release)**:
- [ ] All R CMD check tests pass (0 errors, 0 warnings, 0 notes)
- [ ] Documentation complete (100% exported functions documented)
- [ ] 4+ vignettes (intro, migration, FA, GM/IRT/CDM)
- [ ] CRAN submission successful

### 10.2 User-Facing Metrics

**Adoption**:
- Track downloads of v0.2.0+ (target: >1000 in first 3 months)
- GitHub stars/forks/issues
- Citation count (Google Scholar)

**Quality**:
- User-reported bugs (target: <5 critical bugs in first month)
- Positive user feedback on new API
- Successful use cases with GM/IRT/CDM models

---

## 11. Open Questions & Decisions Needed

### 11.1 Naming Conventions

**Question**: Should we rename package to reflect multi-model support?

**Options**:
1. Keep `psychinterpreter` (current name implies broader scope)
2. Rename to `llmpsych` or `psychllm` (emphasizes LLM focus)
3. Rename to `modelinterpreter` (generic but less domain-specific)

**Recommendation**: Keep `psychinterpreter` - name is already established and "psych" implies psychometric models broadly.

### 11.2 Class Naming

**Question**: Should base classes be `interpretation` or `model_interpretation`?

**Options**:
1. `interpretation` (shorter, cleaner)
2. `model_interpretation` (more explicit, avoids conflicts)

**Recommendation**: `interpretation` - cleaner and unlikely to conflict given package context.

### 11.3 Model Priority

**Question**: Should we implement all models (GM, IRT, CDM) or start with subset?

**Options**:
1. Implement FA + GM only for v0.2.0, defer IRT/CDM
2. Implement all four model types for v0.2.0
3. Implement FA + IRT (more commonly used than GM/CDM)

**Recommendation**: Implement GM in v0.2.0 as proof-of-concept, defer IRT/CDM to v0.3.0+ based on user demand.

### 11.4 Dependency Management

**Question**: Should new model types add package dependencies?

**Options**:
1. Add mclust, mirt, CDM to Suggests (user installs if needed)
2. Keep all model packages in Suggests, check at runtime
3. Create separate packages (e.g., `psychinterpreter.irt`)

**Recommendation**: Keep all in Suggests with runtime checks - maintains single-package simplicity while avoiding forced dependencies.

---

## 12. Next Steps

### Immediate Actions (Week 1)

1. **Review this plan** with stakeholders/collaborators
2. **Create GitHub project board** for tracking
3. **Set up development branch** (`refactor/multi-model-support`)
4. **Run test coverage audit** to establish baseline
5. **Create deprecation documentation template**

### Week 2 Actions

1. **Begin Phase 1**: Create `R/core/` directory structure
2. **Extract `json_parser.R`** from `interpret_fa.R`
3. **Draft `interpret_core.R`** skeleton
4. **Set up CI/CD** for new branch

---

## Appendix A: File Rename Mapping

| Current File | New Location | Reason |
|--------------|--------------|--------|
| `interpret_fa.R` | `R/core/interpret_core.R` + `R/models/fa/interpret_fa.R` | Split generic from FA-specific |
| `chat_fa.R` | `R/core/chat_session.R` + `R/models/fa/chat_fa.R` | Split generic from FA-specific |
| `fa_utilities.R` | `R/models/fa/diagnostics_fa.R` | Clarify purpose |
| `fa_report_functions.R` | `R/core/report_builder.R` + `R/models/fa/report_fa.R` | Split generic from FA-specific |
| `interpret_methods.R` | `R/models/fa/methods_fa.R` | Currently all FA methods |
| `export_functions.R` | `R/utils/export.R` | Move to utils |
| `utils.R` | `R/utils/text_utils.R` | More specific name |
| `visualization.R` | Keep as-is | Already generic enough |
| N/A | `R/deprecated.R` | New file for legacy wrappers |

---

## Appendix B: Glossary

**Term** | **Definition**
---|---
**FA** | Factor Analysis - decomposition of observed variables into latent factors
**GM** | Gaussian Mixture Model - probabilistic clustering with multivariate normal distributions
**IRT** | Item Response Theory - relationship between latent trait and item responses
**CDM** | Cognitive Diagnosis Model - classification of latent attribute mastery
**S3 method** | R's simple object-oriented system using generic function dispatch
**Deprecation** | Marking functions as outdated; soft = warning, hard = removal
**LLM** | Large Language Model (e.g., GPT-4, Claude)
**Loadings** | Factor analysis coefficients indicating variable-factor relationships
**Q-matrix** | Binary matrix in CDM indicating which attributes each item measures
**Heywood case** | Factor analysis error where variance estimate becomes negative

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-03 | Claude Code | Initial comprehensive refactoring plan |

---

**END OF REFACTORING PLAN**
