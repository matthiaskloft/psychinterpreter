# ==============================================================================
# SHARED VISUALIZATION UTILITIES
# ==============================================================================
#
# This script provides shared visualization utilities for all psychinterpreter
# model types (FA, GM, IRT, CDM).
#
# Functions:
# - psychinterpreter_colors()     : Color-blind friendly palette generator
# - theme_psychinterpreter()      : Custom ggplot theme for all visualizations
#
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
