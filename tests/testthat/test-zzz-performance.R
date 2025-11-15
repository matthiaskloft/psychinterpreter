# Performance Benchmarking Tests
# File name starts with zzz to run last
# These tests measure performance and should not fail builds
# Part of Phase 2 Test Optimization (2.2)

test_that("single interpretation performance benchmark", {
  skip_on_ci()
  skip_if_no_llm()

  loadings <- minimal_loadings()
  var_info <- minimal_variable_info()

  # Benchmark single interpretation
  benchmark <- system.time({
    result <- interpret(
      fit_results = list(loadings = loadings),
      variable_info = var_info,
      analysis_type = "fa",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud",
      word_limit = 20,
      silent = 2
    )
  })

  elapsed <- benchmark["elapsed"]

  # Log results
  cli::cli_alert_info("=== Single Interpretation Benchmark ===")
  cli::cli_alert_info("Elapsed time: {.val {sprintf('%.2f', elapsed)}} seconds")
  cli::cli_alert_info("User time: {.val {sprintf('%.2f', benchmark['user.self'])}} seconds")
  cli::cli_alert_info("System time: {.val {sprintf('%.2f', benchmark['sys.self'])}} seconds")

  # Soft expectation (warning, not failure)
  if (elapsed > 10) {
    cli::cli_alert_warning(
      "Single interpretation took {.val {sprintf('%.2f', elapsed)}} seconds (target: <10s). Consider optimization."
    )
  } else {
    cli::cli_alert_success("Performance within target (<10s)")
  }

  expect_s3_class(result, "fa_interpretation")
})

test_that("chat session reuse performance benchmark", {
  skip_on_ci()
  skip_if_no_llm()

  loadings <- minimal_loadings()
  var_info <- minimal_variable_info()

  # Benchmark: 3 interpretations with reused session
  benchmark_reuse <- system.time({
    chat <- chat_session(
      analysis_type = "fa",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud"
    )

    result1 <- interpret(
      chat_session = chat,
      fit_results = list(loadings = loadings),
      variable_info = var_info,
      word_limit = 20,
      silent = 2
    )
    result2 <- interpret(
      chat_session = chat,
      fit_results = list(loadings = loadings),
      variable_info = var_info,
      word_limit = 20,
      silent = 2
    )
    result3 <- interpret(
      chat_session = chat,
      fit_results = list(loadings = loadings),
      variable_info = var_info,
      word_limit = 20,
      silent = 2
    )
  })

  # Benchmark: 3 separate interpretations (no session reuse)
  benchmark_separate <- system.time({
    result1 <- interpret(
      fit_results = list(loadings = loadings),
      variable_info = var_info,
      analysis_type = "fa",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud",
      word_limit = 20,
      silent = 2
    )
    result2 <- interpret(
      fit_results = list(loadings = loadings),
      variable_info = var_info,
      analysis_type = "fa",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud",
      word_limit = 20,
      silent = 2
    )
    result3 <- interpret(
      fit_results = list(loadings = loadings),
      variable_info = var_info,
      analysis_type = "fa",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud",
      word_limit = 20,
      silent = 2
    )
  })

  elapsed_reuse <- benchmark_reuse["elapsed"]
  elapsed_separate <- benchmark_separate["elapsed"]
  savings_pct <- (1 - elapsed_reuse / elapsed_separate) * 100

  # Log results
  cli::cli_alert_info("=== Chat Session Reuse Benchmark ===")
  cli::cli_alert_info("3x interpretations WITH session reuse: {.val {sprintf('%.2f', elapsed_reuse)}} seconds")
  cli::cli_alert_info("3x interpretations WITHOUT session reuse: {.val {sprintf('%.2f', elapsed_separate)}} seconds")
  cli::cli_alert_info("Time savings: {.val {sprintf('%.1f', savings_pct)}}%")

  # Soft expectations
  if (elapsed_reuse > 30) {
    cli::cli_alert_warning(
      "Chat session (3x) took {.val {sprintf('%.2f', elapsed_reuse)}} seconds (target: <30s). Consider optimization."
    )
  } else {
    cli::cli_alert_success("Performance within target (<30s)")
  }

  # Session reuse should be faster (or at least not slower)
  # Allow 10% margin of error
  expect_lte(elapsed_reuse, elapsed_separate * 1.1)
})

test_that("fixture loading performance", {
  # Clear cache first to measure true first-load performance
  if (exists(".test_cache")) {
    rm(list = ls(envir = .test_cache), envir = .test_cache)
  }

  # Benchmark first load
  benchmark_first <- system.time({
    loadings1 <- sample_loadings()
  })

  # Benchmark cached load
  benchmark_cached <- system.time({
    loadings2 <- sample_loadings()
  })

  cli::cli_alert_info("=== Fixture Loading Benchmark ===")
  cli::cli_alert_info("First load: {.val {sprintf('%.4f', benchmark_first['elapsed'])}} seconds")
  cli::cli_alert_info("Cached load: {.val {sprintf('%.4f', benchmark_cached['elapsed'])}} seconds")

  # Cached load should be much faster (or at least as fast)
  speedup <- benchmark_first["elapsed"] / benchmark_cached["elapsed"]
  cli::cli_alert_info("Speedup: {.val {sprintf('%.1fx', speedup)}}")

  # Cached should be at least as fast as first load
  expect_lte(benchmark_cached["elapsed"], benchmark_first["elapsed"])
})

test_that("test suite overall performance tracking", {
  skip_on_ci()

  # This test exists to document overall test performance
  # Run with: testthat::test_file("tests/testthat/test-zzz-performance.R")

  cli::cli_alert_info("=== Test Suite Performance Summary ===")
  cli::cli_text("Run {.code devtools::test()} and observe:")
  cli::cli_ul(c(
    "Tests without LLM should complete in <20 seconds",
    "Tests with LLM (full suite) should complete in <90 seconds",
    "Individual LLM tests should complete in <10 seconds each"
  ))

  cli::cli_text("")
  cli::cli_text("To track performance over time:")
  cli::cli_code("devtools::test()")

  cli::cli_text("")
  cli::cli_text("To run only fast tests (no LLM):")
  cli::cli_code("devtools::test(filter = '^test-0')")

  cli::cli_text("")
  cli::cli_text("To run only integration tests (with LLM):")
  cli::cli_code("devtools::test(filter = '^test-1')")

  expect_true(TRUE)
})

test_that("minimal fixture creation performance", {
  # Benchmark creating minimal test fixtures
  benchmark <- system.time({
    for (i in 1:100) {
      loadings <- minimal_loadings()
      var_info <- minimal_variable_info()
      fa_model <- minimal_fa_model()
    }
  })

  elapsed_per_iteration <- benchmark["elapsed"] / 100

  cli::cli_alert_info("=== Minimal Fixture Creation Benchmark ===")
  cli::cli_alert_info("100 iterations: {.val {sprintf('%.4f', benchmark['elapsed'])}} seconds")
  cli::cli_alert_info("Per iteration: {.val {sprintf('%.6f', elapsed_per_iteration)}} seconds")

  # Fixture creation should be very fast
  # Each iteration should take less than 1ms on average
  expect_lt(elapsed_per_iteration, 0.001)
})

test_that("prompt building performance", {
  skip_if_not_installed("psych")

  fa_model <- minimal_fa_model()
  var_info <- minimal_variable_info()

  # Extract analysis data first
  analysis_data <- psychinterpreter:::build_analysis_data(
    fit_results = fa_model,
    analysis_type = "fa",
    interpretation_args = interpretation_args(analysis_type = "fa"),
    variable_info = var_info
  )

  # Benchmark prompt building
  benchmark_system <- system.time({
    for (i in 1:50) {
      system_prompt <- psychinterpreter:::build_system_prompt(analysis_data)
    }
  })

  benchmark_main <- system.time({
    for (i in 1:50) {
      main_prompt <- psychinterpreter:::build_main_prompt(analysis_data)
    }
  })

  elapsed_system <- benchmark_system["elapsed"] / 50
  elapsed_main <- benchmark_main["elapsed"] / 50

  cli::cli_alert_info("=== Prompt Building Benchmark ===")
  cli::cli_alert_info("System prompt (50x): {.val {sprintf('%.4f', benchmark_system['elapsed'])}} seconds")
  cli::cli_alert_info("Main prompt (50x): {.val {sprintf('%.4f', benchmark_main['elapsed'])}} seconds")
  cli::cli_alert_info("System prompt per iteration: {.val {sprintf('%.6f', elapsed_system)}} seconds")
  cli::cli_alert_info("Main prompt per iteration: {.val {sprintf('%.6f', elapsed_main)}} seconds")

  # Prompt building should be fast (< 10ms per prompt on average)
  expect_lt(elapsed_system, 0.01)
  expect_lt(elapsed_main, 0.01)
})

test_that("JSON parsing performance with fallback tiers", {
  # Create test responses
  valid_json <- '{"suggested_names": {"F1": "Factor 1"}, "component_summaries": {"F1": {"llm_interpretation": "Test", "variables": [], "used_emergency_rule": false}}}'
  malformed_json <- '{suggested_names": {"F1": "Factor 1"}}'  # Will use fallback
  partial_json <- '{"suggested_names": {"F1": "Factor 1"}}'  # Missing component_summaries

  factor_names <- c("F1", "F2")

  # Benchmark valid JSON (tier 1)
  benchmark_valid <- system.time({
    for (i in 1:100) {
      result <- psychinterpreter:::parse_llm_response(
        response = list(content = valid_json),
        analysis_type = "fa",
        factor_names = factor_names
      )
    }
  })

  # Benchmark malformed JSON (tier 2-3)
  benchmark_malformed <- system.time({
    for (i in 1:100) {
      result <- psychinterpreter:::parse_llm_response(
        response = list(content = malformed_json),
        analysis_type = "fa",
        factor_names = factor_names
      )
    }
  })

  # Benchmark partial JSON (tier 3-4)
  benchmark_partial <- system.time({
    for (i in 1:100) {
      result <- psychinterpreter:::parse_llm_response(
        response = list(content = partial_json),
        analysis_type = "fa",
        factor_names = factor_names
      )
    }
  })

  elapsed_valid <- benchmark_valid["elapsed"] / 100
  elapsed_malformed <- benchmark_malformed["elapsed"] / 100
  elapsed_partial <- benchmark_partial["elapsed"] / 100

  cli::cli_alert_info("=== JSON Parsing Performance ===")
  cli::cli_alert_info("Valid JSON (100x): {.val {sprintf('%.4f', benchmark_valid['elapsed'])}} seconds")
  cli::cli_alert_info("Malformed JSON (100x): {.val {sprintf('%.4f', benchmark_malformed['elapsed'])}} seconds")
  cli::cli_alert_info("Partial JSON (100x): {.val {sprintf('%.4f', benchmark_partial['elapsed'])}} seconds")
  cli::cli_alert_info("Valid per iteration: {.val {sprintf('%.6f', elapsed_valid)}} seconds")
  cli::cli_alert_info("Malformed per iteration: {.val {sprintf('%.6f', elapsed_malformed)}} seconds")
  cli::cli_alert_info("Partial per iteration: {.val {sprintf('%.6f', elapsed_partial)}} seconds")

  # Parsing should be fast even with fallbacks (< 10ms per parse)
  expect_lt(elapsed_valid, 0.01)
  expect_lt(elapsed_malformed, 0.01)
  expect_lt(elapsed_partial, 0.01)

  # Fallback tiers shouldn't be dramatically slower than valid JSON
  # (should be within 5x of valid JSON performance)
  expect_lt(elapsed_malformed, elapsed_valid * 5)
  expect_lt(elapsed_partial, elapsed_valid * 5)
})
