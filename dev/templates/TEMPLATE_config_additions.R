# Template for additions to R/config.R
# Add these functions to the existing config.R file
# Replace all instances of {MODEL}, {model}, {PARAM1}, etc. with your values

# ==============================================================================
# {MODEL} Configuration Object
# ==============================================================================

#' Create {MODEL} configuration object
#'
#' Creates a configuration object for {MODEL}-specific parameters used during
#' interpretation. This allows grouping related parameters together for cleaner
#' function calls.
#'
#' @param {PARAM1} {Description of parameter 1}. Options: {list options}. Default: {default value}
#' @param {PARAM2} {Description of parameter 2}. Default: {default value}
#' @param ... Additional parameters (reserved for future use)
#'
#' @return {MODEL} configuration object (list with class "{model}_args")
#'
#' @export
#'
#' @examples
#' # Create {MODEL} configuration
#' config <- {model}_args(
#'   {PARAM1} = "{option1}",
#'   {PARAM2} = 5
#' )
#'
#' # Use in interpret() call
#' interpretation <- interpret(
#'   fit_results = fit,
#'   variable_info = var_info,
#'   {model}_args = config,
#'   provider = "ollama",
#'   model = "gpt-oss:20b-cloud"
#' )
{model}_args <- function({PARAM1} = NULL,
                          {PARAM2} = NULL,
                          ...) {

  # Pattern from config.R:41-72 (fa_args)

  # ============================================================================
  # Validate {PARAM1}
  # ============================================================================

  if (!is.null({PARAM1})) {
    valid_options <- c("option1", "option2", "option3")  # TODO: Define valid options

    if (!{PARAM1} %in% valid_options) {
      cli::cli_abort(c(
        "x" = "Invalid {PARAM1}: {{PARAM1}}",
        "i" = "Must be one of: {paste(valid_options, collapse = ', ')}"
      ))
    }
  }


  # ============================================================================
  # Validate {PARAM2}
  # ============================================================================

  if (!is.null({PARAM2})) {
    # Example numeric validation
    if (!is.numeric({PARAM2}) || {PARAM2} < 1 || {PARAM2} > 100) {
      cli::cli_abort(c(
        "x" = "{PARAM2} must be a number between 1 and 100",
        "i" = "Got: {{PARAM2}}"
      ))
    }
  }


  # ============================================================================
  # TODO: Add validation for additional parameters
  # ============================================================================


  # ============================================================================
  # Create configuration object
  # ============================================================================

  config <- list(
    {PARAM1} = {PARAM1},
    {PARAM2} = {PARAM2}
    # TODO: Add additional parameters
  )

  # Add class attributes
  structure(
    config,
    class = c("{model}_args", "model_config", "list")
  )
}


#' Build {MODEL} arguments from multiple sources
#'
#' Internal helper that merges {MODEL} parameters from multiple sources with
#' proper precedence: {model}_args object > dots (...) > defaults.
#'
#' @param {model}_args Configuration object from {model}_args()
#' @param dots List of additional arguments (from ...)
#'
#' @return Merged {MODEL} configuration object
#' @keywords internal
#' @noRd
build_{model}_args <- function({model}_args = NULL, dots = list()) {

  # Pattern from config.R:103-130 (build_fa_args)

  # ============================================================================
  # Define default values
  # ============================================================================

  defaults <- list(
    {PARAM1} = "default_option",  # TODO: Set appropriate default
    {PARAM2} = 10                  # TODO: Set appropriate default
    # TODO: Add additional defaults
  )


  # ============================================================================
  # Extract from {model}_args if provided
  # ============================================================================

  if (!is.null({model}_args) && inherits({model}_args, "{model}_args")) {
    args_list <- as.list({model}_args)
  } else {
    args_list <- list()
  }


  # ============================================================================
  # Extract from dots
  # ============================================================================

  # Define parameter names to extract from dots
  param_names <- c(
    "{PARAM1}",
    "{PARAM2}"
    # TODO: Add additional parameter names
  )

  # Extract matching parameters from dots
  dots_params <- dots[names(dots) %in% param_names]


  # ============================================================================
  # Merge with precedence: {model}_args > dots > defaults
  # ============================================================================

  # Start with defaults
  merged <- defaults

  # Override with dots parameters
  merged[names(dots_params)] <- dots_params

  # Override with {model}_args parameters (highest precedence)
  merged[names(args_list)] <- args_list


  # ============================================================================
  # Create final configuration object
  # ============================================================================

  # Use do.call to pass merged list to constructor
  # This ensures validation is applied
  do.call({model}_args, merged)
}


# ==============================================================================
# INTEGRATION NOTE
# ==============================================================================
#
# After adding these functions to R/config.R, you also need to:
#
# 1. Update R/constants.R:
#    - Uncomment "{model}" in VALID_MODEL_TYPES constant
#    - This enables validation across the package
#
# 2. Update R/utils_interpret.R:
#    - Uncomment {model}_args parameter to handle_raw_data_interpret()
#    - Uncomment {model} case in switch statement
#
# 3. Update R/interpret_method_dispatch.R:
#    - Uncomment {model}_args parameter in interpret() function signature
#    - Uncomment {model}_args in interpret_core() call
#
# 4. Update R/core_interpret.R:
#    - Uncomment {model}_args parameter in interpret_core() signature
#    - Uncomment {model}_args in build_model_data() call
#
# 5. Run devtools::document() to update documentation
#
# IMPORTANT: Only include ANALYSIS PARAMETERS in {model}_args.
# Do NOT include model DATA fields (e.g., factor_cor_mat for FA).
# Model data should be extracted from fit_results in build_model_data.{CLASS}().
#
# ==============================================================================


# ==============================================================================
# TESTING RECOMMENDATIONS
# ==============================================================================
#
# Create tests/testthat/test-{model}_config.R with:
#
# test_that("{model}_args validates {PARAM1}", {
#   expect_error(
#     {model}_args({PARAM1} = "invalid_option"),
#     "Invalid {PARAM1}"
#   )
#   expect_no_error({model}_args({PARAM1} = "option1"))
# })
#
# test_that("build_{model}_args merges sources correctly", {
#   # Test precedence: {model}_args > dots > defaults
#   config <- {model}_args({PARAM1} = "option1")
#   dots <- list({PARAM1} = "option2", {PARAM2} = 5)
#
#   result <- build_{model}_args(config, dots)
#
#   # {model}_args should win
#   expect_equal(result${PARAM1}, "option1")
#   # {PARAM2} from dots should be used
#   expect_equal(result${PARAM2}, 5)
# })
#
# ==============================================================================
