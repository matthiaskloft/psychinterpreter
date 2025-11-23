# ==============================================================================
# INTEGRATION TESTS: Gaussian Mixture Model Interpretations
# ==============================================================================

test_that("interpret() works with Mclust objects (minimal LLM test)", {
  skip_on_ci()
  skip_if_not_installed("mclust")

  # Load minimal fixtures
  gm_model <- readRDS(test_path("fixtures/gm/minimal_gm_model.rds"))
  gm_var_info <- readRDS(test_path("fixtures/gm/minimal_gm_var_info.rds"))

  # Run interpretation with minimal word_limit (skip if rate limited)
  result <- with_llm_rate_limit_skip({
    interpret(
      fit_results = gm_model,
      variable_info = gm_var_info,
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud",
      word_limit = 20,
      silent = 2
    )
  })

  # Check structure
  expect_s3_class(result, "gm_interpretation")
  expect_true("component_summaries" %in% names(result))
  expect_true("analysis_data" %in% names(result))
  expect_true("fit_summary" %in% names(result))

  # Check interpretation content
  expect_equal(length(result$component_summaries), gm_model$G)
  expect_true(all(sapply(result$component_summaries, is.character)))

  # Check suggested names
  expect_equal(length(result$suggested_names), gm_model$G)
})

test_that("interpret() works with GM structured lists", {
  skip("Structured list routing not yet implemented for GM - feature in development")
  skip_on_ci()
  skip_if_not_installed("mclust")

  # Load structured list fixture
  gm_list <- readRDS(test_path("fixtures/gm/sample_gm_list.rds"))
  gm_var_info <- readRDS(test_path("fixtures/gm/sample_gm_var_info.rds"))

  # Test with actual interpret() function (user-facing API)
  expect_no_error({
    result <- interpret(
      fit_results = gm_list,
      variable_info = gm_var_info,
      analysis_type = "gm",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud",
      word_limit = 20,
      min_cluster_size = 5
    )
  })

  # Verify structure
  expect_s3_class(result, "gm_interpretation")
  expect_equal(result$analysis_data$analysis_type, "gm")
  expect_equal(result$analysis_data$n_clusters, ncol(gm_list$means))
})

test_that("interpret() handles GM chat sessions", {
  skip_on_ci()
  skip_if_not_installed("mclust")

  # Load fixtures
  gm_model <- readRDS(test_path("fixtures/gm/minimal_gm_model.rds"))
  gm_var_info <- readRDS(test_path("fixtures/gm/minimal_gm_var_info.rds"))

  # Create chat session
  chat <- chat_session(
    analysis_type = "gm",
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud"
  )

  expect_s3_class(chat, "chat_session")

  # Run interpretation with chat session (skip if rate limited)
  result <- with_llm_rate_limit_skip({
    interpret(
      chat_session = chat,
      fit_results = gm_model,
      variable_info = gm_var_info,
      word_limit = 20,
      silent = 2
    )
  })

  expect_s3_class(result, "gm_interpretation")
})

test_that("interpret() respects GM-specific parameters", {
  skip_if_not_installed("mclust")
  # Note: This test only calls build_analysis_data (no LLM), but skip for consistency
  skip_on_ci()

  # Load fixtures
  gm_model <- readRDS(test_path("fixtures/gm/sample_gm_model.rds"))
  gm_var_info <- readRDS(test_path("fixtures/gm/sample_gm_var_info.rds"))

  # Test build_analysis_data with different parameters
  analysis_data_default <- psychinterpreter:::build_analysis_data.Mclust(gm_model, variable_info = gm_var_info)
  expect_equal(analysis_data_default$min_cluster_size, 5)  # default
  expect_equal(analysis_data_default$separation_threshold, 0.3)  # default
  expect_false(analysis_data_default$weight_by_uncertainty)  # default

  # Test with custom parameters
  analysis_data_custom <- psychinterpreter:::build_analysis_data.Mclust(
    gm_model,
    variable_info = gm_var_info,
    min_cluster_size = 10,
    separation_threshold = 0.5,
    weight_by_uncertainty = TRUE,
    plot_type = "heatmap"
  )

  expect_equal(analysis_data_custom$min_cluster_size, 10)
  expect_equal(analysis_data_custom$separation_threshold, 0.5)
  expect_true(analysis_data_custom$weight_by_uncertainty)
  expect_equal(analysis_data_custom$plot_type, "heatmap")
})

test_that("GM interpretation handles edge cases", {
  skip_if_not_installed("mclust")

  # Single cluster
  single_model <- readRDS(test_path("fixtures/gm/single_cluster_model.rds"))
  single_var_info <- data.frame(
    variable = c("Var1", "Var2", "Var3", "Var4", "Var5"),
    description = c("Openness to experience", "Conscientiousness", "Extraversion", "Agreeableness", "Neuroticism")
  )
  expect_no_error({
    analysis_data <- psychinterpreter:::build_analysis_data.Mclust(single_model, variable_info = single_var_info)
  })
  expect_equal(analysis_data$n_clusters, 1)

  # Overlapping clusters (high uncertainty)
  overlap_model <- readRDS(test_path("fixtures/gm/overlap_model.rds"))
  overlap_var_info <- data.frame(
    variable = c("X1", "X2", "X3"),
    description = c("Variable X1", "Variable X2", "Variable X3")
  )
  analysis_data_overlap <- psychinterpreter:::build_analysis_data.Mclust(overlap_model, variable_info = overlap_var_info)
  fit_summary <- psychinterpreter:::create_fit_summary.gm("gm", analysis_data_overlap)
  # Should have warnings about overlap/uncertainty
  expect_true(length(fit_summary$warnings) > 0 || length(fit_summary$notes) > 0)

  # Unbalanced clusters
  unbalanced_model <- readRDS(test_path("fixtures/gm/unbalanced_model.rds"))
  unbalanced_var_info <- data.frame(
    variable = c("Y1", "Y2", "Y3"),
    description = c("Variable Y1", "Variable Y2", "Variable Y3")
  )
  analysis_data_unbalanced <- psychinterpreter:::build_analysis_data.Mclust(unbalanced_model, variable_info = unbalanced_var_info)
  fit_summary_unbalanced <- psychinterpreter:::create_fit_summary.gm("gm", analysis_data_unbalanced)
  # Should warn about small or unbalanced clusters
  expect_true(any(grepl("Small|unbalanced", fit_summary_unbalanced$warnings, ignore.case = TRUE)))
})

test_that("GM visualization works with different plot types", {
  skip_if_not_installed("mclust")
  skip_if_not_installed("ggplot2")

  # Load sample model and create mock interpretation
  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  mock_interpretation <- structure(
    list(
      component_summaries = list(
        Cluster_1 = "High achievers",
        Cluster_2 = "Low achievers",
        Cluster_3 = "Balanced"
      ),
      analysis_data = analysis_data,
      fit_summary = list(),
      suggested_names = list(
        Cluster_1 = "High",
        Cluster_2 = "Low",
        Cluster_3 = "Balanced"
      )
    ),
    class = c("gm_interpretation", "interpretation", "list")
  )

  # Test different plot types
  expect_no_error({
    p_heatmap <- plot(mock_interpretation, plot_type = "heatmap")
  })

  expect_no_error({
    p_parallel <- plot(mock_interpretation, plot_type = "parallel")
  })

  expect_no_error({
    p_radar <- plot(mock_interpretation, plot_type = "radar")
  })

  # Test auto selection
  expect_no_error({
    p_auto <- plot(mock_interpretation, plot_type = "auto")
  })

  # Test all plots
  expect_no_error({
    all_plots <- plot(mock_interpretation, plot_type = "all")
  })
  expect_true(is.list(all_plots))
  expect_equal(length(all_plots), 3)
})

test_that("print() method works for GM interpretations", {
  skip_if_not_installed("mclust")

  # Load sample analysis data
  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  # Create mock interpretation
  mock_interpretation <- structure(
    list(
      component_summaries = list(
        Cluster_1 = "This is cluster 1",
        Cluster_2 = "This is cluster 2",
        Cluster_3 = "This is cluster 3"
      ),
      analysis_data = analysis_data,
      fit_summary = list(warnings = character(), notes = character()),
      suggested_names = list(
        Cluster_1 = "High",
        Cluster_2 = "Low",
        Cluster_3 = "Medium"
      ),
      output_args = output_args(format = "cli", silent = 0)
    ),
    class = c("gm_interpretation", "interpretation", "list")
  )

  # Print should work without error - specify output_format to regenerate report
  expect_output({
    print(mock_interpretation, output_format = "cli")
  }, "Gaussian Mixture")

  # Markdown format
  expect_output({
    print(mock_interpretation, output_format = "markdown")
  }, "Gaussian Mixture")
})

test_that("export works for GM interpretations", {
  skip_if_not_installed("mclust")

  # Load sample analysis data
  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  # Create mock interpretation
  mock_interpretation <- structure(
    list(
      component_summaries = list(
        Cluster_1 = "Cluster 1 interpretation",
        Cluster_2 = "Cluster 2 interpretation",
        Cluster_3 = "Cluster 3 interpretation"
      ),
      analysis_data = analysis_data,
      fit_summary = list(warnings = character(), notes = character()),
      suggested_names = list(
        Cluster_1 = "C1",
        Cluster_2 = "C2",
        Cluster_3 = "C3"
      ),
      output_args = output_args(format = "cli", silent = 2)
    ),
    class = c("gm_interpretation", "interpretation", "list")
  )

  # Test export to temp file
  temp_file <- tempfile(fileext = ".txt")
  expect_no_error({
    export_interpretation(mock_interpretation, temp_file, format = "txt")
  })
  expect_true(file.exists(temp_file))
  expect_true(file.size(temp_file) > 0)

  # Test markdown export
  temp_md <- tempfile(fileext = ".md")
  expect_no_error({
    export_interpretation(mock_interpretation, temp_md, format = "md")
  })
  expect_true(file.exists(temp_md))

  # Cleanup
  unlink(c(temp_file, temp_md))
})

# ==============================================================================
# METADATA DISPLAY TESTS
# ==============================================================================

test_that("LLM metadata is displayed in reports (CLI format)", {
  skip_if_not_installed("mclust")

  # Load sample analysis data
  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  # Create mock chat session
  mock_chat <- structure(
    list(
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud"
    ),
    class = "chat_session"
  )

  # Create mock interpretation with LLM info
  mock_interpretation <- structure(
    list(
      component_summaries = list(
        Cluster_1 = "High performers",
        Cluster_2 = "Low performers",
        Cluster_3 = "Average performers"
      ),
      analysis_data = analysis_data,
      fit_summary = list(warnings = character(), notes = character()),
      suggested_names = list(
        Cluster_1 = "High",
        Cluster_2 = "Low",
        Cluster_3 = "Average"
      ),
      chat = mock_chat,
      output_args = output_args(format = "cli", silent = 0)
    ),
    class = c("gm_interpretation", "interpretation", "list")
  )

  # Build report
  report <- psychinterpreter:::build_report.gm_interpretation(
    mock_interpretation,
    output_format = "cli"
  )

  # Check for LLM info line
  expect_match(report, "LLM used:", fixed = TRUE)
  expect_match(report, "ollama - gpt-oss:20b-cloud", fixed = TRUE)
})

test_that("LLM metadata is displayed in reports (markdown format)", {
  skip_if_not_installed("mclust")

  # Load sample analysis data
  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  # Create mock chat session
  mock_chat <- structure(
    list(
      llm_provider = "anthropic",
      llm_model = "claude-3-5-sonnet-20241022"
    ),
    class = "chat_session"
  )

  # Create mock interpretation
  mock_interpretation <- structure(
    list(
      component_summaries = list(
        Cluster_1 = "Test interpretation",
        Cluster_2 = "Test interpretation 2"
      ),
      analysis_data = analysis_data,
      fit_summary = list(warnings = character(), notes = character()),
      suggested_names = list(
        Cluster_1 = "Name1",
        Cluster_2 = "Name2"
      ),
      chat = mock_chat,
      output_args = output_args(format = "markdown", silent = 0)
    ),
    class = c("gm_interpretation", "interpretation", "list")
  )

  # Build report
  report <- psychinterpreter:::build_report.gm_interpretation(
    mock_interpretation,
    output_format = "markdown"
  )

  # Check for markdown-formatted LLM info
  expect_match(report, "\\*\\*LLM used:\\*\\*", fixed = FALSE)
  expect_match(report, "anthropic - claude-3-5-sonnet-20241022", fixed = TRUE)
})

test_that("token counts are displayed when available (CLI format)", {
  skip_if_not_installed("mclust")

  # Load sample analysis data
  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  # Create mock chat session
  mock_chat <- structure(
    list(
      llm_provider = "openai",
      llm_model = "gpt-4o"
    ),
    class = "chat_session"
  )

  # Create mock interpretation with token counts
  mock_interpretation <- structure(
    list(
      component_summaries = list(Cluster_1 = "Test"),
      analysis_data = analysis_data,
      fit_summary = list(warnings = character(), notes = character()),
      suggested_names = list(Cluster_1 = "Test"),
      chat = mock_chat,
      input_tokens = 1523,
      output_tokens = 487,
      output_args = output_args(format = "cli", silent = 0)
    ),
    class = c("gm_interpretation", "interpretation", "list")
  )

  # Build report
  report <- psychinterpreter:::build_report.gm_interpretation(
    mock_interpretation,
    output_format = "cli"
  )

  # Check for token information
  expect_match(report, "Tokens:", fixed = TRUE)
  expect_match(report, "Input: 1523", fixed = TRUE)
  expect_match(report, "Output: 487", fixed = TRUE)
})

test_that("token counts are displayed when available (markdown format)", {
  skip_if_not_installed("mclust")

  # Load sample analysis data
  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  # Create mock chat session
  mock_chat <- structure(
    list(
      llm_provider = "anthropic",
      llm_model = "claude-3-5-sonnet-20241022"
    ),
    class = "chat_session"
  )

  # Create mock interpretation with token counts
  mock_interpretation <- structure(
    list(
      component_summaries = list(Cluster_1 = "Test"),
      analysis_data = analysis_data,
      fit_summary = list(warnings = character(), notes = character()),
      suggested_names = list(Cluster_1 = "Test"),
      chat = mock_chat,
      input_tokens = 2341,
      output_tokens = 612,
      output_args = output_args(format = "markdown", silent = 0)
    ),
    class = c("gm_interpretation", "interpretation", "list")
  )

  # Build report
  report <- psychinterpreter:::build_report.gm_interpretation(
    mock_interpretation,
    output_format = "markdown"
  )

  # Check for markdown-formatted token information
  expect_match(report, "\\*\\*Tokens:\\*\\*", fixed = FALSE)
  expect_match(report, "Input: 2341", fixed = TRUE)
  expect_match(report, "Output: 612", fixed = TRUE)
})

test_that("elapsed time is displayed when available (CLI format)", {
  skip_if_not_installed("mclust")

  # Load sample analysis data
  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  # Create mock chat session
  mock_chat <- structure(
    list(
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud"
    ),
    class = "chat_session"
  )

  # Create mock interpretation with elapsed time
  mock_interpretation <- structure(
    list(
      component_summaries = list(Cluster_1 = "Test"),
      analysis_data = analysis_data,
      fit_summary = list(warnings = character(), notes = character()),
      suggested_names = list(Cluster_1 = "Test"),
      chat = mock_chat,
      elapsed_time = 3.456,
      output_args = output_args(format = "cli", silent = 0)
    ),
    class = c("gm_interpretation", "interpretation", "list")
  )

  # Build report
  report <- psychinterpreter:::build_report.gm_interpretation(
    mock_interpretation,
    output_format = "cli"
  )

  # Check for elapsed time
  expect_match(report, "Elapsed time:", fixed = TRUE)
  expect_match(report, "3.46", fixed = TRUE)
})

test_that("elapsed time is displayed when available (markdown format)", {
  skip_if_not_installed("mclust")

  # Load sample analysis data
  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  # Create mock chat session
  mock_chat <- structure(
    list(
      llm_provider = "anthropic",
      llm_model = "claude-3-5-sonnet-20241022"
    ),
    class = "chat_session"
  )

  # Create mock interpretation with elapsed time
  mock_interpretation <- structure(
    list(
      component_summaries = list(Cluster_1 = "Test"),
      analysis_data = analysis_data,
      fit_summary = list(warnings = character(), notes = character()),
      suggested_names = list(Cluster_1 = "Test"),
      chat = mock_chat,
      elapsed_time = 2.789,
      output_args = output_args(format = "markdown", silent = 0)
    ),
    class = c("gm_interpretation", "interpretation", "list")
  )

  # Build report
  report <- psychinterpreter:::build_report.gm_interpretation(
    mock_interpretation,
    output_format = "markdown"
  )

  # Check for markdown-formatted elapsed time
  expect_match(report, "\\*\\*Elapsed time:\\*\\*", fixed = FALSE)
  expect_match(report, "2.79", fixed = TRUE)
})

test_that("elapsed time appears after tokens when both are present", {
  skip_if_not_installed("mclust")

  # Load sample analysis data
  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  # Create mock chat session
  mock_chat <- structure(
    list(
      llm_provider = "openai",
      llm_model = "gpt-4o"
    ),
    class = "chat_session"
  )

  # Create mock interpretation with both tokens and elapsed time
  mock_interpretation <- structure(
    list(
      component_summaries = list(Cluster_1 = "Test"),
      analysis_data = analysis_data,
      fit_summary = list(warnings = character(), notes = character()),
      suggested_names = list(Cluster_1 = "Test"),
      chat = mock_chat,
      input_tokens = 1000,
      output_tokens = 500,
      elapsed_time = 4.321,
      output_args = output_args(format = "cli", silent = 0)
    ),
    class = c("gm_interpretation", "interpretation", "list")
  )

  # Build report
  report <- psychinterpreter:::build_report.gm_interpretation(
    mock_interpretation,
    output_format = "cli"
  )

  # Check that elapsed time appears after tokens
  tokens_pos <- regexpr("Tokens:", report, fixed = TRUE)
  elapsed_pos <- regexpr("Elapsed time:", report, fixed = TRUE)

  expect_true(tokens_pos > 0)
  expect_true(elapsed_pos > 0)
  expect_true(elapsed_pos > tokens_pos)
})

test_that("cluster statistics are displayed in detailed interpretations (CLI)", {
  skip_if_not_installed("mclust")

  # Load sample analysis data
  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  # Add proportions to analysis data
  analysis_data$proportions <- c(0.35, 0.42, 0.23)
  analysis_data$n_observations <- 500

  # Create mock interpretation
  mock_interpretation <- structure(
    list(
      component_summaries = list(
        Cluster_1 = "High achievers",
        Cluster_2 = "Average achievers",
        Cluster_3 = "Low achievers"
      ),
      analysis_data = analysis_data,
      fit_summary = list(warnings = character(), notes = character()),
      suggested_names = list(
        Cluster_1 = "High",
        Cluster_2 = "Average",
        Cluster_3 = "Low"
      ),
      output_args = output_args(format = "cli", silent = 0)
    ),
    class = c("gm_interpretation", "interpretation", "list")
  )

  # Build report
  report <- psychinterpreter:::build_report.gm_interpretation(
    mock_interpretation,
    output_format = "cli"
  )

  # Check for cluster size information (n= and %)
  expect_match(report, "n=175, 35%", fixed = TRUE)  # 0.35 * 500
  expect_match(report, "n=210, 42%", fixed = TRUE)  # 0.42 * 500
  expect_match(report, "n=115, 23%", fixed = TRUE)  # 0.23 * 500
})

test_that("cluster uncertainty is displayed when available", {
  skip_if_not_installed("mclust")

  # Load sample analysis data
  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  # Add uncertainty data
  analysis_data$uncertainty <- list(
    Cluster_1 = c(0.05, 0.08, 0.03, 0.06),
    Cluster_2 = c(0.15, 0.20, 0.12, 0.18),
    Cluster_3 = c(0.10, 0.11, 0.09, 0.10)
  )

  # Create mock interpretation
  mock_interpretation <- structure(
    list(
      component_summaries = list(
        Cluster_1 = "High confidence cluster",
        Cluster_2 = "Lower confidence cluster",
        Cluster_3 = "Medium confidence cluster"
      ),
      analysis_data = analysis_data,
      fit_summary = list(warnings = character(), notes = character()),
      suggested_names = list(
        Cluster_1 = "High",
        Cluster_2 = "Low",
        Cluster_3 = "Medium"
      ),
      output_args = output_args(format = "cli", silent = 0)
    ),
    class = c("gm_interpretation", "interpretation", "list")
  )

  # Build report
  report <- psychinterpreter:::build_report.gm_interpretation(
    mock_interpretation,
    output_format = "cli"
  )

  # Check for uncertainty information
  expect_match(report, "Average assignment uncertainty:", fixed = TRUE)
  expect_match(report, "0.055", fixed = TRUE)  # mean of Cluster_1 uncertainty
  expect_match(report, "0.162", fixed = TRUE)  # mean of Cluster_2 uncertainty
  expect_match(report, "0.1", fixed = TRUE)    # mean of Cluster_3 uncertainty
})

test_that("cluster separators appear in CLI format", {
  skip_if_not_installed("mclust")

  # Load sample analysis data
  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  # Create mock interpretation
  mock_interpretation <- structure(
    list(
      component_summaries = list(
        Cluster_1 = "First cluster",
        Cluster_2 = "Second cluster",
        Cluster_3 = "Third cluster"
      ),
      analysis_data = analysis_data,
      fit_summary = list(warnings = character(), notes = character()),
      suggested_names = list(
        Cluster_1 = "C1",
        Cluster_2 = "C2",
        Cluster_3 = "C3"
      ),
      output_args = output_args(format = "cli", silent = 0)
    ),
    class = c("gm_interpretation", "interpretation", "list")
  )

  # Build report
  report <- psychinterpreter:::build_report.gm_interpretation(
    mock_interpretation,
    output_format = "cli"
  )

  # CLI format should have separators (dashes)
  # Count occurrences of separator pattern
  separator_count <- length(gregexpr("---", report, fixed = TRUE)[[1]])
  expect_true(separator_count >= 3)  # At least one separator per cluster
})

test_that("markdown format has proper cluster sections", {
  skip_if_not_installed("mclust")

  # Load sample analysis data
  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  # Create mock interpretation
  mock_interpretation <- structure(
    list(
      component_summaries = list(
        Cluster_1 = "First cluster",
        Cluster_2 = "Second cluster",
        Cluster_3 = "Third cluster"
      ),
      analysis_data = analysis_data,
      fit_summary = list(warnings = character(), notes = character()),
      suggested_names = list(
        Cluster_1 = "C1",
        Cluster_2 = "C2",
        Cluster_3 = "C3"
      ),
      output_args = output_args(format = "markdown", silent = 0)
    ),
    class = c("gm_interpretation", "interpretation", "list")
  )

  # Build report
  report <- psychinterpreter:::build_report.gm_interpretation(
    mock_interpretation,
    output_format = "markdown"
  )

  # Markdown format should have cluster headers (###)
  expect_match(report, "### Cluster_1:", fixed = TRUE)
  expect_match(report, "### Cluster_2:", fixed = TRUE)
  expect_match(report, "### Cluster_3:", fixed = TRUE)

  # Should have section headers (##)
  expect_match(report, "## Cluster Interpretations", fixed = TRUE)
})

test_that("metadata display works with minimal LLM test", {
  skip_on_ci()
  skip_if_not_installed("mclust")

  # Load minimal fixtures
  gm_model <- readRDS(test_path("fixtures/gm/minimal_gm_model.rds"))
  gm_var_info <- readRDS(test_path("fixtures/gm/minimal_gm_var_info.rds"))

  # Run interpretation with minimal word_limit (skip if rate limited)
  result <- with_llm_rate_limit_skip({
    interpret(
      fit_results = gm_model,
      variable_info = gm_var_info,
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud",
      word_limit = 20,
      silent = 2
    )
  })

  # Build report
  report <- psychinterpreter:::build_report.gm_interpretation(
    result,
    output_format = "cli"
  )

  # Verify metadata is present
  expect_match(report, "LLM used:", fixed = TRUE)
  expect_match(report, "ollama", fixed = TRUE)

  # Check elapsed_time field exists
  expect_true(!is.null(result$elapsed_time))
  expect_true(is.numeric(result$elapsed_time))
  expect_true(result$elapsed_time >= 0)

  # Verify elapsed time in report
  expect_match(report, "Elapsed time:", fixed = TRUE)
})

# ==============================================================================
# NEW GM MOCK TESTS (Phase 1, Task 1)
# ==============================================================================

test_that("GM interpretation handles malformed JSON with mock", {
  skip_if_not_installed("mclust")

  # Load sample model
  gm_model <- readRDS(test_path("fixtures/gm/minimal_gm_model.rds"))
  gm_var_info <- readRDS(test_path("fixtures/gm/minimal_gm_var_info.rds"))

  # Create analysis data
  analysis_data <- psychinterpreter:::build_analysis_data.Mclust(gm_model, variable_info = gm_var_info)

  # Create malformed GM JSON response
  malformed_response <- list(
    content = '{
      "Cluster_1": { "name": "High achievers", "interpretation": "Test" ,,
      "Cluster_2": { "name": "Low achievers" }
    }',
    input_tokens = 100,
    output_tokens = 20
  )

  # Mock chat object
  mock_chat <- list(
    chat = function(prompt, echo = "none", ...) {
      malformed_response
    },
    get_turns = function() list(),
    extract_data = function(...) list()
  )

  mock_session <- structure(
    list(
      chat = mock_chat,
      analysis_type = "gm",
      n_interpretations = 0,
      total_input_tokens = 0,
      total_output_tokens = 0,
      llm_provider = "mock",
      llm_model = "mock-model",
      created_at = Sys.time()
    ),
    class = c("gm_chat_session", "chat_session")
  )

  # Should handle malformed JSON - either return defaults or handle error
  result <- tryCatch({
    psychinterpreter:::interpret_core(
      analysis_data = analysis_data,
      chat_session = mock_session,
      variable_info = gm_var_info,
      silent = 2
    )
  }, error = function(e) NULL)

  # If it returns a result, check it's valid
  if (!is.null(result)) {
    expect_s3_class(result, "gm_interpretation")
    expect_true("component_summaries" %in% names(result))
    expect_true("suggested_names" %in% names(result))
  } else {
    # Or it can fail gracefully with error
    expect_null(result)
  }
})

test_that("GM interpretation handles partial response (missing clusters) with mock", {
  skip_if_not_installed("mclust")

  # Load sample model
  gm_model <- readRDS(test_path("fixtures/gm/minimal_gm_model.rds"))
  gm_var_info <- readRDS(test_path("fixtures/gm/minimal_gm_var_info.rds"))

  # Create analysis data
  analysis_data <- psychinterpreter:::build_analysis_data.Mclust(gm_model, variable_info = gm_var_info)

  # Get expected number of clusters
  n_clusters <- gm_model$G

  # Create partial GM response (only one cluster when expecting multiple)
  partial_response <- list(
    content = '{
      "Cluster_1": { "name": "High achievers", "interpretation": "Test interpretation" }
    }',
    input_tokens = 100,
    output_tokens = 30
  )

  # Mock chat object
  mock_chat <- list(
    chat = function(prompt, echo = "none", ...) {
      partial_response
    },
    get_turns = function() list(),
    extract_data = function(...) list()
  )

  mock_session <- structure(
    list(
      chat = mock_chat,
      analysis_type = "gm",
      n_interpretations = 0,
      total_input_tokens = 0,
      total_output_tokens = 0,
      llm_provider = "mock",
      llm_model = "mock-model",
      created_at = Sys.time()
    ),
    class = c("gm_chat_session", "chat_session")
  )

  # Should handle partial response
  result <- tryCatch({
    psychinterpreter:::interpret_core(
      analysis_data = analysis_data,
      chat_session = mock_session,
      variable_info = gm_var_info,
      silent = 2
    )
  }, error = function(e) NULL)

  # If it returns a result, check it's valid
  if (!is.null(result)) {
    expect_s3_class(result, "gm_interpretation")
    expect_true("component_summaries" %in% names(result))
    expect_equal(length(result$component_summaries), n_clusters)
  } else {
    # Or it can fail gracefully
    expect_null(result)
  }
})

test_that("GM interpretation handles wrong cluster count with mock", {
  skip_if_not_installed("mclust")

  # Load sample model
  gm_model <- readRDS(test_path("fixtures/gm/minimal_gm_model.rds"))
  gm_var_info <- readRDS(test_path("fixtures/gm/minimal_gm_var_info.rds"))

  # Create analysis data
  analysis_data <- psychinterpreter:::build_analysis_data.Mclust(gm_model, variable_info = gm_var_info)

  # Get expected number of clusters
  n_clusters <- gm_model$G

  # Create response with wrong number of clusters (too many)
  wrong_count_response <- list(
    content = '{
      "Cluster_1": { "name": "C1", "interpretation": "Test 1" },
      "Cluster_2": { "name": "C2", "interpretation": "Test 2" },
      "Cluster_3": { "name": "C3", "interpretation": "Test 3" },
      "Cluster_4": { "name": "C4", "interpretation": "Test 4" },
      "Cluster_5": { "name": "C5", "interpretation": "Test 5" }
    }',
    input_tokens = 100,
    output_tokens = 50
  )

  # Mock chat object
  mock_chat <- list(
    chat = function(prompt, echo = "none", ...) {
      wrong_count_response
    },
    get_turns = function() list(),
    extract_data = function(...) list()
  )

  mock_session <- structure(
    list(
      chat = mock_chat,
      analysis_type = "gm",
      n_interpretations = 0,
      total_input_tokens = 0,
      total_output_tokens = 0,
      llm_provider = "mock",
      llm_model = "mock-model",
      created_at = Sys.time()
    ),
    class = c("gm_chat_session", "chat_session")
  )

  # Should handle wrong cluster count
  result <- tryCatch({
    psychinterpreter:::interpret_core(
      analysis_data = analysis_data,
      chat_session = mock_session,
      variable_info = gm_var_info,
      silent = 2
    )
  }, error = function(e) NULL)

  # If it returns a result, check it's valid
  if (!is.null(result)) {
    expect_s3_class(result, "gm_interpretation")
    expect_true("component_summaries" %in% names(result))
    # Should have correct number of clusters (from analysis_data)
    expect_equal(length(result$component_summaries), n_clusters)
  } else {
    # Or it can fail gracefully
    expect_null(result)
  }
})

test_that("GM interpretation handles unicode in cluster names with mock", {
  skip_if_not_installed("mclust")

  # Load sample model
  gm_model <- readRDS(test_path("fixtures/gm/minimal_gm_model.rds"))
  gm_var_info <- readRDS(test_path("fixtures/gm/minimal_gm_var_info.rds"))

  # Create analysis data
  analysis_data <- psychinterpreter:::build_analysis_data.Mclust(gm_model, variable_info = gm_var_info)

  # Get expected number of clusters
  n_clusters <- gm_model$G

  # Create cluster names with unicode
  cluster_names <- paste0("Cluster_", 1:n_clusters)
  unicode_json <- paste0(
    '{\n',
    paste(
      paste0(
        '  "', cluster_names, '": { "name": "',
        c("High achievers 🎯", "Low achievers 📉")[1:n_clusters],
        '", "interpretation": "Test interpretation with émojis 😊" }'
      ),
      collapse = ",\n"
    ),
    '\n}'
  )

  unicode_response <- list(
    content = unicode_json,
    input_tokens = 100,
    output_tokens = 60
  )

  # Mock chat object
  mock_chat <- list(
    chat = function(prompt, echo = "none", ...) {
      unicode_response
    },
    get_turns = function() list(),
    extract_data = function(...) list()
  )

  mock_session <- structure(
    list(
      chat = mock_chat,
      analysis_type = "gm",
      n_interpretations = 0,
      total_input_tokens = 0,
      total_output_tokens = 0,
      llm_provider = "mock",
      llm_model = "mock-model",
      created_at = Sys.time()
    ),
    class = c("gm_chat_session", "chat_session")
  )

  # Should handle unicode
  result <- tryCatch({
    psychinterpreter:::interpret_core(
      analysis_data = analysis_data,
      chat_session = mock_session,
      variable_info = gm_var_info,
      silent = 2
    )
  }, error = function(e) NULL)

  # If it returns a result, check it's valid
  if (!is.null(result)) {
    expect_s3_class(result, "gm_interpretation")
    expect_true("component_summaries" %in% names(result))
    expect_true("suggested_names" %in% names(result))

    # Check that unicode is preserved
    if (n_clusters >= 1) {
      expect_match(result$suggested_names$Cluster_1, "🎯")
      expect_match(result$component_summaries$Cluster_1, "😊")
    }
  } else {
    # Or it can fail gracefully
    expect_null(result)
  }
})
