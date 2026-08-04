# ==============================================================================
# TEST: Config object resolution (F-06)
# ==============================================================================
# Purpose: llm_args()/output_args() values must actually reach the code that
#          uses them. The old resolution block tested `is.null(x)` to decide
#          "did the caller supply this?", which is never TRUE for a parameter
#          with a non-NULL default - so output_args was inert and six of the
#          eight llm_args fields were dropped on the floor.
# Ref:     dev/CODE_REVIEW_CONSOLIDATED_2026-07-25.md (F-06)
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

run_interpret <- function(...) {
  model <- fixture_fa_model()
  session <- fake_chat_session("fa", response = fake_fa_response(colnames(model$loadings)))
  result <- interpret(
    fit_results = model, chat_session = session,
    variable_info = fixture_var_info(), analysis_type = "fa", ...
  )
  list(result = result, prompt = fake_prompts(session)[[1]], session = session)
}

# ------------------------------------------------------- resolve_call_params()

test_that("a supplied value beats a config value, which beats the default", {
  resolve <- function(supplied, config) {
    resolve_call_params(
      supplied = supplied, config = config,
      defaults = list(word_limit = 100, output_format = "cli")
    )
  }

  # Nothing supplied anywhere -> default.
  expect_equal(resolve(list(), NULL)$word_limit, 100)
  # Config only -> config wins over default.
  expect_equal(resolve(list(), list(word_limit = 250))$word_limit, 250)
  # Direct argument -> beats config.
  expect_equal(resolve(list(word_limit = 75), list(word_limit = 250))$word_limit, 75)
})

test_that("a supplied value equal to the default still beats the config", {
  # The old code used `verbosity == 2` as its not-supplied test, so a caller who
  # explicitly asked for the default value was silently overridden. Supplying a
  # value must win regardless of what that value happens to be.
  out <- resolve_call_params(
    supplied = list(word_limit = 100),
    config = list(word_limit = 250),
    defaults = list(word_limit = 100)
  )
  expect_equal(out$word_limit, 100)
})

test_that("an explicit NULL is treated as supplied, not as absent", {
  out <- resolve_call_params(
    supplied = list(system_prompt = NULL),
    config = list(system_prompt = "from config"),
    defaults = list(system_prompt = NULL)
  )
  expect_null(out$system_prompt)
})

test_that("config keys unknown to the defaults are ignored, not injected", {
  out <- resolve_call_params(
    supplied = list(), config = list(word_limit = 250, nonsense = 1),
    defaults = list(word_limit = 100)
  )
  expect_named(out, "word_limit")
})

# ------------------------------------------------------------- output_args

test_that("output_args$format actually changes the report format", {
  # Regression: format has a non-NULL default ("cli"), so `is.null(output_format)`
  # was never TRUE and output_args was ignored entirely. The markdown report
  # opens with a "#" heading; the cli one opens with a bare underlined title.
  via_config <- run_interpret(output_args = list(format = "markdown", verbosity = 0))
  via_direct <- run_interpret(output_format = "markdown", output_args = list(verbosity = 0))
  as_cli <- run_interpret(output_args = list(format = "cli", verbosity = 0))

  expect_match(via_config$result$report, "^#")
  expect_match(via_direct$result$report, "^#")
  expect_false(grepl("^#", as_cli$result$report))
})

test_that("output_args$heading_level and $suppress_heading take effect", {
  with_heading <- run_interpret(output_args = list(
    format = "markdown", heading_level = 3, suppress_heading = FALSE, verbosity = 0
  ))
  suppressed <- run_interpret(output_args = list(
    format = "markdown", heading_level = 3, suppress_heading = TRUE, verbosity = 0
  ))

  # heading_level 3 means the title is rendered as "### ", not "# ".
  expect_match(with_heading$result$report, "^### ")
  # suppress_heading drops the title line altogether.
  expect_false(grepl("^#", suppressed$result$report))
})

test_that("a direct argument still overrides output_args", {
  res <- run_interpret(
    output_format = "cli",
    output_args = list(format = "markdown", verbosity = 0)
  )
  expect_false(grepl("^#", res$result$report))
})

# ---------------------------------------------------------------- llm_args

# llm_args() treats llm_provider as a required field, so these configs carry one
# even though the chat_session is what actually gets used.

test_that("llm_args$word_limit reaches the prompt", {
  res <- run_interpret(
    llm_args = list(llm_provider = "ollama", word_limit = 250),
    output_args = list(verbosity = 0)
  )
  expect_match(res$prompt, "250")
})

test_that("llm_args$additional_info reaches the prompt", {
  res <- run_interpret(
    llm_args = list(llm_provider = "ollama", additional_info = "ZZCONTEXTZZ"),
    output_args = list(verbosity = 0)
  )
  expect_match(res$prompt, "ZZCONTEXTZZ", fixed = TRUE)
})

test_that("llm_args$interpretation_guidelines reaches the prompt", {
  # This one has no formal in interpret_core(); the prompt builders read it out
  # of `...`, so the config value has to be routed into dots explicitly.
  res <- run_interpret(
    llm_args = list(llm_provider = "ollama", interpretation_guidelines = "ZZGUIDEZZ"),
    output_args = list(verbosity = 0)
  )
  expect_match(res$prompt, "ZZGUIDEZZ", fixed = TRUE)
})

test_that("values routed through llm_args are validated like direct arguments", {
  # The sharpest symptom of F-06: llm_args(word_limit = 999) was accepted in
  # silence while word_limit = 999 was correctly rejected, because nothing ever
  # read the config value and so nothing ever validated it.
  expect_error(
    run_interpret(
      llm_args = list(llm_provider = "ollama", word_limit = 999),
      output_args = list(verbosity = 0)
    ),
    "word_limit"
  )
  expect_error(
    run_interpret(output_args = list(max_line_length = 5000, verbosity = 0)),
    "max_line_length"
  )
})

# ---------------------------------------------------------------- registry

test_that("registry defaults agree with the function formals", {
  # These disagreed (word_limit 150 vs 100, max_line_length 80 vs 120). While
  # the config path was inert the mismatch was invisible; now it would silently
  # change output for anyone using llm_args()/output_args().
  expect_equal(get_param_default("word_limit"), formals(interpret_core)$word_limit)
  expect_equal(get_param_default("max_line_length"), formals(interpret_core)$max_line_length)
})
