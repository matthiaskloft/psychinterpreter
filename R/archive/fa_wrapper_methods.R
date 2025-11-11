# ==============================================================================
# S3 METHODS FOR INTERPRETING FACTOR ANALYSIS RESULTS FROM COMMON PACKAGES
# ==============================================================================

#' Interpret Factor Analysis Results Using S3 Methods
#'
#' Generic function to interpret factor analysis results from various R packages
#' (psych, lavaan, mirt). This function extracts loadings and factor correlations
#' from fitted model objects and passes them to \code{\link{interpret_fa}} for
#' LLM-powered interpretation.
#'
#' @param model A factor analysis model object from supported packages
#' @param variable_info A dataframe with at least two columns:
#'   - variable: variable names matching the model variables
#'   - description: labels or descriptions of the variables
#' @param ... Additional arguments passed to \code{\link{interpret_fa}}, such as
#'   llm_provider, llm_model, cutoff, word_limit, etc.
#'
#' @details
#' This generic function provides a unified interface for interpreting factor
#' analysis results from multiple R packages. Package-specific methods automatically
#' extract loadings and factor correlations from fitted model objects.
#'
#' **Supported Model Types:**
#' - \code{psych::fa()} - Exploratory factor analysis (class: psych.fa)
#' - \code{psych::principal()} - Principal components analysis (class: psych.principal)
#' - \code{lavaan::cfa()}, \code{lavaan::sem()}, \code{lavaan::lavaan()} - CFA/SEM (class: lavaan)
#' - \code{lavaan::efa()} with output="efa" - EFA (class: efaList)
#' - \code{mirt::mirt()} - Multidimensional IRT (class: SingleGroupClass)
#'
#' Methods automatically detect and extract:
#' - Factor loadings matrix (variables × factors)
#' - Factor correlations for oblique rotations (when available)
#'
#' @return An \code{fa_interpretation} object (see \code{\link{interpret_fa}} for details)
#'
#' @seealso \code{\link{interpret_fa}} for the underlying interpretation function
#'
#' @importFrom cli cli_abort
#' @importFrom tidyr pivot_wider
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Set up API credentials
#' Sys.setenv(OPENAI_API_KEY = "your-api-key-here")
#'
#' # Example with psych package
#' library(psych)
#' fa_model <- fa(mtcars[,1:4], nfactors = 2, rotate = "oblimin")
#'
#' var_info <- data.frame(
#'   variable = c("mpg", "cyl", "disp", "hp"),
#'   description = c("Miles per gallon", "Number of cylinders",
#'                   "Displacement", "Horsepower")
#' )
#'
#' # Interpret using S3 method
#' result <- interpret(fa_model, variable_info = var_info,
#'                     llm_provider = "openai",
#'                     llm_model = "gpt-4o-mini")
#'
#' # Example with lavaan package
#' library(lavaan)
#' model <- 'visual  =~ x1 + x2 + x3
#'           textual =~ x4 + x5 + x6
#'           speed   =~ x7 + x8 + x9'
#' fit <- cfa(model, data = HolzingerSwineford1939)
#'
#' var_info_lavaan <- data.frame(
#'   variable = paste0("x", 1:9),
#'   description = paste("Indicator", 1:9)
#' )
#'
#' result <- interpret(fit, variable_info = var_info_lavaan,
#'                     llm_provider = "anthropic",
#'                     llm_model = "claude-haiku-4-5-20251001")
#' }
interpret <- function(model, variable_info, ...) {
  UseMethod("interpret")
}


#' @export
interpret.default <- function(model, variable_info, ...) {
  cli::cli_abort(
    c("No interpret method available for object of class {.cls {class(model)}}",
      "i" = "Supported classes: fa (psych), principal (psych), lavaan, efaList, SingleGroupClass",
      "i" = "See {.help interpret} for details on supported packages")
  )
}


# ==============================================================================
# METHODS FOR PSYCH PACKAGE
# ==============================================================================

#' @export
interpret.psych <- function(model, variable_info, ...) {
  if (inherits(model, "fa")) {
    interpret.fa(model, variable_info, ...)
  } else if (inherits(model, "principal")) {
    interpret.principal(model, variable_info, ...)
  } else {
    cli::cli_abort(
      c("Unsupported psych model type",
        "x" = "Class of object: {.cls {class(model)}}")
    )
  }
}


#' Interpret Results from psych::fa()
#'
#' S3 method to interpret exploratory factor analysis results from the psych package.
#' Automatically extracts factor loadings and factor correlations (for oblique rotations).
#'
#' @param model A fitted model from \code{psych::fa()}
#' @param variable_info Dataframe with variable names and descriptions
#' @param ... Additional arguments passed to \code{\link{interpret_fa}}
#'
#' @return An \code{fa_interpretation} object
#'
#' @details
#' This method extracts:
#' - Factor loadings from \code{model$loadings}
#' - Factor correlations from \code{model$Phi} (for oblique rotations)
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(psych)
#' fa_model <- fa(mtcars[,1:4], nfactors = 2, rotate = "oblimin")
#'
#' var_info <- data.frame(
#'   variable = c("mpg", "cyl", "disp", "hp"),
#'   description = c("Miles per gallon", "Cylinders", "Displacement", "Horsepower")
#' )
#'
#' result <- interpret(fa_model, variable_info = var_info,
#'                     llm_provider = "openai", llm_model = "gpt-4o-mini")
#' }
interpret.fa <- function(model, variable_info, ...) {
  # Validate model structure
  if (!inherits(model, "psych") && !inherits(model, "fa")) {
    cli::cli_abort(
      c("Model must be of class {.cls psych.fa}",
        "x" = "You supplied class: {.cls {class(model)}}")
    )
  }

  if (is.null(model$loadings)) {
    cli::cli_abort("Model does not contain loadings component")
  }

  # Extract loadings and convert to data frame
  loadings <- as.data.frame(unclass(model$loadings))

  # Extract factor correlations if oblique rotation was used
  factor_cor_mat <- if (!is.null(model$Phi)) {
    model$Phi
  } else {
    NULL
  }

  # Call interpret_fa with extracted components
  result <- interpret_fa(
    loadings = loadings,
    variable_info = variable_info,
    factor_cor_mat = factor_cor_mat,
    ...
  )

  # Validate return class
  stopifnot(inherits(result, "fa_interpretation"))

  return(result)
}

#' Interpret Results from psych::principal()
#'
#' S3 method to interpret principal components analysis results from the psych package.
#' Automatically extracts component loadings.
#'
#' @param model A fitted model from \code{psych::principal()}
#' @param variable_info Dataframe with variable names and descriptions
#' @param ... Additional arguments passed to \code{\link{interpret_fa}}
#'
#' @return An \code{fa_interpretation} object
#'
#' @details
#' This method extracts component loadings from \code{model$loadings}.
#' Principal components are orthogonal, so no factor correlations are extracted.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(psych)
#' pca_model <- principal(mtcars[,1:4], nfactors = 2, rotate = "varimax")
#'
#' var_info <- data.frame(
#'   variable = c("mpg", "cyl", "disp", "hp"),
#'   description = c("Miles per gallon", "Cylinders", "Displacement", "Horsepower")
#' )
#'
#' result <- interpret(pca_model, variable_info = var_info,
#'                     llm_provider = "openai", llm_model = "gpt-4o-mini")
#' }
interpret.principal <- function(model, variable_info, ...) {
  # Validate model structure
  if (!inherits(model, "psych") &&!inherits(model, "principal")) {
    cli::cli_abort(
      c("Model must be of class {.cls psych.principal}",
        "x" = "You supplied class: {.cls {class(model)}}")
    )
  }

  if (is.null(model$loadings)) {
    cli::cli_abort("Model does not contain loadings component")
  }

  # Extract loadings and convert to data frame
  loadings <- as.data.frame(unclass(model$loadings))

  # PCA produces orthogonal components, no correlations
  # Call interpret_fa with extracted components
  result <- interpret_fa(
    loadings = loadings,
    variable_info = variable_info,
    factor_cor_mat = NULL,
    ...
  )

  # Validate return class
  stopifnot(inherits(result, "fa_interpretation"))

  return(result)
}


# ==============================================================================
# METHODS FOR LAVAAN PACKAGE
# ==============================================================================

#' Interpret Results from lavaan Models (CFA/SEM)
#'
#' S3 method to interpret confirmatory factor analysis or structural equation
#' models from the lavaan package. Automatically extracts standardized factor
#' loadings and factor correlations.
#'
#' @param model A fitted model from \code{lavaan::cfa()}, \code{lavaan::sem()},
#'   or \code{lavaan::lavaan()}
#' @param variable_info Dataframe with variable names and descriptions
#' @param ... Additional arguments passed to \code{\link{interpret_fa}}
#'
#' @return An \code{fa_interpretation} object
#'
#' @details
#' This method extracts:
#' - Standardized factor loadings using \code{lavaan::standardizedSolution()}
#' - Factor correlations from latent variable covariances
#'
#' The method filters for measurement model relationships (op == "=~") and
#' reshapes them into a loadings matrix format.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(lavaan)
#' model_syntax <- '
#'   visual  =~ x1 + x2 + x3
#'   textual =~ x4 + x5 + x6
#'   speed   =~ x7 + x8 + x9
#' '
#' fit <- cfa(model_syntax, data = HolzingerSwineford1939)
#'
#' var_info <- data.frame(
#'   variable = paste0("x", 1:9),
#'   description = paste("Visual/Textual/Speed indicator", 1:9)
#' )
#'
#' result <- interpret(fit, variable_info = var_info,
#'                     llm_provider = "anthropic",
#'                     llm_model = "claude-haiku-4-5-20251001")
#' }
interpret.lavaan <- function(model, variable_info, ...) {
  # Check if lavaan is available
  if (!requireNamespace("lavaan", quietly = TRUE)) {
    cli::cli_abort(
      c("Package {.pkg lavaan} is required for this method",
        "i" = "Install with: install.packages(\"lavaan\")")
    )
  }

  # Validate model
  if (!inherits(model, "lavaan")) {
    cli::cli_abort(
      c("Model must be of class {.cls lavaan}",
        "x" = "You supplied class: {.cls {class(model)}}")
    )
  }

  # Extract standardized solution
  std_solution <- lavaan::standardizedSolution(model)

  # Filter for loading relationships (measurement model)
  loadings_long <- std_solution[std_solution$op == "=~", ]

  if (nrow(loadings_long) == 0) {
    cli::cli_abort(
      c("No factor loadings found in model",
        "i" = "Make sure the model contains measurement model relationships (=~)")
    )
  }

  # Reshape to wide format (variables × factors)
  loadings_wide <- tidyr::pivot_wider(
    loadings_long,
    id_cols = "rhs",
    names_from = "lhs",
    values_from = "est.std",
    values_fill = 0
  )

  # Convert to data frame with proper row names
  loadings <- as.data.frame(loadings_wide[, -1])
  rownames(loadings) <- loadings_wide$rhs

  # Extract factor correlations (latent variable correlations)
  factor_cor_mat <- NULL
  cor_data <- std_solution[std_solution$op == "~~" &
                             std_solution$lhs %in% unique(loadings_long$lhs) &
                             std_solution$rhs %in% unique(loadings_long$lhs) &
                             std_solution$lhs != std_solution$rhs, ]

  if (nrow(cor_data) > 0) {
    # Get unique factor names
    factor_names <- unique(loadings_long$lhs)
    n_factors <- length(factor_names)

    # Create correlation matrix
    factor_cor_mat <- diag(n_factors)
    rownames(factor_cor_mat) <- factor_names
    colnames(factor_cor_mat) <- factor_names

    # Fill in correlations
    for (i in seq_len(nrow(cor_data))) {
      f1 <- cor_data$lhs[i]
      f2 <- cor_data$rhs[i]
      cor_val <- cor_data$est.std[i]
      factor_cor_mat[f1, f2] <- cor_val
      factor_cor_mat[f2, f1] <- cor_val
    }
  }

  # Call interpret_fa
  result <- interpret_fa(
    loadings = loadings,
    variable_info = variable_info,
    factor_cor_mat = factor_cor_mat,
    ...
  )

  # Validate return class
  stopifnot(inherits(result, "fa_interpretation"))

  return(result)
}


#' Interpret Results from lavaan::efa()
#'
#' S3 method to interpret exploratory factor analysis results from lavaan's
#' efa() function when output="efa" is specified.
#'
#' @param model A fitted model from \code{lavaan::efa()} with output="efa"
#' @param variable_info Dataframe with variable names and descriptions
#' @param ... Additional arguments passed to \code{\link{interpret_fa}}
#'
#' @return An \code{fa_interpretation} object
#'
#' @details
#' This method extracts factor loadings using the \code{loadings()} function
#' from the stats package, which works on efaList objects.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(lavaan)
#' fit <- efa(data = HolzingerSwineford1939[, 7:15],
#'            nfactors = 3,
#'            rotation = "geomin")
#'
#' var_info <- data.frame(
#'   variable = paste0("x", 1:9),
#'   description = paste("Indicator", 1:9)
#' )
#'
#' result <- interpret(fit, variable_info = var_info,
#'                     llm_provider = "openai", llm_model = "gpt-4o-mini")
#' }
interpret.efaList <- function(model, variable_info, ...) {
  # Check if lavaan is available
  if (!requireNamespace("lavaan", quietly = TRUE)) {
    cli::cli_abort(
      c("Package {.pkg lavaan} is required for this method",
        "i" = "Install with: install.packages(\"lavaan\")")
    )
  }

  # Validate model
  if (!inherits(model, "efaList")) {
    cli::cli_abort(
      c("Model must be of class {.cls efaList}",
        "x" = "You supplied class: {.cls {class(model)}}")
    )
  }

  # Extract loadings using stats::loadings() which works on efaList
  loadings_obj <- loadings(model)

  # Convert to data frame
  loadings <- as.data.frame(unclass(loadings_obj))

  # Try to extract factor correlations from efaList structure
  factor_cor_mat <- NULL
  if (!is.null(model$rotation) && !is.null(model$rotation$phi)) {
    factor_cor_mat <- model$rotation$phi
  }

  # Call interpret_fa
  result <- interpret_fa(
    loadings = loadings,
    variable_info = variable_info,
    factor_cor_mat = factor_cor_mat,
    ...
  )

  # Validate return class
  stopifnot(inherits(result, "fa_interpretation"))

  return(result)
}


# ==============================================================================
# METHODS FOR MIRT PACKAGE
# ==============================================================================

#' Interpret Results from mirt::mirt()
#'
#' S3 method to interpret multidimensional item response theory models from
#' the mirt package. Automatically extracts standardized factor loadings and
#' factor correlations.
#'
#' @param model A fitted model from \code{mirt::mirt()}
#' @param variable_info Dataframe with variable (item) names and descriptions
#' @param rotate Character. Rotation method to apply when extracting loadings.
#'   Options include "oblimin", "varimax", "promax", etc. Default is "oblimin"
#' @param ... Additional arguments passed to \code{\link{interpret_fa}}
#'
#' @return An \code{fa_interpretation} object
#'
#' @details
#' This method extracts standardized factor loadings using \code{summary(model)}
#' with the specified rotation. For multidimensional models, it also attempts
#' to extract factor correlations.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(mirt)
#' # Fit a 2-dimensional model
#' data <- expand.table(LSAT7)
#' model <- mirt(data, 2, itemtype = "2PL")
#'
#' var_info <- data.frame(
#'   variable = colnames(data),
#'   description = paste("LSAT item", 1:5)
#' )
#'
#' result <- interpret(model, variable_info = var_info,
#'                     llm_provider = "openai", llm_model = "gpt-4o-mini")
#' }
interpret.SingleGroupClass <- function(model, variable_info, rotate = "oblimin", ...) {
  # Check if mirt is available
  if (!requireNamespace("mirt", quietly = TRUE)) {
    cli::cli_abort(
      c("Package {.pkg mirt} is required for this method",
        "i" = "Install with: install.packages(\"mirt\")")
    )
  }

  # Validate model
  if (!inherits(model, "SingleGroupClass")) {
    cli::cli_abort(
      c("Model must be of class {.cls SingleGroupClass}",
        "x" = "You supplied class: {.cls {class(model)}}")
    )
  }

  # Extract standardized loadings using summary with rotation
  sum_obj <- mirt::summary(model, rotate = rotate, verbose = FALSE)

  # Extract loadings from summary object
  # The structure varies, but typically loadings are in $rotF or similar
  if (!is.null(sum_obj$rotF)) {
    loadings <- as.data.frame(sum_obj$rotF)
  } else if (!is.null(sum_obj$fcor)) {
    # Try alternative extraction method using coef
    coef_list <- mirt::coef(model, simplify = TRUE)
    if (!is.null(coef_list$items)) {
      # Extract a1, a2, etc. columns (discrimination parameters = loadings)
      items <- coef_list$items
      loading_cols <- grep("^a[0-9]+$", colnames(items), value = TRUE)
      if (length(loading_cols) > 0) {
        loadings <- as.data.frame(items[, loading_cols, drop = FALSE])
        # Rename columns to F1, F2, etc.
        colnames(loadings) <- paste0("F", seq_len(ncol(loadings)))
      } else {
        cli::cli_abort("Could not extract loadings from mirt model")
      }
    } else {
      cli::cli_abort("Could not extract loadings from mirt model")
    }
  } else {
    cli::cli_abort("Could not extract loadings from mirt model summary")
  }

  # Extract factor correlations if available
  factor_cor_mat <- NULL
  if (!is.null(sum_obj$fcor)) {
    factor_cor_mat <- sum_obj$fcor
  } else if (!is.null(model@Phi)) {
    factor_cor_mat <- model@Phi
  }

  # Call interpret_fa
  result <- interpret_fa(
    loadings = loadings,
    variable_info = variable_info,
    factor_cor_mat = factor_cor_mat,
    ...
  )

  # Validate return class
  stopifnot(inherits(result, "fa_interpretation"))

  return(result)
}
