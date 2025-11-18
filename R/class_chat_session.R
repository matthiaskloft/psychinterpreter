#' Create Analysis Chat Session
#'
#' Creates a persistent chat session for psychometric interpretation that can be reused
#' across multiple analyses to avoid repeating the system prompt and reduce
#' token costs.
#'
#' @param analysis_type Character. Type of analysis: "fa" (factor analysis), "gm" (gaussian mixture),
#'   "irt" (item response theory), or "cdm" (cognitive diagnosis model)
#' @param llm_provider Character. LLM provider (e.g., "anthropic", "openai", "ollama")
#' @param llm_model Character. Model name (e.g., "claude-haiku-4-5-20251001")
#' @param system_prompt Character or NULL. Optional custom system prompt text to override the model-specific
#'   default system prompt. Use this to provide institution- or project-specific framing for the LLM
#'   (e.g., preferred terminology, audience level, or reporting conventions). If NULL, the model-specific
#'   default system prompt is used (default = NULL).
#' @param params List. ellmer parameters (temperature, etc.). Default uses ellmer::params()
#' @param echo Character. Echo level ("none", "output", "all"). Default is "none"
#' @param word_limit Integer. Word limit for interpretations (only used if system_prompt is NULL).
#'   Default is 100.
#'
#' @return A chat_session object containing the persistent chat session
#'
#' @details
#' The chat_session object stores:
#' - A persistent ellmer chat session with the model-specific system prompt already loaded
#' - Analysis type, provider, and model information
#' - Token usage tracking (cumulative input/output tokens across all interpretations)
#' - Session metadata (number of interpretations run, creation timestamp)
#'
#' This allows for efficient reuse across multiple interpretations without
#' resending the system prompt each time.
#'
#' **Token Tracking Note:**
#' The package tracks per-interpretation token counts using roles returned by
#' `ellmer::chat$get_tokens()` (user/assistant). Some providers or the `ellmer`
#' wrapper do not consistently expose `system`/`system_prompt` token counts (this
#' appears to be an upstream limitation/bug). To avoid incorrect cumulative
#' accounting (double-counting or negative accumulation), `chat_session` intentionally
#' does NOT include `system_prompt` tokens in the package-level cumulative
#' counters (`total_input_tokens` / `total_output_tokens`).
#'
#' If you require a provider-specific view that includes system prompt tokens,
#' call `chat$chat$get_tokens(include_system_prompt = TRUE)` directly — but note
#' that results may vary across providers.
#'
#' @examples
#' \dontrun{
#' # Create a persistent chat session for factor analysis
#' chat <- chat_session("fa", "anthropic", "claude-haiku-4-5-20251001")
#'
#' # Use with multiple analyses
#' result1 <- interpret_fa(loadings1, var_info1, chat_session = chat)
#' result2 <- interpret_fa(loadings2, var_info2, chat_session = chat)
#'
#' # Check token usage
#' print(chat)
#'
#' # Create session for different analysis type
#' chat_gm <- chat_session("gm", "anthropic", "claude-haiku-4-5-20251001")
#' }
#'
#' @export
chat_session <- function(analysis_type = "fa",
                        llm_provider,
                        llm_model = NULL,
                        system_prompt = NULL,
                        params = NULL,
                        echo = "none",
                        word_limit = 100) {
  # Validate analysis_type
  validate_analysis_type(analysis_type)

  # Validate inputs
  if (!is.character(llm_provider) || length(llm_provider) != 1) {
    cli::cli_abort("llm_provider must be a single character string")
  }

  if (!is.null(llm_model) &&
      (!is.character(llm_model) || length(llm_model) != 1)) {
    cli::cli_abort("llm_model must be a single character string or NULL")
  }

  if (is.null(params)) {
    params <- ellmer::params()
  }

  # Use user system_prompt if provided, otherwise build model-specific prompt
  if (!is.null(system_prompt)) {
    final_system_prompt <- system_prompt
  } else {
    # Delegate to model-specific system prompt builder (S3 dispatch)
    final_system_prompt <- build_system_prompt(
      structure(list(), class = analysis_type),
      word_limit = word_limit
    )
  }

  # Create provider/model specification
  provider_spec <- if (!is.null(llm_model)) {
    llm_provider <- tolower(llm_provider)
    paste0(llm_provider, "/", llm_model)
  } else {
    llm_provider
  }

  # Initialize chat using generic ellmer::chat
  chat <- tryCatch({
    ellmer::chat(
      name = provider_spec,
      system_prompt = final_system_prompt,
      params = params,
      echo = echo
    )
  }, error = function(e) {
    cli::cli_abort(
      c(
        "Failed to initialize LLM chat",
        "x" = "Provider: {.val {llm_provider}}, Model: {.val {llm_model %||% 'default'}}",
        "i" = "Error: {e$message}",
        "i" = "Check your API credentials and model availability"
      )
    )
  })

  # Create chat_session object using environment for reference semantics
  # This allows modifications (like incrementing counters) to persist
  chat_obj <- new.env(parent = emptyenv())
  chat_obj$analysis_type <- analysis_type
  chat_obj$chat <- chat
  chat_obj$llm_provider <- llm_provider
  chat_obj$llm_model <- llm_model
  chat_obj$params <- params
  chat_obj$echo <- echo
  chat_obj$created_at <- Sys.time()
  chat_obj$n_interpretations <- 0L
  # Initialize token tracking fields as single numeric values
  # (Some providers don't support token tracking and will leave these at 0)
  chat_obj$total_input_tokens <- 0.0
  chat_obj$total_output_tokens <- 0.0
  chat_obj$cumulative_tokens <- list(
    input_tokens = 0.0,
    output_tokens = 0.0,
    total_tokens = 0.0
  )
  chat_obj$system_prompt <- final_system_prompt

  class(chat_obj) <- c(paste0(analysis_type, "_chat_session"), "chat_session")
  return(chat_obj)
}

#' Print method for chat_session objects
#'
#' @param x A chat_session object
#' @param ... Additional arguments (unused)
#'
#' @export
print.chat_session <- function(x, ...) {
  # Get nice analysis type name
  analysis_type_names <- c(
    fa = "Factor Analysis",
    gm = "Gaussian Mixture",
    irt = "Item Response Theory",
    cdm = "Cognitive Diagnosis"
  )
  analysis_type_name <- analysis_type_names[x$analysis_type] %||% x$analysis_type

  cat(analysis_type_name, "Chat Session\n")
  cat("Provider:", x$llm_provider, "\n")
  cat("Model:", x$llm_model %||% "default", "\n")
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

#' Check if object is a chat_session
#'
#' @param x Object to test
#' @return Logical indicating if x is a chat_session object
#'
#' @export
is.chat_session <- function(x) {
  inherits(x, "chat_session")
}

#' Reset chat session
#'
#' Clears the conversation history while keeping the system prompt.
#' Useful for starting fresh analyses while maintaining the same session.
#'
#' @param chat_obj A chat_session object
#' @return The chat_session object with reset conversation history
#'
#' @export
reset.chat_session <- function(chat_obj) {
  if (!is.chat_session(chat_obj)) {
    cli::cli_abort("Object must be a chat_session")
  }

  # Reset the chat session by creating a new one
  new_chat <- chat_session(
    analysis_type = chat_obj$analysis_type,
    llm_provider = chat_obj$llm_provider,
    llm_model = chat_obj$llm_model,
    system_prompt = chat_obj$system_prompt,  # Reuse same prompt
    params = chat_obj$params,
    echo = chat_obj$echo
  )

  # Preserve original creation timestamp
  new_chat$created_at <- chat_obj$created_at
  # Reset counters and token tracking
  new_chat$n_interpretations <- 0L

  new_chat
}
