# Common Pitfalls When Adding New Model Types

**Last Updated**: 2025-11-12
**Purpose**: Help developers avoid common mistakes when implementing new model types (GM, IRT, CDM)

---

## 1. Forgetting to Update Constants

### Issue
New model type not recognized by validation functions

### Location
`R/core_constants.R:22`

### Solution
```r
# Update this constant when adding a new model type
IMPLEMENTED_MODEL_TYPES <- c("fa", "gm")  # Add "gm" here
```

**Remember**: Just adding to `VALID_MODEL_TYPES` is not enough - must also add to `IMPLEMENTED_MODEL_TYPES`

---

## 2. Missing S3 Method Registration

### Issue
Package check fails with "S3 methods not registered" or methods not dispatched correctly

### Location
Each model-specific file (e.g., `R/gm_model_data.R`)

### Solution
Ensure all 8 required methods have proper roxygen tags:
```r
#' @export
build_model_data.Mclust <- function(...) {
  # implementation
}
```

**Verify**: Run `devtools::check()` and check NAMESPACE for all your methods

---

## 3. Incorrect Parameter Extraction

### Issue
Parameters not correctly extracted from various input formats

### Location
`build_model_data.{class}()` methods

### Solution
Each model type has unique parameter structures. Example for GM:

```r
# For mclust objects:
means <- fit_results$parameters$mean
covariances <- fit_results$parameters$variance$sigma

# For custom lists:
means <- fit_results$means
covariances <- fit_results$covariances
```

**Best Practice**: Study existing FA implementation in `R/fa_model_data.R:75-150` for patterns

---

## 4. Token Efficiency Oversight

### Issue
Sending too much data to LLM, wasting tokens and money

### Location
`build_main_prompt.{model}()` methods

### Solution
Consider what's essential for interpretation:

**Good** (GM example):
```r
prompt <- sprintf(
  "Cluster %d: Mean = %.2f, N = %d",
  i, cluster_mean, n_observations
)
```

**Bad** (Too verbose):
```r
# Don't send full covariance matrices unless necessary
prompt <- paste0(prompt, "\nFull covariance matrix:\n",
                 paste(capture.output(print(cov_matrix)), collapse = "\n"))
```

---

## 5. Hardcoding Model Type

### Issue
Code not flexible for future extensions

### Location
Various functions

### Solution
```r
# ❌ BAD
if (model_type == "fa" || model_type == "gm" || model_type == "irt") {
  # ...
}

# ✅ GOOD
if (model_type %in% IMPLEMENTED_MODEL_TYPES) {
  # ...
}
```

---

## 6. Forgetting Variable Info Validation

### Issue
Function fails with cryptic error when variable_info is malformed

### Location
`build_{model}_model_data_internal()` functions

### Solution
```r
# Always validate variable_info structure
if (!is.data.frame(variable_info)) {
  cli::cli_abort("{.arg variable_info} must be a data frame")
}

if (!all(c("variable", "description") %in% names(variable_info))) {
  cli::cli_abort("{.arg variable_info} must have 'variable' and 'description' columns")
}
```

---

## 7. Inconsistent Error Messages

### Issue
Error messages don't match package style

### Solution
Always use `cli` package for errors:

```r
# ✅ GOOD
cli::cli_abort(c(
  "x" = "Invalid cluster count: {n_clusters}",
  "i" = "Must be between 2 and 20",
  "i" = "Received: {n_clusters}"
))

# ❌ BAD
stop("Invalid n_clusters")
```

---

## 8. Missing Test Coverage

### Issue
New methods not tested, leading to bugs in production

### Location
`tests/testthat/test-{model}_*.R`

### Solution
Create comprehensive tests:
- Data extraction from fitted objects
- Validation logic
- Edge cases (NULL values, missing columns, etc.)
- LLM interpretation (minimal, with `skip_on_ci()`)

**Template**: Copy `tests/testthat/test-interpret_fa.R` structure

---

## 9. Ignoring Documentation

### Issue
Functions work but users don't know how to use them

### Solution
Add roxygen documentation for ALL exported functions:

```r
#' Build Model Data for Gaussian Mixture Models
#'
#' Extracts cluster parameters from mclust objects
#'
#' @param fit_results Mclust object from mclust::Mclust()
#' @param variable_info Data frame with variable descriptions
#' @param ... Additional arguments
#'
#' @return List with standardized model data
#' @export
#'
#' @examples
#' \dontrun{
#' library(mclust)
#' fit <- Mclust(data, G = 3)
#' model_data <- build_model_data(fit, var_info)
#' }
build_model_data.Mclust <- function(fit_results, variable_info, ...) {
  # implementation
}
```

---

## 10. Not Handling Multiple Package Classes

### Issue
Model type works for one package but not others (e.g., mclust vs. flexmix for GM)

### Location
Multiple `build_model_data.{class}()` methods needed

### Solution
Create separate methods for each package class:

```r
# For mclust package
#' @export
build_model_data.Mclust <- function(...) {
  build_gm_model_data_internal(...)
}

# For flexmix package
#' @export
build_model_data.flexmix <- function(...) {
  build_gm_model_data_internal(...)
}

# Shared internal logic
build_gm_model_data_internal <- function(fit_results, ...) {
  # Extract data regardless of source package
}
```

---

## Checklist Before Submitting

- [ ] All 8 required S3 methods implemented
- [ ] `IMPLEMENTED_MODEL_TYPES` updated
- [ ] All methods have roxygen documentation
- [ ] All methods have `#' @export` tags
- [ ] Tests created for all new methods
- [ ] LLM tests have `skip_on_ci()`
- [ ] Error messages use `cli` package
- [ ] Token efficiency considered in prompts
- [ ] Variable validation implemented
- [ ] Multiple package classes handled (if applicable)
- [ ] `devtools::check()` passes with 0 errors, 0 warnings
- [ ] Templates updated in `dev/templates/`

---

**See Also**:
- `dev/MODEL_IMPLEMENTATION_GUIDE.md` - Complete implementation guide
- `dev/templates/` - Code templates for all required files
- `dev/TESTING_GUIDELINES.md` - Testing best practices
