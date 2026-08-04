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
