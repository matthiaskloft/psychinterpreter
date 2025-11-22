# ===================================================================
# FILE: gm_visualization.R
# PURPOSE: Visualization functions for Gaussian Mixture Model interpretations
# ===================================================================

#' @importFrom stats aggregate sd var
#' @importFrom utils modifyList
NULL

#' Plot GM Interpretation
#'
#' Creates visualizations of cluster profiles with multiple plot type options.
#'
#' @param x An object of class "gm_interpretation"
#' @param plot_type Character: "auto", "heatmap", "parallel", "radar", or "all"
#' @param what Character or character vector: "means" (cluster means, default), "variances" (within-cluster SDs),
#'   or "ratio" (between/within variance ratio for discrimination). When a vector is provided (e.g., c("means", "variances")),
#'   a faceted plot is created with panels for each data type, sharing the same variable axis labels for easy comparison.
#' @param cutoff Numeric threshold for highlighting important values (default: 0.3)
#' @param variables Character vector of variables to include (NULL for all)
#' @param orientation Character: "horizontal" (variables on x-axis, default) or
#'   "vertical" (clusters/values on x-axis). Affects heatmap and parallel plots.
#' @param variable_order Character: "variance" (default) orders by variance descending,
#'   "variance_reversed" by variance ascending, "mean" orders by mean value ascending,
#'   "mean_reversed" by mean value descending, "original" preserves data order,
#'   "original_reversed" reverses data order, "alphabetical" sorts A-Z,
#'   "alphabetical_reversed" sorts Z-A. When `what` is a vector, variable ordering is determined
#'   by the first value in `what` (e.g., for c("means", "variances"), ordering is based on means).
#'   Cluster order is always fixed to the original model order.
#' @param top_k Integer: maximum number of variables to display (default: Inf, shows all variables).
#'   If there are more variables than this limit, only the top k most variable features (by variance) will be shown.
#'   Applies to all plot types.
#' @param centering Character: "none" (default, no centering), "variable" (center each variable
#'   by its mean across clusters), or "global" (center all values by the grand mean).
#'   Only applies when what="means". Centering helps highlight cluster differences.
#' @param layout Character: "auto" (default), "horizontal", or "vertical". Controls how facets
#'   are arranged when `what` is a vector. "horizontal" places facets side-by-side (1 row, multiple columns),
#'   "vertical" stacks them (1 column, multiple rows), and "auto" uses horizontal layout (one row)
#'   for all facet counts. Ignored if `facet_nrow` or `facet_ncol` is specified.
#' @param facet_nrow Integer: Number of rows for facet layout (default: NULL). When specified, overrides
#'   the `layout` parameter. Only applies when `what` is a vector.
#' @param facet_ncol Integer: Number of columns for facet layout (default: NULL). When specified, overrides
#'   the `layout` parameter. Only applies when `what` is a vector.
#' @param ... Additional arguments passed to specific plot functions
#'
#' @return For single `what` value: a ggplot2 object (heatmap/parallel) or recordedplot object (radar).
#'   For multiple `what` values: a faceted ggplot2 object with panels for each data type.
#'   For plot_type="all": a list containing all three plot types.
#' @export
#'
#' @examples
#' \dontrun{
#' # Basic plot (auto-selects best type, shows means)
#' plot(gm_interpretation)
#'
#' # Variance visualizations
#' plot(gm_interpretation, what = "variances")  # Within-cluster standard deviations
#' plot(gm_interpretation, what = "ratio")      # Discrimination ratios
#'
#' # Specific plot type with variance
#' plot(gm_interpretation, plot_type = "heatmap", what = "variances")
#' plot(gm_interpretation, plot_type = "parallel", what = "ratio")
#'
#' # Horizontal orientation (variables on x-axis, default)
#' plot(gm_interpretation, plot_type = "heatmap", orientation = "horizontal")
#' plot(gm_interpretation, plot_type = "parallel", orientation = "horizontal")
#'
#' # Vertical orientation (clusters/values on x-axis)
#' plot(gm_interpretation, plot_type = "heatmap", orientation = "vertical")
#' plot(gm_interpretation, plot_type = "parallel", orientation = "vertical")
#'
#' # Variable ordering in parallel plots (cluster order is always model order)
#' plot(gm_interpretation, plot_type = "parallel", variable_order = "variance")
#' plot(gm_interpretation, plot_type = "parallel", variable_order = "variance_reversed")
#' plot(gm_interpretation, plot_type = "parallel", variable_order = "alphabetical")
#'
#' # All plot types
#' plots <- plot(gm_interpretation, plot_type = "all")
#'
#' # Focus on specific variables
#' plot(gm_interpretation, variables = c("var1", "var2", "var3"))
#'
#' # Multiple what values with faceting (shares variable axis labels)
#' plot(gm_interpretation, what = c("means", "variances"))  # Horizontal facets (side-by-side)
#' plot(gm_interpretation, what = c("means", "variances", "ratio"), layout = "vertical")
#'
#' # Custom facet layout with nrow/ncol
#' plot(gm_interpretation, what = c("means", "variances", "ratio"), facet_nrow = 1)  # Force 1 row
#' plot(gm_interpretation, what = c("means", "variances", "ratio"), facet_ncol = 1)  # Force 1 column
#' plot(gm_interpretation, what = c("means", "variances", "ratio", "ratio"), facet_nrow = 2)
#'
#' # Note: When what is a vector, variable ordering is based on the first type
#' # For example, this orders by variance in the means:
#' plot(gm_interpretation, what = c("means", "variances"), variable_order = "variance")
#' # This orders by variance in the variances (swap order):
#' plot(gm_interpretation, what = c("variances", "means"), variable_order = "variance")
#' }
plot.gm_interpretation <- function(
    x,
    plot_type = NULL,
    what = "means",
    cutoff = 0.3,
    variables = NULL,
    orientation = "horizontal",
    variable_order = "variance",
    top_k = Inf,
    centering = "none",
    layout = "auto",
    facet_nrow = NULL,
    facet_ncol = NULL,
    ...) {

  # Extract analysis data
  analysis_data <- x$analysis_data

  # Use suggested names from LLM interpretation if available
  if (!is.null(x$suggested_names) && length(x$suggested_names) == analysis_data$n_clusters) {
    # Map suggested names to cluster names in order
    suggested_cluster_names <- character(analysis_data$n_clusters)
    for (i in seq_len(analysis_data$n_clusters)) {
      generic_name <- analysis_data$cluster_names[i]
      if (!is.null(x$suggested_names[[generic_name]])) {
        suggested_cluster_names[i] <- x$suggested_names[[generic_name]]
      } else {
        suggested_cluster_names[i] <- generic_name
      }
    }
    # Update cluster names in analysis_data for plotting
    analysis_data$cluster_names <- suggested_cluster_names
  }

  # Use plot_type from analysis_data if not specified
  if (is.null(plot_type)) {
    plot_type <- ifelse(
      !is.null(analysis_data$plot_type),
      analysis_data$plot_type,
      "auto"
    )
  }

  # Auto-select plot type based on data characteristics
  if (plot_type == "auto") {
    if (analysis_data$n_clusters <= 4 && analysis_data$n_variables <= 10) {
      plot_type <- "radar"
    } else if (analysis_data$n_variables > 20) {
      plot_type <- "heatmap"
    } else {
      plot_type <- "parallel"
    }
  }

  # Filter variables if specified
  if (!is.null(variables)) {
    var_indices <- which(analysis_data$variable_names %in% variables)
    if (length(var_indices) == 0) {
      cli::cli_abort("None of the specified variables found in the data")
    }
    analysis_data <- filter_variables_gm(analysis_data, var_indices)
  }

  # Validate orientation parameter
  if (!orientation %in% c("horizontal", "vertical")) {
    cli::cli_abort("orientation must be 'horizontal' or 'vertical'")
  }

  # Validate what parameter - can be a vector for multiple plots
  if (!all(what %in% c("means", "variances", "ratio"))) {
    invalid_vals <- what[!what %in% c("means", "variances", "ratio")]
    cli::cli_abort("{.arg what} contains invalid value(s): {.val {invalid_vals}}. Must be 'means', 'variances', or 'ratio'")
  }

  # Validate centering parameter
  if (!centering %in% c("none", "variable", "global")) {
    cli::cli_abort("{.arg centering} must be 'none', 'variable', or 'global', not {.val {centering}}")
  }

  # Validate layout parameter
  if (!layout %in% c("auto", "horizontal", "vertical")) {
    cli::cli_abort("{.arg layout} must be 'auto', 'horizontal', or 'vertical', not {.val {layout}}")
  }

  # Handle vector what parameter - create faceted plots
  if (length(what) > 1) {
    # Radar plots cannot be faceted
    if (plot_type == "radar") {
      cli::cli_abort("Radar plots cannot be faceted. Use plot_type = 'heatmap' or 'parallel', or provide a single value for {.arg what}.")
    }

    # plot_type="all" doesn't make sense with vector what
    if (plot_type == "all") {
      cli::cli_abort("{.arg plot_type} = 'all' cannot be combined with vector {.arg what}. Use a single plot type.")
    }

    # Inform user about centering for non-means plots
    non_means <- what[what != "means"]
    if (centering != "none" && length(non_means) > 0) {
      cli::cli_inform("{.arg centering} only applies to 'means' plots, ignoring for: {.val {non_means}}")
    }

    # Determine which plot type to use
    if (plot_type == "heatmap" || (plot_type %in% c("auto", NULL) && analysis_data$n_variables > 20)) {
      return(create_heatmap_gm_faceted(analysis_data = analysis_data, what = what, cutoff = cutoff,
                                        orientation = orientation, variable_order = variable_order,
                                        top_k = top_k, centering = centering, layout = layout,
                                        facet_nrow = facet_nrow, facet_ncol = facet_ncol, ...))
    } else if (plot_type == "parallel" || (plot_type %in% c("auto", NULL) && analysis_data$n_variables <= 20)) {
      return(create_parallel_plot_gm_faceted(analysis_data = analysis_data, what = what, cutoff = cutoff,
                                              orientation = orientation, variable_order = variable_order,
                                              top_k = top_k, centering = centering, layout = layout,
                                              facet_nrow = facet_nrow, facet_ncol = facet_ncol, ...))
    }
  }

  # Single what value - inform user about centering for non-means plots
  if (length(what) == 1 && centering != "none" && what != "means") {
    cli::cli_inform("{.arg centering} only applies when {.arg what} is 'means', ignoring for '{what}'")
  }

  # Create appropriate plot(s)
  if (plot_type == "all") {
    plots <- list(
      heatmap = create_heatmap_gm(analysis_data, what, cutoff, orientation, variable_order, top_k, centering, ...),
      parallel = create_parallel_plot_gm(analysis_data, what, cutoff, orientation, variable_order, top_k, centering, ...),
      radar = create_radar_plot_gm(analysis_data, what, cutoff, variable_order, top_k, centering, ...)
    )
    return(plots)
  } else if (plot_type == "heatmap") {
    return(create_heatmap_gm(analysis_data, what, cutoff, orientation, variable_order, top_k, centering, ...))
  } else if (plot_type == "parallel") {
    return(create_parallel_plot_gm(analysis_data, what, cutoff, orientation, variable_order, top_k, centering, ...))
  } else if (plot_type == "radar") {
    return(create_radar_plot_gm(analysis_data, what, cutoff, variable_order, top_k, centering, ...))
  } else {
    cli::cli_abort("Invalid plot_type: must be 'auto', 'heatmap', 'parallel', 'radar', or 'all'")
  }
}

#' Create Heatmap for GM Clusters
#'
#' Creates a heatmap showing cluster profiles (means, variance, or discrimination ratios).
#'
#' @param analysis_data Standardized GM analysis data
#' @param what Character: "means" (cluster means, default), "variances" (within-cluster SDs),
#'   or "ratio" (between/within variance ratio for discrimination)
#' @param cutoff Threshold for highlighting
#' @param orientation Character: "horizontal" (variables on x-axis) or "vertical" (clusters on x-axis)
#' @param variable_order Character: how to order variables. Options: "variance" (by variance across clusters, descending),
#'   "variance_reversed" (by variance, ascending), "mean" (by mean value, ascending), "mean_reversed" (by mean value, descending),
#'   "alphabetical" (A-Z), "alphabetical_reversed" (Z-A), "original" (data order), "original_reversed" (reversed data order)
#' @param top_k Integer: maximum number of variables to display (default: Inf, shows all).
#'   If there are more variables, only the top k most variable features are shown.
#' @param centering Character: "none" (default), "variable" (center by row mean), or "global" (center by grand mean).
#'   Only applies when what="means".
#' @param title Plot title (optional)
#' @return ggplot2 object
#' @keywords internal
create_heatmap_gm <- function(analysis_data, what = "means", cutoff = 0.3, orientation = "horizontal", variable_order = "variance", top_k = Inf, centering = "none", title = NULL) {
  # Validate what parameter (must be single value for this internal function)
  if (length(what) != 1 || !what %in% c("means", "variances", "ratio")) {
    cli::cli_abort("{.arg what} must be a single value: 'means', 'variances', or 'ratio', not {.val {what}}")
  }

  # Extract appropriate data matrix based on what parameter
  if (what == "means") {
    data_matrix <- analysis_data$means
  } else if (what == "variances") {
    data_matrix <- extract_variance_matrix(analysis_data)
  } else {  # what == "ratio"
    data_matrix <- extract_variance_ratio_matrix(analysis_data)
  }

  # Apply centering (only for means)
  if (what == "means" && centering != "none") {
    data_matrix <- apply_centering(data_matrix, centering)
  }

  # Prepare data for plotting
  plot_df <- as.data.frame(data_matrix)
  colnames(plot_df) <- analysis_data$cluster_names
  plot_df$Variable <- analysis_data$variable_names

  # Reshape to long format
  plot_data <- tidyr::pivot_longer(
    plot_df,
    cols = -Variable,
    names_to = "Cluster",
    values_to = "Value"
  )

  # Preserve cluster order by converting to factor with correct levels
  plot_data$Cluster <- factor(plot_data$Cluster, levels = analysis_data$cluster_names)

  # Limit to top k variables if specified
  if (analysis_data$n_variables > top_k) {
    # Select top k most variable features
    var_variances <- aggregate(Value ~ Variable, plot_data, var)
    top_vars <- var_variances$Variable[order(var_variances[[2]], decreasing = TRUE)[1:top_k]]

    # Filter plot_data to include only top variables
    plot_data <- plot_data[plot_data$Variable %in% top_vars, ]

    # Update variable_names list for ordering
    analysis_data$variable_names <- top_vars

    cli::cli_inform(
      "Heatmap limited to top {top_k} most variable features for clarity"
    )
  }

  # Validate variable_order parameter
  valid_orders <- c("variance", "variance_reversed", "mean", "mean_reversed",
                   "original", "original_reversed", "alphabetical", "alphabetical_reversed")
  if (!variable_order %in% valid_orders) {
    cli::cli_abort("{.arg variable_order} must be one of: {.val {valid_orders}}, not {.val {variable_order}}")
  }

  # Determine variable order
  if (variable_order == "variance") {
    # Order by variance across clusters (descending - most variable first)
    var_importance <- aggregate(Value ~ Variable, plot_data, var)
    var_levels <- var_importance$Variable[order(var_importance[[2]], decreasing = TRUE)]
  } else if (variable_order == "variance_reversed") {
    # Order by variance ascending (least variable first)
    var_importance <- aggregate(Value ~ Variable, plot_data, var)
    var_levels <- var_importance$Variable[order(var_importance[[2]], decreasing = FALSE)]
  } else if (variable_order == "mean") {
    # Order by mean value across clusters (ascending - lowest mean first)
    var_means <- aggregate(Value ~ Variable, plot_data, mean)
    var_levels <- var_means$Variable[order(var_means[[2]], decreasing = FALSE)]
  } else if (variable_order == "mean_reversed") {
    # Order by mean value descending (highest mean first)
    var_means <- aggregate(Value ~ Variable, plot_data, mean)
    var_levels <- var_means$Variable[order(var_means[[2]], decreasing = TRUE)]
  } else if (variable_order == "alphabetical") {
    var_levels <- sort(analysis_data$variable_names)
  } else if (variable_order == "alphabetical_reversed") {
    var_levels <- sort(analysis_data$variable_names, decreasing = TRUE)
  } else if (variable_order == "original") {
    var_levels <- analysis_data$variable_names
  } else {
    # "original_reversed" - reverse data order
    var_levels <- rev(analysis_data$variable_names)
  }

  # Apply variable ordering
  plot_data$Variable <- factor(plot_data$Variable, levels = var_levels)

  # Apply cutoff based on what type
  if (what == "means") {
    plot_data$Significant <- abs(plot_data$Value) >= cutoff
  } else {
    # For variance and ratio, use absolute value cutoff
    plot_data$Significant <- plot_data$Value >= cutoff
  }

  # Set up axis labels based on variable ordering
  var_label_suffix <- switch(variable_order,
    "variance" = " (by variance desc)",
    "variance_reversed" = " (by variance asc)",
    "mean" = " (by mean asc)",
    "mean_reversed" = " (by mean desc)",
    "alphabetical" = " (A-Z)",
    "alphabetical_reversed" = " (Z-A)",
    "original_reversed" = " (reversed)",
    "original" = ""
  )

  # Set up axes based on orientation
  if (orientation == "horizontal") {
    # Variables on x-axis (horizontal), clusters on y-axis
    x_var <- "Variable"
    y_var <- "Cluster"
    x_lab <- paste0("Variable", var_label_suffix)
    y_lab <- "Cluster"
    x_angle <- 45
  } else {
    # Clusters on x-axis (vertical), variables on y-axis
    x_var <- "Cluster"
    y_var <- "Variable"
    x_lab <- "Cluster"
    y_lab <- paste0("Variable", var_label_suffix)
    x_angle <- 45
  }

  # Set up color scale and labels based on what parameter
  if (what == "means") {
    fill_scale <- ggplot2::scale_fill_gradient2(
      low = psychinterpreter_colors("diverging")[1],
      mid = "white",
      high = psychinterpreter_colors("diverging")[3],
      midpoint = 0,
      limits = c(-max(abs(plot_data$Value)), max(abs(plot_data$Value))),
      name = "Mean\nValue"
    )
    default_title <- "Cluster Profiles: Variable Means"
  } else if (what == "variances") {
    fill_scale <- ggplot2::scale_fill_gradient(
      low = "white",
      high = psychinterpreter_colors("diverging")[1],  # Blue
      name = "Std Dev"
    )
    default_title <- "Cluster Profiles: Within-Cluster Variance"
  } else {  # what == "ratio"
    fill_scale <- ggplot2::scale_fill_gradient(
      low = "white",
      high = psychinterpreter_colors("diverging")[3],  # Orange
      name = "Variance\nRatio"
    )
    default_title <- "Cluster Profiles: Discrimination Ratio"
  }

  # Create heatmap
  p <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = .data[[x_var]], y = .data[[y_var]], fill = Value)
  ) +
    ggplot2::geom_tile(color = "white", linewidth = 0.5) +
    fill_scale +
    theme_psychinterpreter() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = x_angle, hjust = 1),
      panel.grid = ggplot2::element_blank()
    ) +
    ggplot2::labs(
      title = title %||% default_title,
      subtitle = paste0("Gaussian Mixture Model with ", analysis_data$n_clusters, " clusters"),
      x = x_lab,
      y = y_lab
    )

  # Add text for significant values
  if (any(plot_data$Significant)) {
    p <- p + ggplot2::geom_text(
      data = plot_data[plot_data$Significant, ],
      ggplot2::aes(label = round(Value, 2)),
      color = "black",
      size = 3
    )
  }

  return(p)
}

#' Create Parallel Coordinates Plot for GM Clusters
#'
#' Creates a parallel coordinates plot showing cluster profiles (means, variance, or discrimination ratios).
#'
#' @param analysis_data Standardized GM analysis data
#' @param what Character: "means" (cluster means, default), "variances" (within-cluster SDs),
#'   or "ratio" (between/within variance ratio for discrimination)
#' @param cutoff Threshold for highlighting
#' @param orientation Character: "horizontal" (variables on x-axis, default) or "vertical" (variables on y-axis)
#' @param variable_order Character: "variance" (default) orders by variance descending,
#'   "variance_reversed" by variance ascending, "mean" orders by mean value ascending,
#'   "mean_reversed" by mean descending, "original" preserves data order,
#'   "original_reversed" reverses data order, "alphabetical" sorts alphabetically,
#'   "alphabetical_reversed" reverse alphabetical
#' @param top_k Integer: maximum number of variables to display (default: Inf, shows all).
#'   If there are more variables, only the top k most variable features are shown.
#' @param centering Character: "none" (default), "variable" (center by row mean), or "global" (center by grand mean).
#'   Only applies when what="means".
#' @param title Plot title (optional)
#' @return ggplot2 object
#' @keywords internal
create_parallel_plot_gm <- function(analysis_data, what = "means", cutoff = 0.3, orientation = "horizontal",
                                     variable_order = "variance", top_k = Inf, centering = "none", title = NULL) {
  # Validate what parameter (must be single value for this internal function)
  if (length(what) != 1 || !what %in% c("means", "variances", "ratio")) {
    cli::cli_abort("{.arg what} must be a single value: 'means', 'variances', or 'ratio', not {.val {what}}")
  }

  # Extract appropriate data matrix based on what parameter
  if (what == "means") {
    data_matrix <- analysis_data$means
  } else if (what == "variances") {
    data_matrix <- extract_variance_matrix(analysis_data)
  } else {  # what == "ratio"
    data_matrix <- extract_variance_ratio_matrix(analysis_data)
  }

  # Apply centering (only for means)
  if (what == "means" && centering != "none") {
    data_matrix <- apply_centering(data_matrix, centering)
  }

  # Validate variable_order parameter
  valid_orders <- c("variance", "variance_reversed", "mean", "mean_reversed",
                   "original", "original_reversed", "alphabetical", "alphabetical_reversed")
  if (!variable_order %in% valid_orders) {
    cli::cli_abort("{.arg variable_order} must be one of: {.val {valid_orders}}, not {.val {variable_order}}")
  }

  # Limit to top k variables if specified
  if (analysis_data$n_variables > top_k) {
    # Select top k most variable features
    var_variances <- apply(data_matrix, 1, var)
    top_var_idx <- order(var_variances, decreasing = TRUE)[1:top_k]

    # Filter to include only top variables
    data_matrix <- data_matrix[top_var_idx, , drop = FALSE]
    analysis_data$variable_names <- analysis_data$variable_names[top_var_idx]

    cli::cli_inform(
      "Parallel plot limited to top {top_k} most variable features for clarity"
    )
  }

  # Cluster order is always fixed to model order (numerical)
  cluster_levels <- analysis_data$cluster_names

  # Prepare data
  data_df <- as.data.frame(t(data_matrix))
  colnames(data_df) <- analysis_data$variable_names
  data_df$Cluster <- factor(
    analysis_data$cluster_names,
    levels = cluster_levels
  )

  # Add cluster size information
  if (!is.null(analysis_data$proportions)) {
    data_df$Size <- analysis_data$proportions
  } else {
    data_df$Size <- 1 / analysis_data$n_clusters
  }

  # Reshape to long format
  plot_data <- tidyr::pivot_longer(
    data_df,
    cols = -c(Cluster, Size),
    names_to = "Variable",
    values_to = "Value"
  )

  # Determine variable order
  if (variable_order == "variance") {
    # Order by variance across clusters (descending - most variable first)
    var_importance <- aggregate(Value ~ Variable, plot_data, var)
    var_levels <- var_importance$Variable[order(var_importance[[2]], decreasing = TRUE)]
  } else if (variable_order == "variance_reversed") {
    # Order by variance ascending (least variable first)
    var_importance <- aggregate(Value ~ Variable, plot_data, var)
    var_levels <- var_importance$Variable[order(var_importance[[2]], decreasing = FALSE)]
  } else if (variable_order == "mean") {
    # Order by mean value across clusters (ascending - lowest mean first)
    var_means <- aggregate(Value ~ Variable, plot_data, mean)
    var_levels <- var_means$Variable[order(var_means[[2]], decreasing = FALSE)]
  } else if (variable_order == "mean_reversed") {
    # Order by mean value descending (highest mean first)
    var_means <- aggregate(Value ~ Variable, plot_data, mean)
    var_levels <- var_means$Variable[order(var_means[[2]], decreasing = TRUE)]
  } else if (variable_order == "alphabetical") {
    var_levels <- sort(analysis_data$variable_names)
  } else if (variable_order == "alphabetical_reversed") {
    var_levels <- sort(analysis_data$variable_names, decreasing = TRUE)
  } else if (variable_order == "original") {
    # Preserve data order
    var_levels <- analysis_data$variable_names
  } else {
    # "original_reversed" - reverse data order
    var_levels <- rev(analysis_data$variable_names)
  }

  plot_data$Variable <- factor(plot_data$Variable, levels = var_levels)

  # Set up axis labels based on variable ordering
  var_label_suffix <- switch(variable_order,
    "variance" = " (by variance desc)",
    "variance_reversed" = " (by variance asc)",
    "mean" = " (by mean asc)",
    "mean_reversed" = " (by mean desc)",
    "alphabetical" = " (A-Z)",
    "alphabetical_reversed" = " (Z-A)",
    "original_reversed" = " (reversed)",
    "original" = ""
  )

  # Set up value label based on what parameter
  if (what == "means") {
    value_label <- "Standardized Mean"
    default_title <- "Cluster Profiles: Parallel Coordinates"
    show_reference_lines <- TRUE
  } else if (what == "variances") {
    value_label <- "Std Dev"
    default_title <- "Cluster Profiles: Within-Cluster Variance"
    show_reference_lines <- FALSE  # No reference lines for variance
  } else {  # what == "ratio"
    value_label <- "Variance Ratio"
    default_title <- "Cluster Profiles: Discrimination Ratio"
    show_reference_lines <- FALSE  # No reference lines for ratio
  }

  # Set up axes and reference lines based on orientation
  if (orientation == "horizontal") {
    # Variables on x-axis (standard parallel coordinates)
    aes_mapping <- ggplot2::aes(x = Variable, y = Value, group = Cluster, color = Cluster)
    x_lab <- paste0("Variable", var_label_suffix)
    y_lab <- value_label
    x_angle <- 45
    if (show_reference_lines) {
      ref_line_layer <- list(
        ggplot2::geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5),
        ggplot2::geom_hline(yintercept = c(-cutoff, cutoff), linetype = "dotted", alpha = 0.3)
      )
    } else {
      ref_line_layer <- list()
    }
  } else {
    # Variables on y-axis (rotated parallel coordinates)
    # Sort data by Cluster and Variable to ensure lines connect points correctly
    plot_data <- plot_data[order(plot_data$Cluster, plot_data$Variable), ]

    aes_mapping <- ggplot2::aes(x = Value, y = Variable, group = Cluster, color = Cluster)
    x_lab <- value_label
    y_lab <- paste0("Variable", var_label_suffix)
    x_angle <- 0
    if (show_reference_lines) {
      ref_line_layer <- list(
        ggplot2::geom_vline(xintercept = 0, linetype = "dashed", alpha = 0.5),
        ggplot2::geom_vline(xintercept = c(-cutoff, cutoff), linetype = "dotted", alpha = 0.3)
      )
    } else {
      ref_line_layer <- list()
    }
  }

  # Create parallel coordinates plot
  # Use geom_path for vertical (respects data order) and geom_line for horizontal (sorts by x)
  if (orientation == "vertical") {
    line_layer <- ggplot2::geom_path(ggplot2::aes(linewidth = Size), alpha = 0.7)
  } else {
    line_layer <- ggplot2::geom_line(ggplot2::aes(linewidth = Size), alpha = 0.7)
  }

  p <- ggplot2::ggplot(plot_data, aes_mapping) +
    line_layer +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_color_manual(
      values = psychinterpreter_colors("categorical")[1:analysis_data$n_clusters]
    ) +
    ggplot2::scale_linewidth_continuous(
      range = c(0.5, 2),
      guide = "none"
    ) +
    theme_psychinterpreter() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = x_angle, hjust = 1),
      legend.position = "right"
    ) +
    ggplot2::labs(
      title = title %||% default_title,
      subtitle = paste0("Line thickness represents cluster size"),
      x = x_lab,
      y = y_lab
    ) +
    ref_line_layer

  return(p)
}

#' Create Radar Plot for GM Clusters
#'
#' Creates a radar/spider plot showing cluster profiles (means, variance, or discrimination ratios) using fmsb::radarchart.
#'
#' @param analysis_data Standardized GM analysis data
#' @param what Character: "means" (cluster means, default), "variances" (within-cluster SDs),
#'   or "ratio" (between/within variance ratio for discrimination)
#' @param cutoff Threshold for highlighting (not used in fmsb implementation)
#' @param variable_order Character: how to order variables. Options: "variance" (by variance across clusters, descending),
#'   "variance_reversed" (by variance, ascending), "mean" (by mean value, ascending), "mean_reversed" (by mean value, descending),
#'   "alphabetical" (A-Z), "alphabetical_reversed" (Z-A), "original" (data order), "original_reversed" (reversed data order)
#' @param top_k Integer: maximum number of variables to display (default: Inf, shows all variables).
#'   If there are more variables than this limit, only the top k most variable features will be shown.
#' @param centering Character: "none" (default), "variable" (center by row mean), or "global" (center by grand mean).
#'   Only applies when what="means".
#' @param title Plot title (optional)
#' @param ... Additional arguments passed to fmsb::radarchart
#' @return A recorded plot object (class "recordedplot")
#' @keywords internal
create_radar_plot_gm <- function(analysis_data, what = "means", cutoff = 0.3, variable_order = "variance", top_k = Inf, centering = "none", title = NULL, ...) {
  # Check if fmsb is available
  if (!requireNamespace("fmsb", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg fmsb} is required for radar plots. Install it with: install.packages('fmsb')")
  }

  # Validate what parameter (must be single value for this internal function)
  if (length(what) != 1 || !what %in% c("means", "variances", "ratio")) {
    cli::cli_abort("{.arg what} must be a single value: 'means', 'variances', or 'ratio', not {.val {what}}")
  }

  # Extract appropriate data matrix based on what parameter
  if (what == "means") {
    data_matrix <- analysis_data$means
    default_title <- "Cluster Profiles: Radar Plot"
  } else if (what == "variances") {
    data_matrix <- extract_variance_matrix(analysis_data)
    default_title <- "Cluster Profiles: Within-Cluster Variance (Radar)"
  } else {  # what == "ratio"
    data_matrix <- extract_variance_ratio_matrix(analysis_data)
    default_title <- "Cluster Profiles: Discrimination Ratio (Radar)"
  }

  # Apply centering (only for means)
  if (what == "means" && centering != "none") {
    data_matrix <- apply_centering(data_matrix, centering)
  }

  # Validate variable_order parameter
  valid_orders <- c("variance", "variance_reversed", "mean", "mean_reversed",
                   "original", "original_reversed", "alphabetical", "alphabetical_reversed")
  if (!variable_order %in% valid_orders) {
    cli::cli_abort("{.arg variable_order} must be one of: {.val {valid_orders}}, not {.val {variable_order}}")
  }

  # Limit to reasonable number of variables for radar plot
  if (analysis_data$n_variables > top_k) {
    # Select top k most variable features
    var_sds <- apply(data_matrix, 1, sd)
    top_vars <- order(var_sds, decreasing = TRUE)[1:top_k]

    data_subset <- data_matrix[top_vars, , drop = FALSE]
    var_names_subset <- analysis_data$variable_names[top_vars]

    cli::cli_inform(
      "Radar plot limited to top {top_k} most variable features for clarity"
    )
  } else {
    data_subset <- data_matrix
    var_names_subset <- analysis_data$variable_names
  }

  # Inform if too many clusters for overlaid radar (best practice: 2-3 max)
  if (analysis_data$n_clusters > 3) {
    cli::cli_inform(
      "Overlaid radar plot may be difficult to read with {analysis_data$n_clusters} clusters. Consider using heatmap or parallel plot instead."
    )
  }

  # Apply variable ordering
  if (variable_order == "variance") {
    # Order by variance across clusters (descending - most variable first)
    var_importance <- apply(data_subset, 1, var)
    var_order_idx <- order(var_importance, decreasing = TRUE)
  } else if (variable_order == "variance_reversed") {
    # Order by variance ascending (least variable first)
    var_importance <- apply(data_subset, 1, var)
    var_order_idx <- order(var_importance, decreasing = FALSE)
  } else if (variable_order == "mean") {
    # Order by mean value across clusters (ascending - lowest mean first)
    var_means <- apply(data_subset, 1, mean)
    var_order_idx <- order(var_means, decreasing = FALSE)
  } else if (variable_order == "mean_reversed") {
    # Order by mean value descending (highest mean first)
    var_means <- apply(data_subset, 1, mean)
    var_order_idx <- order(var_means, decreasing = TRUE)
  } else if (variable_order == "alphabetical") {
    var_order_idx <- order(var_names_subset)
  } else if (variable_order == "alphabetical_reversed") {
    var_order_idx <- order(var_names_subset, decreasing = TRUE)
  } else if (variable_order == "original") {
    var_order_idx <- seq_along(var_names_subset)
  } else {
    # "original_reversed" - reverse data order
    var_order_idx <- rev(seq_along(var_names_subset))
  }

  # Apply ordering to subset data
  data_subset <- data_subset[var_order_idx, , drop = FALSE]
  var_names_subset <- var_names_subset[var_order_idx]

  # Prepare data for fmsb::radarchart
  # Format: first row = max, second row = min, remaining rows = data
  data_range <- range(data_subset)
  max_val <- ceiling(data_range[2])
  min_val <- floor(data_range[1])

  # Transpose data so variables are columns
  radar_data <- as.data.frame(t(data_subset))
  colnames(radar_data) <- var_names_subset
  rownames(radar_data) <- analysis_data$cluster_names

  # Add max and min rows
  radar_data <- rbind(
    max = rep(max_val, ncol(radar_data)),
    min = rep(min_val, ncol(radar_data)),
    radar_data
  )

  # Get color palette (with transparency for fills)
  cluster_colors <- psychinterpreter_colors("categorical")[seq_len(analysis_data$n_clusters)]

  # Set up plotting parameters
  n_clusters <- analysis_data$n_clusters

  # Default radarchart parameters with better styling
  default_args <- list(
    df = radar_data,
    axistype = 1,
    pcol = cluster_colors,
    pfcol = NA,  # No shading/fill
    plwd = 2,
    plty = 1,
    cglcol = "grey",
    cglty = 1,
    axislabcol = "grey",  # Match grid color
    caxislabels = seq(min_val, max_val, length.out = 5),
    cglwd = 0.8,
    vlcex = 0.8,
    title = title %||% default_title
  )

  # Merge with user-provided arguments
  radar_args <- modifyList(default_args, list(...))

  # Clear any existing plot
  graphics::plot.new()

  # Create the radar chart
  do.call(fmsb::radarchart, radar_args)

  # Add legend
  graphics::legend(
    x = "topright",
    legend = analysis_data$cluster_names,
    bty = "n",
    pch = 20,
    col = cluster_colors,
    text.col = "grey20",
    cex = 0.9,
    pt.cex = 2
  )

  # Record and return the plot
  p <- grDevices::recordPlot()
  return(p)
}

#' Create Faceted Parallel Plot for Multiple What Values
#'
#' Creates a parallel coordinates plot with facets for different data types (means, variances, ratio).
#'
#' @param analysis_data Standardized GM analysis data
#' @param what Character vector: values from c("means", "variances", "ratio")
#' @param cutoff Threshold for highlighting
#' @param orientation Character: "horizontal" or "vertical"
#' @param variable_order Character: variable ordering method
#' @param top_k Integer: maximum number of variables to display
#' @param centering Character: centering method (only for means)
#' @param layout Character: "auto", "horizontal", or "vertical" for facet layout
#' @param title Plot title (optional)
#' @return ggplot2 object with facets
#' @keywords internal
create_parallel_plot_gm_faceted <- function(analysis_data, what, cutoff = 0.3, orientation = "horizontal",
                                             variable_order = "variance", top_k = Inf, centering = "none",
                                             layout = "auto", facet_nrow = NULL, facet_ncol = NULL, title = NULL) {
  # Combine data from all what values
  data_list <- lapply(what, function(w) {
    # Extract appropriate data matrix
    if (w == "means") {
      data_matrix <- analysis_data$means
      if (centering != "none") {
        data_matrix <- apply_centering(data_matrix, centering)
      }
    } else if (w == "variances") {
      data_matrix <- extract_variance_matrix(analysis_data)
    } else {  # w == "ratio"
      data_matrix <- extract_variance_ratio_matrix(analysis_data)
    }

    # Limit to top k variables if needed
    if (analysis_data$n_variables > top_k) {
      var_variances <- apply(data_matrix, 1, var)
      top_var_idx <- order(var_variances, decreasing = TRUE)[1:top_k]
      data_matrix <- data_matrix[top_var_idx, , drop = FALSE]
      var_names <- analysis_data$variable_names[top_var_idx]
    } else {
      var_names <- analysis_data$variable_names
    }

    # Prepare data
    data_df <- as.data.frame(t(data_matrix))
    colnames(data_df) <- var_names
    data_df$Cluster <- factor(analysis_data$cluster_names, levels = analysis_data$cluster_names)

    # Add cluster size information
    if (!is.null(analysis_data$proportions)) {
      data_df$Size <- analysis_data$proportions
    } else {
      data_df$Size <- 1 / analysis_data$n_clusters
    }

    # Reshape to long format
    plot_data <- tidyr::pivot_longer(
      data_df,
      cols = -c(Cluster, Size),
      names_to = "Variable",
      values_to = "Value"
    )

    # Add what type
    plot_data$Type <- w

    return(plot_data)
  })

  # Combine all data
  combined_data <- do.call(rbind, data_list)

  # Apply variable ordering (using first 'what' type for ordering)
  if (variable_order != "original") {
    first_type_data <- combined_data[combined_data$Type == what[1], ]
    if (variable_order == "variance") {
      var_importance <- aggregate(Value ~ Variable, first_type_data, var)
      var_levels <- var_importance$Variable[order(var_importance[[2]], decreasing = TRUE)]
    } else if (variable_order == "variance_reversed") {
      var_importance <- aggregate(Value ~ Variable, first_type_data, var)
      var_levels <- var_importance$Variable[order(var_importance[[2]], decreasing = FALSE)]
    } else if (variable_order == "mean") {
      var_means <- aggregate(Value ~ Variable, first_type_data, mean)
      var_levels <- var_means$Variable[order(var_means[[2]], decreasing = FALSE)]
    } else if (variable_order == "mean_reversed") {
      var_means <- aggregate(Value ~ Variable, first_type_data, mean)
      var_levels <- var_means$Variable[order(var_means[[2]], decreasing = TRUE)]
    } else if (variable_order == "alphabetical") {
      var_levels <- sort(unique(combined_data$Variable))
    } else if (variable_order == "alphabetical_reversed") {
      var_levels <- sort(unique(combined_data$Variable), decreasing = TRUE)
    } else {  # "original_reversed"
      var_levels <- rev(unique(combined_data$Variable))
    }
    combined_data$Variable <- factor(combined_data$Variable, levels = var_levels)
  }

  # Create facet labels
  type_labels <- c(
    "means" = "Cluster Means",
    "variances" = "Within-Cluster SD",
    "ratio" = "Discrimination Ratio"
  )
  combined_data$Type <- factor(combined_data$Type, levels = what, labels = type_labels[what])

  # Determine facet layout
  if (layout == "auto") {
    facet_layout <- "horizontal"  # Always horizontal (one row) for auto
  } else {
    facet_layout <- layout
  }

  # Set up axes based on orientation
  if (orientation == "horizontal") {
    aes_mapping <- ggplot2::aes(x = Variable, y = Value, group = Cluster, color = Cluster)
    x_angle <- 45
  } else {
    # Sort data for proper line connections in vertical orientation
    combined_data <- combined_data[order(combined_data$Cluster, combined_data$Variable), ]
    aes_mapping <- ggplot2::aes(x = Value, y = Variable, group = Cluster, color = Cluster)
    x_angle <- 0
  }

  # Create parallel coordinates plot with facets
  if (orientation == "vertical") {
    line_layer <- ggplot2::geom_path(ggplot2::aes(linewidth = Size), alpha = 0.7)
  } else {
    line_layer <- ggplot2::geom_line(ggplot2::aes(linewidth = Size), alpha = 0.7)
  }

  p <- ggplot2::ggplot(combined_data, aes_mapping) +
    line_layer +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_color_manual(
      values = psychinterpreter_colors("categorical")[1:analysis_data$n_clusters]
    ) +
    ggplot2::scale_linewidth_continuous(
      range = c(0.5, 2),
      guide = "none"
    ) +
    theme_psychinterpreter() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = x_angle, hjust = 1),
      legend.position = "right"
    ) +
    ggplot2::labs(
      title = title %||% "Cluster Profiles: Parallel Coordinates (Faceted)",
      subtitle = paste0("Line thickness represents cluster size"),
      x = if (orientation == "horizontal") "Variable" else "Value",
      y = if (orientation == "horizontal") "Value" else "Variable"
    )

  # Add facets with appropriate scale freedom based on orientation
  if (orientation == "horizontal") {
    # Variables on x-axis: keep x fixed (shared variable labels), free y (different value scales)
    scales_setting <- "free_y"
  } else {
    # Variables on y-axis: keep y fixed (shared variable labels), free x (different value scales)
    scales_setting <- "free_x"
  }

  # Apply faceting with user-specified nrow/ncol if provided
  if (!is.null(facet_nrow) || !is.null(facet_ncol)) {
    # User explicitly specified nrow or ncol - use those
    p <- p + ggplot2::facet_wrap(~Type, nrow = facet_nrow, ncol = facet_ncol, scales = scales_setting)
  } else {
    # Use layout parameter to determine nrow/ncol
    if (facet_layout == "horizontal") {
      p <- p + ggplot2::facet_wrap(~Type, nrow = 1, scales = scales_setting)
    } else {
      p <- p + ggplot2::facet_wrap(~Type, ncol = 1, scales = scales_setting)
    }
  }

  return(p)
}

#' Create Faceted Heatmap for Multiple What Values
#'
#' Creates a heatmap with facets for different data types (means, variances, ratio).
#'
#' @param analysis_data Standardized GM analysis data
#' @param what Character vector: values from c("means", "variances", "ratio")
#' @param cutoff Threshold for highlighting
#' @param orientation Character: "horizontal" or "vertical"
#' @param variable_order Character: variable ordering method
#' @param top_k Integer: maximum number of variables to display
#' @param centering Character: centering method (only for means)
#' @param layout Character: "auto", "horizontal", or "vertical" for facet layout
#' @param title Plot title (optional)
#' @return ggplot2 object with facets
#' @keywords internal
create_heatmap_gm_faceted <- function(analysis_data, what, cutoff = 0.3, orientation = "horizontal",
                                       variable_order = "variance", top_k = Inf, centering = "none",
                                       layout = "auto", facet_nrow = NULL, facet_ncol = NULL, title = NULL) {
  # Combine data from all what values
  data_list <- lapply(what, function(w) {
    # Extract appropriate data matrix
    if (w == "means") {
      data_matrix <- analysis_data$means
      if (centering != "none") {
        data_matrix <- apply_centering(data_matrix, centering)
      }
    } else if (w == "variances") {
      data_matrix <- extract_variance_matrix(analysis_data)
    } else {  # w == "ratio"
      data_matrix <- extract_variance_ratio_matrix(analysis_data)
    }

    # Limit to top k variables if needed
    if (analysis_data$n_variables > top_k) {
      var_variances <- apply(data_matrix, 1, var)
      top_var_idx <- order(var_variances, decreasing = TRUE)[1:top_k]
      data_matrix <- data_matrix[top_var_idx, , drop = FALSE]
      var_names <- analysis_data$variable_names[top_var_idx]
    } else {
      var_names <- analysis_data$variable_names
    }

    # Prepare data for plotting
    plot_df <- as.data.frame(data_matrix)
    colnames(plot_df) <- analysis_data$cluster_names
    plot_df$Variable <- var_names

    # Reshape to long format
    plot_data <- tidyr::pivot_longer(
      plot_df,
      cols = -Variable,
      names_to = "Cluster",
      values_to = "Value"
    )

    # Preserve cluster order
    plot_data$Cluster <- factor(plot_data$Cluster, levels = analysis_data$cluster_names)

    # Add what type
    plot_data$Type <- w

    return(plot_data)
  })

  # Combine all data
  combined_data <- do.call(rbind, data_list)

  # Apply variable ordering (using first what type for ordering)
  if (variable_order != "original") {
    first_type_data <- combined_data[combined_data$Type == what[1], ]
    if (variable_order == "variance") {
      var_importance <- aggregate(Value ~ Variable, first_type_data, var)
      var_levels <- var_importance$Variable[order(var_importance[[2]], decreasing = TRUE)]
    } else if (variable_order == "variance_reversed") {
      var_importance <- aggregate(Value ~ Variable, first_type_data, var)
      var_levels <- var_importance$Variable[order(var_importance[[2]], decreasing = FALSE)]
    } else if (variable_order == "mean") {
      var_means <- aggregate(Value ~ Variable, first_type_data, mean)
      var_levels <- var_means$Variable[order(var_means[[2]], decreasing = FALSE)]
    } else if (variable_order == "mean_reversed") {
      var_means <- aggregate(Value ~ Variable, first_type_data, mean)
      var_levels <- var_means$Variable[order(var_means[[2]], decreasing = TRUE)]
    } else if (variable_order == "alphabetical") {
      var_levels <- sort(unique(combined_data$Variable))
    } else if (variable_order == "alphabetical_reversed") {
      var_levels <- sort(unique(combined_data$Variable), decreasing = TRUE)
    } else {  # "original_reversed"
      var_levels <- rev(unique(combined_data$Variable))
    }
    combined_data$Variable <- factor(combined_data$Variable, levels = var_levels)
  }

  # Create facet labels
  type_labels <- c(
    "means" = "Cluster Means",
    "variances" = "Within-Cluster SD",
    "ratio" = "Discrimination Ratio"
  )
  combined_data$Type <- factor(combined_data$Type, levels = what, labels = type_labels[what])

  # Apply cutoff and determine significance
  combined_data$Significant <- sapply(1:nrow(combined_data), function(i) {
    if (combined_data$Type[i] == type_labels["means"]) {
      abs(combined_data$Value[i]) >= cutoff
    } else {
      combined_data$Value[i] >= cutoff
    }
  })

  # Determine facet layout
  if (layout == "auto") {
    facet_layout <- "horizontal"  # Always horizontal (one row) for auto
  } else {
    facet_layout <- layout
  }

  # Set up axes based on orientation
  if (orientation == "horizontal") {
    x_var <- "Variable"
    y_var <- "Cluster"
    x_angle <- 45
  } else {
    x_var <- "Cluster"
    y_var <- "Variable"
    x_angle <- 45
  }

  # Create heatmap with facets - use free scales for each facet
  p <- ggplot2::ggplot(
    combined_data,
    ggplot2::aes(x = .data[[x_var]], y = .data[[y_var]], fill = Value)
  ) +
    ggplot2::geom_tile(color = "white", linewidth = 0.5) +
    ggplot2::scale_fill_gradient2(
      low = psychinterpreter_colors("diverging")[1],
      mid = "white",
      high = psychinterpreter_colors("diverging")[3],
      midpoint = 0,
      name = "Value"
    ) +
    theme_psychinterpreter() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = x_angle, hjust = 1),
      panel.grid = ggplot2::element_blank()
    ) +
    ggplot2::labs(
      title = title %||% "Cluster Profiles: Heatmap (Faceted)",
      subtitle = paste0("Gaussian Mixture Model with ", analysis_data$n_clusters, " clusters"),
      x = if (orientation == "horizontal") "Variable" else "Cluster",
      y = if (orientation == "horizontal") "Cluster" else "Variable"
    )

  # Add facets with appropriate scale freedom based on orientation
  if (orientation == "horizontal") {
    # Variables on x-axis: keep x fixed (shared variable labels), free y (different value scales)
    scales_setting <- "free_y"
  } else {
    # Variables on y-axis: keep y fixed (shared variable labels), free x (different value scales)
    scales_setting <- "free_x"
  }

  # Apply faceting with user-specified nrow/ncol if provided
  if (!is.null(facet_nrow) || !is.null(facet_ncol)) {
    # User explicitly specified nrow or ncol - use those
    p <- p + ggplot2::facet_wrap(~Type, nrow = facet_nrow, ncol = facet_ncol, scales = scales_setting)
  } else {
    # Use layout parameter to determine nrow/ncol
    if (facet_layout == "horizontal") {
      p <- p + ggplot2::facet_wrap(~Type, nrow = 1, scales = scales_setting)
    } else {
      p <- p + ggplot2::facet_wrap(~Type, ncol = 1, scales = scales_setting)
    }
  }

  # Add text for significant values
  if (any(combined_data$Significant)) {
    p <- p + ggplot2::geom_text(
      data = combined_data[combined_data$Significant, ],
      ggplot2::aes(label = round(Value, 2)),
      color = "black",
      size = 3
    )
  }

  return(p)
}

#' Filter Variables for GM Visualization
#'
#' Helper function to filter analysis_data to specific variables.
#'
#' @param analysis_data Standardized GM analysis data
#' @param var_indices Indices of variables to keep
#' @return Modified analysis_data with filtered variables
#' @keywords internal
filter_variables_gm <- function(analysis_data, var_indices) {
  analysis_data$means <- analysis_data$means[var_indices, , drop = FALSE]
  analysis_data$variable_names <- analysis_data$variable_names[var_indices]
  analysis_data$n_variables <- length(var_indices)

  if (!is.null(analysis_data$covariances)) {
    analysis_data$covariances <- analysis_data$covariances[
      var_indices, var_indices, , drop = FALSE
    ]
  }

  return(analysis_data)
}

#' Extract Variance Matrix from GM Analysis Data
#'
#' Extracts within-cluster standard deviations from covariance matrices.
#'
#' @param analysis_data Standardized GM analysis data containing covariances
#' @return Matrix of standard deviations (n_variables x n_clusters)
#' @keywords internal
extract_variance_matrix <- function(analysis_data) {
  if (is.null(analysis_data$covariances)) {
    cli::cli_abort("Covariance matrices not available in analysis_data")
  }

  # Extract standard deviations (sqrt of diagonal) from each cluster's covariance matrix
  sds_matrix <- matrix(
    NA,
    nrow = analysis_data$n_variables,
    ncol = analysis_data$n_clusters
  )

  for (k in seq_len(analysis_data$n_clusters)) {
    sds_matrix[, k] <- sqrt(diag(analysis_data$covariances[, , k]))
  }

  # Set row names to match variable names
  rownames(sds_matrix) <- analysis_data$variable_names

  return(sds_matrix)
}

#' Extract Variance Ratio Matrix from GM Analysis Data
#'
#' Calculates between-cluster to within-cluster variance ratios for each variable.
#' Higher ratios indicate variables that better discriminate between clusters.
#'
#' @param analysis_data Standardized GM analysis data containing means and covariances
#' @return Matrix of variance ratios (n_variables x n_clusters)
#' @keywords internal
extract_variance_ratio_matrix <- function(analysis_data) {
  if (is.null(analysis_data$covariances)) {
    cli::cli_abort("Covariance matrices not available in analysis_data")
  }

  # Calculate between-cluster variance (variance of means across clusters)
  between_var <- apply(analysis_data$means, 1, var)

  # Calculate within-cluster variance (average variance within clusters)
  sds_matrix <- extract_variance_matrix(analysis_data)
  within_var <- apply(sds_matrix^2, 1, mean)  # Average variance across clusters

  # Calculate ratio: between / within (like F-ratio in ANOVA)
  # Higher values = better discrimination
  ratio_vector <- between_var / (within_var + 1e-10)  # Add small constant to avoid division by zero

  # Create matrix by replicating ratio for each cluster (for consistent plotting interface)
  ratio_matrix <- matrix(
    rep(ratio_vector, analysis_data$n_clusters),
    nrow = analysis_data$n_variables,
    ncol = analysis_data$n_clusters
  )

  return(ratio_matrix)
}

#' Apply Centering to Data Matrix
#'
#' Centers the data matrix by variable mean, global mean, or not at all.
#'
#' @param data_matrix Numeric matrix (n_variables x n_clusters)
#' @param centering Character: "none" (no centering), "variable" (center each variable
#'   by its row mean), or "global" (center all values by grand mean)
#' @return Centered data matrix with same dimensions
#' @keywords internal
apply_centering <- function(data_matrix, centering = "none") {
  if (centering == "none") {
    return(data_matrix)
  } else if (centering == "variable") {
    # Center each variable by its mean across clusters
    row_means <- rowMeans(data_matrix)
    centered_matrix <- data_matrix - row_means
    return(centered_matrix)
  } else if (centering == "global") {
    # Center all values by the grand mean
    grand_mean <- mean(data_matrix)
    centered_matrix <- data_matrix - grand_mean
    return(centered_matrix)
  } else {
    cli::cli_abort("{.arg centering} must be 'none', 'variable', or 'global', not {.val {centering}}")
  }
}

#' Create Cluster Profile Plot
#'
#' Standalone function to create cluster profile visualizations.
#' Note: This function only supports visualizing means. For variance and ratio
#' visualizations, use plot.gm_interpretation() with a fitted model object.
#'
#' @param means Matrix of cluster means (variables x clusters)
#' @param variable_names Character vector of variable names
#' @param cluster_names Character vector of cluster names
#' @param plot_type Type of plot: "heatmap", "parallel", or "radar"
#' @param what Character: must be "means" (default and only supported value for standalone function)
#' @param cutoff Threshold for highlighting important values
#' @param orientation Character: "horizontal" (variables on x-axis, default) or
#'   "vertical" (clusters/values on x-axis). Affects heatmap and parallel plots.
#' @param variable_order Character: "variance" (default) orders by variance descending,
#'   "variance_reversed" by variance ascending, "mean" orders by mean value ascending,
#'   "mean_reversed" by mean value descending, "original" preserves data order,
#'   "original_reversed" reverses data order, "alphabetical" sorts A-Z,
#'   "alphabetical_reversed" sorts Z-A. Cluster order is always fixed to input order.
#' @param top_k Integer: maximum number of variables to display (default: Inf, shows all variables).
#'   If there are more variables than this limit, only the top k most variable features (by variance) will be shown.
#'   Applies to all plot types.
#' @param title Plot title
#'
#' @return For heatmap/parallel: a ggplot2 object. For radar: a recordedplot
#'   object (base R graphics created with fmsb::radarchart).
#' @export
#'
#' @examples
#' \dontrun{
#' # Create sample data
#' means <- matrix(rnorm(15), nrow = 5, ncol = 3)
#' var_names <- paste0("Var", 1:5)
#' cluster_names <- paste0("Cluster_", 1:3)
#'
#' # Create heatmap with default horizontal orientation
#' p <- create_cluster_profile_plot(
#'   means, var_names, cluster_names,
#'   plot_type = "heatmap"
#' )
#' print(p)
#'
#' # Create heatmap with vertical orientation
#' p <- create_cluster_profile_plot(
#'   means, var_names, cluster_names,
#'   plot_type = "heatmap",
#'   orientation = "vertical"
#' )
#' print(p)
#' }
create_cluster_profile_plot <- function(
    means,
    variable_names = NULL,
    cluster_names = NULL,
    plot_type = "heatmap",
    what = "means",
    cutoff = 0.3,
    orientation = "horizontal",
    variable_order = "variance",
    top_k = Inf,
    title = NULL) {

  # Validate orientation parameter
  if (!orientation %in% c("horizontal", "vertical")) {
    cli::cli_abort("orientation must be 'horizontal' or 'vertical'")
  }

  # Validate what parameter - only "means" supported in standalone function
  if (what != "means") {
    cli::cli_warn("Standalone function only supports what='means'. For variance/ratio visualizations, use plot.gm_interpretation() with a fitted model object.")
    what <- "means"
  }

  # Validate variable_order parameter
  valid_orders <- c("variance", "variance_reversed", "mean", "mean_reversed",
                   "original", "original_reversed", "alphabetical", "alphabetical_reversed")
  if (!variable_order %in% valid_orders) {
    cli::cli_abort("{.arg variable_order} must be one of: {.val {valid_orders}}, not {.val {variable_order}}")
  }

  # Prepare analysis_data structure for plotting functions
  if (is.null(variable_names)) {
    variable_names <- paste0("V", seq_len(nrow(means)))
  }
  if (is.null(cluster_names)) {
    cluster_names <- paste0("Cluster_", seq_len(ncol(means)))
  }

  analysis_data <- list(
    means = as.matrix(means),
    variable_names = variable_names,
    cluster_names = cluster_names,
    n_clusters = ncol(means),
    n_variables = nrow(means),
    proportions = NULL
  )

  # Create appropriate plot
  if (plot_type == "heatmap") {
    return(create_heatmap_gm(analysis_data, what, cutoff, orientation, variable_order, top_k, centering = "none", title))
  } else if (plot_type == "parallel") {
    return(create_parallel_plot_gm(analysis_data, what, cutoff, orientation, variable_order, top_k, centering = "none", title))
  } else if (plot_type == "radar") {
    return(create_radar_plot_gm(analysis_data, what, cutoff, variable_order, top_k, centering = "none", title))
  } else {
    cli::cli_abort("Invalid plot_type: must be 'heatmap', 'parallel', or 'radar'")
  }
}