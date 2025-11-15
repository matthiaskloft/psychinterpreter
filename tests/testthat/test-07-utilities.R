test_that("find_cross_loadings identifies cross-loading variables", {
  loadings <- sample_loadings()

  # Test with default cutoff (0.3)
  cross_loadings <- find_cross_loadings(loadings, cutoff = 0.3)

  # Check return structure (data frame)
  expect_s3_class(cross_loadings, "data.frame")
  expect_true(all(c("variable", "factors") %in% names(cross_loadings)) | nrow(cross_loadings) == 0)

  # With high cutoff, should have no cross-loadings
  no_cross <- find_cross_loadings(loadings, cutoff = 0.9)
  expect_equal(nrow(no_cross), 0)

  # With low cutoff, should detect cross-loadings
  many_cross <- find_cross_loadings(loadings, cutoff = 0.1)
  expect_true(nrow(many_cross) > 0)
})

test_that("find_no_loadings identifies variables with no significant loadings", {
  loadings <- sample_loadings()

  # Test with default cutoff (0.3)
  no_loadings <- find_no_loadings(loadings, cutoff = 0.3)

  # Check return structure (data frame)
  expect_s3_class(no_loadings, "data.frame")
  expect_true(all(c("variable", "highest_loading") %in% names(no_loadings)) | nrow(no_loadings) == 0)

  # With very high cutoff, should have some variables with no loadings
  many_no_load <- find_no_loadings(loadings, cutoff = 0.95)
  expect_true(nrow(many_no_load) > 0)

  # With very low cutoff, should have no variables with no loadings
  no_no_load <- find_no_loadings(loadings, cutoff = 0.01)
  expect_equal(nrow(no_no_load), 0)
})

test_that("leading zero removal works correctly for negative numbers", {
  # Test the new pattern for removing leading zeros
  # Pattern: sub("^(-?)0\\.", "\\1.", x)

  positive <- sprintf("%.3f", 0.456)
  expect_equal(sub("^(-?)0\\.", "\\1.", positive), ".456")

  negative <- sprintf("%.3f", -0.456)
  expect_equal(sub("^(-?)0\\.", "\\1.", negative), "-.456")

  # Test with actual cross-loadings output
  loadings <- data.frame(
    variable = c("test_var"),
    ML1 = c(0.456),
    ML2 = c(-0.123)
  )

  cross <- find_cross_loadings(loadings, cutoff = 0.1)
  if (nrow(cross) > 0) {
    # Check that the formatted values don't have leading zeros
    factors_str <- cross$factors[1]
    expect_false(grepl("-0\\.", factors_str))  # No "-0." pattern
    expect_false(grepl("\\(0\\.", factors_str))  # No "(0." pattern for positives
  }
})

test_that("utility functions handle edge cases", {
  # Empty loadings
  empty_loadings <- data.frame(variable = character(0))
  expect_equal(nrow(find_cross_loadings(empty_loadings)), 0)
  expect_equal(nrow(find_no_loadings(empty_loadings)), 0)

  # Single variable
  single_var <- data.frame(
    variable = "var1",
    ML1 = 0.8
  )
  expect_s3_class(find_cross_loadings(single_var), "data.frame")
  expect_s3_class(find_no_loadings(single_var), "data.frame")
})
