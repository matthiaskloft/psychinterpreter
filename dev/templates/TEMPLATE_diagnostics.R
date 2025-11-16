# Template for {MODEL}_diagnostics.R
# Replace all instances of {MODEL}, {model}, {COMPONENT}, etc. with your values

#' Create fit summary for {MODEL} interpretation
#'
#' Generates fit summary and performs model-specific diagnostic checks, generating
#' warnings for potential issues in the {MODEL} results. Checks for common problems
#' like {ISSUE1}, {ISSUE2}, etc.
#'
#' This is an S3 method dispatched from core_interpret.R:459-466 (create_fit_summary generic).
#' Uses a modular helper function approach: each diagnostic check is implemented as
#' a separate detect_*() helper that returns a list with issue details (see examples
#' in fa_diagnostics.R for patterns).
#'
#' @param analysis_type Analysis type object with class "{model}" (dispatch key via S3)
#' @param analysis_data Analysis data from build_analysis_data.{CLASS}()
#' @param ... Additional arguments (ignored)
#'
#' @return List with fit summary and diagnostic information:
#'   \item{has_warnings}{Logical - TRUE if any warnings generated}
#'   \item{warnings}{Character vector of warning messages}
#'   \item{info}{List with additional diagnostic details}
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Create fit summary
#' analysis_data <- build_analysis_data(fit, var_info, analysis_type = "{model}")
#' fit_summary <- create_fit_summary.{model}("{model}", analysis_data)
#'
#' # Check for warnings
#' if (fit_summary$has_warnings) {
#'   cat(paste(fit_summary$warnings, collapse = "\n"))
#' }
#' }
create_fit_summary.{model} <- function(analysis_type, analysis_data, ...) {

  # Pattern from fa_diagnostics.R (modular diagnostic approach):
  # - Lines 1-35: Main exported diagnostic helper (find_cross_loadings)
  # - Helper functions return list(has_issue = ..., affected_components = ..., details = ...)
  # - Format warnings with sprintf() for clean, aligned output
  # - Store diagnostic details in diagnostics$info for potential post-processing

  # ============================================================================
  # Initialize diagnostics
  # ============================================================================

  diagnostics <- list(
    has_warnings = FALSE,
    warnings = character(0),
    info = list()
  )


  # ============================================================================
  # DIAGNOSTIC CHECK 1: {ISSUE1_NAME}
  # ============================================================================

  # Example for GM: Check for overlapping clusters (low separation)
  # Example for IRT: Check for poor item fit
  # Example for FA: Check for cross-loadings
  # Example for CDM: Check for under-identified attributes

  # TODO: Replace with your model-specific diagnostic check

  # Example pattern:
  # issue1_detected <- detect_{issue1}_{model}(model_data)
  #
  # if (issue1_detected$has_issue) {
  #   diagnostics$has_warnings <- TRUE
  #
  #   warning_msg <- format_{issue1}_warning(issue1_detected)
  #   diagnostics$warnings <- c(diagnostics$warnings, warning_msg)
  #
  #   # Store details for potential further analysis
  #   diagnostics$info${issue1}_details <- issue1_detected
  # }


  # ============================================================================
  # DIAGNOSTIC CHECK 2: {ISSUE2_NAME}
  # ============================================================================

  # TODO: Add second diagnostic check

  # Example for GM: Check for very small clusters
  # if (any(cluster_sizes < 0.05)) {
  #   diagnostics$has_warnings <- TRUE
  #
  #   small_clusters <- which(cluster_sizes < 0.05)
  #   warning_msg <- paste0(
  #     "Warning: Very small clusters detected:\n",
  #     paste(paste0("  - Cluster_", small_clusters, ": ",
  #                  sprintf("%.1f%%", cluster_sizes[small_clusters] * 100)),
  #           collapse = "\n")
  #   )
  #
  #   diagnostics$warnings <- c(diagnostics$warnings, warning_msg)
  #   diagnostics$info$small_clusters <- small_clusters
  # }


  # ============================================================================
  # DIAGNOSTIC CHECK 3: {ISSUE3_NAME}
  # ============================================================================

  # TODO: Add third diagnostic check (if applicable)

  # Example for IRT: Check for items with discrimination < 0.5
  # Example for FA: Check for variables with no significant loadings
  # Example for GM: Check for non-positive definite covariance matrices


  # ============================================================================
  # DIAGNOSTIC CHECK 4: Interpretation quality (optional)
  # ============================================================================

  # Check if LLM generated meaningful interpretations

  # Example: Check for "Undefined" or generic interpretations
  # undefined_count <- sum(grepl("Undefined|Unable to", interpretation, ignore.case = TRUE))
  #
  # if (undefined_count > 0) {
  #   diagnostics$has_warnings <- TRUE
  #
  #   warning_msg <- paste0(
  #     "Warning: ", undefined_count, " {COMPONENT_LOWER}(s) ",
  #     "could not be interpreted meaningfully.\n",
  #     "Consider:\n",
  #     "  - Reviewing the raw data for these {COMPONENT_LOWER}s\n",
  #     "  - Providing additional context via additional_info parameter\n",
  #     "  - Adjusting model parameters (e.g., number of {COMPONENT_LOWER}s)"
  #   )
  #
  #   diagnostics$warnings <- c(diagnostics$warnings, warning_msg)
  #   diagnostics$info$undefined_count <- undefined_count
  # }


  # ============================================================================
  # Return diagnostics
  # ============================================================================

  diagnostics
}


# ==============================================================================
# Helper Functions for Specific Diagnostic Checks
# ==============================================================================

# Add helper functions for each diagnostic check
# Keep functions focused and testable

# Example helper 1: Detect specific issue
# #' Detect {ISSUE1} in {MODEL} results
# #'
# #' @param analysis_data Analysis data from build_analysis_data.{CLASS}()
# #'
# #' @return List with:
# #'   \item{has_issue}{Logical - TRUE if issue detected}
# #'   \item{affected_components}{Vector of affected {COMPONENT_LOWER} indices}
# #'   \item{details}{Additional details for reporting}
# #'
# #' @keywords internal
# #' @noRd
# detect_{issue1}_{model} <- function(model_data) {
#
#   # Extract relevant data
#   data <- model_data$data_field1
#   n_components <- model_data$n_components
#
#   # Perform check
#   # TODO: Implement your diagnostic logic
#
#   affected <- c()  # Indices of affected components
#
#   # Example logic:
#   # for (i in 1:n_components) {
#   #   if (some_condition) {
#   #     affected <- c(affected, i)
#   #   }
#   # }
#
#   list(
#     has_issue = length(affected) > 0,
#     affected_components = affected,
#     details = list()  # Add relevant details
#   )
# }


# Example helper 2: Format warning message
# #' Format {ISSUE1} warning message
# #'
# #' @param issue_data List from detect_{issue1}_{model}()
# #'
# #' @return Character string with formatted warning
# #'
# #' @keywords internal
# #' @noRd
# format_{issue1}_warning <- function(issue_data) {
#
#   affected <- issue_data$affected_components
#   n_affected <- length(affected)
#
#   if (n_affected == 0) {
#     return(NULL)
#   }
#
#   # Format warning message
#   msg <- paste0(
#     "Warning: {ISSUE1} detected in ", n_affected, " {COMPONENT_LOWER}(s):\n"
#   )
#
#   # Add details for each affected component
#   for (idx in affected) {
#     msg <- paste0(
#       msg,
#       "  - {COMPONENT}_", idx, ": ",
#       "{description of issue for this component}\n"
#     )
#   }
#
#   # Add recommendations
#   msg <- paste0(
#     msg,
#     "\nRecommendations:\n",
#     "  - {Recommendation 1}\n",
#     "  - {Recommendation 2}\n"
#   )
#
#   msg
# }


# ==============================================================================
# Exported Helper Functions (if applicable)
# ==============================================================================

# If you have diagnostic helpers that users might want to call directly,
# export them with proper documentation

# Example from FA: find_cross_loadings() and find_no_loadings() are exported
# so users can identify problematic variables before interpretation

# #' Find {PROBLEMATIC_PATTERN} in {MODEL} results
# #'
# #' Public helper to identify {COMPONENTS} with {PROBLEMATIC_PATTERN}.
# #' Useful for pre-interpretation diagnostics.
# #'
# #' @param analysis_data Analysis data from build_analysis_data.{CLASS}(), OR
# #' @param data_field1 {DATA_FIELD1 description} (matrix or data frame)
# #' @param threshold Threshold for {CRITERION} (default: {DEFAULT_VALUE})
# #'
# #' @return Data frame with:
# #'   \item{{component_id}}{{COMPONENT} identifier}
# #'   \item{issue_measure}{Measure of issue severity}
# #'   \item{description}{Human-readable description}
# #'
# #' @export
# #'
# #' @examples
# #' \dontrun{
# #' analysis_data <- build_analysis_data(fit, var_info, analysis_type = "{model}")
# #' issues <- find_{problematic_pattern}(model_data)
# #' print(issues)
# #' }
# find_{problematic_pattern} <- function(model_data = NULL,
#                                        data_field1 = NULL,
#                                        threshold = {DEFAULT_VALUE}) {
#
#   # Extract data from model_data or use provided data_field1
#   if (!is.null(model_data)) {
#     data <- model_data$data_field1
#   } else if (!is.null(data_field1)) {
#     data <- data_field1
#   } else {
#     cli::cli_abort("Must provide either model_data or data_field1")
#   }
#
#   # Perform diagnostic check
#   # TODO: Implement check
#
#   # Return results as data frame
#   # TODO: Format results
# }
