# Tests for visualization functions
# NOTE: Using sample_interpretation() fixture to avoid LLM calls

test_that("plot.fa_interpretation requires ggplot2", {
  results <- sample_interpretation()

  # Test that ggplot2 requirement is checked
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    expect_error(
      plot(results),
      "ggplot2.*required"
    )
  }
})

test_that("plot.fa_interpretation validates input object", {
  skip_if_not_installed("ggplot2")

  # Test with wrong object type
  bad_object <- list(data = "test")
  class(bad_object) <- c("fa_interpretation", "list")  # Set class to trigger method

  expect_error(
    plot(bad_object),
    "must contain.*loading_matrix"
  )

  # Test with fa_interpretation object missing loading_matrix
  bad_object <- list(suggested_names = list())
  class(bad_object) <- c("fa_interpretation", "list")

  expect_error(
    plot(bad_object),
    "must contain a 'loading_matrix'"
  )
})

test_that("plot.fa_interpretation creates ggplot object", {
  skip_if_not_installed("ggplot2")

  results <- sample_interpretation()

  # Create plot
  p <- plot(results)

  # Check it's a ggplot object
  expect_s3_class(p, "ggplot")
  expect_s3_class(p, "gg")
})

test_that("plot.fa_interpretation uses default heatmap type", {
  skip_if_not_installed("ggplot2")

  results <- sample_interpretation()

  # Create plot without specifying type
  p <- plot(results)

  # Should create a heatmap
  expect_s3_class(p, "ggplot")

  # Check for expected elements in the plot
  expect_true("GeomTile" %in% class(p$layers[[1]]$geom))
})

test_that("plot.fa_interpretation rejects unsupported plot types", {
  skip_if_not_installed("ggplot2")

  results <- sample_interpretation()

  # Test with unsupported type
  expect_error(
    plot(results, type = "barplot"),
    "Unsupported plot type"
  )

  expect_error(
    plot(results, type = "scatterplot"),
    "Unsupported plot type"
  )
})

test_that("plot.fa_interpretation uses stored cutoff by default", {
  skip_if_not_installed("ggplot2")

  # Use cached interpretation result
  results <- sample_interpretation()

  # Create plot without specifying cutoff
  p <- plot(results)

  # Check that plot has a caption with loading threshold information
  caption <- p$labels$caption
  expect_true(grepl("Black outline indicates", caption, ignore.case = TRUE))
  # Should contain a numeric cutoff value (e.g., "0.3" or "0.35")
  expect_true(grepl("0\\.[0-9]+", caption))
})

test_that("plot.fa_interpretation allows cutoff override", {
  skip_if_not_installed("ggplot2")

  # Use cached interpretation result
  results <- sample_interpretation()

  # Create plot with custom cutoff
  p <- plot(results, cutoff = 0.5)

  # Check that the custom cutoff is used in the caption
  caption <- p$labels$caption
  expect_true(grepl("0.5", caption))
})

test_that("plot.fa_interpretation uses suggested factor names", {
  skip_if_not_installed("ggplot2")

  results <- sample_interpretation()

  # Create plot
  p <- plot(results)

  # Check that plot data includes the suggested names
  plot_data <- p$data
  expect_true("factor" %in% names(plot_data))

  # If suggested names exist, they should be in the factor column
  if (!is.null(results$suggested_names) && length(results$suggested_names) > 0) {
    suggested_names <- unlist(results$suggested_names)
    # At least some suggested names should appear in the plot data
    expect_true(any(suggested_names %in% unique(plot_data$factor)))
  }
})

test_that("plot.fa_interpretation can be further customized", {
  skip_if_not_installed("ggplot2")

  library(ggplot2)

  # Use cached interpretation result
  results <- sample_interpretation()

  # Create plot and add custom elements
  p <- plot(results) +
    labs(title = "Custom Title") +
    theme(axis.text.y = element_text(size = 6))

  # Check that customization worked
  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$title, "Custom Title")
})

test_that("plot.fa_interpretation handles empty strings in loadings", {
  skip_if_not_installed("ggplot2")

  results <- sample_interpretation()

  # Create plot (should handle empty strings in loading_matrix)
  p <- plot(results)

  # Should create plot without errors
  expect_s3_class(p, "ggplot")

  # Plot data should convert empty strings to 0
  plot_data <- p$data
  expect_true(all(is.numeric(plot_data$loading_num)))
})

# ==============================================================================
# TESTS FOR create_factor_plot() - Backward Compatible Wrapper
# ==============================================================================

test_that("create_factor_plot is a wrapper for plot method", {
  skip_if_not_installed("ggplot2")

  results <- sample_interpretation()

  # Create plots using both methods
  p1 <- plot(results)
  p2 <- create_factor_plot(results)

  # Both should be ggplot objects
  expect_s3_class(p1, "ggplot")
  expect_s3_class(p2, "ggplot")

  # Data should be the same
  expect_equal(nrow(p1$data), nrow(p2$data))
})

test_that("create_factor_plot accepts plot_type parameter", {
  skip_if_not_installed("ggplot2")

  results <- sample_interpretation()

  # Create plot with explicit type
  p <- create_factor_plot(results, plot_type = "heatmap")

  expect_s3_class(p, "ggplot")
})

test_that("create_factor_plot accepts cutoff parameter", {
  skip_if_not_installed("ggplot2")

  results <- sample_interpretation()

  # Create plot with custom cutoff
  p <- create_factor_plot(results, cutoff = 0.45)

  # Check that cutoff is used in caption
  caption <- p$labels$caption
  expect_true(grepl("0.45", caption))
})

test_that("create_factor_plot produces same result as plot method", {
  skip_if_not_installed("ggplot2")

  results <- sample_interpretation()

  # Create plots with same parameters
  p1 <- plot(results, cutoff = 0.4)
  p2 <- create_factor_plot(results, plot_type = "heatmap", cutoff = 0.4)

  # Check that key elements match
  expect_equal(p1$labels$caption, p2$labels$caption)
  expect_equal(nrow(p1$data), nrow(p2$data))
  expect_equal(names(p1$data), names(p2$data))
})
