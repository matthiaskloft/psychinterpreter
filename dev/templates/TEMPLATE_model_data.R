# ==============================================================================
# TEMPLATE: {MODEL}_model_data.R
# ==============================================================================
#
# PURPOSE: Extract and validate data from fitted {MODEL} objects
#
# ARCHITECTURE: Implements Data Structure Pattern (see dev/COMMON_ARCHITECTURE_PATTERNS.md)
# - Section: "Data Structure Pattern" (lines 88-156)
# - Section: "Parameter Extraction Pattern" (lines 158-193)
# - Section: "S3 Method Dispatch Pattern" (lines 36-86)
#
# PATTERN COMPLIANCE CHECKLIST:
# [ ] Implements build_analysis_data.{CLASS}() S3 method
# [ ] Implements build_{model}_analysis_data_internal() helper
# [ ] Returns standardized analysis_data structure with 5 universal fields
# [ ] Uses triple-tier parameter extraction pattern
# [ ] Integrates with model dispatch table
# [ ] Validates via parameter registry
#
# ==============================================================================
# REPLACEMENT PLACEHOLDERS
# ==============================================================================
#
# Replace all instances of {MODEL}, {model}, {CLASS}, {PARAM1}, etc. with your values
#
# ==============================================================================
# EXAMPLE REPLACEMENTS BY MODEL TYPE
# ==============================================================================
#
# Gaussian Mixture (GM) - Reference Implementation:
#   {MODEL} -> Gaussian Mixture
#   {model} -> gm
#   {CLASS} -> Mclust
#   {PACKAGE} -> mclust
#   {PARAM1} -> min_cluster_size
#   {PARAM2} -> separation_threshold
#   {DATA_FIELD1} -> means
#   {DATA_FIELD2} -> covariances
#   {COMPONENTS} -> clusters
#   See: R/gm_model_data.R for full implementation
#
# Factor Analysis (FA) - Reference Implementation:
#   {MODEL} -> Factor Analysis
#   {model} -> fa
#   {CLASS} -> psych
#   {PACKAGE} -> psych
#   {PARAM1} -> cutoff
#   {PARAM2} -> n_emergency
#   {DATA_FIELD1} -> loadings_df
#   {DATA_FIELD2} -> factor_summaries
#   {COMPONENTS} -> factors
#   See: R/fa_model_data.R for full implementation
#
# Item Response Theory (IRT) - To Be Implemented:
#   {MODEL} -> Item Response Theory
#   {model} -> irt
#   {CLASS} -> SingleGroupClass
#   {PACKAGE} -> mirt
#   {PARAM1} -> model_spec
#   {PARAM2} -> n_factors
#   {DATA_FIELD1} -> item_params
#   {DATA_FIELD2} -> ability_estimates
#   {COMPONENTS} -> items
#
# Cognitive Diagnosis Models (CDM) - To Be Implemented:
#   {MODEL} -> Cognitive Diagnosis Model
#   {model} -> cdm
#   {CLASS} -> gdina
#   {PACKAGE} -> GDINA
#   {PARAM1} -> rule
#   {PARAM2} -> n_attributes
#   {DATA_FIELD1} -> q_matrix
#   {DATA_FIELD2} -> item_params
#   {COMPONENTS} -> attributes

# ==============================================================================
# INTEGRATION WITH DISPATCH SYSTEM (2025-11-16 ARCHITECTURE)
# ==============================================================================
#
# After implementing this file, you MUST register your model type in:
# R/aaa_model_type_dispatch.R
#
# 1. Add entry to get_model_dispatch_table():
#    {CLASS} = list(
#      analysis_type = "{model}",
#      package = "{PACKAGE}",
#      validator_name = "validate_{model}_model",
#      extractor_name = "extract_{model}_data"
#    )
#
# 2. Implement validator function:
#    validate_{model}_model <- function(model) {
#      # Check class inheritance
#      # Check required components exist
#      # Check package availability
#    }
#
# 3. Implement extractor function:
#    extract_{model}_data <- function(model) {
#      # Extract model-specific components
#      # Return list with standardized structure
#    }
#
# This dispatch system provides:
# - Centralized model type checking via is_supported_model()
# - Automatic validation via validate_model_structure()
# - Clean S3 dispatch without complex inherits() chains
#
# See R/aaa_model_type_dispatch.R (lines 21-145) for examples
# See R/fa_model_data.R (lines 404-428) for FA implementation pattern
#
# ==============================================================================

# ==============================================================================
# S3 METHOD FOR FITTED MODEL OBJECTS
# ==============================================================================
#
# This S3 method is called when interpret() receives a fitted model object.
# It integrates with the dispatch system to:
# 1. Validate model structure (via validate_model_structure())
# 2. Extract model data (via extractor function from dispatch table)
# 3. Pass to internal helper for standardization
#
# Pattern from fa_model_data.R:383-428

#' Build model data for {MODEL} interpretation
#'
#' Extracts data from {CLASS} objects (from {PACKAGE} package) and standardizes
#' it for LLM interpretation.
#'
#' @param fit_results Fitted {MODEL} object from {PACKAGE}::{CLASS}()
#' @param variable_info Data frame with columns 'variable' and 'description'
#' @param analysis_type Analysis type identifier (should be "{model}")
#' @param interpretation_args Optional configuration object from interpretation_args(analysis_type = "{model}", ...)
#' @param ... Additional arguments (for parameter extraction)
#'
#' @return List with standardized {MODEL} data structure containing:
#'   \item{DATA_FIELD1}{Description of first data field}
#'   \item{DATA_FIELD2}{Description of second data field}
#'   \item{n_components}{Number of {COMPONENTS} (e.g., clusters, factors, items)}
#'   \item{n_variables}{Number of variables}
#'   \item{analysis_type}{Analysis type identifier ("{model}")}
#'   \item{{PARAM1}}{First model-specific parameter}
#'   \item{{PARAM2}}{Second model-specific parameter}
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library({PACKAGE})
#'
#' # Fit {MODEL} model
#' fit <- {CLASS}(data, ...)
#'
#' # Prepare variable info
#' var_info <- data.frame(
#'   variable = colnames(data),
#'   description = c("Description 1", "Description 2", ...)
#' )
#'
#' # Extract analysis data
#' analysis_data <- build_analysis_data(fit, var_info, analysis_type = "{model}")
#' }
build_analysis_data.{CLASS} <- function(fit_results,
                                      variable_info,
                                      analysis_type = "{model}",
                                      interpretation_args = NULL,
                                      ...) {

  # Extract parameters from ...
  dots <- list(...)
  variable_info <- dots$variable_info

  # Remove variable_info from dots to avoid passing it twice
  dots$variable_info <- NULL

  # Ensure analysis_type is "{model}" if NULL (use default)
  if (is.null(analysis_type)) analysis_type <- "{model}"

  # Validate variable_info is provided
  if (is.null(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} is required for {MODEL}",
        "i" = "Provide a data frame with 'variable' and 'description' columns"
      )
    )
  }

  # Validate model structure using dispatch table
  # This calls validate_{model}_model() defined in R/aaa_model_type_dispatch.R
  validate_model_structure(fit_results)

  # Extract data using dispatch table
  # This calls extract_{model}_data() defined in R/aaa_model_type_dispatch.R
  model_info <- get_model_info(fit_results)
  extractor_fn <- get(model_info$extractor_name, mode = "function")
  extracted_data <- extractor_fn(fit_results)

  # Call internal function with named parameters, passing remaining dots
  # Filter dots to avoid parameter name conflicts
  dots_filtered <- dots[!names(dots) %in% c("fit_results", "variable_info", "analysis_type", "interpretation_args")]

  do.call(
    build_{model}_analysis_data_internal,
    c(
      list(
        fit_results = extracted_data,
        variable_info = variable_info,
        analysis_type = analysis_type,
        interpretation_args = interpretation_args
      ),
      dots_filtered
    )
  )
}


# ==============================================================================
# INTERNAL HELPER FUNCTION
# ==============================================================================
#
# This internal function is called by:
# 1. build_analysis_data.{CLASS}() for fitted model objects
# 2. build_analysis_data.list() for structured lists
# 3. build_analysis_data.matrix() / .data.frame() for raw data
#
# It assumes fit_results has already been validated and extracted by the
# S3 method, so it focuses on:
# - Parameter extraction and validation
# - Data processing and standardization
# - Creating the final analysis_data structure
#
# See dev/DEVELOPER_GUIDE.md section 3 for architecture details

#' Internal helper to build {MODEL} model data
#'
#' @keywords internal
#' @noRd
build_{model}_analysis_data_internal <- function(fit_results,
                                               variable_info,
                                               analysis_type = "{model}",
                                               interpretation_args = NULL,
                                               ...) {

  # ============================================================================
  # STEP 1: Extract model-specific parameters using parameter registry
  # ============================================================================
  #
  # ARCHITECTURE PATTERN: Triple-Tier Parameter Extraction
  # (see dev/COMMON_ARCHITECTURE_PATTERNS.md - "Parameter Extraction Pattern")
  #
  # This pattern is IDENTICAL across FA and GM implementations:
  # 1. Check interpretation_args (highest priority - user configuration object)
  # 2. Fall back to ... (dots - direct parameter passing)
  # 3. Fall back to get_param_default() (package defaults from registry)
  #
  # WHY THIS PATTERN?
  # - Allows users to pass parameters three different ways (flexibility)
  # - Configuration objects enable reusable settings across analyses
  # - Direct parameters enable quick one-off overrides
  # - Registry defaults ensure consistent behavior when nothing specified
  #
  # SIDE-BY-SIDE COMPARISON:
  #
  # FA Example (R/fa_model_data.R:26-40):
  #   cutoff <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
  #     interpretation_args$cutoff
  #   } else {
  #     dots$cutoff
  #   }
  #   if (is.null(cutoff)) cutoff <- get_param_default("cutoff")  # Default: 0.3
  #
  # GM Example (R/gm_model_data.R:49-54):
  #   min_cluster_size <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
  #     interpretation_args$min_cluster_size
  #   } else {
  #     dots$min_cluster_size
  #   }
  #   if (is.null(min_cluster_size)) min_cluster_size <- get_param_default("min_cluster_size")  # Default: 5
  #
  # NOTE: The code structure is IDENTICAL - only parameter names differ!

  dots <- list(...)

  # TRIPLE-TIER EXTRACTION: Parameter 1
  {PARAM1} <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
    interpretation_args${PARAM1}  # Tier 1: Configuration object
  } else {
    dots${PARAM1}  # Tier 2: Direct parameter
  }
  if (is.null({PARAM1})) {PARAM1} <- get_param_default("{PARAM1}")  # Tier 3: Registry default

  # TRIPLE-TIER EXTRACTION: Parameter 2
  {PARAM2} <- if (!is.null(interpretation_args) && is.list(interpretation_args)) {
    interpretation_args${PARAM2}  # Tier 1: Configuration object
  } else {
    dots${PARAM2}  # Tier 2: Direct parameter
  }
  if (is.null({PARAM2})) {PARAM2} <- get_param_default("{PARAM2}")  # Tier 3: Registry default

  # TODO: Add additional parameters following the EXACT same pattern
  # IMPORTANT: All model-specific parameters MUST use this triple-tier pattern
  # for consistency with FA and GM implementations


  # ============================================================================
  # STEP 2: Validate parameters using parameter registry
  # ============================================================================
  #
  # RECOMMENDED: Use registry-based validation instead of manual validation.
  # This ensures consistency with the rest of the package and reduces code duplication.
  #
  # Option A: Registry-based validation (RECOMMENDED)
  # --------------------------------------------------
  # If you registered your parameters in R/core_parameter_registry.R, use validate_params():
  #
  # param_list <- list(
  #   {PARAM1} = {PARAM1},
  #   {PARAM2} = {PARAM2}
  # )
  # validated <- validate_params(param_list, throw_error = TRUE)
  # {PARAM1} <- validated${PARAM1}
  # {PARAM2} <- validated${PARAM2}
  #
  # See R/core_parameter_registry.R for parameter registration pattern
  #
  # Option B: Manual validation (if registry not used)
  # ---------------------------------------------------
  # Pattern from fa_model_data.R:50-67

  # Validate {PARAM1}
  if (!is.null({PARAM1})) {
    valid_options <- c("option1", "option2", "option3")  # TODO: Define valid options
    if (!{PARAM1} %in% valid_options) {
      cli::cli_abort(c(
        "x" = "Invalid {PARAM1}: {{PARAM1}}",
        "i" = "Must be one of: {paste(valid_options, collapse = ', ')}"
      ))
    }
  }

  # Validate {PARAM2}
  if (!is.null({PARAM2})) {
    if (!is.numeric({PARAM2}) || {PARAM2} < 1) {
      cli::cli_abort(c(
        "x" = "{PARAM2} must be a positive number",
        "i" = "Got: {{PARAM2}}"
      ))
    }
  }

  # TODO: Add additional parameter validation
  # Prefer registry-based validation when possible


  # ============================================================================
  # STEP 3: Extract data from fitted model
  # ============================================================================

  # THIS IS MODEL-SPECIFIC - extract relevant components from fit_results

  # Example for Gaussian Mixture:
  # means <- fit_results$parameters$mean
  # covariances <- fit_results$parameters$variance$sigma
  # probabilities <- fit_results$z
  # n_clusters <- fit_results$G

  # Example for IRT:
  # item_params <- mirt::coef(fit_results, simplify = TRUE)$items
  # ability_estimates <- mirt::fscores(fit_results)
  # n_items <- mirt::extract.mirt(fit_results, "nitems")

  # TODO: Replace with your model-specific extraction
  data_field1 <- NULL  # TODO: Extract first data component
  data_field2 <- NULL  # TODO: Extract second data component
  n_components <- NULL  # TODO: Extract number of components (clusters, factors, etc.)


  # ============================================================================
  # STEP 4: Validate variable_info
  # ============================================================================

  # Pattern from fa_model_data.R:74-118

  # Check it's a data frame
  if (!is.data.frame(variable_info)) {
    cli::cli_abort(c(
      "x" = "variable_info must be a data frame",
      "i" = "Got: {class(variable_info)[1]}"
    ))
  }

  # Check required columns
  required_cols <- c("variable", "description")
  missing_cols <- setdiff(required_cols, names(variable_info))

  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "x" = "variable_info missing required columns: {paste(missing_cols, collapse = ', ')}",
      "i" = "Required columns: {paste(required_cols, collapse = ', ')}"
    ))
  }

  # Check for empty descriptions
  empty_desc <- which(is.na(variable_info$description) | variable_info$description == "")
  if (length(empty_desc) > 0) {
    empty_vars <- variable_info$variable[empty_desc]
    cli::cli_abort(c(
      "x" = "variable_info has empty descriptions for: {paste(empty_vars, collapse = ', ')}",
      "i" = "All variables must have descriptions"
    ))
  }

  # Check variable count matches model
  n_variables <- nrow(variable_info)
  n_model_vars <- ncol(data_field1)  # TODO: Adjust based on your data structure

  if (n_variables != n_model_vars) {
    cli::cli_abort(c(
      "x" = "Number of variables mismatch",
      "i" = "variable_info has {n_variables} rows",
      "i" = "Model has {n_model_vars} variables"
    ))
  }


  # ============================================================================
  # STEP 5: Process and format model data
  # ============================================================================

  # THIS IS MODEL-SPECIFIC - create any derived data structures

  # Example for GM: Create cluster summaries
  # cluster_summaries <- lapply(1:n_clusters, function(k) {
  #   list(
  #     cluster = k,
  #     mean = means[, k],
  #     covariance = covariances[, , k],
  #     probability = mean(probabilities[, k])
  #   )
  # })

  # Example for FA: Create factor summaries with top loadings
  # factor_summaries <- lapply(1:n_factors, function(f) {
  #   loadings <- loadings_matrix[, f]
  #   top_vars <- which(abs(loadings) >= cutoff)
  #   list(
  #     factor = f,
  #     n_loadings = length(top_vars),
  #     top_variables = variable_info$variable[top_vars]
  #   )
  # })

  # TODO: Replace with your model-specific processing
  processed_data <- NULL  # TODO: Create any derived structures


  # ============================================================================
  # STEP 6: Return standardized structure
  # ============================================================================
  #
  # ARCHITECTURE PATTERN: Standardized analysis_data Structure
  # (see dev/COMMON_ARCHITECTURE_PATTERNS.md - "Data Structure Pattern")
  #
  # CRITICAL: The first 5 fields MUST be present in ALL models:
  # 1. analysis_type  - Model type identifier ("fa", "gm", "irt", "cdm")
  # 2. n_components   - Number of factors/clusters/items/attributes
  # 3. n_variables    - Number of variables
  # 4. variable_names - Character vector of variable names
  # 5. component_names - Character vector of component names (Factor_1, Cluster_1, etc.)
  #
  # WHY THIS PATTERN?
  # - Enables generic functions to work across all model types
  # - S3 dispatch uses these fields for validation and formatting
  # - Prompt builders rely on consistent metadata
  # - Report generators expect these fields
  #
  # SIDE-BY-SIDE COMPARISON:
  #
  # FA Structure (R/fa_model_data.R:293-304):
  #   list(
  #     analysis_type = "fa",                    # 1. UNIVERSAL
  #     loadings_df = loadings_df,               # Model-specific data
  #     factor_summaries = factor_summaries,     # Model-specific data
  #     factor_cols = factor_cols,               # Component names (Factor_1, Factor_2, ...)
  #     n_factors = n_factors,                   # 2. UNIVERSAL (n_components)
  #     n_variables = n_variables,               # 3. UNIVERSAL
  #     factor_cor_mat = factor_cor_mat,         # Model-specific data (optional)
  #     cutoff = cutoff,                         # Model-specific parameter
  #     n_emergency = n_emergency,               # Model-specific parameter
  #     hide_low_loadings = hide_low_loadings    # Model-specific parameter
  #   )
  #
  # GM Structure (R/gm_model_data.R:125-151):
  #   list(
  #     means = means,                           # Model-specific data
  #     covariances = covariances,               # Model-specific data
  #     proportions = proportions,               # Model-specific data
  #     memberships = memberships,               # Model-specific data
  #     classification = classification,         # Model-specific data (optional)
  #     uncertainty = uncertainty,               # Model-specific data (optional)
  #     covariance_type = covariance_type,       # Model-specific metadata
  #     n_clusters = n_clusters,                 # 2. UNIVERSAL (n_components)
  #     n_variables = n_variables,               # 3. UNIVERSAL
  #     n_observations = n_observations,         # Model-specific metadata
  #     analysis_type = "gm",                    # 1. UNIVERSAL
  #     variable_names = variable_names,         # 4. UNIVERSAL
  #     cluster_names = cluster_names,           # 5. UNIVERSAL (component_names)
  #     min_cluster_size = min_cluster_size,     # Model-specific parameter
  #     separation_threshold = separation_threshold,  # Model-specific parameter
  #     profile_variables = profile_variables,   # Model-specific parameter
  #     weight_by_uncertainty = weight_by_uncertainty,  # Model-specific parameter
  #     plot_type = plot_type                    # Model-specific parameter
  #   )
  #
  # NOTICE:
  # - Both have analysis_type, n_components, n_variables
  # - Field order doesn't matter (but putting universal fields first is clearer)
  # - Model-specific data and parameters are unique to each model
  # - Class structure is consistent: c("{model}_analysis_data", "analysis_data", "list")

  structure(
    list(
      # ==== UNIVERSAL METADATA (REQUIRED FOR ALL MODELS) ====
      analysis_type = analysis_type,        # 1. Model type identifier
      n_components = n_components,          # 2. Number of factors/clusters/items
      n_variables = n_variables,            # 3. Number of variables
      variable_names = variable_info$variable,  # 4. Variable names (character vector)
      component_names = paste0("{COMPONENT}_", seq_len(n_components)),  # 5. Component names

      # ==== MODEL-SPECIFIC DATA ====
      # TODO: Replace with your actual field names and data structures
      data_field1 = data_field1,  # e.g., loadings_df (FA), means (GM), item_params (IRT)
      data_field2 = data_field2,  # e.g., factor_summaries (FA), covariances (GM), ability_estimates (IRT)
      processed_data = processed_data,  # Optional: any derived structures

      # ==== MODEL-SPECIFIC PARAMETERS ====
      # These parameters are stored here for use in prompts and reports
      {PARAM1} = {PARAM1},
      {PARAM2} = {PARAM2}
      # TODO: Add additional parameters as needed
    ),
    class = c("{model}_analysis_data", "analysis_data", "list")
  )
}


# ==============================================================================
# Additional Class Methods (if needed)
# ==============================================================================

# If your model type has multiple fitted object classes, create additional methods

# Example: If there's another class that produces {MODEL} results
# #' @export
# build_analysis_data.{OTHER_CLASS} <- function(fit_results,
#                                            variable_info,
#                                            analysis_type = "{model}",
#                                            interpretation_args = NULL,
#                                            ...) {
#
#   # Convert {OTHER_CLASS} object to standard format
#   # TODO: Extract data from {OTHER_CLASS} object
#   converted_data <- ...
#
#   # Call internal helper with converted data
#   build_{model}_analysis_data_internal(
#     fit_results = converted_data,
#     variable_info = variable_info,
#     analysis_type = analysis_type,
#     interpretation_args = interpretation_args,
#     ...
#   )
# }


# ==============================================================================
# Helper functions (if needed)
# ==============================================================================

# Add any helper functions for data extraction or processing

# Example helper:
# #' @keywords internal
# #' @noRd
# extract_{something}_from_{model} <- function(fit_results) {
#   # Implementation
# }


# ==============================================================================
# IMPLEMENTATION CHECKLIST (2025-11-16 ARCHITECTURE)
# ==============================================================================
#
# Complete implementation requires integration with multiple system components:
#
# [ ] 1. MODEL DISPATCH REGISTRATION (R/aaa_model_type_dispatch.R)
#     - Add entry to get_model_dispatch_table()
#     - Implement validate_{model}_model() function
#     - Implement extract_{model}_data() function
#     - Test with is_supported_model() and validate_model_structure()
#
# [ ] 2. PARAMETER REGISTRY (R/aaa_param_registry.R)
#     - Register model-specific parameters with .register_param()
#     - Define default values, types, and validation rules
#     - Test with get_param_default() and validate_params()
#
# [ ] 3. CONFIGURATION OBJECTS (R/shared_config.R)
#     - Add interpretation_args_{model}() constructor function
#     - Register in .INTERPRETATION_ARGS_DISPATCH table
#     - Add model parameters to .VALID_INTERPRETATION_PARAMS
#     - Update print.interpretation_args() for model-specific display
#
# [ ] 4. CORE DISPATCH (R/core_interpret.R)
#     - No changes needed - dispatch is automatic via S3 classes
#     - Verify interpret() can find build_analysis_data.{CLASS}()
#
# [ ] 5. PROMPT BUILDERS (R/{model}_prompt_builder.R)
#     - Implement build_system_prompt.{model}_analysis_data()
#     - Implement build_main_prompt.{model}_analysis_data()
#     - Use parameters from analysis_data structure
#
# [ ] 6. JSON PARSER (R/{model}_json.R)
#     - Implement parse_json.{model}_interpretation()
#     - Handle model-specific response structure
#     - Implement fallback extraction if needed
#
# [ ] 7. REPORT GENERATOR (R/{model}_report.R)
#     - Implement format_interpretation_report.{model}_interpretation()
#     - Support both CLI and markdown formats
#     - Follow package output_args standards
#
# [ ] 8. DOCUMENTATION
#     - Add roxygen2 docs for all exported functions
#     - Run devtools::document()
#     - Update _pkgdown.yml if adding user-facing functions
#     - Add usage examples to CLAUDE.md
#
# [ ] 9. TESTS (tests/testthat/test-{model}_*.R)
#     - Test model data extraction
#     - Test parameter validation
#     - Test prompt generation
#     - Test JSON parsing
#     - Test report formatting
#     - Test edge cases and error handling
#
# [ ] 10. PACKAGE CHECK
#     - devtools::test() - All tests pass
#     - devtools::check() - No errors, warnings, or notes
#     - Verify NAMESPACE exports are correct
#     - Check documentation builds correctly
#
# See dev/MODEL_IMPLEMENTATION_GUIDE.md for detailed step-by-step instructions
# See dev/templates/ for additional template files
#
# ==============================================================================
