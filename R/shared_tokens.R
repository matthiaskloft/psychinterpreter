# ==============================================================================
# TOKEN ACCOUNTING
# ==============================================================================
# `ellmer::chat$get_tokens()` changed shape in ellmer 0.4.0. It now returns one
# row per completed assistant turn with columns `input`, `output`,
# `cached_input`, `cost` and `input_preview`. Before that it returned a long
# frame of `role`/`tokens` pairs.
#
# The package read the old shape directly, so under any supported ellmer
# version it found no `role` column, fell through to `input_tokens <- 0`, and
# reported zero tokens for every call. Reporting 0 for "we could not tell" is
# what kept that defect invisible: a wrong number is indistinguishable from a
# real one. Anything we cannot parse now reports NA instead.
# ==============================================================================

# Warn-once state. An unrecognised schema is a property of the installed ellmer
# and the provider, not of any one call, so it does not change between
# interpretations - repeating the warning for every interpretation in a loop
# would be noise. This environment is package-global and lives for the whole R
# session, not per chat_session.
.token_schema_state <- new.env(parent = emptyenv())

#' Reset the one-time unknown-token-schema warning
#'
#' The warning is suppressed for the remainder of the R session once shown.
#' Exposed so tests can assert it fires, and so a long-running session can opt
#' back into being told again.
#'
#' @return Invisibly `NULL`, called for its side effect.
#' @keywords internal
reset_token_schema_warning <- function() {
  .token_schema_state$warned <- FALSE
  invisible(NULL)
}

#' Extract token counts from an ellmer token data frame
#'
#' Understands both the modern (ellmer >= 0.4) and legacy token schemas.
#'
#' @param tokens_df The data frame returned by `chat$get_tokens()`, or `NULL`.
#' @param warn Emit a one-time warning when the schema is unrecognised.
#'
#' @return A list with `input_tokens`, `output_tokens`, `cached_input_tokens`
#'   and `schema`. Counts are `NA_real_` when the schema is not recognised;
#'   `schema` is one of `"modern"`, `"legacy"`, `"none"` or `"unknown"`.
#'
#' @details
#' `cached_input` is added to `input_tokens`. ellmer documents a turn's tokens
#' as "input tokens (uncached), output tokens, and input tokens (cached)", so
#' the two input columns are disjoint parts of one total rather than a total
#' and a subset. Counting only `input` would systematically undercount every
#' provider that caches prompts.
#'
#' An empty frame means no assistant turns have completed yet. That is a known
#' zero, not an unknown quantity, so it reports 0 rather than NA.
#'
#' @keywords internal
extract_token_counts <- function(tokens_df, warn = TRUE) {
  no_tokens <- list(
    input_tokens = 0, output_tokens = 0, cached_input_tokens = 0,
    schema = "none"
  )

  if (is.null(tokens_df) || !is.data.frame(tokens_df) || nrow(tokens_df) == 0) {
    return(no_tokens)
  }

  column_names <- names(tokens_df)

  # ellmer >= 0.4
  if (all(c("input", "output") %in% column_names)) {
    cached <- if ("cached_input" %in% column_names) {
      normalize_token_count(sum(tokens_df$cached_input, na.rm = TRUE))
    } else {
      0
    }
    return(list(
      input_tokens = normalize_token_count(sum(tokens_df$input, na.rm = TRUE)) + cached,
      output_tokens = normalize_token_count(sum(tokens_df$output, na.rm = TRUE)),
      cached_input_tokens = cached,
      schema = "modern"
    ))
  }

  # ellmer < 0.4. Retained deliberately: DESCRIPTION pins ellmer >= 0.4.0, so
  # this branch is unreachable by contract, but it costs three lines and the
  # alternative if that floor is ever relaxed is a silent NA.
  if (all(c("role", "tokens") %in% column_names)) {
    return(list(
      input_tokens = normalize_token_count(
        sum(tokens_df$tokens[tokens_df$role == "user"], na.rm = TRUE)
      ),
      output_tokens = normalize_token_count(
        sum(tokens_df$tokens[tokens_df$role == "assistant"], na.rm = TRUE)
      ),
      cached_input_tokens = 0,
      schema = "legacy"
    ))
  }

  if (isTRUE(warn) && !isTRUE(.token_schema_state$warned)) {
    .token_schema_state$warned <- TRUE
    cli::cli_warn(c(
      "Unrecognised token schema returned by {.fn get_tokens}.",
      "x" = "Columns found: {.val {column_names}}",
      "i" = "Token counts will be reported as {.val NA} for this session.",
      "i" = "Interpretations are unaffected; only usage reporting is."
    ))
  }

  list(
    input_tokens = NA_real_, output_tokens = NA_real_,
    cached_input_tokens = NA_real_, schema = "unknown"
  )
}

#' Add one interpretation's token counts to a chat session
#'
#' @param chat_session A `chat_session` environment, mutated in place.
#' @param counts The list returned by [extract_token_counts()].
#'
#' @return Invisibly the updated `chat_session`.
#'
#' @details
#' `NA` propagates on purpose. Once a session has recorded an interpretation it
#' could not measure, its cumulative total is genuinely unknown, and carrying on
#' with a partial sum would present that partial figure as complete.
#'
#' @keywords internal
update_session_tokens <- function(chat_session, counts) {
  chat_session$total_input_tokens <-
    chat_session$total_input_tokens + counts$input_tokens
  chat_session$total_output_tokens <-
    chat_session$total_output_tokens + counts$output_tokens

  chat_session$cumulative_tokens$input_tokens <- chat_session$total_input_tokens
  chat_session$cumulative_tokens$output_tokens <- chat_session$total_output_tokens
  chat_session$cumulative_tokens$total_tokens <-
    chat_session$total_input_tokens + chat_session$total_output_tokens

  invisible(chat_session)
}
