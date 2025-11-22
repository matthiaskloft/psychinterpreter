# ==============================================================================
# TEMPLATE: {MODEL}_config_additions.R
# ==============================================================================
#
# PURPOSE: Add configuration support for new {MODEL} analysis type
#
# ARCHITECTURE: Implements Integration Points (see dev/COMMON_ARCHITECTURE_PATTERNS.md)
# - Section: "Integration Points" (lines 512-596)
# - Registers in dispatch tables (shared_config.R)
# - Creates interpretation_args_{model}() constructor
# - Integrates with parameter registry
#
# PATTERN COMPLIANCE CHECKLIST:
# [ ] Added to .ANALYSIS_TYPE_DISPLAY_NAMES dispatch table
# [ ] Added to .VALID_INTERPRETATION_PARAMS dispatch table
# [ ] Added to .INTERPRETATION_ARGS_DISPATCH dispatch table
# [ ] Implemented interpretation_args_{model}() constructor
# [ ] Registered parameters in aaa_param_registry.R
# [ ] Added to model dispatch table in aaa_model_type_dispatch.R
#
# SIDE-BY-SIDE COMPARISON:
# FA: R/shared_config.R (lines 130-180) - interpretation_args_fa()
# GM: R/shared_config.R (lines 182-241) - interpretation_args_gm()
# Both follow identical constructor pattern with parameter extraction
#
# ==============================================================================
# REPLACEMENT PLACEHOLDERS
# ==============================================================================
#
# IMPORTANT: Replace ALL instances of:
#   {model}          -> analysis type code (e.g., "gm", "irt", "cdm")
#   {MODEL}          -> capitalized analysis name (e.g., "Gaussian Mixture")
#   {PARAM1}         -> first parameter name (e.g., "min_cluster_size")
#   {PARAM2}         -> second parameter name (e.g., "separation_threshold")
#   {param1_default} -> default value for PARAM1
#   {param2_default} -> default value for PARAM2
#
# Last Updated: 2025-11-22 (Enhanced with Architecture Patterns)
# ==============================================================================


# ==============================================================================
# STEP 1: REGISTER IN DISPATCH TABLES (R/shared_config.R)
# ==============================================================================
#
# Add your new analysis type to 3 dispatch tables at the top of shared_config.R:
#
# 1. Display Names (lines 31-36)
# ------------------------------------------------------------------------------

.ANALYSIS_TYPE_DISPLAY_NAMES <- c(
  fa = "Factor Analysis",
  gm = "Gaussian Mixture",      # EXISTING
  irt = "Item Response Theory",  # EXISTING
  cdm = "Cognitive Diagnosis",   # EXISTING
  {model} = "{MODEL}"            # ADD YOUR TYPE HERE
)


# 2. Valid Parameters (lines 45-50)
# ------------------------------------------------------------------------------

.VALID_INTERPRETATION_PARAMS <- list(
  fa = c("cutoff", "n_emergency", "hide_low_loadings", "sort_loadings"),
  gm = character(0),   # Future: placeholder
  irt = character(0),  # Future: placeholder
  cdm = character(0),  # Future: placeholder
  {model} = c("{PARAM1}", "{PARAM2}")  # ADD YOUR PARAMETERS HERE
)


# 3. Handler Dispatch Table (lines 217-219)
# ------------------------------------------------------------------------------
# This table is defined AFTER the handler functions (see Step 2 below)

.INTERPRETATION_ARGS_DISPATCH <- list(
  fa = interpretation_args_fa,
  {model} = interpretation_args_{model}  # ADD YOUR HANDLER HERE (define in Step 2)
)


# ==============================================================================
# STEP 2: ADD PARAMETER METADATA TO REGISTRY (R/core_parameter_registry.R)
# ==============================================================================
#
# Add each parameter to the PARAMETER_REGISTRY list with full metadata:
#
# Location: After FA parameters section (~line 300+)
# Pattern: Copy from R/core_parameter_registry.R lines 241-280 (FA params)
# ------------------------------------------------------------------------------

# In PARAMETER_REGISTRY list, add:

  # ==========================================================================
  # {MODEL} PARAMETERS
  # ==========================================================================

  {PARAM1} = list(
    default = {param1_default},  # e.g., 2, "full", TRUE
    type = "integer",             # or "character", "numeric", "logical"
    range = c(1, 100),            # For numeric types, or NULL
    allowed_values = NULL,        # For character types with fixed options, or NULL
    config_group = "interpretation_args",
    model_specific = "{model}",   # e.g., "gm", "irt", "cdm"
    required = FALSE,
    validation_fn = function(value) {
      # Example: numeric range validation
      if (!is.numeric(value) || length(value) != 1) {
        return(list(valid = FALSE, message = "{.arg {PARAM1}} must be a single numeric value"))
      }
      if (value < 1 || value > 100) {
        return(list(valid = FALSE, message = "{.arg {PARAM1}} must be between 1 and 100"))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Short description of {PARAM1}"
  ),

  {PARAM2} = list(
    default = "{param2_default}",  # e.g., "full", "tied", "diag"
    type = "character",
    range = NULL,
    allowed_values = c("option1", "option2", "option3"),  # Define valid choices
    config_group = "interpretation_args",
    model_specific = "{model}",
    required = FALSE,
    validation_fn = function(value) {
      # Example: allowed values validation
      allowed <- c("option1", "option2", "option3")
      if (!is.character(value) || length(value) != 1) {
        return(list(valid = FALSE, message = "{.arg {PARAM2}} must be a single character value"))
      }
      if (!value %in% allowed) {
        return(list(valid = FALSE, message = paste0(
          "{.arg {PARAM2}} must be one of: ", paste(allowed, collapse = ", ")
        )))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Short description of {PARAM2}"
  )


# ==============================================================================
# STEP 3: CREATE HANDLER FUNCTION (R/shared_config.R)
# ==============================================================================
#
# Add this function BEFORE the .INTERPRETATION_ARGS_DISPATCH table definition
# (around line 180-200 in shared_config.R)
#
# Location: After interpretation_args_fa() function (~line 201)
# Pattern: Copy from R/shared_config.R lines 181-201 (interpretation_args_fa)
# ------------------------------------------------------------------------------

#' Create {MODEL}-Specific Interpretation Args (Internal)
#'
#' Internal handler function called by interpretation_args() dispatcher.
#' Uses parameter registry for defaults and validation.
#'
#' @param {PARAM1} {Description}. Default from registry: {param1_default}
#' @param {PARAM2} {Description}. Default from registry: {param2_default}
#'
#' @return interpretation_args object with validated parameters
#' @keywords internal
#' @noRd
interpretation_args_{model} <- function({PARAM1} = NULL,
                                        {PARAM2} = NULL) {

  # Build parameter list with registry defaults
  param_list <- list(
    analysis_type = "{model}",
    {PARAM1} = {PARAM1} %||% get_param_default("{PARAM1}"),
    {PARAM2} = {PARAM2} %||% get_param_default("{PARAM2}")
  )

  # Validate all parameters using registry
  validated <- validate_params(param_list, throw_error = TRUE)

  # Return with proper class structure
  structure(
    validated,
    class = c("interpretation_args", "model_config", "list")
  )
}


# ==============================================================================
# STEP 4: UPDATE PRINT METHOD (R/shared_config.R)
# ==============================================================================
#
# Add custom formatting for your parameters in print.interpretation_args()
# Location: Lines 443-476 in shared_config.R
# ------------------------------------------------------------------------------

# In print.interpretation_args(), add to the parameter display section:

      } else if (param == "{PARAM1}") {
        cli::cli_li("{PARAM1}: {.val {value}}")
      } else if (param == "{PARAM2}") {
        cli::cli_li("{PARAM2}: {.val {value}}")


# ==============================================================================
# STEP 5: UPDATE MODEL TYPE DISPATCH (R/aaa_model_type_dispatch.R)
# ==============================================================================
#
# If your analysis type supports specific model classes (like lavaan, mirt),
# add them to the model dispatch table.
#
# Location: get_model_dispatch_table() function, lines 21-65
# Pattern: See existing entries for psych, lavaan, mirt
# ------------------------------------------------------------------------------

# Example: Adding support for a Gaussian Mixture model class from 'mixtools'

get_model_dispatch_table <- function() {
  list(
    # ... existing entries ...

    # mixtools package models
    mixEM = list(
      analysis_type = "gm",
      package = "mixtools",
      validator_name = "validate_mixtools_model",
      extractor_name = "extract_mixtools_data"
    )
  )
}

# Then create validator and extractor functions:

#' Validate mixtools Package Models
#' @keywords internal
#' @noRd
validate_mixtools_model <- function(model) {
  if (!inherits(model, "mixEM")) {
    cli::cli_abort(c(
      "Model must inherit from {.cls mixEM}",
      "x" = "Got class: {.cls {class(model)}}"
    ))
  }

  # Add model-specific validation
  if (is.null(model$lambda)) {
    cli::cli_abort("Model does not contain mixture weights (lambda)")
  }

  invisible(NULL)
}

#' Extract Data from mixtools Models
#' @keywords internal
#' @noRd
extract_mixtools_data <- function(model) {
  list(
    mixture_weights = model$lambda,
    component_means = model$mu,
    component_sigmas = model$sigma
    # Extract whatever components your analysis type needs
  )
}


# ==============================================================================
# STEP 6: CREATE S3 METHODS FOR YOUR ANALYSIS TYPE
# ==============================================================================
#
# Create a new file: R/{model}_model_data.R
# Pattern: Copy structure from R/fa_model_data.R
# ------------------------------------------------------------------------------

# Example structure for R/gm_model_data.R:

#' Build Analysis Data for Gaussian Mixture Models
#'
#' @param fit_results Model object or structured list
#' @param variable_info Data frame with variable descriptions
#' @param interpretation_args Configuration from interpretation_args()
#' @param ... Additional parameters
#'
#' @return List with analysis data
#' @keywords internal
#' @noRd
build_analysis_data.gm <- function(fit_results, variable_info,
                                    interpretation_args = NULL, ...) {
  # Extract parameters from interpretation_args or registry
  dots <- list(...)

  n_components <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
    interpretation_args$n_components
  } else {
    dots$n_components
  }
  if (is.null(n_components)) n_components <- get_param_default("n_components")

  covariance_type <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
    interpretation_args$covariance_type
  } else {
    dots$covariance_type
  }
  if (is.null(covariance_type)) covariance_type <- get_param_default("covariance_type")

  # Validate parameters using registry
  validate_params(list(
    n_components = n_components,
    covariance_type = covariance_type
  ), throw_error = TRUE)

  # Extract model data
  if (is_supported_model(fit_results)) {
    model_data <- get_model_info(fit_results)
    extractor <- get(model_data$extractor_name, mode = "function")
    extracted <- extractor(fit_results)
  } else if (is.list(fit_results)) {
    # Handle structured list input
    extracted <- fit_results
  } else {
    cli::cli_abort("fit_results must be a supported model object or structured list")
  }

  # Build your analysis-specific data structure
  list(
    mixture_weights = extracted$mixture_weights,
    component_means = extracted$component_means,
    component_sigmas = extracted$component_sigmas,
    n_components = n_components,
    covariance_type = covariance_type,
    variable_info = variable_info
    # Add whatever your analysis type needs
  )
}


# ==============================================================================
# STEP 7: CREATE PROMPT BUILDER METHODS
# ==============================================================================
#
# Create a new file: R/{model}_prompt_builder.R
# Pattern: Copy from R/fa_prompt_builder.R (lines 1-200)
# ------------------------------------------------------------------------------

# Implement these S3 methods:

#' @export
build_system_prompt.gm <- function(analysis_data, llm_args = NULL, ...) {
  # Build system prompt for your analysis type
  # See R/fa_prompt_builder.R lines 17-85 for pattern
}

#' @export
build_main_prompt.gm <- function(analysis_data, llm_args = NULL, ...) {
  # Build main prompt with analysis data
  # See R/fa_prompt_builder.R lines 107-181 for pattern
}


# ==============================================================================
# STEP 8: CREATE JSON PARSER
# ==============================================================================
#
# Create a new file: R/{model}_json.R
# Pattern: Copy from R/fa_json.R
# ------------------------------------------------------------------------------

#' @export
parse_llm_json.gm <- function(llm_response, analysis_data, llm_args = NULL, ...) {
  # Parse LLM JSON response
  # See R/fa_json.R for full pattern with fallback strategies
}


# ==============================================================================
# STEP 9: CREATE REPORT BUILDER
# ==============================================================================
#
# Create a new file: R/{model}_report.R
# Pattern: Copy from R/fa_report.R, using dispatch tables for format handling
# ------------------------------------------------------------------------------

#' @export
build_report.gm <- function(interpretation_obj, output_args = NULL, ...) {
  # Build formatted report
  # Use .format_dispatch_table pattern from R/fa_report.R lines 31-56
}


# ==============================================================================
# STEP 10: CREATE TESTS
# ==============================================================================
#
# Create test files following existing patterns:
# ------------------------------------------------------------------------------

# 1. tests/testthat/test-{model}_config.R
#    Pattern: Copy from test-fa_config.R
#    Tests: parameter validation, dispatch routing, config object creation

# 2. tests/testthat/test-{model}_model_data.R
#    Pattern: Copy from test-fa_model_data.R
#    Tests: data extraction, validation, structured list handling

# 3. tests/testthat/test-interpret_{model}.R
#    Pattern: Copy from test-interpret_fa.R
#    Tests: full integration tests with mock LLM responses


# ==============================================================================
# STEP 11: UPDATE DOCUMENTATION
# ==============================================================================

# 1. Update R/shared_config.R roxygen docs for interpretation_args()
#    Add your model type to the examples and parameter documentation

# 2. Run devtools::document() to regenerate .Rd files

# 3. Update CLAUDE.md:
#    - Add to "Quick Reference Tables" section
#    - Add usage examples

# 4. Update dev/DEVELOPER_GUIDE.md:
#    - Document your analysis type architecture
#    - Add to model type dispatch table section

# 5. Update _pkgdown.yml if adding new exported functions


# ==============================================================================
# STEP 12: RUN QUALITY CHECKS
# ==============================================================================

# 1. Regenerate documentation
devtools::document()

# 2. Run tests
devtools::test()

# 3. Check package
devtools::check()

# 4. Build package
devtools::build()


# ==============================================================================
# VALIDATION CHECKLIST
# ==============================================================================
#
# Before submitting, verify:
#
# [ ] Parameters registered in PARAMETER_REGISTRY with validation functions
# [ ] Display name added to .ANALYSIS_TYPE_DISPLAY_NAMES
# [ ] Valid parameters added to .VALID_INTERPRETATION_PARAMS
# [ ] Handler function interpretation_args_{model}() created
# [ ] Handler registered in .INTERPRETATION_ARGS_DISPATCH
# [ ] Print method updated with parameter formatting
# [ ] Model dispatch table updated (if applicable)
# [ ] build_analysis_data.{model}() method created
# [ ] build_system_prompt.{model}() method created
# [ ] build_main_prompt.{model}() method created
# [ ] parse_llm_json.{model}() method created
# [ ] build_report.{model}() method created
# [ ] Tests created and passing (aim for >90% coverage)
# [ ] Documentation updated and regenerated
# [ ] Examples use standard test settings (ollama + word_limit = 20)
# [ ] devtools::check() passes with no errors/warnings
# [ ] CLAUDE.md updated with usage patterns
# [ ] DEVELOPER_GUIDE.md updated with technical details
#
# ==============================================================================


# ==============================================================================
# EXAMPLE: COMPLETE MINIMAL IMPLEMENTATION
# ==============================================================================
#
# Here's a minimal example for adding "gm" (Gaussian Mixture) support:
# ------------------------------------------------------------------------------

# --- R/core_parameter_registry.R (add to PARAMETER_REGISTRY) ---

  # GAUSSIAN MIXTURE PARAMETERS
  n_components = list(
    default = 2,
    type = "integer",
    range = c(1, 20),
    allowed_values = NULL,
    config_group = "interpretation_args",
    model_specific = "gm",
    required = FALSE,
    validation_fn = function(value) {
      if (!is.numeric(value) || length(value) != 1) {
        return(list(valid = FALSE, message = "{.arg n_components} must be a single integer"))
      }
      if (value < 1 || value > 20) {
        return(list(valid = FALSE, message = "{.arg n_components} must be between 1 and 20"))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Number of mixture components"
  ),

  covariance_type = list(
    default = "full",
    type = "character",
    range = NULL,
    allowed_values = c("full", "tied", "diag", "spherical"),
    config_group = "interpretation_args",
    model_specific = "gm",
    required = FALSE,
    validation_fn = function(value) {
      allowed <- c("full", "tied", "diag", "spherical")
      if (!is.character(value) || length(value) != 1) {
        return(list(valid = FALSE, message = "{.arg covariance_type} must be a single character value"))
      }
      if (!value %in% allowed) {
        return(list(valid = FALSE, message = paste0(
          "{.arg covariance_type} must be one of: ", paste(allowed, collapse = ", ")
        )))
      }
      list(valid = TRUE, message = NULL)
    },
    description = "Type of covariance matrix"
  )


# --- R/shared_config.R (update dispatch tables) ---

# Display names (lines 31-36)
.ANALYSIS_TYPE_DISPLAY_NAMES <- c(
  fa = "Factor Analysis",
  gm = "Gaussian Mixture"  # ADD
)

# Valid parameters (lines 45-50)
.VALID_INTERPRETATION_PARAMS <- list(
  fa = c("cutoff", "n_emergency", "hide_low_loadings", "sort_loadings"),
  gm = c("n_components", "covariance_type")  # ADD
)

# Handler function (add before dispatch table, ~line 180-200)
interpretation_args_gm <- function(n_components = NULL, covariance_type = NULL) {
  param_list <- list(
    analysis_type = "gm",
    n_components = n_components %||% get_param_default("n_components"),
    covariance_type = covariance_type %||% get_param_default("covariance_type")
  )
  validated <- validate_params(param_list, throw_error = TRUE)
  structure(validated, class = c("interpretation_args", "model_config", "list"))
}

# Dispatch table registration (lines 217-219)
.INTERPRETATION_ARGS_DISPATCH <- list(
  fa = interpretation_args_fa,
  gm = interpretation_args_gm  # ADD
)

# Print method update (in print.interpretation_args, ~line 450)
      } else if (param == "n_components") {
        cli::cli_li("Components: {.val {value}}")
      } else if (param == "covariance_type") {
        cli::cli_li("Covariance: {.val {value}}")


# --- R/gm_model_data.R (new file) ---

build_analysis_data.gm <- function(fit_results, variable_info,
                                    interpretation_args = NULL, ...) {
  dots <- list(...)

  # Extract parameters with registry fallback
  n_components <- interpretation_args$n_components %||% dots$n_components %||%
                  get_param_default("n_components")
  covariance_type <- interpretation_args$covariance_type %||% dots$covariance_type %||%
                     get_param_default("covariance_type")

  # Validate
  validate_params(list(n_components = n_components, covariance_type = covariance_type),
                  throw_error = TRUE)

  # Build data structure
  list(
    n_components = n_components,
    covariance_type = covariance_type,
    variable_info = variable_info
  )
}


# --- Usage ---

# Now users can do:
interp_config <- interpretation_args(
  analysis_type = "gm",
  n_components = 3,
  covariance_type = "tied"
)

result <- interpret(
  fit_results = gm_model,
  variable_info = vars,
  interpretation_args = interp_config,
  llm_provider = "ollama",
  llm_model = "gpt-oss:20b-cloud"
)


# ==============================================================================
# ADDITIONAL RESOURCES
# ==============================================================================
#
# Reference Files:
# - R/shared_config.R: Configuration system and dispatch tables
# - R/core_parameter_registry.R: Parameter metadata and validation
# - R/aaa_model_type_dispatch.R: Model type dispatch system
# - R/fa_model_data.R: Example build_analysis_data implementation
# - R/fa_prompt_builder.R: Example prompt builder methods
# - R/fa_json.R: Example JSON parser with fallback strategies
# - R/fa_report.R: Example report builder with format dispatch
# - dev/DISPATCH_TABLE_SUMMARY.md: Complete architecture overview
# - dev/DEVELOPER_GUIDE.md: Technical implementation guide
# - CLAUDE.md: User-facing documentation patterns
#
# Key Patterns:
# 1. Parameters go in PARAMETER_REGISTRY, not hardcoded
# 2. Use get_param_default() for defaults
# 3. Use validate_params() for validation
# 4. Use dispatch tables, not if/else chains
# 5. Use %||% (null-coalescing) for parameter merging
# 6. Use cli::cli_abort() for user-facing errors
# 7. Follow naming convention: interpretation_args_{model}()
#
# ==============================================================================
