# ==============================================================================
# INTEGRATION TESTS: Gaussian Mixture Model Interpretations
# ==============================================================================

test_that("interpret() works with Mclust objects (minimal LLM test)", {
  skip_on_ci()
  skip_if_not_installed("mclust")

  # Load minimal fixtures
  gm_model <- readRDS(test_path("fixtures/gm/minimal_gm_model.rds"))
  gm_var_info <- readRDS(test_path("fixtures/gm/minimal_gm_var_info.rds"))

  # Run interpretation with minimal word_limit
  result <- interpret(
    fit_results = gm_model,
    variable_info = gm_var_info,
    llm_provider = "ollama",
    llm_model = "gpt-oss:20b-cloud",
    word_limit = 20,
    silent = 2
  )

  # Check structure
  expect_s3_class(result, "gm_interpretation")
  expect_true("interpretation" %in% names(result))
  expect_true("analysis_data" %in% names(result))
  expect_true("fit_summary" %in% names(result))

  # Check interpretation content
  expect_equal(length(result$interpretation), gm_model$G)
  expect_true(all(sapply(result$interpretation, is.character)))

  # Check suggested names
  expect_equal(length(result$suggested_names), gm_model$G)
})

test_that("interpret() works with GM structured lists", {
  skip_if_not_installed("mclust")

  # Load structured list fixture
  gm_list <- readRDS(test_path("fixtures/gm/sample_gm_list.rds"))
  gm_var_info <- readRDS(test_path("fixtures/gm/sample_gm_var_info.rds"))

  # Should work without LLM (using build_analysis_data)
  expect_no_error({
    analysis_data <- psychinterpreter:::validate_list_structure.gm(
      gm_list,
      interpretation_args = interpretation_args(
        analysis_type = "gm",
        min_cluster_size = 5
      )
    )
  })

  expect_equal(analysis_data$analysis_type, "gm")
  expect_equal(analysis_data$n_clusters, ncol(gm_list$means))
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

  # Run interpretation with chat session
  result <- interpret(
    chat_session = chat,
    fit_results = gm_model,
    variable_info = gm_var_info,
    word_limit = 20,
    silent = 2
  )

  expect_s3_class(result, "gm_interpretation")
})

test_that("interpret() respects GM-specific parameters", {
  skip_if_not_installed("mclust")

  # Load fixtures
  gm_model <- readRDS(test_path("fixtures/gm/sample_gm_model.rds"))

  # Test build_analysis_data with different parameters
  analysis_data_default <- psychinterpreter:::build_analysis_data.Mclust(gm_model)
  expect_equal(analysis_data_default$min_cluster_size, 5)  # default
  expect_equal(analysis_data_default$separation_threshold, 0.3)  # default
  expect_false(analysis_data_default$weight_by_uncertainty)  # default

  # Test with custom parameters
  analysis_data_custom <- psychinterpreter:::build_analysis_data.Mclust(
    gm_model,
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
  expect_no_error({
    analysis_data <- psychinterpreter:::build_analysis_data.Mclust(single_model)
  })
  expect_equal(analysis_data$n_clusters, 1)

  # Overlapping clusters (high uncertainty)
  overlap_model <- readRDS(test_path("fixtures/gm/overlap_model.rds"))
  analysis_data_overlap <- psychinterpreter:::build_analysis_data.Mclust(overlap_model)
  fit_summary <- psychinterpreter:::create_fit_summary.gm(analysis_data_overlap)
  # Should have warnings about overlap/uncertainty
  expect_true(length(fit_summary$warnings) > 0 || length(fit_summary$notes) > 0)

  # Unbalanced clusters
  unbalanced_model <- readRDS(test_path("fixtures/gm/unbalanced_model.rds"))
  analysis_data_unbalanced <- psychinterpreter:::build_analysis_data.Mclust(unbalanced_model)
  fit_summary_unbalanced <- psychinterpreter:::create_fit_summary.gm(analysis_data_unbalanced)
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
      interpretation = list(
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
      interpretation = list(
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

  # Print should work without error
  expect_output({
    print(mock_interpretation)
  })

  # Markdown format
  mock_interpretation$output_args <- output_args(format = "markdown", silent = 0)
  expect_output({
    print(mock_interpretation)
  })
})

test_that("export works for GM interpretations", {
  skip_if_not_installed("mclust")

  # Load sample analysis data
  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  # Create mock interpretation
  mock_interpretation <- structure(
    list(
      interpretation = list(
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
