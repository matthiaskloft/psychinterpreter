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
#' @param cutoff Numeric threshold for highlighting important values (default: 0.3)
#' @param variables Character vector of variables to include (NULL for all)
#' @param orientation Character: "horizontal" (variables on x-axis, default) or
#'   "vertical" (clusters/values on x-axis). Affects heatmap and parallel plots.
#' @param cluster_order Character: "alphabetical" (default) sorts cluster names alphabetically
#'   in parallel plots, "numerical" preserves original model order, "reverse" reverses the
#'   original model order. Only affects parallel plots.
#' @param ... Additional arguments passed to specific plot functions
#'
#' @return For heatmap/parallel: a ggplot2 object. For radar: a recordedplot object
#'   (base R graphics). For plot_type="all": a list containing all three plot types.
#' @export
#'
#' @examples
#' \dontrun{
#' # Basic plot (auto-selects best type)
#' plot(gm_interpretation)
#'
#' # Specific plot type
#' plot(gm_interpretation, plot_type = "heatmap")
#' plot(gm_interpretation, plot_type = "parallel")
#'
#' # Horizontal orientation (variables on x-axis, default)
#' plot(gm_interpretation, plot_type = "heatmap", orientation = "horizontal")
#' plot(gm_interpretation, plot_type = "parallel", orientation = "horizontal")
#'
#' # Vertical orientation (clusters/values on x-axis)
#' plot(gm_interpretation, plot_type = "heatmap", orientation = "vertical")
#' plot(gm_interpretation, plot_type = "parallel", orientation = "vertical")
#'
#' # Cluster ordering in parallel plots
#' plot(gm_interpretation, plot_type = "parallel", cluster_order = "alphabetical")
#' plot(gm_interpretation, plot_type = "parallel", cluster_order = "numerical")
#' plot(gm_interpretation, plot_type = "parallel", cluster_order = "reverse")
#'
#' # All plot types
#' plots <- plot(gm_interpretation, plot_type = "all")
#'
#' # Focus on specific variables
#' plot(gm_interpretation, variables = c("var1", "var2", "var3"))
#' }
plot.gm_interpretation <- function(
    x,
    plot_type = NULL,
    cutoff = 0.3,
    variables = NULL,
    orientation = "horizontal",
    cluster_order = "alphabetical",
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

  # Create appropriate plot(s)
  if (plot_type == "all") {
    plots <- list(
      heatmap = create_heatmap_gm(analysis_data, cutoff, orientation, ...),
      parallel = create_parallel_plot_gm(analysis_data, cutoff, orientation, cluster_order, ...),
      radar = create_radar_plot_gm(analysis_data, cutoff, ...)
    )
    return(plots)
  } else if (plot_type == "heatmap") {
    return(create_heatmap_gm(analysis_data, cutoff, orientation, ...))
  } else if (plot_type == "parallel") {
    return(create_parallel_plot_gm(analysis_data, cutoff, orientation, cluster_order, ...))
  } else if (plot_type == "radar") {
    return(create_radar_plot_gm(analysis_data, cutoff, ...))
  } else {
    cli::cli_abort("Invalid plot_type: must be 'auto', 'heatmap', 'parallel', 'radar', or 'all'")
  }
}

#' Create Heatmap for GM Clusters
#'
#' Creates a heatmap showing standardized means for each cluster.
#'
#' @param analysis_data Standardized GM analysis data
#' @param cutoff Threshold for highlighting
#' @param orientation Character: "horizontal" (variables on x-axis) or "vertical" (clusters on x-axis)
#' @param title Plot title (optional)
#' @return ggplot2 object
#' @keywords internal
create_heatmap_gm <- function(analysis_data, cutoff = 0.3, orientation = "horizontal", title = NULL) {
  # Prepare data for plotting
  means_df <- as.data.frame(analysis_data$means)
  colnames(means_df) <- analysis_data$cluster_names
  means_df$Variable <- analysis_data$variable_names

  # Reshape to long format
  plot_data <- tidyr::pivot_longer(
    means_df,
    cols = -Variable,
    names_to = "Cluster",
    values_to = "Mean"
  )

  # Preserve cluster order by converting to factor with correct levels
  plot_data$Cluster <- factor(plot_data$Cluster, levels = analysis_data$cluster_names)

  # Apply cutoff
  plot_data$Significant <- abs(plot_data$Mean) >= cutoff

  # Set up axes based on orientation
  if (orientation == "horizontal") {
    # Variables on x-axis (horizontal), clusters on y-axis
    x_var <- "Variable"
    y_var <- "Cluster"
    x_lab <- "Variable"
    y_lab <- "Cluster"
    x_angle <- 45
  } else {
    # Clusters on x-axis (vertical), variables on y-axis
    x_var <- "Cluster"
    y_var <- "Variable"
    x_lab <- "Cluster"
    y_lab <- "Variable"
    x_angle <- 45
  }

  # Create heatmap
  p <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = .data[[x_var]], y = .data[[y_var]], fill = Mean)
  ) +
    ggplot2::geom_tile(color = "white", linewidth = 0.5) +
    ggplot2::scale_fill_gradient2(
      low = psychinterpreter_colors("diverging")[1],
      mid = "white",
      high = psychinterpreter_colors("diverging")[3],
      midpoint = 0,
      limits = c(-max(abs(plot_data$Mean)), max(abs(plot_data$Mean))),
      name = "Mean\nValue"
    ) +
    theme_psychinterpreter() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = x_angle, hjust = 1),
      panel.grid = ggplot2::element_blank()
    ) +
    ggplot2::labs(
      title = title %||% "Cluster Profiles: Variable Means",
      subtitle = paste0("Gaussian Mixture Model with ", analysis_data$n_clusters, " clusters"),
      x = x_lab,
      y = y_lab
    )

  # Add text for significant values
  if (any(plot_data$Significant)) {
    p <- p + ggplot2::geom_text(
      data = plot_data[plot_data$Significant, ],
      ggplot2::aes(label = round(Mean, 2)),
      color = "black",
      size = 3
    )
  }

  return(p)
}

#' Create Parallel Coordinates Plot for GM Clusters
#'
#' Creates a parallel coordinates plot showing cluster profiles.
#'
#' @param analysis_data Standardized GM analysis data
#' @param cutoff Threshold for highlighting
#' @param orientation Character: "horizontal" (variables on x-axis, default) or "vertical" (variables on y-axis)
#' @param cluster_order Character: "alphabetical" (default) sorts cluster names alphabetically,
#'   "numerical" preserves original model order, "reverse" reverses the original model order
#' @param title Plot title (optional)
#' @return ggplot2 object
#' @keywords internal
create_parallel_plot_gm <- function(analysis_data, cutoff = 0.3, orientation = "horizontal",
                                     cluster_order = "alphabetical", title = NULL) {
  # Validate cluster_order parameter
  if (!cluster_order %in% c("alphabetical", "numerical", "reverse")) {
    cli::cli_abort("{.arg cluster_order} must be 'alphabetical', 'numerical', or 'reverse', not {.val {cluster_order}}")
  }

  # Determine cluster order
  if (cluster_order == "alphabetical") {
    cluster_levels <- sort(analysis_data$cluster_names)
  } else if (cluster_order == "reverse") {
    cluster_levels <- rev(analysis_data$cluster_names)
  } else {
    cluster_levels <- analysis_data$cluster_names
  }

  # Prepare data
  means_df <- as.data.frame(t(analysis_data$means))
  colnames(means_df) <- analysis_data$variable_names
  means_df$Cluster <- factor(
    analysis_data$cluster_names,
    levels = cluster_levels
  )

  # Add cluster size information
  if (!is.null(analysis_data$proportions)) {
    means_df$Size <- analysis_data$proportions
  } else {
    means_df$Size <- 1 / analysis_data$n_clusters
  }

  # Reshape to long format
  plot_data <- tidyr::pivot_longer(
    means_df,
    cols = -c(Cluster, Size),
    names_to = "Variable",
    values_to = "Value"
  )

  # Order variables by variance across clusters
  var_importance <- aggregate(Value ~ Variable, plot_data, var)
  var_order <- var_importance$Variable[order(var_importance$Value, decreasing = TRUE)]
  plot_data$Variable <- factor(plot_data$Variable, levels = var_order)

  # Set up axes and reference lines based on orientation
  if (orientation == "horizontal") {
    # Variables on x-axis (standard parallel coordinates)
    aes_mapping <- ggplot2::aes(x = Variable, y = Value, group = Cluster, color = Cluster)
    x_lab <- "Variable (ordered by variance)"
    y_lab <- "Standardized Mean"
    x_angle <- 45
    ref_line_layer <- list(
      ggplot2::geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5),
      ggplot2::geom_hline(yintercept = c(-cutoff, cutoff), linetype = "dotted", alpha = 0.3)
    )
  } else {
    # Variables on y-axis (rotated parallel coordinates)
    # Sort data by Cluster and Variable to ensure lines connect points correctly
    plot_data <- plot_data[order(plot_data$Cluster, plot_data$Variable), ]

    aes_mapping <- ggplot2::aes(x = Value, y = Variable, group = Cluster, color = Cluster)
    x_lab <- "Standardized Mean"
    y_lab <- "Variable (ordered by variance)"
    x_angle <- 0
    ref_line_layer <- list(
      ggplot2::geom_vline(xintercept = 0, linetype = "dashed", alpha = 0.5),
      ggplot2::geom_vline(xintercept = c(-cutoff, cutoff), linetype = "dotted", alpha = 0.3)
    )
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
      title = title %||% "Cluster Profiles: Parallel Coordinates",
      subtitle = paste0("Line thickness represents cluster size"),
      x = x_lab,
      y = y_lab
    ) +
    ref_line_layer

  return(p)
}

#' Create Radar Plot for GM Clusters
#'
#' Creates a radar/spider plot showing cluster profiles using fmsb::radarchart.
#'
#' @param analysis_data Standardized GM analysis data
#' @param cutoff Threshold for highlighting (not used in fmsb implementation)
#' @param title Plot title (optional)
#' @param ... Additional arguments passed to fmsb::radarchart
#' @return A recorded plot object (class "recordedplot")
#' @keywords internal
create_radar_plot_gm <- function(analysis_data, cutoff = 0.3, title = NULL, ...) {
  # Check if fmsb is available
  if (!requireNamespace("fmsb", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg fmsb} is required for radar plots. Install it with: install.packages('fmsb')")
  }

  # Limit to reasonable number of variables for radar plot
  if (analysis_data$n_variables > 15) {
    # Select top 15 most variable features
    var_sds <- apply(analysis_data$means, 1, sd)
    top_vars <- order(var_sds, decreasing = TRUE)[1:15]

    means_subset <- analysis_data$means[top_vars, , drop = FALSE]
    var_names_subset <- analysis_data$variable_names[top_vars]

    cli::cli_inform(
      "Radar plot limited to top 15 most variable features for clarity"
    )
  } else {
    means_subset <- analysis_data$means
    var_names_subset <- analysis_data$variable_names
  }

  # Inform if too many clusters for overlaid radar (best practice: 2-3 max)
  if (analysis_data$n_clusters > 3) {
    cli::cli_inform(
      "Overlaid radar plot may be difficult to read with {analysis_data$n_clusters} clusters. Consider using heatmap or parallel plot instead."
    )
  }

  # Prepare data for fmsb::radarchart
  # Format: first row = max, second row = min, remaining rows = data
  data_range <- range(means_subset)
  max_val <- ceiling(data_range[2])
  min_val <- floor(data_range[1])

  # Transpose means so variables are columns
  radar_data <- as.data.frame(t(means_subset))
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
    title = title %||% "Cluster Profiles: Radar Plot"
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

#' Create Cluster Profile Plot
#'
#' Standalone function to create cluster profile visualizations.
#'
#' @param means Matrix of cluster means (variables x clusters)
#' @param variable_names Character vector of variable names
#' @param cluster_names Character vector of cluster names
#' @param plot_type Type of plot: "heatmap", "parallel", or "radar"
#' @param cutoff Threshold for highlighting important values
#' @param orientation Character: "horizontal" (variables on x-axis, default) or
#'   "vertical" (clusters/values on x-axis). Affects heatmap and parallel plots.
#' @param cluster_order Character: "alphabetical" (default) sorts cluster names alphabetically
#'   in parallel plots, "numerical" preserves original order, "reverse" reverses the original
#'   order. Only affects parallel plots.
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
    cutoff = 0.3,
    orientation = "horizontal",
    cluster_order = "alphabetical",
    title = NULL) {

  # Validate orientation parameter
  if (!orientation %in% c("horizontal", "vertical")) {
    cli::cli_abort("orientation must be 'horizontal' or 'vertical'")
  }

  # Validate cluster_order parameter
  if (!cluster_order %in% c("alphabetical", "numerical", "reverse")) {
    cli::cli_abort("{.arg cluster_order} must be 'alphabetical', 'numerical', or 'reverse', not {.val {cluster_order}}")
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
    return(create_heatmap_gm(analysis_data, cutoff, orientation, title))
  } else if (plot_type == "parallel") {
    return(create_parallel_plot_gm(analysis_data, cutoff, orientation, cluster_order, title))
  } else if (plot_type == "radar") {
    return(create_radar_plot_gm(analysis_data, cutoff, title))
  } else {
    cli::cli_abort("Invalid plot_type: must be 'heatmap', 'parallel', or 'radar'")
  }
}