# ==============================================================================
# TEST: Canonical GM parameter shapes (F-05)
# ==============================================================================
# Purpose: mclust does not use a uniform representation. For a one-variable
#          mixture it returns `parameters$mean` as a bare vector and
#          `parameters$variance$sigma` as a scalar or per-cluster vector.
#          Everything downstream indexes means[, k] and covariances[, , k], so
#          univariate models failed with "incorrect number of dimensions".
# Ref:     dev/CODE_REVIEW_CONSOLIDATED_2026-07-25.md (F-05)
# ==============================================================================

# ------------------------------------------------------------------------------
# normalize_gm_shapes() unit tests - no mclust required
# ------------------------------------------------------------------------------

test_that("univariate means and scalar variance become canonical shapes", {
  out <- normalize_gm_shapes(
    means = c(0, 6), covariances = 1.5,
    n_variables = 1, n_clusters = 2
  )
  expect_equal(dim(out$means), c(1L, 2L))
  expect_equal(dim(out$covariances), c(1L, 1L, 2L))
  expect_equal(as.numeric(out$means), c(0, 6))
  # A shared variance is applied to every cluster.
  expect_equal(as.numeric(out$covariances), c(1.5, 1.5))
})

test_that("univariate per-cluster variances are preserved", {
  out <- normalize_gm_shapes(
    means = c(0, 6), covariances = c(1, 4),
    n_variables = 1, n_clusters = 2
  )
  expect_equal(dim(out$covariances), c(1L, 1L, 2L))
  expect_equal(out$covariances[1, 1, 1], 1)
  expect_equal(out$covariances[1, 1, 2], 4)
})

test_that("a shared p x p covariance matrix is replicated across clusters", {
  shared <- matrix(c(2, 1, 1, 3), 2, 2)
  out <- normalize_gm_shapes(
    means = matrix(c(0, 0, 5, 5), 2, 2), covariances = shared,
    n_variables = 2, n_clusters = 2
  )
  expect_equal(dim(out$covariances), c(2L, 2L, 2L))
  expect_equal(out$covariances[, , 1], shared, ignore_attr = TRUE)
  expect_equal(out$covariances[, , 2], shared, ignore_attr = TRUE)
})

test_that("already-canonical input is returned unchanged", {
  means <- matrix(c(0, 0, 5, 5), 2, 2)
  covs <- array(0, dim = c(2, 2, 2))
  covs[, , 1] <- diag(2)
  covs[, , 2] <- diag(2) * 3
  out <- normalize_gm_shapes(means, covs, n_variables = 2, n_clusters = 2)
  expect_equal(out$means, means, ignore_attr = TRUE)
  expect_equal(out$covariances, covs, ignore_attr = TRUE)
})

test_that("dimnames are applied when supplied", {
  out <- normalize_gm_shapes(
    means = c(0, 6), covariances = 1,
    n_variables = 1, n_clusters = 2,
    variable_names = "v1", cluster_names = c("C1", "C2")
  )
  expect_equal(rownames(out$means), "v1")
  expect_equal(colnames(out$means), c("C1", "C2"))
})

test_that("unreshapeable input is rejected with a clear error", {
  expect_error(
    normalize_gm_shapes(means = c(1, 2, 3), covariances = 1,
                        n_variables = 1, n_clusters = 2),
    "Cannot reshape cluster means"
  )
  expect_error(
    normalize_gm_shapes(means = matrix(0, 2, 2), covariances = c(1, 2, 3, 4, 5),
                        n_variables = 2, n_clusters = 2),
    "Cannot reshape covariances"
  )
})


# ------------------------------------------------------------------------------
# End-to-end: a real univariate mclust fit
# ------------------------------------------------------------------------------

test_that("univariate mclust models produce canonical analysis data", {
  skip_if_not_installed("mclust")
  library(mclust)  # Mclust() calls mclustBIC() unqualified; needs attaching

  set.seed(1)
  x <- c(rnorm(60, 0, 1), rnorm(60, 6, 1))
  model <- mclust::Mclust(x, G = 2, verbose = FALSE)

  # Precondition: mclust really does hand back dimensionless parameters.
  expect_null(dim(model$parameters$mean))

  ad <- build_analysis_data(
    model, analysis_type = "gm",
    variable_info = data.frame(
      variable = "x", description = "a single measured variable",
      stringsAsFactors = FALSE
    )
  )

  expect_equal(dim(ad$means), c(1L, 2L))
  expect_equal(dim(ad$covariances), c(1L, 1L, 2L))
})

test_that("univariate mclust models reach a fit summary without erroring", {
  skip_if_not_installed("mclust")
  library(mclust)  # Mclust() calls mclustBIC() unqualified; needs attaching

  set.seed(1)
  x <- c(rnorm(60, 0, 1), rnorm(60, 6, 1))
  model <- mclust::Mclust(x, G = 2, verbose = FALSE)
  ad <- build_analysis_data(
    model, analysis_type = "gm",
    variable_info = data.frame(
      variable = "x", description = "a single measured variable",
      stringsAsFactors = FALSE
    )
  )

  # This aborted with "incorrect number of dimensions" before the fix.
  expect_no_error(create_fit_summary("gm", ad))
})

test_that("guard: multivariate mclust models are unaffected", {
  skip_if_not_installed("mclust")
  library(mclust)  # Mclust() calls mclustBIC() unqualified; needs attaching

  set.seed(1)
  y <- cbind(
    a = c(rnorm(60, 0, 1), rnorm(60, 6, 1)),
    b = c(rnorm(60, 0, 1), rnorm(60, 6, 1))
  )
  model <- mclust::Mclust(y, G = 2, verbose = FALSE)
  ad <- build_analysis_data(
    model, analysis_type = "gm",
    variable_info = data.frame(
      variable = c("a", "b"), description = c("first", "second"),
      stringsAsFactors = FALSE
    )
  )

  expect_equal(dim(ad$means), c(2L, 2L))
  expect_equal(dim(ad$covariances), c(2L, 2L, 2L))
  expect_no_error(create_fit_summary("gm", ad))
})

# ------------------------------------------------------------------------------
# End-to-end through the FULL interpretation path
# ------------------------------------------------------------------------------
# Normalizing the stored array is not sufficient: `covariances[, , k]` drops
# dimensions when p == 1, so consumers re-broke what the producer fixed.
# create_fit_summary() happens to survive that; the prompt builder does not.
# These tests go all the way through, which is what the user actually does.

univariate_gm_data <- function() {
  skip_if_not_installed("mclust")
  library(mclust)  # Mclust() calls mclustBIC() unqualified; needs attaching
  set.seed(1)
  x <- c(rnorm(60, 0, 1), rnorm(60, 6, 1))
  model <- mclust::Mclust(x, G = 2, verbose = FALSE)
  build_analysis_data(
    model, analysis_type = "gm",
    variable_info = data.frame(
      variable = "x", description = "a single measured variable",
      stringsAsFactors = FALSE
    )
  )
}

test_that("univariate GM builds a prompt without erroring", {
  ad <- univariate_gm_data()

  # Aborted with "attempt to set 'rownames' on an object with no dimensions".
  prompt <- build_main_prompt(
    structure(list(), class = "gm"), analysis_data = ad,
    variable_info = data.frame(variable = "x", description = "a single measured variable",
                               stringsAsFactors = FALSE),
    word_limit = 50, additional_info = NULL
  )
  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 0)
})

test_that("univariate GM prompt reports the real variance, not NA", {
  ad <- univariate_gm_data()

  # diag() on a dimension-dropped slice returns a 0 x 0 matrix, so the variance
  # silently became NA and that NA was sent to the LLM.
  expect_equal(
    diag(gm_cluster_cov(ad$covariances, 1)),
    ad$covariances[1, 1, 1],
    ignore_attr = TRUE
  )

  prompt <- build_main_prompt(
    structure(list(), class = "gm"), analysis_data = ad,
    variable_info = data.frame(variable = "x", description = "a single measured variable",
                               stringsAsFactors = FALSE),
    word_limit = 50, additional_info = NULL
  )
  expect_false(grepl("(NA)", prompt, fixed = TRUE))
})

test_that("univariate GM completes a full interpretation offline", {
  ad <- univariate_gm_data()
  session <- fake_chat_session("gm", response = fake_gm_response(ad$cluster_names))

  result <- interpret_core(
    analysis_data = ad, analysis_type = "gm", chat_session = session,
    variable_info = data.frame(variable = "x", description = "a single measured variable",
                               stringsAsFactors = FALSE),
    verbosity = 0
  )

  expect_s3_class(result, "gm_interpretation")
  expect_true(nchar(result$report) > 0)
})

test_that("univariate GM variance extraction for plotting works", {
  ad <- univariate_gm_data()
  # Errored with "replacement has length zero".
  v <- extract_variance_matrix(ad)
  expect_equal(dim(v), c(1L, 2L))
})

test_that("gm_cluster_cov never drops dimensions", {
  covs <- array(c(2, 5), dim = c(1, 1, 2))
  expect_equal(dim(gm_cluster_cov(covs, 1)), c(1L, 1L))
  expect_equal(as.numeric(gm_cluster_cov(covs, 2)), 5)

  covs2 <- array(0, dim = c(3, 3, 2))
  covs2[, , 1] <- diag(3)
  expect_equal(dim(gm_cluster_cov(covs2, 1)), c(3L, 3L))
})

test_that("non-canonical dimensioned input is rejected, not silently accepted", {
  # A transposed [G, p] means matrix must not flow through untouched.
  expect_error(
    normalize_gm_shapes(means = matrix(0, 3, 2), covariances = array(0, dim = c(2, 2, 3)),
                        n_variables = 2, n_clusters = 3),
    "wrong dimensions"
  )
  expect_error(
    normalize_gm_shapes(means = matrix(0, 2, 2), covariances = array(0, dim = c(5, 5, 9)),
                        n_variables = 2, n_clusters = 2),
    "wrong dimensions"
  )
})


test_that("univariate GM does not auto-select an undrawable radar plot", {
  ad <- univariate_gm_data()
  # fmsb::radarchart refuses to draw with fewer than 3 axes but returns without
  # error, so auto-selecting radar produced a blank device and no warning.
  interp <- structure(
    list(analysis_type = "gm", analysis_data = ad,
         fit_summary = create_fit_summary("gm", ad),
         component_summaries = list(), suggested_names = list(),
         cluster_names = ad$cluster_names),
    class = c("gm_interpretation", "interpretation", "list")
  )

  pdf(tempfile())
  on.exit(dev.off(), add = TRUE)
  p <- plot(interp, plot_type = "auto")
  # parallel/heatmap are ggplot objects; radar is a recordedplot.
  expect_s3_class(p, "ggplot")
})

test_that("explicitly requesting radar with < 3 variables errors clearly", {
  ad <- univariate_gm_data()
  expect_error(
    create_radar_plot_gm(ad, what = "means"),
    "at least 3 variables"
  )
})

test_that("Mclust(df$col) names the variable usably", {
  skip_if_not_installed("mclust")
  library(mclust)  # Mclust() calls mclustBIC() unqualified; needs attaching

  set.seed(1)
  df <- data.frame(score = c(rnorm(60, 0, 1), rnorm(60, 6, 1)))
  # mclust records the deparsed call ("df$score") as the column name here.
  model <- mclust::Mclust(df$score, G = 2, verbose = FALSE)
  expect_equal(colnames(model$data), "df$score")

  ad <- build_analysis_data(
    model, analysis_type = "gm",
    variable_info = data.frame(variable = "score", description = "a score",
                               stringsAsFactors = FALSE)
  )
  expect_equal(ad$variable_names, "score")
})

test_that("guard: a real column name is never overridden", {
  skip_if_not_installed("mclust")
  library(mclust)

  set.seed(1)
  df <- data.frame(score = c(rnorm(60, 0, 1), rnorm(60, 6, 1)))
  model <- mclust::Mclust(df, G = 2, verbose = FALSE)
  expect_equal(colnames(model$data), "score")

  ad <- build_analysis_data(
    model, analysis_type = "gm",
    variable_info = data.frame(variable = "score", description = "a score",
                               stringsAsFactors = FALSE)
  )
  expect_equal(ad$variable_names, "score")
})


test_that("univariate structured list is accepted", {
  ad <- validate_list_structure(
    model_type = "gm",
    fit_results_list = list(
      means = matrix(c(0, 6), nrow = 1),
      covariances = c(1, 1),
      proportions = c(0.5, 0.5)
    ),
    variable_info = data.frame(
      variable = "V1", description = "only variable", stringsAsFactors = FALSE
    )
  )

  expect_equal(dim(ad$means), c(1L, 2L))
  expect_equal(dim(ad$covariances), c(1L, 1L, 2L))
})
