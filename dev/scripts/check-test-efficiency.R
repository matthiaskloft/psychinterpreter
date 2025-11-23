#!/usr/bin/env Rscript
# ==============================================================================
# Test Efficiency Compliance Checker
# ==============================================================================
# Purpose: Verify that all LLM-dependent tests follow efficiency standards
# Usage: source("dev/scripts/check-test-efficiency.R")
# Last Updated: 2025-11-23
# ==============================================================================

# Setup ------------------------------------------------------------------------
if (!requireNamespace("cli", quietly = TRUE)) {
  stop("Package 'cli' is required. Install with: install.packages('cli')")
}

library(cli)

# Configuration ----------------------------------------------------------------
TEST_DIR <- "tests/testthat"
REQUIRED_WORD_LIMIT <- 20
EXEMPTION_PATTERNS <- c(
  "word_limit behavior",
  "testing word_limit",
  "validates word_limit",
  "provider-specific",
  "performance benchmark"
)

# Helper Functions -------------------------------------------------------------

#' Check if a line is an exemption comment
#' @param lines Character vector of lines to check
#' @param line_num Line number to check
#' @return Logical indicating if line is exempt
is_exemption <- function(lines, line_num) {
  # Check previous 5 lines for exemption comments
  start_line <- max(1, line_num - 5)
  context <- lines[start_line:line_num]

  any(vapply(EXEMPTION_PATTERNS, function(pattern) {
    any(grepl(pattern, context, ignore.case = TRUE))
  }, logical(1)))
}

#' Extract word_limit value from a line
#' @param line Character string containing word_limit assignment
#' @return Integer word_limit value or NULL
extract_word_limit <- function(line) {
  match <- regmatches(line, regexec("word_limit\\s*=\\s*(\\d+)", line))
  if (length(match[[1]]) > 1) {
    as.integer(match[[1]][2])
  } else {
    NULL
  }
}

#' Check if lines contain skip_on_ci() within context
#' @param lines Character vector of lines
#' @param start_line Start of context
#' @param end_line End of context
#' @return Logical
has_skip_on_ci <- function(lines, start_line, end_line) {
  context <- lines[start_line:end_line]
  any(grepl("skip_on_ci\\(\\)", context))
}

#' Check if test makes actual LLM calls
#' @param lines Character vector of lines
#' @param start_line Start of test block
#' @param end_line End of test block
#' @return Logical
makes_llm_call <- function(lines, start_line, end_line) {
  context <- lines[start_line:end_line]

  # Remove comment lines to avoid false positives from mentions in comments
  non_comment_context <- context[!grepl("^\\s*#", context)]

  # Check for interpret() or label_variables() calls (not in comments)
  has_interpret <- any(grepl("interpret\\s*\\(", non_comment_context))
  has_label <- any(grepl("label_variables\\s*\\(", non_comment_context))

  # Exclude if not actually calling LLM:
  # 1. Tests that expect errors (validation tests that fail before LLM)
  is_validation_test <- any(grepl("expect_error|expect_warning", non_comment_context))

  # 2. Tests that use mocks or only test utility functions
  is_mock <- any(grepl("build_system_prompt|build_main_prompt|mock_|llm_args\\(|interpretation_args\\(|output_args\\(|parse_|format_label|abbreviate_word|remove_label_|simplify_description|create_variable_labels", non_comment_context))

  # 3. Tests using cached fixtures (not making new LLM calls)
  uses_cached_fixture <- any(grepl("sample_interpretation\\(\\)|sample_interpretation_", non_comment_context))

  # 4. Only flag tests that explicitly have skip_if_no_llm or skip_on_ci (strong signal)
  # OR tests in integration test files (test-1X-*.R)
  file_context <- lines[max(1, start_line - 50):min(length(lines), start_line + 10)]
  likely_llm_test <- any(grepl("skip_if_no_llm|skip_on_ci", file_context))

  (has_interpret || has_label) && !is_validation_test && !is_mock && !uses_cached_fixture && likely_llm_test
}

#' Find test block boundaries
#' @param lines Character vector of lines
#' @param test_start Line number where test_that starts
#' @return List with start and end line numbers
find_test_block <- function(lines, test_start) {
  # Find opening brace
  open_brace <- test_start
  while (open_brace <= length(lines) && !grepl("\\{", lines[open_brace])) {
    open_brace <- open_brace + 1
  }

  # Count braces to find matching close
  brace_count <- 1
  current_line <- open_brace + 1

  while (current_line <= length(lines) && brace_count > 0) {
    line <- lines[current_line]
    brace_count <- brace_count + sum(gregexpr("\\{", line)[[1]] > 0)
    brace_count <- brace_count - sum(gregexpr("\\}", line)[[1]] > 0)

    if (brace_count == 0) break
    current_line <- current_line + 1
  }

  list(start = open_brace, end = current_line)
}

# Main Checking Logic ----------------------------------------------------------

#' Check a single test file for efficiency compliance
#' @param file_path Path to test file
#' @return List with issues found
check_test_file <- function(file_path) {
  lines <- readLines(file_path, warn = FALSE)
  file_name <- basename(file_path)
  issues <- list()

  # Find all test_that blocks
  test_starts <- grep("test_that\\(", lines)

  for (test_start in test_starts) {
    # Find test block boundaries
    block <- find_test_block(lines, test_start)

    # Check if this test makes LLM calls
    if (!makes_llm_call(lines, block$start, block$end)) {
      next
    }

    # Extract test name
    test_line <- lines[test_start]
    test_name_match <- regmatches(test_line, regexec('test_that\\("([^"]+)"', test_line))
    test_name <- if (length(test_name_match[[1]]) > 1) test_name_match[[1]][2] else "Unknown"

    # Check for word_limit in test block
    word_limit_lines <- grep("word_limit\\s*=", lines[block$start:block$end])

    if (length(word_limit_lines) > 0) {
      # Adjust line numbers to full file context
      actual_line_nums <- (block$start - 1) + word_limit_lines

      for (line_num in actual_line_nums) {
        line <- lines[line_num]
        limit <- extract_word_limit(line)

        if (!is.null(limit) && limit != REQUIRED_WORD_LIMIT) {
          # Check for exemption
          if (!is_exemption(lines, line_num)) {
            issues <- c(issues, list(list(
              file = file_name,
              line = line_num,
              test = test_name,
              type = "word_limit",
              detail = sprintf("word_limit = %d (should be 20)", limit)
            )))
          }
        }
      }
    } else {
      # Only flag missing word_limit if test actually calls interpret() with llm_provider
      # (not just testing data structures or internal methods)
      context <- lines[block$start:block$end]

      # Check for interpret() calls
      has_interpret <- any(grepl("interpret\\s*\\(", context))

      # Check if it's being called with llm_provider= or chat_session= parameter
      # (not just creating a chat_session with chat_session())
      has_llm_provider <- any(grepl("llm_provider\\s*=", context))
      has_chat_param <- any(grepl("chat_session\\s*=", context))  # Parameter to interpret()
      only_chat_constructor <- any(grepl("<-\\s*chat_session\\(", context))  # Just creating session

      # Flag if interpret() is called with provider OR with chat_session parameter
      # (but not if only creating a chat_session object)
      has_interpret_with_provider <- has_interpret && (has_llm_provider || (has_chat_param && !only_chat_constructor))

      # Additional check: if test only has chat_session constructor and no interpret(),
      # it's not an LLM test
      if (only_chat_constructor && !has_interpret) {
        has_interpret_with_provider <- FALSE
      }

      if (has_interpret_with_provider) {
        # LLM test without word_limit specified (will use default)
        issues <- c(issues, list(list(
          file = file_name,
          line = test_start,
          test = test_name,
          type = "missing_word_limit",
          detail = "LLM test should explicitly set word_limit = 20"
        )))
      }
    }

    # Check for skip_on_ci()
    if (!has_skip_on_ci(lines, block$start, block$end)) {
      issues <- c(issues, list(list(
        file = file_name,
        line = test_start,
        test = test_name,
        type = "missing_skip_on_ci",
        detail = "LLM test should use skip_on_ci()"
      )))
    }

    # Check for use of sample_* fixtures instead of minimal_*
    context <- lines[block$start:block$end]
    has_sample_fixture <- any(grepl("sample_fa_model\\(\\)|sample_loadings\\(\\)|sample_variable_info\\(\\)", context))
    has_minimal_fixture <- any(grepl("minimal_fa_model\\(\\)|minimal_loadings\\(\\)|minimal_variable_info\\(\\)", context))

    if (has_sample_fixture && !has_minimal_fixture) {
      issues <- c(issues, list(list(
        file = file_name,
        line = test_start,
        test = test_name,
        type = "inefficient_fixture",
        detail = "Use minimal_* fixtures instead of sample_* for LLM tests"
      )))
    }
  }

  issues
}

#' Run compliance check on all test files
#' @return Invisibly returns list of all issues
check_all_tests <- function() {
  cli_h1("Test Efficiency Compliance Check")
  cli_alert_info("Checking test files in {.path {TEST_DIR}}")
  cli_text("")

  # Find all test files
  test_files <- list.files(
    TEST_DIR,
    pattern = "^test-.*\\.R$",
    full.names = TRUE
  )

  if (length(test_files) == 0) {
    cli_alert_warning("No test files found in {.path {TEST_DIR}}")
    return(invisible(list()))
  }

  cli_alert_info("Found {length(test_files)} test files")
  cli_text("")

  # Check each file
  all_issues <- list()
  files_with_issues <- 0

  for (file in test_files) {
    issues <- check_test_file(file)
    if (length(issues) > 0) {
      all_issues <- c(all_issues, issues)
      files_with_issues <- files_with_issues + 1
    }
  }

  # Report results
  if (length(all_issues) == 0) {
    cli_alert_success("All tests pass efficiency standards! {col_green(symbol$tick)}")
    cli_text("")
    cli_alert_info("Compliance Status:")
    cli_ul(c(
      "{.strong 100%} of LLM tests use word_limit = 20",
      "{.strong 100%} of LLM tests use skip_on_ci()",
      "{.strong 100%} of LLM tests use minimal fixtures"
    ))
  } else {
    cli_alert_danger("Found {length(all_issues)} issue(s) in {files_with_issues} file(s)")
    cli_text("")

    # Group issues by type
    by_type <- split(all_issues, vapply(all_issues, function(x) x$type, character(1)))

    for (type in names(by_type)) {
      type_label <- switch(type,
        "word_limit" = "Suboptimal word_limit",
        "missing_word_limit" = "Missing word_limit",
        "missing_skip_on_ci" = "Missing skip_on_ci()",
        "inefficient_fixture" = "Inefficient fixture usage",
        type
      )

      cli_h2(type_label)

      for (issue in by_type[[type]]) {
        cli_alert_warning("{.file {issue$file}}:{issue$line}")
        cli_text("  {.strong Test}: {issue$test}")
        cli_text("  {.strong Issue}: {issue$detail}")
        cli_text("")
      }
    }

    # Provide remediation guidance
    cli_h2("Remediation Guide")
    cli_text("")

    if ("word_limit" %in% names(by_type) || "missing_word_limit" %in% names(by_type)) {
      cli_h3("Fix word_limit issues:")
      cli_text("")
      cli_text("  interpret(")
      cli_text("    fit_results = minimal_fa_model(),")
      cli_text("    variable_info = minimal_variable_info(),")
      cli_text("    llm_provider = \"ollama\",")
      cli_text("    llm_model = \"gpt-oss:20b-cloud\",")
      cli_text("    {.strong word_limit = 20},  # <-- Add this line")
      cli_text("    silent = TRUE")
      cli_text("  )")
      cli_text("")
    }

    if ("missing_skip_on_ci" %in% names(by_type)) {
      cli_h3("Fix skip_on_ci issues:")
      cli_text("")
      cli_text("  test_that(\"description\", {{")
      cli_text("    {.strong skip_on_ci()}       # <-- Add this line")
      cli_text("    skip_if_no_llm()   # <-- Also recommended")
      cli_text("")
      cli_text("    result <- interpret(...)")
      cli_text("  }})")
      cli_text("")
    }

    if ("inefficient_fixture" %in% names(by_type)) {
      cli_h3("Fix fixture issues:")
      cli_text("Replace sample_* fixtures with minimal_* equivalents:")
      cli_ul(c(
        "{.code sample_fa_model()} → {.code minimal_fa_model()}",
        "{.code sample_loadings()} → {.code minimal_loadings()}",
        "{.code sample_variable_info()} → {.code minimal_variable_info()}"
      ))
      cli_text("")
    }

    cli_text("See {.path dev/TESTING_GUIDELINES.md} for detailed standards.")
  }

  invisible(all_issues)
}

# Run Check --------------------------------------------------------------------
if (!interactive()) {
  # Running as script
  issues <- check_all_tests()

  # Exit with non-zero if issues found (for CI integration)
  if (length(issues) > 0) {
    quit(status = 1)
  }
} else {
  # Running interactively
  check_all_tests()
}
