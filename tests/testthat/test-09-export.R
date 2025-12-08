# Tests for export_interpretation function
# NOTE: Using sample_interpretation() fixture to avoid LLM calls

test_that("export_interpretation validates input parameters", {
  # Test invalid interpretation_results
  expect_error(
    export_interpretation("not a list", format = "txt"),
    "must be a list"
  )

  expect_error(
    export_interpretation(NULL, format = "txt"),
    "must be a list"
  )

  # Test invalid format
  expect_error(
    export_interpretation(list(), format = "invalid"),
    "Unsupported format"
  )

  expect_error(
    export_interpretation(list(), format = "csv"),
    "Unsupported format"
  )

  # Test invalid file parameter
  expect_error(
    export_interpretation(list(), format = "txt", file = c("file1", "file2")),
    "must be a single character string"
  )

  expect_error(
    export_interpretation(list(), format = "txt", file = 123),
    "must be a single character string"
  )
})

test_that("export_interpretation handles file extensions correctly", {
  results <- sample_interpretation()

  # Test txt format without extension
  temp_file <- tempfile(pattern = "test_report", fileext = "")
  export_interpretation(results, format = "txt", file = temp_file, verbosity = 0)
  expect_true(file.exists(paste0(temp_file, ".txt")))
  unlink(paste0(temp_file, ".txt"))

  # Test txt format with .txt extension
  temp_file <- tempfile(pattern = "test_report", fileext = ".txt")
  export_interpretation(results, format = "txt", file = temp_file, verbosity = 0)
  expect_true(file.exists(temp_file))
  expect_false(file.exists(paste0(temp_file, ".txt")))  # Should not double-add
  unlink(temp_file)

  # Test md format without extension
  temp_file <- tempfile(pattern = "test_report", fileext = "")
  export_interpretation(results, format = "md", file = temp_file, verbosity = 0)
  expect_true(file.exists(paste0(temp_file, ".md")))
  unlink(paste0(temp_file, ".md"))

  # Test md format with .md extension
  temp_file <- tempfile(pattern = "test_report", fileext = ".md")
  export_interpretation(results, format = "md", file = temp_file, verbosity = 0)
  expect_true(file.exists(temp_file))
  expect_false(file.exists(paste0(temp_file, ".md")))  # Should not double-add
  unlink(temp_file)
})

test_that("export_interpretation replaces wrong extension with correct one", {
  results <- sample_interpretation()

  # Request txt but provide .md extension - should create .txt
  temp_file <- tempfile(pattern = "test_report", fileext = ".md")
  base_name <- tools::file_path_sans_ext(temp_file)

  export_interpretation(results, format = "txt", file = temp_file, verbosity = 0)
  expect_true(file.exists(paste0(base_name, ".txt")))
  expect_false(file.exists(temp_file))  # Original .md shouldn't exist
  unlink(paste0(base_name, ".txt"))

  # Request md but provide .txt extension - should create .md
  temp_file <- tempfile(pattern = "test_report", fileext = ".txt")
  base_name <- tools::file_path_sans_ext(temp_file)

  export_interpretation(results, format = "md", file = temp_file, verbosity = 0)
  expect_true(file.exists(paste0(base_name, ".md")))
  expect_false(file.exists(temp_file))  # Original .txt shouldn't exist
  unlink(paste0(base_name, ".md"))
})

test_that("export_interpretation checks directory existence", {
  results <- sample_interpretation()

  # Test with non-existent directory
  expect_error(
    export_interpretation(results, format = "txt",
                        file = "/nonexistent/directory/file.txt",
                        verbosity = 0),
    "Directory does not exist"
  )
})

test_that("export_interpretation creates valid text files", {
  results <- sample_interpretation()

  temp_file <- tempfile(pattern = "test_report", fileext = ".txt")
  export_interpretation(results, format = "txt", file = temp_file, verbosity = 0)

  # Check file exists and has content
  expect_true(file.exists(temp_file))
  content <- readLines(temp_file)
  expect_true(length(content) > 0)

  # Check that content includes factor information
  full_content <- paste(content, collapse = "\n")
  expect_true(grepl("Factor", full_content, ignore.case = TRUE))

  unlink(temp_file)
})

test_that("export_interpretation creates valid markdown files", {
  results <- sample_interpretation()

  temp_file <- tempfile(pattern = "test_report", fileext = ".md")
  export_interpretation(results, format = "md", file = temp_file, verbosity = 0)

  # Check file exists and has content
  expect_true(file.exists(temp_file))
  content <- readLines(temp_file)
  expect_true(length(content) > 0)

  # Check for markdown formatting
  full_content <- paste(content, collapse = "\n")
  expect_true(grepl("#", full_content))  # Should have markdown headers

  unlink(temp_file)
})

test_that("export_interpretation returns invisible TRUE", {
  results <- sample_interpretation()

  temp_file <- tempfile(pattern = "test_report", fileext = ".txt")

  # Check return value
  result <- export_interpretation(results, format = "txt", file = temp_file, verbosity = 0)
  expect_true(result)
  expect_invisible(
    export_interpretation(results, format = "txt", file = temp_file, verbosity = 0)
  )

  unlink(temp_file)
})

test_that("export_interpretation verbosity parameter works", {
  results <- sample_interpretation()

  temp_file <- tempfile(pattern = "test_report", fileext = ".txt")

  # With verbosity = 0, should not produce message
  expect_silent(
    export_interpretation(results, format = "txt", file = temp_file, verbosity = 0)
  )

  # With verbosity = 2, should produce success message
  expect_message(
    export_interpretation(results, format = "txt", file = temp_file, verbosity = 2),
    "Report exported"
  )

  unlink(temp_file)
})

test_that("export_interpretation works with tempdir paths", {
  results <- sample_interpretation()

  # Test with full directory path
  temp_dir <- tempdir()
  file_path <- file.path(temp_dir, "test_report")

  export_interpretation(results, format = "txt", file = file_path, verbosity = 0)
  expect_true(file.exists(paste0(file_path, ".txt")))

  unlink(paste0(file_path, ".txt"))
})
