#' Create Factor Analysis Chat Session
#'
#' Creates a persistent chat session for factor analysis interpretation that can be reused
#' across multiple analyses to avoid repeating the system prompt and reduce
#' token costs.
#'
#' @param provider Character. LLM provider (e.g., "anthropic", "openai", "ollama")
#' @param model Character. Model name (e.g., "claude-haiku-4-5-20251001")
#' @param params List. ellmer parameters (temperature, etc.). Default uses ellmer::params()
#' @param echo Character. Echo level ("none", "output", "all"). Default is "none"
#'
#' @return A chat_fa object containing the persistent chat session
#'
#' @details
#' The chat_fa object stores:
#' - A persistent ellmer chat session with the factor analysis system prompt already loaded
#' - Provider and model information
#' - Token usage tracking (cumulative input/output tokens across all interpretations)
#' - Session metadata (number of interpretations run, creation timestamp)
#'
#' This allows for efficient reuse across multiple factor analysis interpretations without
#' resending the system prompt each time.
#'
#' **Token Tracking Note:** System prompt tokens are captured on first use (when the first
#' interpretation is run) because LLM providers don't send the system prompt until the first
#' message exchange. Cumulative token counts may be approximate for some providers (e.g., Ollama)
#' that cache system prompts. Input tokens may be undercounted due to caching, while output
#' tokens are typically accurate. Use `results$run_tokens` to access per-interpretation token counts.
#'
#' @examples
#' \dontrun{
#' # Create a persistent chat session
#' chat <- chat_fa("anthropic", "claude-haiku-4-5-20251001")
#'
#' # Use with multiple analyses
#' result1 <- interpret_fa(loadings1, var_info1, chat_session = chat)
#' result2 <- interpret_fa(loadings2, var_info2, chat_session = chat)
#'
#' # Check token usage
#' print(chat)
#' }
#'
#' @export
chat_fa <- function(provider,
                    model = NULL,
                    params = NULL,
                    echo = "none") {
  # Validate inputs
  if (!is.character(provider) || length(provider) != 1) {
    cli::cli_abort("provider must be a single character string")
  }

  if (!is.null(model) &&
      (!is.character(model) || length(model) != 1)) {
    cli::cli_abort("model must be a single character string or NULL")
  }

  if (is.null(params)) {
    params <- ellmer::params()
  }

  # Build system prompt (same as in interpret_fa)
  system_prompt <- paste0(
    "# ROLE\n",
    "You are an expert psychometrician specializing in factor analysis.\n\n",

    "# TASK\n",
    "Provide comprehensive factor analysis interpretation by: (1) identifying and naming meaningful constructs, (2) explaining factor composition and boundaries, and (3) analyzing relationships between factors.\n\n",

    "# KEY DEFINITIONS\n",
    "- **Loading**: Correlation coefficient (-1 to +1) between variable and factor\n",
    "- **Significant loading**: Loading with absolute value >= cutoff threshold\n",
    "- **Convergent validity**: Variables measuring similar constructs should load together; for two factors covering similar constructs, the correlation will be highly positive or negative\n",
    "- **Discriminant validity**: Factors should represent meaningfully distinct constructs; for two factors covering similar constructs, the correlation will be near zero\n",
    "- **Factor correlation**: Correlation between factors indicating relationship strength\n",
    "- **Factor interpretation**: Identifying underlying construct explaining variable relationships\n",
    "- **Variance explained**: Percentage of total data variance captured by each factor\n",
    "- **Emergency rule**: Use highest absolute loadings when none meet cutoff\n\n"
  )

  # Create provider/model specification
  provider_spec <- if (!is.null(model)) {
    provider <- tolower(provider)
    paste0(provider, "/", model)
  } else {
    provider
  }

  # Initialize chat using generic ellmer::chat
  chat <- tryCatch({
    ellmer::chat(
      name = provider_spec,
      system_prompt = system_prompt,
      params = params,
      echo = echo
    )
  }, error = function(e) {
    cli::cli_abort(
      c(
        "Failed to initialize LLM chat",
        "x" = "Provider: {.val {provider}}, Model: {.val {model %||% 'default'}}",
        "i" = "Error: {e$message}",
        "i" = "Check your API credentials and model availability"
      )
    )
  })
  #chat$chat('Respond with "Ready"')
  # Create chat_fa object using environment for reference semantics
  # This allows modifications (like incrementing counters) to persist
  chat_obj <- new.env(parent = emptyenv())
  chat_obj$chat <- chat
  chat_obj$provider <- provider
  chat_obj$model <- model
  chat_obj$params <- params
  chat_obj$echo <- echo
  chat_obj$created_at <- Sys.time()
  chat_obj$n_interpretations <- 0L
  chat_obj$total_input_tokens <- 0
  chat_obj$total_output_tokens <- 0

  class(chat_obj) <- "chat_fa"
  return(chat_obj)
}

#' Print method for chat_fa objects
#'
#' @param x A chat_fa object
#' @param ... Additional arguments (unused)
#'
#' @export
print.chat_fa <- function(x, ...) {
  cat("Factor Analysis Chat Session\n")
  cat("Provider:", x$provider, "\n")
  cat("Model:", x$model %||% "default", "\n")
  cat("Created:", as.character(x$created_at), "\n")
  cat("Interpretations run:", x$n_interpretations, "\n")

  # Show cumulative token usage from tracked fields
  # These are maintained separately to provide accurate cumulative counts

  cat(
    "Total tokens - Input:",
    x$total_input_tokens,
    ", Output:",
    x$total_output_tokens,
    "\n"
  )

  invisible(x)
}

#' Check if object is a chat_fa
#'
#' @param x Object to test
#' @return Logical indicating if x is a chat_fa object
#'
#' @export
is.chat_fa <- function(x) {
  inherits(x, "chat_fa")
}

#' Reset chat session
#'
#' Clears the conversation history while keeping the system prompt.
#' Useful for starting fresh analyses while maintaining the same session.
#'
#' @param chat_obj A chat_fa object
#' @return The chat_fa object with reset conversation history
#'
#' @export
reset.chat_fa <- function(chat_obj) {
  if (!is.chat_fa(chat_obj)) {
    cli::cli_abort("Object must be a chat_fa")
  }

  # Reset the chat session by creating a new one
  new_chat <- chat_fa(
    provider = chat_obj$provider,
    model = chat_obj$model,
    params = chat_obj$params,
    echo = chat_obj$echo
  )

  # Preserve original creation timestamp
  new_chat$created_at <- chat_obj$created_at
  # Reset counters and token tracking
  new_chat$n_interpretations <- 0L

  return(new_chat)
}
