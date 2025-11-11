#' Find Cross-Loading Variables
#'
#' Identifies variables that load on multiple factors above the cutoff threshold. 
#' Used for identifying potential issues with factor structure and discriminant validity.
#' Cross-loading variables may indicate that factors are not well-separated or that
#' the variable measures multiple constructs.
#'
#' @param loadings_df A dataframe with loadings including a 'variable' column
#' @param factor_cols Character vector of factor column names. If NULL, automatically
#'   detects all columns except 'variable' (default = NULL)
#' @param cutoff Numeric. Minimum absolute loading value to consider (default = 0.3)
#'
#' @return A dataframe with columns:
#'   \item{variable}{Variable name}
#'   \item{factors}{Formatted string showing all factors and loadings above cutoff}
#'
#' @examples
#' \dontrun{
#' # Assuming you have factor loadings
#' loadings_df <- data.frame(
#'   variable = c("var1", "var2", "var3"),
#'   Factor1 = c(0.8, 0.4, 0.1),
#'   Factor2 = c(0.2, 0.7, 0.9)
#' )
#'
#' # Find variables loading on multiple factors (auto-detect factor columns)
#' cross_vars <- find_cross_loadings(loadings_df, cutoff = 0.3)
#'
#' # Or specify factor columns explicitly
#' cross_vars <- find_cross_loadings(loadings_df, c("Factor1", "Factor2"), cutoff = 0.3)
#' print(cross_vars)
#' }
#'
#' @export
find_cross_loadings <- function(loadings_df, factor_cols = NULL, cutoff = 0.3) {
  # Auto-detect factor columns if not provided
  if (is.null(factor_cols)) {
    factor_cols <- setdiff(names(loadings_df), "variable")
  }

  # Handle empty data frames
  if (nrow(loadings_df) == 0 || length(factor_cols) == 0) {
    return(data.frame(variable = character(), factors = character()))
  }
  # Pre-allocate list for results for efficiency
  cross_list <- vector("list", nrow(loadings_df))
  
  for (i in 1:nrow(loadings_df)) {
    high_loadings <- c()
    
    # Check each factor for significant loadings
    for (col in factor_cols) {
      if (abs(loadings_df[[col]][i]) >= cutoff) {
        high_loadings <- c(high_loadings, paste0(col, " (", format_loading(loadings_df[[col]][i]), ")"))
      }
    }
    
    # Only include variables with multiple significant loadings
    if (length(high_loadings) > 1) {
      cross_list[[i]] <- data.frame(
        variable = loadings_df$variable[i],
        factors = paste(high_loadings, collapse = ", ")
      )
    }
  }
  
  # Remove NULL entries and combine results
  cross_list <- Filter(Negate(is.null), cross_list)
  
  if (length(cross_list) == 0) {
    return(data.frame(variable = character(), factors = character()))
  }
  
  cross_loadings <- do.call(rbind, cross_list)
  rownames(cross_loadings) <- NULL
  
  return(cross_loadings)
}

#' Find Variables with No Loadings Above Cutoff
#'
#' Identifies variables that do not have any factor loading above the cutoff threshold. 
#' These variables may indicate issues with the factor structure, suggest additional 
#' factors may be needed, or indicate variables that don't fit well in the current 
#' factor solution.
#'
#' @param loadings_df A dataframe with loadings including a 'variable' column
#' @param factor_cols Character vector of factor column names. If NULL, automatically
#'   detects all columns except 'variable' (default = NULL)
#' @param cutoff Numeric. Minimum absolute loading value to consider (default = 0.3)
#'
#' @return A dataframe with columns:
#'   \item{variable}{Variable name}
#'   \item{highest_loading}{Formatted string showing the highest loading (even if below cutoff)}
#'
#' @examples
#' \dontrun{
#' # Assuming you have factor loadings
#' loadings_df <- data.frame(
#'   variable = c("var1", "var2", "var3"),
#'   Factor1 = c(0.8, 0.2, 0.1),
#'   Factor2 = c(0.1, 0.15, 0.05)
#' )
#'
#' # Find variables with no significant loadings (auto-detect factor columns)
#' weak_vars <- find_no_loadings(loadings_df, cutoff = 0.3)
#'
#' # Or specify factor columns explicitly
#' weak_vars <- find_no_loadings(loadings_df, c("Factor1", "Factor2"), cutoff = 0.3)
#' print(weak_vars)
#' }
#'
#' @export
find_no_loadings <- function(loadings_df, factor_cols = NULL, cutoff = 0.3) {
  # Auto-detect factor columns if not provided
  if (is.null(factor_cols)) {
    factor_cols <- setdiff(names(loadings_df), "variable")
  }

  # Handle empty data frames
  if (nrow(loadings_df) == 0 || length(factor_cols) == 0) {
    return(data.frame(variable = character(), highest_loading = character()))
  }
  # Pre-allocate list for results for efficiency
  no_load_list <- vector("list", nrow(loadings_df))
  
  for (i in 1:nrow(loadings_df)) {
    # Track the highest loading for each variable
    has_significant_loading <- FALSE
    max_loading <- -Inf
    max_factor <- ""
    
    for (col in factor_cols) {
      loading_val <- abs(loadings_df[[col]][i])
      if (loading_val >= cutoff) {
        has_significant_loading <- TRUE
        break
      }
      # Track the highest loading even if below cutoff
      if (loading_val > max_loading) {
        max_loading <- loading_val
        max_factor <- col
      }
    }
    
    # Add variables with no significant loadings to the list
    if (!has_significant_loading) {
      no_load_list[[i]] <- data.frame(
        variable = loadings_df$variable[i],
        highest_loading = paste0(max_factor, " = ", format_loading(max_loading))
      )
    }
  }
  
  # Remove NULL entries and combine results
  no_load_list <- Filter(Negate(is.null), no_load_list)
  
  if (length(no_load_list) == 0) {
    return(data.frame(variable = character(), highest_loading = character()))
  }
  
  no_loadings <- do.call(rbind, no_load_list)
  rownames(no_loadings) <- NULL

  return(no_loadings)
}

#' Create Diagnostics for Factor Analysis
#'
#' S3 method that implements diagnostic analysis for FA. Integrates with
#' the core interpret_core() workflow.
#'
#' @param model_type Object with class "fa"
#' @param model_data List. Contains loadings_df, factor_cols
#' @param cutoff Numeric. Loading cutoff threshold
#' @param ... Additional arguments (unused)
#'
#' @return List with cross_loadings and no_loadings data frames
#' @export
#' @keywords internal
create_diagnostics.fa <- function(model_type,
                                   model_data,
                                   cutoff = 0.3,
                                   ...) {
  list(
    cross_loadings = find_cross_loadings(
      loadings_df = model_data$loadings_df,
      factor_cols = model_data$factor_cols,
      cutoff = cutoff
    ),
    no_loadings = find_no_loadings(
      loadings_df = model_data$loadings_df,
      factor_cols = model_data$factor_cols,
      cutoff = cutoff
    )
  )
}
