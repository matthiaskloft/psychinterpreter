# ==============================================================================
# FA VISUALIZATION FUNCTIONS
# ==============================================================================
#
# This script provides visualization functions for Exploratory Factor Analysis
# results, particularly for output from the interpret_fa() function.
#
# Main Functions:
# - plot.fa_interpretation()      : S3 plot method for fa_interpretation objects
# - create_factor_plot()          : Standalone function (calls plot method)
# - theme_psychinterpreter()      : Custom ggplot theme for package visualizations
# - psychinterpreter_colors()     : Color-blind friendly palette generator
#
# Future visualization functions can be added here.
# ==============================================================================

# ==============================================================================
# COLOR-BLIND FRIENDLY PALETTES
# ==============================================================================

#' Get Color-Blind Friendly Palettes for psychinterpreter Visualizations
#'
#' Provides color-blind friendly color palettes for use in package visualizations.
#' Uses scientifically validated color schemes that work well for deuteranopia,
#' protanopia, and tritanopia.
#'
#' @param palette Character. Type of palette to return:
#'   - "diverging": Blue-white-orange scale for loadings (default)
#'   - "sequential_blue": Sequential blue scale
#'   - "sequential_orange": Sequential orange scale
#'   - "categorical": Okabe-Ito categorical palette (up to 8 colors)
#'
#' @return A named list with color values:
#'   - For "diverging": list(low, mid, high)
#'   - For "sequential_*": character vector of colors
#'   - For "categorical": character vector of colors
#'
#' @details
#' The diverging palette uses:
#' - Low (negative): Dark orange (#D55E00)
#' - Mid (zero): White (#FFFFFF)
#' - High (positive): Deep blue (#0072B2)
#'
#' This orange-blue combination is distinguishable for all common forms of
#' color blindness and provides good contrast on both screen and print.
#'
#' The categorical palette is based on the Okabe-Ito palette, specifically
#' designed for color-blind accessibility.
#'
#' @references
#' Okabe, M., & Ito, K. (2008). Color Universal Design (CUD):
#' How to make figures and presentations that are friendly to Colorblind people.
#' https://jfly.uni-koeln.de/color/
#'
#' @examples
#' # Get diverging palette
#' cols <- psychinterpreter_colors("diverging")
#'
#' # Get categorical palette
#' cat_cols <- psychinterpreter_colors("categorical")
#'
#' @export
psychinterpreter_colors <- function(palette = "diverging") {
  palettes <- list(
    # Orange-white-blue diverging (color-blind friendly)
    # Negative loadings = orange, positive loadings = blue
    diverging = list(
      low = "#D55E00",
      # Orange (negative)
      mid = "#FFFFFF",
      # White (zero)
      high = "#0072B2"    # Blue (positive)
    ),

    # Sequential palettes
    sequential_blue = c(
      "#F7FBFF",
      "#DEEBF7",
      "#C6DBEF",
      "#9ECAE1",
      "#6BAED6",
      "#4292C6",
      "#2171B5",
      "#08519C",
      "#08306B"
    ),

    sequential_orange = c(
      "#FFF5EB",
      "#FEE6CE",
      "#FDD0A2",
      "#FDAE6B",
      "#FD8D3C",
      "#F16913",
      "#D94801",
      "#A63603",
      "#7F2704"
    ),

    # Okabe-Ito categorical palette (8 colors)
    categorical = c(
      "#E69F00",
      # Orange
      "#56B4E9",
      # Sky blue
      "#009E73",
      # Bluish green
      "#F0E442",
      # Yellow
      "#0072B2",
      # Blue
      "#D55E00",
      # Vermillion
      "#CC79A7",
      # Reddish purple
      "#000000"   # Black
    )
  )

  if (!palette %in% names(palettes)) {
    cli::cli_abort(
      c("Unknown palette: {.val {palette}}", "i" = "Available palettes: {.val {names(palettes)}}")
    )
  }

  return(palettes[[palette]])
}


# ==============================================================================
# CUSTOM GGPLOT THEME
# ==============================================================================

#' Custom ggplot2 Theme for psychinterpreter Visualizations
#'
#' A clean, publication-ready theme for psychinterpreter package visualizations.
#' Builds on theme_minimal() with customizations for better readability and
#' professional appearance.
#'
#' @param base_size Numeric. Base font size in points (default: 11)
#' @param base_family Character. Base font family (default: "")
#' @param base_line_size Numeric. Base line size (default: base_size/22)
#' @param base_rect_size Numeric. Base rectangle size (default: base_size/22)
#'
#' @return A ggplot2 theme object
#'
#' @details
#' Theme characteristics:
#' - Clean minimal design without gridlines
#' - Adequate spacing for readability
#' - Professional typography
#' - Consistent with APA style guidelines
#' - Optimized for both screen and print
#'
#' @examples
#' \dontrun{
#' library(ggplot2)
#'
#' # Apply to a single plot
#' ggplot(data, aes(x, y)) +
#'   geom_point() +
#'   theme_psychinterpreter()
#'
#' # Set as default theme for session
#' theme_set(theme_psychinterpreter())
#' }
#'
#' @importFrom ggplot2 theme_minimal theme element_text element_blank element_line element_rect unit rel margin
#'
#' @export
theme_psychinterpreter <- function(base_size = 11,
                                   base_family = "",
                                   base_line_size = base_size / 22,
                                   base_rect_size = base_size / 22) {
  ggplot2::theme_minimal(
    base_size = base_size,
    base_family = base_family,
    base_line_size = base_line_size,
    base_rect_size = base_rect_size
  ) +
    ggplot2::theme(
      # Remove all gridlines for cleaner appearance
      panel.grid.major = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),

      # Axis styling
      axis.line = ggplot2::element_line(colour = "grey20", linewidth = ggplot2::rel(0.5)),
      axis.ticks = ggplot2::element_line(colour = "grey20", linewidth = ggplot2::rel(0.5)),
      axis.text = ggplot2::element_text(colour = "grey30", size = ggplot2::rel(0.9)),
      axis.title = ggplot2::element_text(
        colour = "grey10",
        size = ggplot2::rel(1.0),
        face = "bold"
      ),

      # Plot title and caption
      plot.title = ggplot2::element_text(
        colour = "grey10",
        size = ggplot2::rel(1.2),
        face = "bold",
        hjust = 0.5,
        margin = ggplot2::margin(
          t = 0,
          r = 0,
          b = 10,
          l = 0,
          unit = "pt"
        )
      ),
      plot.subtitle = ggplot2::element_text(
        colour = "grey30",
        size = ggplot2::rel(1.0),
        hjust = 0.5,
        margin = ggplot2::margin(
          t = 0,
          r = 0,
          b = 8,
          l = 0,
          unit = "pt"
        )
      ),
      plot.caption = ggplot2::element_text(
        colour = "grey50",
        size = ggplot2::rel(0.8),
        hjust = 1,
        margin = ggplot2::margin(
          t = 10,
          r = 0,
          b = 0,
          l = 0,
          unit = "pt"
        )
      ),

      # Legend styling
      legend.title = ggplot2::element_text(
        colour = "grey10",
        size = ggplot2::rel(1.0),
        face = "bold"
      ),
      legend.text = ggplot2::element_text(colour = "grey30", size = ggplot2::rel(0.9)),
      legend.key = ggplot2::element_rect(fill = NA, colour = NA),
      legend.background = ggplot2::element_rect(fill = NA, colour = NA),

      # Facet styling
      strip.text = ggplot2::element_text(
        colour = "grey10",
        size = ggplot2::rel(1.0),
        face = "bold",
        margin = ggplot2::margin(
          t = 5,
          r = 5,
          b = 5,
          l = 5,
          unit = "pt"
        )
      ),
      strip.background = ggplot2::element_rect(fill = "grey95", colour = "grey80"),

      # Panel styling
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),

      # Margins
      plot.margin = ggplot2::unit(c(10, 10, 10, 10), "pt")
    )
}

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
      c("Input must be an fa_interpretation object", "i" = "This should be the output from interpret_fa()")
    )
  }

  if (!"loading_matrix" %in% names(x)) {
    cli::cli_abort(
      c(
        "fa_interpretation object must contain a 'loading_matrix' component",
        "i" = "This should be the output from interpret_fa()"
      )
    )
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
create_factor_plot <- function(interpretation_results,
                               plot_type = "heatmap",
                               cutoff = NULL) {
  # Simply call the S3 plot method
  plot.fa_interpretation(interpretation_results, type = plot_type, cutoff = cutoff)
}
