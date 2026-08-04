# ==============================================================================
# TEST: Token accounting across ellmer schemas (F-01)
# ==============================================================================
# Purpose: ellmer >= 0.4 returns input/output/cached_input; the package used to
#          look for role/tokens and therefore recorded 0 for every call. These
#          tests pin the adapter AND the numbers it produces at the public
#          interpret() surface, not just at the helper.
# Ref:     dev/CODE_REVIEW_CONSOLIDATED_2026-07-25.md (F-01)
# ==============================================================================

# ------------------------------------------------------------------ unit level

test_that("modern ellmer schema is read, not ignored", {
  df <- fake_tokens("modern", input = 100, output = 50, n_turns = 1)
  counts <- extract_token_counts(df)

  expect_equal(counts$schema, "modern")
  expect_equal(counts$input_tokens, 100)
  expect_equal(counts$output_tokens, 50)
})

test_that("cached input counts towards input tokens", {
  # ellmer's Turn documents `tokens` as "input tokens (uncached), output
  # tokens, and input tokens (cached)". cached_input is therefore ADDITIONAL
  # to input, not a subset of it. Dropping it undercounts every provider that
  # caches prompts (notably Anthropic).
  df <- fake_tokens("modern", input = 100, output = 50, cached_input = 30)
  counts <- extract_token_counts(df)

  expect_equal(counts$input_tokens, 130)
  expect_equal(counts$cached_input_tokens, 30)
  expect_equal(counts$output_tokens, 50)
})

test_that("token counts sum across every assistant turn", {
  # get_tokens() returns one row per assistant turn.
  df <- fake_tokens("modern", input = 10, output = 5, n_turns = 3)
  counts <- extract_token_counts(df)

  expect_equal(counts$input_tokens, 30)
  expect_equal(counts$output_tokens, 15)
})

test_that("legacy role/tokens schema is still understood", {
  df <- fake_tokens("legacy", input = 100, output = 50, n_turns = 1)
  counts <- extract_token_counts(df)

  expect_equal(counts$schema, "legacy")
  expect_equal(counts$input_tokens, 100)
  expect_equal(counts$output_tokens, 50)
})

test_that("empty and absent token frames report zero, not NA", {
  # No turns yet is a genuine zero - it is known, not unknown.
  expect_equal(extract_token_counts(fake_tokens("empty"))$input_tokens, 0)
  expect_equal(extract_token_counts(NULL)$input_tokens, 0)
  expect_equal(extract_token_counts(fake_tokens("modern", n_turns = 0))$input_tokens, 0)
  expect_equal(extract_token_counts(NULL)$schema, "none")
})

test_that("an unrecognised schema yields NA and warns once", {
  # The failure mode that hid F-01 was reporting 0 for "we don't know".
  # NA is representable as unknown; 0 is indistinguishable from a real zero.
  reset_token_schema_warning()
  df <- fake_tokens("unknown")

  expect_warning(counts <- extract_token_counts(df), "token")
  expect_true(is.na(counts$input_tokens))
  expect_true(is.na(counts$output_tokens))
  expect_equal(counts$schema, "unknown")

  # Warn-once: a per-call warning would be unusable in a loop over variables.
  expect_no_warning(extract_token_counts(df))
  expect_no_warning(extract_token_counts(df))

  reset_token_schema_warning()
  expect_warning(extract_token_counts(df), "token")
})

# ---------------------------------------------------------- public interface

fixture_fa_model <- function() {
  skip_if_not_installed("psych")
  set.seed(1)
  n <- 120
  f1 <- rnorm(n)
  f2 <- rnorm(n)
  dat <- data.frame(
    a = f1 + rnorm(n, 0, .5), b = f1 + rnorm(n, 0, .5), c = f1 + rnorm(n, 0, .5),
    d = f2 + rnorm(n, 0, .5), e = f2 + rnorm(n, 0, .5), f = f2 + rnorm(n, 0, .5)
  )
  suppressWarnings(psych::fa(dat, nfactors = 2, rotate = "oblimin"))
}

fixture_var_info <- function() {
  data.frame(
    variable = c("a", "b", "c", "d", "e", "f"),
    description = paste("description of", c("a", "b", "c", "d", "e", "f")),
    stringsAsFactors = FALSE
  )
}

test_that("interpret() reports real token counts on the modern schema", {
  # The regression that mattered: this reported 0 for every ellmer >= 0.4 user.
  model <- fixture_fa_model()
  session <- fake_chat_session(
    "fa", response = fake_fa_response(colnames(model$loadings)),
    token_schema = "modern", input_tokens = 100, output_tokens = 50
  )

  result <- interpret(
    fit_results = model, chat_session = session,
    variable_info = fixture_var_info(), analysis_type = "fa",
    output_args = list(verbosity = 0)
  )

  expect_equal(result$total_tokens, 150)
  expect_equal(result$input_tokens, 100)
  expect_equal(result$output_tokens, 50)
})

test_that("session totals accumulate across interpretations", {
  # chat_local is a clone with turns cleared, so each interpretation sees only
  # its own turns; the SESSION counters are what must accumulate.
  model <- fixture_fa_model()
  session <- fake_chat_session(
    "fa", response = fake_fa_response(colnames(model$loadings)),
    token_schema = "modern", input_tokens = 100, output_tokens = 50
  )

  for (i in 1:3) {
    interpret(
      fit_results = model, chat_session = session,
      variable_info = fixture_var_info(), analysis_type = "fa",
      output_args = list(verbosity = 0)
    )
  }

  expect_equal(session$n_interpretations, 3L)
  expect_equal(session$total_input_tokens, 300)
  expect_equal(session$total_output_tokens, 150)
  expect_equal(session$cumulative_tokens$total_tokens, 450)
})

test_that("an unknown schema surfaces as NA rather than a plausible zero", {
  reset_token_schema_warning()
  model <- fixture_fa_model()
  session <- fake_chat_session(
    "fa", response = fake_fa_response(colnames(model$loadings)),
    token_schema = "unknown"
  )

  suppressWarnings(
    result <- interpret(
      fit_results = model, chat_session = session,
      variable_info = fixture_var_info(), analysis_type = "fa",
      output_args = list(verbosity = 0)
    )
  )

  expect_true(is.na(result$total_tokens))
  # The interpretation itself must still succeed - token counts are telemetry.
  expect_s3_class(result, "fa_interpretation")
  expect_true(nchar(result$report) > 0)
  reset_token_schema_warning()
})

test_that("printing a session with unknown token counts does not error", {
  # NA totals must survive the print path, or the honest-NA choice trades a
  # silent wrong number for a crash.
  session <- fake_chat_session("fa")
  session$total_input_tokens <- NA_real_
  session$total_output_tokens <- NA_real_
  session$cumulative_tokens <- list(
    input_tokens = NA_real_, output_tokens = NA_real_, total_tokens = NA_real_
  )

  expect_no_error(capture.output(print(session)))
})
