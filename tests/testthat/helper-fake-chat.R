# ==============================================================================
# OFFLINE CHAT FIXTURE
# ==============================================================================
# A fake ellmer chat / chat_session that satisfies the contract interpret_core()
# and label_variables() actually use, so integration behaviour can be tested
# with no network, no credentials, and no provider.
#
# Why this exists separately from helper-mock-llm.R:
#   - mock_chat_session() returned a plain list. The real chat_session() uses
#     new.env() for REFERENCE semantics, because interpret_core() mutates the
#     session in place (total_input_tokens, cumulative_tokens,
#     n_interpretations). On a list those writes are discarded, so any test of
#     token accounting against it is meaningless.
#   - mock_chat()$get_tokens() returned the legacy role/tokens schema. ellmer
#     >= 0.4 returns input/output/cached_input. A fixture on the old schema
#     would make broken token code look correct.
#
# Contract exercised by the package (R/core_interpret.R, R/label_main.R):
#   session$analysis_type / $chat / $llm_provider / $llm_model / $params /
#     $echo / $created_at / $n_interpretations / $total_input_tokens /
#     $total_output_tokens / $cumulative_tokens / $system_prompt
#   session$chat$clone()$set_turns(list())
#   session$chat$chat(prompt, echo =)
#   session$chat$get_tokens()
#   session$chat$get_provider()@name
#   session$chat$get_model()
# ==============================================================================

setClass("FakeProvider", slots = c(name = "character"))

#' Build a token data frame in a chosen ellmer schema
#'
#' @param schema "modern" (ellmer >= 0.4), "legacy" (pre-0.4), "unknown", or "empty"
#' @param input,output Token counts to report
#' @noRd
#' @param n_turns Assistant turns completed so far. Real ellmer returns one row
#'   PER TURN and zero rows before the first call; a fixture that always returns
#'   a single constant row would let a token fix that ignores multi-turn
#'   accumulation pass untested.
fake_tokens <- function(schema = c("modern", "legacy", "unknown", "empty"),
                        input = 100, output = 50, cached_input = 0,
                        n_turns = 1) {
  schema <- match.arg(schema)
  n <- max(0L, as.integer(n_turns))

  switch(schema,
    # Mirrors ellmer 0.4.2: one row per assistant turn, including the columns
    # the package does not read - a fixture that omits them is not a faithful
    # stand-in.
    modern = data.frame(
      input = rep(input, n), output = rep(output, n),
      cached_input = rep(cached_input, n),
      cost = rep(NA_real_, n), input_preview = rep(NA_character_, n),
      stringsAsFactors = FALSE
    ),
    legacy = data.frame(
      role = rep(c("user", "assistant"), times = n),
      tokens = rep(c(input, output), times = n),
      stringsAsFactors = FALSE
    ),
    unknown = data.frame(
      prompt_units = rep(input, n), completion_units = rep(output, n),
      stringsAsFactors = FALSE
    ),
    empty = data.frame()
  )
}

#' Create a fake ellmer chat object
#'
#' @param response Character scalar returned by $chat(), or a function(prompt)
#' @param token_schema See fake_tokens()
#' @param log Environment used to record prompts; created if NULL
#' @noRd
fake_chat <- function(response = '{"factor_summaries": {}, "suggested_names": {}}',
                      token_schema = "modern",
                      input_tokens = 100,
                      output_tokens = 50,
                      cached_input_tokens = 0,
                      log = NULL) {
  if (is.null(log)) log <- new.env(parent = emptyenv())
  if (is.null(log$prompts)) log$prompts <- character(0)
  if (is.null(log$echos)) log$echos <- character(0)
  if (is.null(log$n_calls)) log$n_calls <- 0L

  # Turn state is PER CHAT OBJECT, while the prompt log is shared across
  # clones. Real ellmer derives get_tokens() from get_turns(), so
  # clone()$set_turns(list()) genuinely resets the token frame to zero rows -
  # which is exactly what interpret_core() relies on to get per-interpretation
  # counts. A fixture with one shared cumulative counter would hide a token
  # fix that double-counts across interpretations.
  state <- new.env(parent = emptyenv())
  state$n_turns <- 0L

  build <- function(state) {
    self <- list(
      .log = log,
      .state = state,
      chat = function(prompt, echo = "none", ...) {
        log$prompts <- c(log$prompts, prompt)
        # Recorded so tests can assert which echo level actually reached the
        # LLM call; it is not stored anywhere in the returned objects.
        log$echos <- c(log$echos, echo)
        log$n_calls <- log$n_calls + 1L
        state$n_turns <- state$n_turns + 1L
        if (is.function(response)) response(prompt) else response
      },
      get_turns = function() vector("list", state$n_turns),
      extract_data = function(...) list(),
      get_tokens = function(...) {
        # One row per completed assistant turn, as real ellmer does.
        fake_tokens(token_schema, input = input_tokens, output = output_tokens,
                    cached_input = cached_input_tokens, n_turns = state$n_turns)
      },
      get_provider = function() new("FakeProvider", name = "fake"),
      get_model = function() "fake-model"
    )
    self$set_turns <- function(value) {
      state$n_turns <- length(value)
      self
    }
    # clone() gets its own turn state, seeded from this one, but keeps writing
    # prompts to the SAME log so tests can inspect what was actually sent.
    self$clone <- function() {
      cloned_state <- new.env(parent = emptyenv())
      cloned_state$n_turns <- state$n_turns
      build(cloned_state)
    }
    self
  }

  build(state)
}

#' Create a fake chat_session with correct reference semantics
#'
#' Mirrors R/class_chat_session.R: an environment, not a list, so in-place
#' mutation of token counters by interpret_core() persists to the caller.
#'
#' @param analysis_type "fa", "gm", or "label"
#' @param response Character scalar returned by the LLM, or function(prompt)
#' @param token_schema See fake_tokens()
#' @noRd
fake_chat_session <- function(analysis_type = "fa",
                              response = '{"factor_summaries": {}, "suggested_names": {}}',
                              token_schema = "modern",
                              input_tokens = 100,
                              output_tokens = 50,
                              cached_input_tokens = 0,
                              system_prompt = "FAKE SYSTEM PROMPT") {
  log <- new.env(parent = emptyenv())
  log$prompts <- character(0)
  log$echos <- character(0)
  log$n_calls <- 0L

  session <- new.env(parent = emptyenv())
  session$analysis_type <- analysis_type
  session$chat <- fake_chat(
    response = response, token_schema = token_schema,
    input_tokens = input_tokens, output_tokens = output_tokens,
    cached_input_tokens = cached_input_tokens, log = log
  )
  session$llm_provider <- "fake"
  session$llm_model <- "fake-model"
  session$params <- NULL
  session$echo <- "none"
  session$created_at <- Sys.time()
  session$n_interpretations <- 0L
  session$total_input_tokens <- 0
  session$total_output_tokens <- 0
  session$cumulative_tokens <- list(
    input_tokens = 0, output_tokens = 0, total_tokens = 0
  )
  session$system_prompt <- system_prompt
  session$.log <- log

  class(session) <- c(paste0(analysis_type, "_chat_session"), "chat_session")
  session
}

#' Prompts recorded by a fake chat session
#' @noRd
fake_prompts <- function(session) session$.log$prompts

#' Number of times the chat method was invoked
#' @noRd
fake_call_count <- function(session) session$.log$n_calls

#' Echo levels the package actually passed to $chat()
#' @noRd
fake_echos <- function(session) session$.log$echos

#' A well-formed FA response matching the package's expected JSON shape
#'
#' validate_parsed_result.fa() expects top-level keys named after the factors,
#' each an object with `name` and `interpretation` (see R/fa_json.R:22-93).
#'
#' @param factors Factor column names, e.g. colnames(fa_model$loadings)
#' @noRd
fake_fa_response <- function(factors = c("MR1", "MR2")) {
  entries <- vapply(
    seq_along(factors),
    function(i) {
      sprintf('"%s": {"name": "Fake Name %d", "interpretation": "Fake interpretation of %s."}',
              factors[i], i, factors[i])
    },
    character(1)
  )
  paste0("{", paste(entries, collapse = ", "), "}")
}

#' A well-formed label response
#'
#' validate_label_structure() expects a JSON ARRAY of objects, each carrying
#' `variable` and `label` (see R/label_json.R:50-74). Anything else silently
#' falls back to pattern extraction and then to variable names, which would make
#' a formatting test pass against unformatted input.
#'
#' @param variables Variable names to label
#' @param labels Labels to return; defaults to "Fake Label <i>"
#' @noRd
fake_label_response <- function(variables, labels = NULL) {
  if (is.null(labels)) labels <- paste("Fake Label", seq_along(variables))
  entries <- vapply(
    seq_along(variables),
    function(i) sprintf('{"variable": "%s", "label": "%s"}', variables[i], labels[i]),
    character(1)
  )
  paste0("[", paste(entries, collapse = ", "), "]")
}

#' A well-formed GM response
#'
#' @param clusters Cluster names
#' @noRd
fake_gm_response <- function(clusters = c("Cluster 1", "Cluster 2")) {
  entries <- vapply(
    seq_along(clusters),
    function(i) {
      sprintf('"%s": {"name": "Fake Cluster %d", "interpretation": "Fake interpretation of %s."}',
              clusters[i], i, clusters[i])
    },
    character(1)
  )
  paste0("{", paste(entries, collapse = ", "), "}")
}
