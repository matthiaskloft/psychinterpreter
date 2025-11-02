# ==============================================================================
# FA VISUALIZATION FUNCTIONS
# ==============================================================================
#
# This script provides visualization functions for Exploratory Factor Analysis
# results, particularly for output from the interpret_fa() function.
#
# Main Functions:
# - plot.fa_interpretation()  : S3 plot method for fa_interpretation objects
# - create_factor_plot()      : Standalone function (calls plot method)
#
# Future visualization functions can be added here.
# ==============================================================================

#' Plot Factor Analysis Interpretation Results
#'
#' S3 plot method for fa_interpretation objects created by interpret_fa().
#' Creates publication-ready visualizations of factor loadings.
#'
#' @param x An fa_interpretation object from interpret_fa()
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
#' - Uses a blue-white-red color scale (negative to positive loadings)
#' - Automatically handles suppressed small loadings (empty strings)
#' - Rotates factor names for better readability
#' - Scales variable names appropriately
#' - Highlights loadings above cutoff with a black outline
#'
#' @examples
#' \dontrun{
#' # Get interpretation results
#' results <- interpret_fa(loadings, variable_info, silent = TRUE)
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
#' @importFrom ggplot2 ggplot aes geom_tile scale_fill_gradient2 theme_minimal theme element_text element_blank labs
#'
#' @export
plot.fa_interpretation <- function(x, type = "heatmap", cutoff = NULL, ...) {

  # Check for required packages
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg ggplot2} is required for plotting",
      "i" = "Install it with: {.code install.packages('ggplot2')}"
    ))
  }

  # Validate input
  if (!inherits(x, "fa_interpretation")) {
    cli::cli_abort(c(
      "Input must be an fa_interpretation object",
      "i" = "This should be the output from interpret_fa()"
    ))
  }

  if (!"loading_matrix" %in% names(x)) {
    cli::cli_abort(c(
      "fa_interpretation object must contain a 'loading_matrix' component",
      "i" = "This should be the output from interpret_fa()"
    ))
  }

  # Use stored cutoff if not provided
  if (is.null(cutoff)) {
    if ("cutoff" %in% names(x)) {
      cutoff <- x$cutoff
    } else {
      cutoff <- 0.3  # Default fallback
    }
  }

  loadings_df <- x$loading_matrix

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
  if (!is.null(x$suggested_names) && length(x$suggested_names) > 0) {
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

  if (type == "heatmap") {
    p <- ggplot2::ggplot(loadings_long,
                         ggplot2::aes(x = factor, y = variable, fill = loading_num)) +
      ggplot2::geom_tile(color = "grey90", linewidth = 0.5) +
      ggplot2::geom_tile(data = loadings_long[loadings_long$is_significant, ],
                         ggplot2::aes(x = factor, y = variable),
                         color = "black", linewidth = 1, fill = NA) +
      ggplot2::scale_fill_gradient2(
        low = "blue",
        mid = "white",
        high = "red",
        midpoint = 0,
        limits = c(-1, 1),
        name = "Loading"
      ) +
      ggplot2::theme_minimal() +
      ggplot2::theme(
        axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
        axis.text.y = ggplot2::element_text(size = 8),
        panel.grid = ggplot2::element_blank(),
        axis.title = ggplot2::element_text(size = 12),
        plot.title = ggplot2::element_text(size = 14, hjust = 0.5)
      ) +
      ggplot2::labs(
        title = "Factor Loadings Heatmap",
        x = "Factor",
        y = "Variable",
        caption = paste0("Generated with interpret_fa() | Black outline indicates |loading| >= ", cutoff)
      )
  } else {
    cli::cli_abort(c(
      "Unsupported plot type: {.val {type}}",
      "i" = "Currently supported: {.val heatmap}",
      "i" = "Additional plot types may be added in future versions"
    ))
  }

  return(p)
}

#' Create a visual representation of factor loadings
#'
#' Standalone function wrapper for plot.fa_interpretation(). Creates visualizations
#' of factor analysis results. For new code, consider using the generic plot()
#' method instead: plot(interpretation_results).
#'
#' @param interpretation_results Results from interpret_fa() - an fa_interpretation object
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
#' - Uses a blue-white-red color scale (negative to positive loadings)
#' - Automatically handles suppressed small loadings (empty strings)
#' - Rotates factor names for better readability
#' - Scales variable names appropriately
#' - Highlights loadings above cutoff with a black outline
#'
#' @examples
#' \dontrun{
#' # Get interpretation results
#' results <- interpret_fa(loadings, variable_info, silent = TRUE)
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
create_factor_plot <- function(interpretation_results, plot_type = "heatmap", cutoff = NULL) {
  # Simply call the S3 plot method
  plot.fa_interpretation(interpretation_results, type = plot_type, cutoff = cutoff)
}
