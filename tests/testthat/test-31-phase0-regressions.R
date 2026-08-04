# ==============================================================================
# TEST: Phase 0 regression tests
# ==============================================================================
# Purpose: Lock in the six defects fixed in PR #1. Every test in this file
#          fails on 55759e0 and passes after the fix.
# Ref:     dev/CODE_REVIEW_CONSOLIDATED_2026-07-25.md (F-02, F-03, F-04,
#          F-09, F-19, F-20)
# Note:    All tests here are offline. None require an LLM provider.
# ==============================================================================


# ------------------------------------------------------------------------------
# F-03: tryCatch handler scoping in calculate_cluster_separation_gm()
# ------------------------------------------------------------------------------
# On 55759e0 the singular-covariance branch assigned into the error handler's
# own frame, so the value was discarded and the pair kept its initialised 0.
# Two maximally separated clusters were therefore reported as fully overlapping.

gm_two_cluster_data <- function(sigma) {
  means <- matrix(c(0, 0, 10, 10), nrow = 2, ncol = 2)
  rownames(means) <- c("v1", "v2")
  colnames(means) <- c("Cluster 1", "Cluster 2")
  covs <- array(0, dim = c(2, 2, 2))
  covs[, , 1] <- sigma
  covs[, , 2] <- sigma
  list(
    means = means,
    covariances = covs,
    n_clusters = 2L,
    proportions = c(0.5, 0.5),
    variable_names = c("v1", "v2"),
    cluster_names = c("Cluster 1", "Cluster 2"),
    separation_threshold = 0.3
  )
}

test_that("singular covariance does not silently report separation of 0", {
  singular <- matrix(c(1, 1, 1, 1), 2, 2)  # rank 1
  expect_true(inherits(try(solve(singular), silent = TRUE), "try-error"))

  sep <- calculate_cluster_separation_gm(gm_two_cluster_data(singular))

  expect_false(is.null(sep))
  # The defect: clusters 10 units apart were reported as distance 0.
  expect_false(isTRUE(all.equal(sep[1, 2], 0)))
  expect_true(is.na(sep[1, 2]))
  expect_true(is.na(sep[2, 1]))
})

test_that("non-singular covariance still yields the Mahalanobis distance", {
  sep <- calculate_cluster_separation_gm(gm_two_cluster_data(diag(2)))

  # With an identity covariance the Mahalanobis distance is Euclidean.
  expect_equal(sep[1, 2], sqrt(200), tolerance = 1e-8)
  expect_equal(sep[1, 2], sep[2, 1])
  expect_equal(sep[1, 1], 0)
})

test_that("separation matrix is symmetric and zero on the diagonal", {
  sep <- calculate_cluster_separation_gm(gm_two_cluster_data(diag(2)))
  expect_equal(sep, t(sep))
  expect_equal(diag(sep), c(0, 0))
})

test_that("find_overlapping_clusters does not claim overlap for unavailable pairs", {
  singular <- matrix(c(1, 1, 1, 1), 2, 2)
  overlaps <- find_overlapping_clusters(gm_two_cluster_data(singular))

  # An uncomputable distance is not evidence of overlap.
  expect_null(overlaps)
})

test_that("all-unavailable separation does not produce Inf or a warning", {
  singular <- matrix(c(1, 1, 1, 1), 2, 2)
  ad <- gm_two_cluster_data(singular)

  fit_summary <- expect_no_warning(create_fit_summary("gm", ad))

  min_sep <- fit_summary$statistics$min_separation
  # min(numeric(0)) would give Inf with a warning; NA is the correct answer.
  expect_false(isTRUE(is.finite(min_sep)))
})


# ------------------------------------------------------------------------------
# F-04: unbound `variable_info` on the structured-list GM route
# ------------------------------------------------------------------------------
# On 55759e0 interpret() referenced `variable_info` as a value although it is
# only present in `...`, so the GM structured-list route aborted with
# "object 'variable_info' not found" - or silently captured an unrelated
# global object of the same name.

gm_structured_list <- function() {
  means <- matrix(c(0, 0, 5, 5), nrow = 2, ncol = 2)
  rownames(means) <- c("v1", "v2")
  covs <- array(0, dim = c(2, 2, 2))
  covs[, , 1] <- diag(2)
  covs[, , 2] <- diag(2)
  list(
    means = means,
    covariances = covs,
    proportions = c(0.5, 0.5),
    z = matrix(c(0.9, 0.1, 0.1, 0.9), nrow = 2, ncol = 2)
  )
}

gm_variable_info <- function() {
  data.frame(
    variable = c("v1", "v2"),
    description = c("first measured variable", "second measured variable"),
    stringsAsFactors = FALSE
  )
}

test_that("structured-list GM route does not reference an unbound variable_info", {
  msg <- tryCatch(
    {
      interpret(
        fit_results = gm_structured_list(),
        analysis_type = "gm",
        variable_info = gm_variable_info(),
        # Deliberately unresolvable so the call fails offline, well after the
        # dispatch code under test.
        llm_provider = "__no_such_provider__",
        verbosity = 0
      )
      NA_character_
    },
    error = function(e) conditionMessage(e)
  )

  expect_false(grepl("object 'variable_info' not found", msg, fixed = TRUE))
})

test_that("structured-list GM route does not capture a global variable_info", {
  # Package code resolves unbound symbols through the global environment, so on
  # 55759e0 a stray global of this name was silently used as the caller's data.
  # Calling WITHOUT variable_info is the discriminator: the route must report it
  # as missing rather than quietly proceeding with the global.
  assign("variable_info", gm_variable_info(), envir = globalenv())
  on.exit(rm("variable_info", envir = globalenv()), add = TRUE)

  msg <- tryCatch(
    {
      interpret(
        fit_results = gm_structured_list(),
        analysis_type = "gm",
        # variable_info deliberately not supplied
        llm_provider = "__no_such_provider__",
        verbosity = 0
      )
      NA_character_
    },
    error = function(e) conditionMessage(e)
  )

  expect_true(grepl("variable_info", msg, fixed = TRUE))
  expect_false(grepl("object 'variable_info' not found", msg, fixed = TRUE))
})


# ------------------------------------------------------------------------------
# F-20: stats::loadings() was called unqualified and was not imported
# ------------------------------------------------------------------------------

test_that("efaList loadings extraction resolves stats::loadings", {
  skip_if_not_installed("lavaan")

  set.seed(42)
  n <- 200
  f1 <- rnorm(n)
  f2 <- rnorm(n)
  dat <- data.frame(
    x1 = f1 + rnorm(n, 0, 0.5), x2 = f1 + rnorm(n, 0, 0.5),
    x3 = f1 + rnorm(n, 0, 0.5), x4 = f2 + rnorm(n, 0, 0.5),
    x5 = f2 + rnorm(n, 0, 0.5), x6 = f2 + rnorm(n, 0, 0.5)
  )
  efa_fit <- lavaan::efa(dat, nfactors = 2)

  extracted <- extract_efalist_loadings(efa_fit)

  expect_true(is.data.frame(extracted$loadings))
  expect_equal(nrow(extracted$loadings), 6)
})


# ------------------------------------------------------------------------------
# F-02 / F-19: package metadata
# ------------------------------------------------------------------------------

test_that("DESCRIPTION declares an R version that provides base %||%", {
  # %||% is used throughout the package but is neither defined nor imported;
  # it entered base R in 4.4.0, so the declared floor must not be lower.
  deps <- read.dcf(system.file("DESCRIPTION", package = "psychinterpreter"),
                   fields = "Depends")[1, 1]
  version <- sub(".*R \\(>= ([0-9.]+)\\).*", "\\1", deps)

  expect_false(is.na(version))
  expect_gte(package_version(version), package_version("4.4.0"))
})

test_that("Maintainer is derived from Authors@R, not a stale hand-written field", {
  # The source DESCRIPTION must carry Authors@R only; R generates Author and
  # Maintainer at install time, so their presence here is expected and cannot
  # be asserted against. What IS observable is the address: the hand-written
  # Maintainer field named a different package (rctbayespower).
  desc <- read.dcf(system.file("DESCRIPTION", package = "psychinterpreter"))

  expect_true("Authors@R" %in% colnames(desc))
  # No field anywhere may reference the unrelated package the stale
  # hand-written Maintainer address named. Checking the whole DESCRIPTION keeps
  # this valid both for an installed package and under pkgload.
  expect_false(any(grepl("rctbayespower", desc, fixed = TRUE)))
})
