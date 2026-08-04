# ==============================================================================
# TEST: Offline chat fixture contract
# ==============================================================================
# Purpose: Prove the fake chat session satisfies the contract interpret_core()
#          actually uses, so Phase 1 defects can be tested with no network.
# Ref:     dev/REMEDIATION_PLAN_2026-07-25.md (PR #2)
# ==============================================================================

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


test_that("fake session drives a full interpretation with no network", {
  model <- fixture_fa_model()
  factors <- colnames(model$loadings)
  session <- fake_chat_session("fa", response = fake_fa_response(factors))

  result <- interpret_core(
    fit_results = model, chat_session = session,
    variable_info = fixture_var_info(), analysis_type = "fa", verbosity = 0
  )

  expect_s3_class(result, "fa_interpretation")
  # The response must have been PARSED, not silently defaulted.
  expect_equal(unname(unlist(result$suggested_names)),
               paste("Fake Name", seq_along(factors)))
  expect_true(nchar(result$report) > 0)
})

test_that("fake session records the prompt actually sent", {
  model <- fixture_fa_model()
  session <- fake_chat_session("fa", response = fake_fa_response(colnames(model$loadings)))

  interpret_core(
    fit_results = model, chat_session = session,
    variable_info = fixture_var_info(), analysis_type = "fa", verbosity = 0
  )

  expect_equal(fake_call_count(session), 1L)
  prompts <- fake_prompts(session)
  expect_length(prompts, 1)
  # Variable descriptions must reach the model.
  expect_true(grepl("description of a", prompts[[1]], fixed = TRUE))
})

test_that("fake session has reference semantics like the real chat_session", {
  # The real chat_session() is an environment because interpret_core() mutates
  # counters in place. A list-based fixture silently discards those writes.
  session <- fake_chat_session("fa")
  expect_true(is.environment(session))
  expect_s3_class(session, "chat_session")

  model <- fixture_fa_model()
  session <- fake_chat_session("fa", response = fake_fa_response(colnames(model$loadings)))
  interpret_core(
    fit_results = model, chat_session = session,
    variable_info = fixture_var_info(), analysis_type = "fa", verbosity = 0
  )

  expect_equal(session$n_interpretations, 1L)
})

test_that("fake session exposes every field the package reads", {
  session <- fake_chat_session("fa")
  required <- c(
    "analysis_type", "chat", "llm_provider", "llm_model", "params", "echo",
    "created_at", "n_interpretations", "total_input_tokens",
    "total_output_tokens", "cumulative_tokens", "system_prompt"
  )
  expect_true(all(required %in% ls(session)))

  expect_true(is.function(session$chat$clone))
  expect_true(is.function(session$chat$get_tokens))
  expect_true(is.function(session$chat$get_model))
  expect_equal(session$chat$get_provider()@name, "fake")
  # interpret_core() calls clone()$set_turns(list())
  expect_no_error(session$chat$clone()$set_turns(list()))
})

test_that("fake session can emit each ellmer token schema", {
  # The modern frame must mirror what ellmer >= 0.4 actually returns.
  expect_true(all(c("input", "output", "cached_input") %in% names(fake_tokens("modern"))))
  expect_named(fake_tokens("legacy"), c("role", "tokens"))
  expect_equal(nrow(fake_tokens("empty")), 0)
  expect_false(any(c("role", "tokens") %in% names(fake_tokens("modern"))))
})

test_that("token schema choice changes what the package records", {
  # Documents F-01 rather than asserting the (broken) values: the package reads
  # role/tokens, which ellmer >= 0.4 no longer emits, so the modern schema
  # yields 0. This test must be updated when F-01 is fixed - at which point
  # modern should report 150 and legacy is the one that stops mattering.
  model <- fixture_fa_model()
  response <- fake_fa_response(colnames(model$loadings))
  run <- function(schema) {
    session <- fake_chat_session("fa", response = response, token_schema = schema,
                                 input_tokens = 100, output_tokens = 50)
    interpret_core(
      fit_results = model, chat_session = session,
      variable_info = fixture_var_info(), analysis_type = "fa", verbosity = 0
    )$total_tokens
  }

  expect_equal(run("legacy"), 150)
  # The schema the declared ellmer dependency actually returns:
  expect_equal(run("modern"), 0)
})

test_that("token frame grows one row per turn, like real ellmer", {
  # Real ellmer returns 0 rows before the first call and one row per assistant
  # turn. A fixture returning a constant single row would let a token fix that
  # ignores multi-turn accumulation pass untested.
  session <- fake_chat_session("fa")
  expect_equal(nrow(session$chat$get_tokens()), 0)

  session$chat$chat("first")
  expect_equal(nrow(session$chat$get_tokens()), 1)

  session$chat$chat("second")
  session$chat$chat("third")
  expect_equal(nrow(session$chat$get_tokens()), 3)
})

test_that("print.chat_session works on the fake session", {
  # Guards against the fixture drifting from the fields print() reads.
  session <- fake_chat_session("fa")
  expect_output(print(session), "Factor Analysis")
})
