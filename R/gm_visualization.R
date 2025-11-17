# ===================================================================
# FILE: gm_visualization.R
# PURPOSE: Visualization functions for Gaussian Mixture Model interpretations
# ===================================================================

#' Plot GM Interpretation
#'
#' Creates visualizations of cluster profiles with multiple plot type options.
#'
#' @param x An object of class "gm_interpretation"
#' @param plot_type Character: "auto", "heatmap", "parallel", "radar", or "all"
#' @param cutoff Numeric threshold for highlighting important values (default: 0.3)
#' @param variables Character vector of variables to include (NULL for all)
#' @param ... Additional arguments passed to specific plot functions
#'
#' @return A ggplot2 object or list of plots if plot_type="all"
#' @export
#'
#' @examples
#' \dontrun{
#' # Basic plot (auto-selects best type)
#' plot(gm_interpretation)
#'
#' # Specific plot type
#' plot(gm_interpretation, plot_type = "heatmap")
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
    ...) {

  # Extract analysis data
  analysis_data <- x$analysis_data

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

  # Create appropriate plot(s)
  if (plot_type == "all") {
    plots <- list(
      heatmap = create_heatmap_gm(analysis_data, cutoff, ...),
      parallel = create_parallel_plot_gm(analysis_data, cutoff, ...),
      radar = create_radar_plot_gm(analysis_data, cutoff, ...)
    )
    return(plots)
  } else if (plot_type == "heatmap") {
    return(create_heatmap_gm(analysis_data, cutoff, ...))
  } else if (plot_type == "parallel") {
    return(create_parallel_plot_gm(analysis_data, cutoff, ...))
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
#' @param title Plot title (optional)
#' @return ggplot2 object
#' @keywords internal
create_heatmap_gm <- function(analysis_data, cutoff = 0.3, title = NULL) {
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

  # Apply cutoff
  plot_data$Significant <- abs(plot_data$Mean) >= cutoff

  # Create heatmap
  p <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = Cluster, y = Variable, fill = Mean)
  ) +
    ggplot2::geom_tile(color = "white", size = 0.5) +
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
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      panel.grid = ggplot2::element_blank()
    ) +
    ggplot2::labs(
      title = title %||% "Cluster Profiles: Variable Means",
      subtitle = paste0("Gaussian Mixture Model with ", analysis_data$n_clusters, " clusters"),
      x = "Cluster",
      y = "Variable"
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
#' @param title Plot title (optional)
#' @return ggplot2 object
#' @keywords internal
create_parallel_plot_gm <- function(analysis_data, cutoff = 0.3, title = NULL) {
  # Prepare data
  means_df <- as.data.frame(t(analysis_data$means))
  colnames(means_df) <- analysis_data$variable_names
  means_df$Cluster <- factor(
    analysis_data$cluster_names,
    levels = analysis_data$cluster_names
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

  # Create parallel coordinates plot
  p <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = Variable, y = Value, group = Cluster, color = Cluster)
  ) +
    ggplot2::geom_line(ggplot2::aes(size = Size), alpha = 0.7) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_color_manual(
      values = psychinterpreter_colors("categorical")[1:analysis_data$n_clusters]
    ) +
    ggplot2::scale_size_continuous(
      range = c(0.5, 2),
      guide = "none"
    ) +
    theme_psychinterpreter() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      legend.position = "right"
    ) +
    ggplot2::labs(
      title = title %||% "Cluster Profiles: Parallel Coordinates",
      subtitle = paste0("Line thickness represents cluster size"),
      x = "Variable (ordered by variance)",
      y = "Standardized Mean"
    ) +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5) +
    ggplot2::geom_hline(yintercept = c(-cutoff, cutoff), linetype = "dotted", alpha = 0.3)

  return(p)
}

#' Create Radar Plot for GM Clusters
#'
#' Creates radar/spider plots for cluster profiles.
#'
#' @param analysis_data Standardized GM analysis data
#' @param cutoff Threshold for highlighting
#' @param title Plot title (optional)
#' @return ggplot2 object or gridExtra arrangement
#' @keywords internal
create_radar_plot_gm <- function(analysis_data, cutoff = 0.3, title = NULL) {
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

  # Prepare data for radar plot
  plot_list <- list()

  for (k in seq_len(analysis_data$n_clusters)) {
    cluster_name <- analysis_data$cluster_names[k]
    cluster_means <- means_subset[, k]

    # Create data frame for this cluster
    cluster_df <- data.frame(
      Variable = var_names_subset,
      Value = cluster_means,
      Cluster = cluster_name
    )

    # Add first row at end to close the polygon
    cluster_df <- rbind(cluster_df, cluster_df[1, ])

    # Create individual radar plot
    p <- ggplot2::ggplot(
      cluster_df,
      ggplot2::aes(x = Variable, y = Value, group = Cluster)
    ) +
      ggplot2::coord_polar() +
      ggplot2::geom_polygon(
        fill = psychinterpreter_colors("categorical")[k],
        alpha = 0.3,
        color = psychinterpreter_colors("categorical")[k],
        size = 1
      ) +
      ggplot2::geom_point(
        color = psychinterpreter_colors("categorical")[k],
        size = 2
      ) +
      theme_psychinterpreter() +
      ggplot2::theme(
        axis.text.x = ggplot2::element_text(size = 8),
        panel.grid.major = ggplot2::element_line(color = "gray90"),
        panel.background = ggplot2::element_rect(fill = "white")
      ) +
      ggplot2::labs(
        title = cluster_name,
        subtitle = if (!is.null(analysis_data$proportions)) {
          paste0(round(analysis_data$proportions[k] * 100, 1), "% of observations")
        } else {
          ""
        }
      ) +
      ggplot2::ylim(
        min(analysis_data$means) - 0.5,
        max(analysis_data$means) + 0.5
      ) +
      ggplot2::geom_hline(
        yintercept = 0,
        linetype = "dashed",
        alpha = 0.5
      )

    plot_list[[k]] <- p
  }

  # Arrange plots in grid
  if (length(plot_list) == 1) {
    return(plot_list[[1]])
  } else {
    # Calculate grid dimensions
    n_cols <- ceiling(sqrt(length(plot_list)))
    n_rows <- ceiling(length(plot_list) / n_cols)

    # Create combined plot
    combined_plot <- gridExtra::grid.arrange(
      grobs = plot_list,
      ncol = n_cols,
      nrow = n_rows,
      top = grid::textGrob(
        title %||% "Cluster Profiles: Radar Plots",
        gp = grid::gpar(fontsize = 14, fontface = "bold")
      )
    )

    return(combined_plot)
  }
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
#' @param title Plot title
#'
#' @return ggplot2 object
#' @export
#'
#' @examples
#' \dontrun{
#' # Create sample data
#' means <- matrix(rnorm(15), nrow = 5, ncol = 3)
#' var_names <- paste0("Var", 1:5)
#' cluster_names <- paste0("Cluster_", 1:3)
#'
#' # Create heatmap
#' p <- create_cluster_profile_plot(
#'   means, var_names, cluster_names,
#'   plot_type = "heatmap"
#' )
#' print(p)
#' }
create_cluster_profile_plot <- function(
    means,
    variable_names = NULL,
    cluster_names = NULL,
    plot_type = "heatmap",
    cutoff = 0.3,
    title = NULL) {

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
    return(create_heatmap_gm(analysis_data, cutoff, title))
  } else if (plot_type == "parallel") {
    return(create_parallel_plot_gm(analysis_data, cutoff, title))
  } else if (plot_type == "radar") {
    return(create_radar_plot_gm(analysis_data, cutoff, title))
  } else {
    cli::cli_abort("Invalid plot_type: must be 'heatmap', 'parallel', or 'radar'")
  }
}