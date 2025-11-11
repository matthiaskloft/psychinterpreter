# ==============================================================================
# FA-SPECIFIC VISUALIZATION FUNCTIONS
# ==============================================================================
#
# This script provides visualization functions specifically for Factor Analysis
# interpretations.
#
# Functions:
# - plot.fa_interpretation()      : S3 plot method for fa_interpretation objects
# - create_factor_plot()          : Standalone wrapper function
#
# Future model types will have parallel files (gm_visualization.R, etc.)
# ==============================================================================

#' Plot Factor Analysis Interpretation Results
#'
#' S3 plot method for fa_interpretation objects created by interpret().
#' Creates publication-ready visualizations of factor loadings.
#'
#' @param x An fa_interpretation object from interpret()
#' @param type Character. Type of plot to create. Currently supports:
#'   - "heatmap": Creates a heatmap of factor loadings (default)
#' @param cutoff Numeric. Cutoff value for highlighting significant loadings. If NULL (default),
#'   uses the cutoff value stored in the fa_interpretation object. Loadings with absolute
#'   values at or above this cutoff will be outlined with a black border.
#' @param ... Additional arguments (currently unused, reserved for future plot types)
#'
#' @return A ggplot object that can be displayed, saved, or further customized
#'
#' @details
#' The heatmap visualization:
#' - Uses LLM-generated suggested factor names (if available)
#' - Uses a color-blind friendly orange-white-blue scale (negative to positive loadings)
#' - Automatically handles suppressed small loadings (empty strings)
#' - Rotates factor names for better readability
#' - Scales variable names appropriately
#' - Highlights loadings above cutoff with a black outline
#' - Applies the custom theme_psychinterpreter() theme
#'
#' @examples
#' \dontrun{
#' # Get interpretation results
#' results <- interpret(
#'   fit_results = fa_result,
#'   variable_info = var_info,
#'   provider = "ollama",
#'   model = "gpt-oss:20b-cloud"
#' )
#'
#' # Use generic plot method with default cutoff
#' plot(results)
#'
#' # Override cutoff value
#' plot(results, cutoff = 0.4)
#'
#' # Save to file
#' p <- plot(results)
#' ggsave("factor_loadings.png", p, width = 10, height = 8, dpi = 300)
#' }
#'
#' @importFrom tidyr pivot_longer
#' @importFrom dplyr mutate
#' @importFrom cli cli_abort
#' @importFrom ggplot2 ggplot aes geom_tile geom_rect scale_fill_gradient2 theme_minimal theme element_text element_blank labs
#' @importFrom rlang .data
#'
#' @export
plot.fa_interpretation <- function(x,
                                   type = "heatmap",
                                   cutoff = NULL,
                                   ...) {
  # Check for required packages
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort(
      c("Package {.pkg ggplot2} is required for plotting", "i" = "Install it with: {.code install.packages('ggplot2')}")
    )
  }

  # Validate input
  if (!inherits(x, "fa_interpretation")) {
    cli::cli_abort(
      c("Input must be an fa_interpretation object", "i" = "This should be the output from interpret()")
    )
  }

  # Check for model_data and loadings_df (new structure after Phase 2-3 refactoring)
  if (!"model_data" %in% names(x) || !"loadings_df" %in% names(x$model_data)) {
    cli::cli_abort(
      c(
        "fa_interpretation object must contain model_data with loadings_df",
        "i" = "This should be the output from interpret()"
      )
    )
  }

  # Use stored cutoff if not provided
  if (is.null(cutoff)) {
    if ("model_data" %in% names(x) && "cutoff" %in% names(x$model_data)) {
      cutoff <- x$model_data$cutoff
    } else {
      cutoff <- 0.3  # Default fallback
    }
  }

  loadings_df <- x$model_data$loadings_df

  # Convert to long format for plotting
  loadings_long <- loadings_df |>
    tidyr::pivot_longer(cols = -variable,
                        names_to = "factor",
                        values_to = "loading") |>
    dplyr::mutate(
      loading_num = as.numeric(ifelse(loading == "", "0", loading)),
      is_significant = abs(loading_num) >= cutoff
    )

  # Replace factor names with LLM-generated suggested names if available
  if (!is.null(x$suggested_names) &&
      length(x$suggested_names) > 0) {
    # Create a mapping from original factor names to suggested names
    factor_name_map <- unlist(x$suggested_names)

    # Replace factor names in the data
    loadings_long <- loadings_long |>
      dplyr::mutate(factor = ifelse(
        factor %in% names(factor_name_map),
        factor_name_map[factor],
        factor
      ))
  }

  # Get unique factor and variable names in order they appear
  factor_levels <- unique(loadings_long$factor)
  variable_levels <- unique(loadings_long$variable)

  # Convert to factors with explicit levels to ensure order
  loadings_long <- loadings_long |>
    dplyr::mutate(
      factor = factor(factor, levels = factor_levels),
      variable = factor(variable, levels = variable_levels),
      factor_num = as.numeric(factor),
      variable_num = as.numeric(variable)
    )

  if (type == "heatmap") {
    # Get color-blind friendly palette
    colors <- psychinterpreter_colors("diverging")

    # Create data for significant loading borders
    sig_loadings <- loadings_long[loadings_long$is_significant, ]

    # define line_width
    line_width <- .6

    p <- ggplot2::ggplot(loadings_long,
                         ggplot2::aes(x = factor, y = variable, fill = loading_num)) +
      ggplot2::geom_tile(color = "grey90", linewidth = line_width) +
      ggplot2::geom_rect(
        data = sig_loadings,
        ggplot2::aes(
          xmin = .data$factor_num - 0.5,
          xmax = .data$factor_num + 0.5,
          ymin = .data$variable_num - 0.5,
          ymax = .data$variable_num + 0.5
        ),
        color = "black",
        linewidth = line_width,
        fill = NA,
        inherit.aes = FALSE,
        lineend = "round",
        linejoin = "round"
      ) +
      ggplot2::scale_fill_gradient2(
        low = colors$low,
        mid = colors$mid,
        high = colors$high,
        midpoint = 0,
        limits = c(-1, 1),
        name = "Loading"
      ) +
      theme_psychinterpreter() +
      ggplot2::theme(
        axis.text.x = ggplot2::element_text(
          angle = 30,
          hjust = 1,
          vjust = 1
        ),
        axis.text.y = ggplot2::element_text(size = ggplot2::rel(0.85))
      ) +
      ggplot2::labs(
        title = "Factor Loadings Heatmap",
        x = "Factor",
        y = "Variable",
        caption = paste0(
          "Black outline indicates |loading| \u2265 ",
          cutoff
        )
      )
  } else {
    cli::cli_abort(
      c(
        "Unsupported plot type: {.val {type}}",
        "i" = "Currently supported: {.val heatmap}",
        "i" = "Additional plot types may be added in future versions"
      )
    )
  }

  return(p)
}

#' Create a visual representation of factor loadings
#'
#' Standalone function wrapper for plot.fa_interpretation(). Creates visualizations
#' of factor analysis results. For new code, consider using the generic plot()
#' method instead: plot(interpretation_results).
#'
#' @param interpretation_results Results from interpret() - an fa_interpretation object
#' @param plot_type Character. Type of plot to create. Currently supports:
#'   - "heatmap": Creates a heatmap of factor loadings (default)
#' @param cutoff Numeric. Cutoff value for highlighting significant loadings. If NULL (default),
#'   uses the cutoff value stored in the fa_interpretation object. Loadings with absolute
#'   values at or above this cutoff will be outlined with a black border.
#'
#' @return A ggplot object that can be displayed, saved, or further customized
#'
#' @details
#' This function provides backward compatibility. New code should use the generic
#' plot() method: plot(interpretation_results).
#'
#' The heatmap visualization:
#' - Uses LLM-generated suggested factor names (if available)
#' - Uses a color-blind friendly orange-white-blue scale (negative to positive loadings)
#' - Automatically handles suppressed small loadings (empty strings)
#' - Rotates factor names for better readability
#' - Scales variable names appropriately
#' - Highlights loadings above cutoff with a black outline
#' - Applies the custom theme_psychinterpreter() theme
#'
#' @examples
#' \dontrun{
#' # Get interpretation results
#' results <- interpret(
#'   fit_results = fa_result,
#'   variable_info = var_info,
#'   provider = "ollama",
#'   model = "gpt-oss:20b-cloud"
#' )
#'
#' # Using this function (backward compatible)
#' p <- create_factor_plot(results)
#'
#' # Override cutoff value
#' p <- create_factor_plot(results, cutoff = 0.4)
#' print(p)
#' }
#'
#' @seealso \code{\link{plot.fa_interpretation}} for the S3 plot method
#'
#' @export
create_factor_plot <- function(interpretation_results,
                               plot_type = "heatmap",
                               cutoff = NULL) {
  # Simply call the S3 plot method
  plot.fa_interpretation(interpretation_results, type = plot_type, cutoff = cutoff)
}
