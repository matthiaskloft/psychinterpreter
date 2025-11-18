# Tests for print.gm_interpretation

# ==============================================================================
# TESTS FOR print.gm_interpretation
# ==============================================================================

test_that("print.gm_interpretation validates input object", {
  # Test with wrong object type
  bad_object <- list(data = "test")
  class(bad_object) <- c("gm_interpretation", "interpretation", "list")  # Set class to trigger method

  expect_error(
    print(bad_object),
    "must contain.*report.*or.*component_summaries"
  )

  # Test with gm_interpretation object missing required components
  bad_object <- list()
  class(bad_object) <- c("gm_interpretation", "interpretation", "list")

  expect_error(
    print(bad_object),
    "must contain 'report' or 'component_summaries'"
  )
})

# NOTE: Using sample_gm_interpretation() fixture for remaining print tests
# to avoid LLM calls

test_that("print.gm_interpretation validates max_line_length parameter", {
  results <- sample_gm_interpretation()

  # Test invalid max_line_length values
  expect_error(
    print(results, max_line_length = "invalid"),
    "must be a single numeric value"
  )

  expect_error(
    print(results, max_line_length = c(60, 80)),
    "must be a single numeric value"
  )

  expect_error(
    print(results, max_line_length = 10),
    "must be between 20 and 300"
  )

  expect_error(
    print(results, max_line_length = 350),
    "must be between 20 and 300"
  )
})

test_that("print.gm_interpretation validates output_format parameter", {
  results <- sample_gm_interpretation()

  # Test invalid output_format values
  expect_error(
    print(results, output_format = "invalid"),
    "must be either 'cli' or 'markdown'"
  )

  expect_error(
    print(results, output_format = c("cli", "markdown")),
    "must be a single character string"
  )

  expect_error(
    print(results, output_format = 123),
    "must be a single character string"
  )
})

test_that("print.gm_interpretation validates heading_level parameter", {
  results <- sample_gm_interpretation()

  # Test invalid heading_level values
  expect_error(
    print(results, output_format = "markdown", heading_level = "invalid"),
    "must be a single numeric value"
  )

  expect_error(
    print(results, output_format = "markdown", heading_level = 0),
    "must be an integer between 1 and 6"
  )

  expect_error(
    print(results, output_format = "markdown", heading_level = 7),
    "must be an integer between 1 and 6"
  )

  expect_error(
    print(results, output_format = "markdown", heading_level = 2.5),
    "must be an integer between 1 and 6"
  )
})

test_that("print.gm_interpretation prints to console", {
  results <- sample_gm_interpretation()

  # Check that print produces output
  expect_output(
    print(results),
    "cluster"
  )
})

test_that("print.gm_interpretation returns invisible NULL", {
  results <- sample_gm_interpretation()

  # Check return value
  result <- print(results)
  expect_null(result)
})

test_that("print.gm_interpretation uses existing report by default", {
  results <- sample_gm_interpretation()

  # Capture output
  output <- capture.output(print(results))
  output_text <- paste(output, collapse = "\n")

  # Should contain cluster information
  expect_true(grepl("Cluster", output_text, ignore.case = TRUE))
})

test_that("print.gm_interpretation regenerates report when output_format specified", {
  results <- sample_gm_interpretation()

  # Print in markdown format
  output <- capture.output(print(results, output_format = "markdown"))
  output_text <- paste(output, collapse = "\n")

  # Markdown format should have heading markers
  expect_true(grepl("#", output_text))
})

test_that("print.gm_interpretation wraps text in cli format", {
  results <- sample_gm_interpretation()

  # Print with short line length
  output_short <- capture.output(print(results, max_line_length = 40))

  # Print with long line length
  output_long <- capture.output(print(results, max_line_length = 120))

  # Short line length should produce more lines
  expect_true(length(output_short) >= length(output_long))
})

test_that("print.gm_interpretation does not wrap markdown format", {
  results <- sample_gm_interpretation()

  # Print in markdown format with different line lengths
  output1 <- capture.output(print(results, output_format = "markdown", max_line_length = 40))
  output2 <- capture.output(print(results, output_format = "markdown", max_line_length = 120))

  # Line counts should be similar (no wrapping)
  expect_equal(length(output1), length(output2))
})

test_that("print.gm_interpretation respects heading_level parameter", {
  results <- sample_gm_interpretation()

  # Print with heading level 1
  output1 <- capture.output(print(results, output_format = "markdown", heading_level = 1))
  output1_text <- paste(output1, collapse = "\n")

  # Print with heading level 3
  output3 <- capture.output(print(results, output_format = "markdown", heading_level = 3))
  output3_text <- paste(output3, collapse = "\n")

  # Different heading levels should produce different output
  # Level 1 uses "# ", level 3 uses "### "
  expect_true(grepl("^# ", output1_text, perl = TRUE) || grepl("\n# ", output1_text, perl = TRUE))
  expect_true(grepl("^### ", output3_text, perl = TRUE) || grepl("\n### ", output3_text, perl = TRUE))
})

test_that("print.gm_interpretation respects suppress_heading parameter", {
  results <- sample_gm_interpretation()

  # Print with heading
  output_with <- capture.output(print(results, output_format = "markdown", suppress_heading = FALSE))
  output_with_text <- paste(output_with, collapse = "\n")

  # Print without heading
  output_without <- capture.output(print(results, output_format = "markdown", suppress_heading = TRUE))
  output_without_text <- paste(output_without, collapse = "\n")

  # Output without heading should be shorter
  expect_true(nchar(output_without_text) < nchar(output_with_text))
})
