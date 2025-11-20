# ==============================================================================
# UNIT TESTS: Gaussian Mixture Model Functions
# ==============================================================================

# =================================
# build_analysis_data.Mclust Tests
# =================================

test_that("build_analysis_data.Mclust extracts data correctly", {
  skip_if_not_installed("mclust")

  gm_model <- readRDS(test_path("fixtures/gm/sample_gm_model.rds"))
  var_info <- readRDS(test_path("fixtures/gm/sample_gm_var_info.rds"))

  analysis_data <- psychinterpreter:::build_analysis_data.Mclust(gm_model, variable_info = var_info)

  # Check required components
  expect_true(all(c("means", "covariances", "proportions", "memberships") %in% names(analysis_data)))
  expect_true(all(c("n_clusters", "n_variables", "n_observations") %in% names(analysis_data)))
  expect_equal(analysis_data$analysis_type, "gm")

  # Check dimensions
  expect_equal(ncol(analysis_data$means), analysis_data$n_clusters)
  expect_equal(nrow(analysis_data$means), analysis_data$n_variables)
  expect_equal(dim(analysis_data$covariances)[3], analysis_data$n_clusters)

  # Check proportions sum to 1
  expect_equal(sum(analysis_data$proportions), 1, tolerance = 0.01)

  # Check cluster names
  expect_equal(length(analysis_data$cluster_names), analysis_data$n_clusters)
  expect_true(all(grepl("^Cluster_[0-9]+$", analysis_data$cluster_names)))
})

test_that("build_analysis_data.Mclust handles spherical models", {
  skip_if_not_installed("mclust")

  gm_model <- readRDS(test_path("fixtures/gm/minimal_gm_model.rds"))
  var_info <- readRDS(test_path("fixtures/gm/minimal_gm_var_info.rds"))

  # This should be EII (spherical) model
  expect_equal(gm_model$modelName, "EII")

  analysis_data <- psychinterpreter:::build_analysis_data.Mclust(gm_model, variable_info = var_info)

  # Should create diagonal covariance matrices
  expect_equal(dim(analysis_data$covariances), c(3, 3, 2))  # 3 vars, 2 clusters

  # Check that covariances are diagonal for EII model
  for (k in 1:analysis_data$n_clusters) {
    cov_matrix <- analysis_data$covariances[,,k]
    # Off-diagonal elements should be zero for diagonal models
    expect_equal(sum(cov_matrix[upper.tri(cov_matrix)]), 0, tolerance = 0.001)
  }
})

test_that("build_analysis_data.Mclust requires variable_info", {
  skip_if_not_installed("mclust")

  gm_model <- readRDS(test_path("fixtures/gm/sample_gm_model.rds"))

  # Should fail without variable_info
  expect_error(
    psychinterpreter:::build_analysis_data.Mclust(gm_model),
    "variable_info.*required"
  )
})

test_that("build_analysis_data.Mclust validates variable matching", {
  skip_if_not_installed("mclust")

  gm_model <- readRDS(test_path("fixtures/gm/sample_gm_model.rds"))

  # Model has variables: Var1, Var2, Var3, Var4, Var5

  # Test 1: Variable in model but not in variable_info
  var_info_missing <- data.frame(
    variable = c("Var1", "Var2", "Var3", "Var4"),  # Missing Var5
    description = c("Test1", "Test2", "Test3", "Test4")
  )
  expect_error(
    psychinterpreter:::build_analysis_data.Mclust(gm_model, variable_info = var_info_missing),
    "Variables in GM model not found in variable_info.*Var5"
  )

  # Test 2: Variable in variable_info but not in model
  var_info_extra <- data.frame(
    variable = c("Var1", "Var2", "Var3", "Var4", "Var5", "Var6"),  # Extra Var6
    description = c("Test1", "Test2", "Test3", "Test4", "Test5", "Test6")
  )
  expect_error(
    psychinterpreter:::build_analysis_data.Mclust(gm_model, variable_info = var_info_extra),
    "Variables in variable_info not found in GM model.*Var6"
  )

  # Test 3: No matching variables at all
  var_info_nomatch <- data.frame(
    variable = c("Wrong1", "Wrong2", "Wrong3", "Wrong4", "Wrong5"),
    description = c("Test1", "Test2", "Test3", "Test4", "Test5")
  )
  expect_error(
    psychinterpreter:::build_analysis_data.Mclust(gm_model, variable_info = var_info_nomatch),
    "No variables from GM model found in variable_info"
  )
})

#' =================================
# validate_list_structure.gm Tests
# =================================

test_that("validate_list_structure.gm works with valid input", {
  skip_if_not_installed("mclust")

  gm_list <- readRDS(test_path("fixtures/gm/sample_gm_list.rds"))
  var_info <- readRDS(test_path("fixtures/gm/sample_gm_var_info.rds"))

  analysis_data <- psychinterpreter:::validate_list_structure_gm_impl(gm_list, variable_info = var_info)

  expect_equal(analysis_data$analysis_type, "gm")
  expect_true("means" %in% names(analysis_data))
  expect_true("covariances" %in% names(analysis_data))
})

test_that("validate_list_structure.gm creates defaults for missing components", {
  skip_if_not_installed("mclust")

  # Minimal list with just means
  minimal_list <- list(
    means = matrix(rnorm(12), nrow = 4, ncol = 3, dimnames = list(c("V1", "V2", "V3", "V4"), NULL))
  )

  # Create matching variable_info
  var_info <- data.frame(
    variable = c("V1", "V2", "V3", "V4"),
    description = c("Variable 1", "Variable 2", "Variable 3", "Variable 4")
  )

  analysis_data <- psychinterpreter:::validate_list_structure_gm_impl(minimal_list, variable_info = var_info)

  # Should create default covariances (identity matrices)
  expect_equal(dim(analysis_data$covariances), c(4, 4, 3))

  # Should create equal proportions
  expect_equal(length(analysis_data$proportions), 3)
  expect_equal(sum(analysis_data$proportions), 1)

  # Should create default variable names
  expect_equal(length(analysis_data$variable_names), 4)
  expect_true(all(grepl("^V[0-9]+$", analysis_data$variable_names)))
})

test_that("validate_list_structure.gm fails without required components", {
  # Create minimal variable_info (won't be used since means is missing)
  var_info <- data.frame(
    variable = c("V1"),
    description = c("Test")
  )

  # Missing means
  expect_error({
    psychinterpreter:::validate_list_structure_gm_impl(list(covariances = matrix(1)), variable_info = var_info)
  }, "Missing required components")
})

test_that("validate_list_structure.gm requires variable_info", {
  # Minimal list with just means
  minimal_list <- list(
    means = matrix(rnorm(12), nrow = 4, ncol = 3, dimnames = list(c("V1", "V2", "V3", "V4"), NULL))
  )

  # Should fail without variable_info
  expect_error(
    psychinterpreter:::validate_list_structure_gm_impl(minimal_list),
    "variable_info.*required"
  )
})

test_that("validate_list_structure.gm validates variable matching", {
  # Create list with means having specific variable names
  gm_list <- list(
    means = matrix(rnorm(15), nrow = 5, ncol = 3, dimnames = list(c("Var1", "Var2", "Var3", "Var4", "Var5"), NULL))
  )

  # Test 1: Variable in model but not in variable_info
  var_info_missing <- data.frame(
    variable = c("Var1", "Var2", "Var3", "Var4"),  # Missing Var5
    description = c("Test1", "Test2", "Test3", "Test4")
  )
  expect_error(
    psychinterpreter:::validate_list_structure_gm_impl(gm_list, variable_info = var_info_missing),
    "Variables in GM model not found in variable_info.*Var5"
  )

  # Test 2: Variable in variable_info but not in model
  var_info_extra <- data.frame(
    variable = c("Var1", "Var2", "Var3", "Var4", "Var5", "Var6"),  # Extra Var6
    description = c("Test1", "Test2", "Test3", "Test4", "Test5", "Test6")
  )
  expect_error(
    psychinterpreter:::validate_list_structure_gm_impl(gm_list, variable_info = var_info_extra),
    "Variables in variable_info not found in GM model.*Var6"
  )
})

# =================================
# interpretation_args_gm Tests
# =================================

test_that("interpretation_args_gm validates parameters correctly", {
  # Valid parameters
  expect_no_error({
    args <- interpretation_args_gm(
      analysis_type = "gm",
      min_cluster_size = 10,
      separation_threshold = 0.4,
      plot_type = "heatmap"
    )
  })

  # Invalid analysis_type
  expect_error({
    interpretation_args_gm(analysis_type = "fa")
  }, "analysis_type must be 'gm'")

  # Invalid min_cluster_size
  expect_error({
    interpretation_args_gm(analysis_type = "gm", min_cluster_size = -1)
  }, "min_cluster_size must be between 1 and 100")

  # Invalid separation_threshold
  expect_error({
    interpretation_args_gm(analysis_type = "gm", separation_threshold = 1.5)
  }, "separation_threshold must be between 0 and 1")

  # Invalid plot_type
  expect_error({
    interpretation_args_gm(analysis_type = "gm", plot_type = "invalid")
  }, "plot_type must be one of")

  # Invalid covariance_type
  expect_error({
    interpretation_args_gm(analysis_type = "gm", covariance_type = "XXX")
  }, "covariance_type must be one of")
})

test_that("interpretation_args_gm returns correct structure", {
  args <- interpretation_args_gm(analysis_type = "gm")

  expect_s3_class(args, "interpretation_args_gm")
  expect_s3_class(args, "interpretation_args")
  expect_true(is.list(args))

  # Check defaults
  expect_equal(args$analysis_type, "gm")
  expect_equal(args$min_cluster_size, 5)
  expect_equal(args$separation_threshold, 0.3)
  expect_false(args$weight_by_uncertainty)
  expect_equal(args$plot_type, "auto")
})

# =================================
# Prompt Building Tests
# =================================

test_that("build_system_prompt.gm creates valid prompt", {
  skip_if_not_installed("mclust")

  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  system_prompt <- psychinterpreter:::build_system_prompt.gm(analysis_data)

  expect_type(system_prompt, "character")
  expect_true(nchar(system_prompt) > 0)
  expect_true(grepl("cluster", system_prompt, ignore.case = TRUE))
  expect_true(grepl("expert", system_prompt, ignore.case = TRUE))
})

test_that("build_main_prompt.gm creates valid prompt", {
  skip_if_not_installed("mclust")

  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))
  var_info <- readRDS(test_path("fixtures/gm/sample_gm_var_info.rds"))

  main_prompt <- psychinterpreter:::build_main_prompt.gm(
    analysis_type = "gm",
    analysis_data = analysis_data,
    word_limit = 50,
    additional_info = NULL,
    variable_info = var_info
  )

  expect_type(main_prompt, "character")
  expect_true(nchar(main_prompt) > 0)
  expect_true(grepl("Cluster", main_prompt))
  expect_true(grepl("JSON", main_prompt))

  # Should include variable descriptions
  for (i in 1:nrow(var_info)) {
    expect_true(grepl(var_info$variable[i], main_prompt))
  }
})

# =================================
# JSON Parsing Tests
# =================================

test_that("validate_parsed_result.gm validates correctly", {
  skip_if_not_installed("mclust")

  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))
  valid_json <- readRDS(test_path("fixtures/gm/valid_gm_json.rds"))

  # Valid result - needs analysis_type parameter (returns formatted result, not TRUE)
  result <- psychinterpreter:::validate_parsed_result.gm(valid_json, "gm", analysis_data)
  expect_true(is.list(result))
  expect_true("component_summaries" %in% names(result))
  expect_true("suggested_names" %in% names(result))

  # Invalid: wrong number of clusters (returns NULL, not FALSE)
  invalid_json1 <- list(Cluster_1 = "text")
  expect_null(
    psychinterpreter:::validate_parsed_result.gm(invalid_json1, "gm", analysis_data)
  )

  # Invalid: non-character values (returns NULL, not FALSE)
  invalid_json2 <- list(
    Cluster_1 = 123,
    Cluster_2 = "text",
    Cluster_3 = "text"
  )
  expect_null(
    psychinterpreter:::validate_parsed_result.gm(invalid_json2, "gm", analysis_data)
  )

  # Invalid: not a list (returns NULL, not FALSE)
  expect_null(
    psychinterpreter:::validate_parsed_result.gm("not a list", "gm", analysis_data)
  )
})

test_that("extract_by_pattern.gm extracts from malformed responses", {
  skip_if_not_installed("mclust")

  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))
  malformed_response <- readRDS(test_path("fixtures/gm/malformed_gm_response.rds"))

  extracted <- psychinterpreter:::extract_by_pattern.gm(
    response = malformed_response,
    analysis_type = "gm",
    analysis_data = analysis_data
  )

  # Should return formatted result with component_summaries
  expect_true(is.list(extracted))
  expect_true("component_summaries" %in% names(extracted))
  expect_equal(length(extracted$component_summaries), analysis_data$n_clusters)
  expect_true(all(sapply(extracted$component_summaries, is.character)))
})

test_that("create_default_result.gm creates valid defaults", {
  skip_if_not_installed("mclust")

  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  defaults <- psychinterpreter:::create_default_result.gm(
    analysis_type = "gm",
    analysis_data = analysis_data
  )

  # Should return formatted result with component_summaries
  expect_true(is.list(defaults))
  expect_true("component_summaries" %in% names(defaults))
  expect_equal(length(defaults$component_summaries), analysis_data$n_clusters)
  expect_equal(names(defaults$component_summaries), analysis_data$cluster_names)
  expect_true(all(sapply(defaults$component_summaries, is.character)))
  expect_true(all(nchar(unlist(defaults$component_summaries)) > 0))
})

# =================================
# Diagnostics Tests
# =================================

test_that("create_fit_summary.gm identifies issues correctly", {
  skip_if_not_installed("mclust")

  # Test with unbalanced model (should warn about small clusters)
  unbalanced_model <- readRDS(test_path("fixtures/gm/unbalanced_model.rds"))
  unbal_var_info <- data.frame(
    variable = c("Y1", "Y2", "Y3"),
    description = c("Variable Y1", "Variable Y2", "Variable Y3")
  )
  analysis_data_unbal <- psychinterpreter:::build_analysis_data.Mclust(unbalanced_model, variable_info = unbal_var_info)
  # create_fit_summary.gm needs analysis_type parameter
  fit_summary_unbal <- psychinterpreter:::create_fit_summary.gm("gm", analysis_data_unbal)

  expect_true(length(fit_summary_unbal$warnings) > 0)
  expect_true(any(grepl("Small|unbalanced", fit_summary_unbal$warnings, ignore.case = TRUE)))

  # Test with overlapping clusters (should warn about uncertainty)
  overlap_model <- readRDS(test_path("fixtures/gm/overlap_model.rds"))
  overlap_var_info <- data.frame(
    variable = c("X1", "X2", "X3"),
    description = c("Variable X1", "Variable X2", "Variable X3")
  )
  analysis_data_overlap <- psychinterpreter:::build_analysis_data.Mclust(overlap_model, variable_info = overlap_var_info)
  fit_summary_overlap <- psychinterpreter:::create_fit_summary.gm("gm", analysis_data_overlap)

  # Should have warnings or notes about overlap/uncertainty
  expect_true(
    length(fit_summary_overlap$warnings) > 0 ||
    length(fit_summary_overlap$notes) > 0
  )
})

test_that("calculate_cluster_separation_gm computes distances", {
  skip_if_not_installed("mclust")

  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  separation_matrix <- psychinterpreter:::calculate_cluster_separation_gm(analysis_data)

  # Should be square matrix with dimensions n_clusters x n_clusters
  expect_equal(dim(separation_matrix), c(analysis_data$n_clusters, analysis_data$n_clusters))

  # Diagonal should be zero
  expect_equal(diag(separation_matrix), rep(0, analysis_data$n_clusters))

  # Should be symmetric
  expect_equal(separation_matrix, t(separation_matrix), tolerance = 0.001)

  # All values should be non-negative
  expect_true(all(separation_matrix >= 0))
})

test_that("find_distinguishing_variables_gm identifies key variables", {
  skip_if_not_installed("mclust")

  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  distinguishing_vars <- psychinterpreter:::find_distinguishing_variables_gm(
    analysis_data, top_n = 3
  )

  # Should return list with one entry per cluster
  expect_equal(length(distinguishing_vars), analysis_data$n_clusters)
  expect_equal(names(distinguishing_vars), analysis_data$cluster_names)

  # Each entry should be a data frame with 3 rows (top_n = 3)
  for (cluster_name in analysis_data$cluster_names) {
    df <- distinguishing_vars[[cluster_name]]
    expect_s3_class(df, "data.frame")
    expect_equal(nrow(df), 3)
    expect_true(all(c("variable", "cluster_mean", "distinctiveness") %in% names(df)))
  }
})

# =================================
# Visualization Tests
# =================================

test_that("create_heatmap_gm generates ggplot object", {
  skip_if_not_installed("mclust")
  skip_if_not_installed("ggplot2")

  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  p <- psychinterpreter:::create_heatmap_gm(analysis_data)

  expect_s3_class(p, "ggplot")
})

test_that("create_parallel_plot_gm generates ggplot object", {
  skip_if_not_installed("mclust")
  skip_if_not_installed("ggplot2")

  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  p <- psychinterpreter:::create_parallel_plot_gm(analysis_data)

  expect_s3_class(p, "ggplot")
})

test_that("create_radar_plot_gm generates plot object", {
  skip_if_not_installed("mclust")
  skip_if_not_installed("ggplot2")

  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  expect_no_error({
    p <- psychinterpreter:::create_radar_plot_gm(analysis_data)
  })
})

test_that("create_radar_plot_gm limits variables for clarity", {
  skip_if_not_installed("mclust")
  skip_if_not_installed("ggplot2")

  # Load very high-dimensional model (20 variables)
  high_dim_model <- readRDS(test_path("fixtures/gm/very_high_dim_model.rds"))

  # Create variable_info for 20 dimensions (model uses V1-V20)
  high_dim_var_info <- data.frame(
    variable = paste0("V", 1:20),
    description = paste("Variable", 1:20)
  )

  analysis_data <- psychinterpreter:::build_analysis_data.Mclust(high_dim_model, variable_info = high_dim_var_info)

  expect_equal(analysis_data$n_variables, 20)

  # Should inform about limiting to 15 variables
  expect_message({
    p <- psychinterpreter:::create_radar_plot_gm(analysis_data)
  }, "limited to top 15")
})

test_that("create_cluster_profile_plot standalone function works", {
  skip_if_not_installed("ggplot2")

  # Create simple test data
  means <- matrix(rnorm(15), nrow = 5, ncol = 3)
  var_names <- paste0("Var", 1:5)
  cluster_names <- paste0("Cluster_", 1:3)

  # Test heatmap
  p_heatmap <- create_cluster_profile_plot(
    means, var_names, cluster_names,
    plot_type = "heatmap"
  )
  expect_s3_class(p_heatmap, "ggplot")

  # Test parallel
  p_parallel <- create_cluster_profile_plot(
    means, var_names, cluster_names,
    plot_type = "parallel"
  )
  expect_s3_class(p_parallel, "ggplot")

  # Test radar
  expect_no_error({
    p_radar <- create_cluster_profile_plot(
      means, var_names, cluster_names,
      plot_type = "radar"
    )
  })
})

# =================================
# Report Building Tests
# =================================

test_that("build_report.gm_interpretation creates valid report", {
  skip_if_not_installed("mclust")

  analysis_data <- readRDS(test_path("fixtures/gm/sample_gm_analysis_data.rds"))

  mock_interpretation <- structure(
    list(
      interpretation = list(
        Cluster_1 = "First cluster description",
        Cluster_2 = "Second cluster description",
        Cluster_3 = "Third cluster description"
      ),
      analysis_data = analysis_data,
      fit_summary = list(
        warnings = c("Test warning"),
        notes = c("Test note")
      ),
      suggested_names = list(
        Cluster_1 = "High",
        Cluster_2 = "Low",
        Cluster_3 = "Medium"
      )
    ),
    class = c("gm_interpretation", "interpretation", "list")
  )

  # CLI format
  report_cli <- psychinterpreter:::build_report.gm_interpretation(
    mock_interpretation, output_format = "cli"
  )
  expect_type(report_cli, "character")
  expect_true(nchar(report_cli) > 0)

  # Markdown format
  report_md <- psychinterpreter:::build_report.gm_interpretation(
    mock_interpretation, output_format = "markdown"
  )
  expect_type(report_md, "character")
  expect_true(grepl("^#", report_md))  # Should start with heading
})

test_that("describe_covariance_type provides descriptions", {
  # Test valid model names
  expect_true(grepl("spherical", psychinterpreter:::describe_covariance_type("EII")))
  expect_true(grepl("ellipsoidal", psychinterpreter:::describe_covariance_type("VVV")))

  # Test invalid model name (should return as-is)
  expect_equal(psychinterpreter:::describe_covariance_type("UNKNOWN"), "UNKNOWN")
})

# =================================
# Integration with Parameter Registry
# =================================

test_that("GM parameters are registered correctly", {
  # Check that GM parameters exist in registry
  expect_true("min_cluster_size" %in% names(PARAMETER_REGISTRY))
  expect_true("separation_threshold" %in% names(PARAMETER_REGISTRY))
  expect_true("weight_by_uncertainty" %in% names(PARAMETER_REGISTRY))
  expect_true("plot_type" %in% names(PARAMETER_REGISTRY))

  # Check model_specific field
  expect_equal(PARAMETER_REGISTRY$min_cluster_size$model_specific, "gm")
  expect_equal(PARAMETER_REGISTRY$separation_threshold$model_specific, "gm")

  # Check defaults
  expect_equal(PARAMETER_REGISTRY$min_cluster_size$default, 5)
  expect_equal(PARAMETER_REGISTRY$separation_threshold$default, 0.3)
  expect_false(PARAMETER_REGISTRY$weight_by_uncertainty$default)
  expect_equal(PARAMETER_REGISTRY$plot_type$default, "auto")
})

test_that("GM dispatch table is registered correctly", {
  # Check analysis type display name
  expect_equal(psychinterpreter:::.ANALYSIS_TYPE_DISPLAY_NAMES["gm"], c(gm = "Gaussian Mixture"))

  # Check valid parameters
  gm_params <- psychinterpreter:::.VALID_INTERPRETATION_PARAMS$gm
  expect_true("min_cluster_size" %in% gm_params)
  expect_true("separation_threshold" %in% gm_params)
  expect_true("plot_type" %in% gm_params)

  # Check interpretation args dispatch
  expect_true("gm" %in% names(psychinterpreter:::.INTERPRETATION_ARGS_DISPATCH))
  expect_equal(psychinterpreter:::.INTERPRETATION_ARGS_DISPATCH$gm, interpretation_args_gm)
})

test_that("Mclust model type dispatch is registered", {
  dispatch_table <- psychinterpreter:::get_model_dispatch_table()

  expect_true("Mclust" %in% names(dispatch_table))
  expect_equal(dispatch_table$Mclust$analysis_type, "gm")
  expect_equal(dispatch_table$Mclust$package, "mclust")
})
