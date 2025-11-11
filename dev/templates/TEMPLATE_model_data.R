# Template for {MODEL}_model_data.R
# Replace all instances of {MODEL}, {model}, {CLASS}, {PARAM1}, etc. with your values
#
# Example replacements for Gaussian Mixture:
#   {MODEL} -> Gaussian Mixture
#   {model} -> gm
#   {CLASS} -> Mclust
#   {PARAM1} -> covariance_type
#   {PARAM2} -> n_clusters

#' Build model data for {MODEL} interpretation
#'
#' Extracts data from {CLASS} objects (from {PACKAGE} package) and standardizes
#' it for LLM interpretation.
#'
#' @param fit_results Fitted {MODEL} object from {PACKAGE}::{CLASS}()
#' @param variable_info Data frame with columns 'variable' and 'description'
#' @param model_type Model type identifier (should be "{model}")
#' @param {model}_args Optional configuration object from {model}_args()
#' @param ... Additional arguments (for parameter extraction)
#'
#' @return List with standardized {MODEL} data structure containing:
#'   \item{DATA_FIELD1}{Description of first data field}
#'   \item{DATA_FIELD2}{Description of second data field}
#'   \item{n_components}{Number of {COMPONENTS} (e.g., clusters, factors, items)}
#'   \item{n_variables}{Number of variables}
#'   \item{model_type}{Model type identifier ("{model}")}
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
#' # Extract model data
#' model_data <- build_model_data(fit, var_info, model_type = "{model}")
#' }
build_model_data.{CLASS} <- function(fit_results,
                                      variable_info,
                                      model_type = "{model}",
                                      {model}_args = NULL,
                                      ...) {

  # Call internal helper to avoid S3 method naming conflicts
  build_{model}_model_data_internal(
    fit_results = fit_results,
    variable_info = variable_info,
    model_type = model_type,
    {model}_args = {model}_args,
    ...
  )
}


#' Internal helper to build {MODEL} model data
#'
#' @keywords internal
#' @noRd
build_{model}_model_data_internal <- function(fit_results,
                                               variable_info,
                                               model_type = "{model}",
                                               {model}_args = NULL,
                                               ...) {

  # ============================================================================
  # STEP 1: Extract model-specific parameters
  # ============================================================================

  # Pattern from fa_model_data.R:26-48
  dots <- list(...)

  # Build config from multiple sources (precedence: {model}_args > ... > defaults)
  config <- build_{model}_args(
    {model}_args = {model}_args,
    dots = dots
  )

  # Extract parameters from config
  {PARAM1} <- config${PARAM1}  # Example: covariance_type for GM
  {PARAM2} <- config${PARAM2}  # Example: n_clusters for GM

  # TODO: Add additional parameter extractions as needed


  # ============================================================================
  # STEP 2: Validate parameters
  # ============================================================================

  # Pattern from fa_model_data.R:50-72

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

  # Pattern from fa_model_data.R:255-265

  structure(
    list(
      # ---- Core model data (MODEL-SPECIFIC) ----
      data_field1 = data_field1,  # TODO: Replace with actual field name (e.g., means, loadings, item_params)
      data_field2 = data_field2,  # TODO: Replace with actual field name (e.g., covariances, Phi, ability_estimates)
      processed_data = processed_data,  # Optional: any derived structures

      # ---- Metadata ----
      n_components = n_components,  # Number of clusters/factors/items
      n_variables = n_variables,
      model_type = model_type,

      # ---- Model-specific parameters (used later in prompts) ----
      {PARAM1} = {PARAM1},
      {PARAM2} = {PARAM2}
      # TODO: Add additional parameters as needed
    ),
    class = c("{model}_model_data", "model_data", "list")
  )
}


# ==============================================================================
# Additional Class Methods (if needed)
# ==============================================================================

# If your model type has multiple fitted object classes, create additional methods

# Example: If there's another class that produces {MODEL} results
# #' @export
# build_model_data.{OTHER_CLASS} <- function(fit_results,
#                                            variable_info,
#                                            model_type = "{model}",
#                                            {model}_args = NULL,
#                                            ...) {
#
#   # Convert {OTHER_CLASS} object to standard format
#   # TODO: Extract data from {OTHER_CLASS} object
#   converted_data <- ...
#
#   # Call internal helper with converted data
#   build_{model}_model_data_internal(
#     fit_results = converted_data,
#     variable_info = variable_info,
#     model_type = model_type,
#     {model}_args = {model}_args,
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
