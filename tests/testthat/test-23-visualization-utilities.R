# test-23-visualization-utilities.R
# Tests for visualization utility functions that were missing test coverage

library(psychinterpreter)

test_that("psychinterpreter_colors returns valid color palettes", {
  # Test diverging palette (returns a list)
  diverging <- psychinterpreter_colors("diverging")
  expect_type(diverging, "list")
  expect_equal(length(diverging), 3)
  expect_named(diverging, c("low", "mid", "high"))
  expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", unlist(diverging))))

  # Test categorical palette (Okabe-Ito)
  categorical <- psychinterpreter_colors("categorical")
  expect_type(categorical, "character")
  expect_equal(length(categorical), 8)
  expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", categorical)))

  # Test sequential blue palette
  seq_blue <- psychinterpreter_colors("sequential_blue")
  expect_type(seq_blue, "character")
  expect_equal(length(seq_blue), 9)  # 9 colors in the sequence
  expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", seq_blue)))

  # Test sequential orange palette
  seq_orange <- psychinterpreter_colors("sequential_orange")
  expect_type(seq_orange, "character")
  expect_equal(length(seq_orange), 9)  # 9 colors in the sequence
  expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", seq_orange)))

  # Test invalid palette error
  expect_error(
    psychinterpreter_colors("invalid"),
    "Unknown palette"
  )
})

test_that("theme_psychinterpreter returns valid ggplot2 theme", {
  skip_if_not_installed("ggplot2")

  theme_obj <- theme_psychinterpreter()

  # Check it's a theme object
  expect_s3_class(theme_obj, "theme")

  # Check it can be added to a plot
  library(ggplot2)
  p <- ggplot(mtcars, aes(x = mpg, y = wt)) + geom_point()
  expect_no_error(p + theme_obj)

  # Check specific theme elements are set
  expect_true("axis.text" %in% names(theme_obj))
  expect_true("panel.background" %in% names(theme_obj))
  expect_true("panel.grid.major" %in% names(theme_obj))
})

test_that("is.interpretation correctly identifies interpretation objects", {
  # Create a valid interpretation object with "interpretation" base class
  interp_obj <- structure(
    list(
      factor_names = list(MR1 = "Factor 1", MR2 = "Factor 2"),
      interpretations = list(MR1 = "Description 1", MR2 = "Description 2"),
      analysis_type = "fa"
    ),
    class = c("fa_interpretation", "interpretation")
  )

  # Test TRUE case
  expect_true(is.interpretation(interp_obj))

  # Test FALSE cases
  expect_false(is.interpretation(list(a = 1)))
  expect_false(is.interpretation(data.frame(x = 1)))
  expect_false(is.interpretation(NULL))
  expect_false(is.interpretation(42))
  expect_false(is.interpretation("not an interpretation"))

  # Test with other interpretation classes (future-proofing)
  gm_obj <- structure(list(), class = c("gm_interpretation", "interpretation"))
  expect_true(is.interpretation(gm_obj))
})

test_that("default_output_args returns correct defaults", {
  defaults <- default_output_args()

  # Check it's a list
  expect_type(defaults, "list")

  # Check expected fields exist
  expect_true("format" %in% names(defaults))
  expect_true("heading_level" %in% names(defaults))
  expect_true("suppress_heading" %in% names(defaults))
  expect_true("max_line_length" %in% names(defaults))
  expect_true("silent" %in% names(defaults))

  # Check default values
  expect_equal(defaults$format, "cli")
  expect_equal(defaults$heading_level, 1)  # Default is 1, not 2
  expect_false(defaults$suppress_heading)
  expect_equal(defaults$max_line_length, 80)
  expect_equal(defaults$silent, 0)

  # Check class
  expect_s3_class(defaults, "output_args")
})

# normalize_token_count is not exported, so it's tested indirectly through token tracking