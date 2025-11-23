# Load the package first
library(psychinterpreter)

test_that("Enhanced GM components are extracted correctly from Mclust", {
  skip_if_not_installed("mclust")

  library(mclust)

  # Create test data
  set.seed(123)
  test_data <- iris[, 1:4]

  # Fit model
  model <- Mclust(test_data, G = 3)

  # Create variable info
  var_info <- data.frame(
    variable = names(test_data),
    description = paste("Variable", 1:4),
    stringsAsFactors = FALSE
  )

  # Extract analysis data
  analysis_data <- build_analysis_data(
    model,
    analysis_type = "gm",
    variable_info = var_info
  )

  # Test that all new components are present
  expect_true(!is.null(analysis_data$aic))
  expect_true(!is.null(analysis_data$bic))
  expect_true(!is.null(analysis_data$icl))
  expect_true(!is.null(analysis_data$loglik))
  expect_true(!is.null(analysis_data$entropy))
  expect_true(!is.null(analysis_data$normalized_entropy))
  expect_true(!is.null(analysis_data$n_parameters))
  expect_true(!is.null(analysis_data$converged))

  # Test AIC calculation
  expected_aic <- -2 * model$loglik + 2 * model$df
  expect_equal(analysis_data$aic, expected_aic, tolerance = 0.001)

  # Test entropy calculation
  expected_entropy <- -sum(model$z * log(model$z + 1e-10), na.rm = TRUE)
  expect_equal(analysis_data$entropy, expected_entropy, tolerance = 0.001)

  # Test normalized entropy
  max_entropy <- model$n * log(model$G)
  expected_norm_entropy <- expected_entropy / max_entropy
  expect_equal(analysis_data$normalized_entropy, expected_norm_entropy, tolerance = 0.001)

  # Test convergence status
  expect_true(analysis_data$converged)

  # Test number of parameters
  expect_equal(analysis_data$n_parameters, model$df)
})

test_that("Enhanced statistics appear in fit_summary", {
  skip_if_not_installed("mclust")

  library(mclust)

  # Create test data
  set.seed(123)
  test_data <- iris[, 1:4]

  # Fit model
  model <- Mclust(test_data, G = 3)

  # Create variable info
  var_info <- data.frame(
    variable = names(test_data),
    description = paste("Variable", 1:4),
    stringsAsFactors = FALSE
  )

  # Extract analysis data
  analysis_data <- build_analysis_data(
    model,
    analysis_type = "gm",
    variable_info = var_info
  )

  # Create fit summary
  fit_summary <- create_fit_summary(
    analysis_type = "gm",
    analysis_data = analysis_data
  )

  # Check that enhanced statistics are in fit_summary
  expect_true(!is.null(fit_summary$statistics$aic))
  expect_true(!is.null(fit_summary$statistics$bic))
  expect_true(!is.null(fit_summary$statistics$icl))
  expect_true(!is.null(fit_summary$statistics$loglik))
  expect_true(!is.null(fit_summary$statistics$entropy))
  expect_true(!is.null(fit_summary$statistics$normalized_entropy))
  expect_true(!is.null(fit_summary$statistics$n_parameters))
  expect_true(!is.null(fit_summary$statistics$converged))

  # Check rounding
  expect_equal(fit_summary$statistics$aic, round(analysis_data$aic, 2))
  expect_equal(fit_summary$statistics$bic, round(analysis_data$bic, 2))
  expect_equal(fit_summary$statistics$entropy, round(analysis_data$entropy, 3))
  expect_equal(fit_summary$statistics$normalized_entropy, round(analysis_data$normalized_entropy, 4))
})

test_that("Enhanced statistics appear in report", {
  skip_if_not_installed("mclust")
  skip_if_not_installed("cli")

  library(mclust)

  # Create test data
  set.seed(123)
  test_data <- iris[, 1:4]

  # Fit model
  model <- Mclust(test_data, G = 3)

  # Create variable info
  var_info <- data.frame(
    variable = names(test_data),
    description = paste("Variable", 1:4),
    stringsAsFactors = FALSE
  )

  # Create a minimal interpretation object
  analysis_data <- build_analysis_data(
    model,
    analysis_type = "gm",
    variable_info = var_info
  )

  fit_summary <- create_fit_summary(
    analysis_type = "gm",
    analysis_data = analysis_data
  )

  interpretation <- list(
    analysis_data = analysis_data,
    fit_summary = fit_summary,
    component_summaries = list(
      cluster_1 = "Test cluster 1",
      cluster_2 = "Test cluster 2",
      cluster_3 = "Test cluster 3"
    ),
    suggested_names = list(
      cluster_1 = "Group A",
      cluster_2 = "Group B",
      cluster_3 = "Group C"
    ),
    chat = list(
      llm_provider = "test",
      llm_model = "test-model"
    ),
    input_tokens = 100,
    output_tokens = 200,
    elapsed_time = 1.5
  )
  class(interpretation) <- c("gm_interpretation", "interpretation", "list")

  # Build report
  report_cli <- build_report(interpretation, output_format = "cli")
  report_md <- build_report(interpretation, output_format = "markdown")

  # Check that enhanced statistics appear in reports
  # AIC
  expect_true(grepl("AIC", report_cli))
  expect_true(grepl("AIC", report_md))

  # ICL
  expect_true(grepl("ICL", report_cli))
  expect_true(grepl("ICL", report_md))

  # Entropy
  expect_true(grepl("Entropy", report_cli))
  expect_true(grepl("entropy", report_cli, ignore.case = TRUE))

  # Normalized entropy
  expect_true(grepl("Normalized entropy", report_cli))
  expect_true(grepl("Normalized entropy", report_md))

  # Number of parameters
  expect_true(grepl("Number of parameters", report_cli))
  expect_true(grepl("Number of parameters", report_md))

  # Convergence status
  expect_true(grepl("Converged", report_cli))
  expect_true(grepl("Converged", report_md))
})

test_that("Missing control parameters are handled gracefully", {
  skip_if_not_installed("mclust")

  library(mclust)

  # Create test data
  set.seed(123)
  test_data <- iris[, 1:4]

  # Fit model (default Mclust doesn't store control parameters)
  model <- Mclust(test_data, G = 3)

  # Create variable info
  var_info <- data.frame(
    variable = names(test_data),
    description = paste("Variable", 1:4),
    stringsAsFactors = FALSE
  )

  # Extract analysis data
  analysis_data <- build_analysis_data(
    model,
    analysis_type = "gm",
    variable_info = var_info
  )

  # Check that missing control parameters result in NA
  expect_true(is.na(analysis_data$convergence_tol))
  expect_true(is.na(analysis_data$max_iterations))

  # But convergence status should still be available
  expect_true(!is.na(analysis_data$converged))
})

test_that("Models with spherical covariance are handled correctly", {
  skip_if_not_installed("mclust")

  library(mclust)

  # Create test data
  set.seed(123)
  test_data <- iris[, 1:4]

  # Fit model with spherical covariance (EII model)
  model <- Mclust(test_data, G = 3, modelNames = "EII")

  # Create variable info
  var_info <- data.frame(
    variable = names(test_data),
    description = paste("Variable", 1:4),
    stringsAsFactors = FALSE
  )

  # Extract analysis data - should not error
  expect_no_error({
    analysis_data <- build_analysis_data(
      model,
      analysis_type = "gm",
      variable_info = var_info
    )
  })

  # Check that enhanced components are still extracted
  expect_true(!is.null(analysis_data$aic))
  expect_true(!is.null(analysis_data$entropy))
  expect_true(!is.null(analysis_data$normalized_entropy))
})