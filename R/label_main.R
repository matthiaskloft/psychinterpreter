#' Generate Variable Labels Using LLM
#'
#' Create short, descriptive labels for variables based on their descriptions
#' using Large Language Models. Supports various label formats and extensive
#' post-processing options.
#'
#' @section Parameter Organization:
#' Parameters are organized into groups:
#' \itemize{
#'   \item **Core**: variable_info, chat_session, llm_provider, llm_model
#'   \item **Semantic Generation (LLM-facing)**: label_type, max_words, max_chars, style_hint
#'   \item **Format Processing (post-processing)**: case, sep, remove_articles, remove_prepositions, abbreviate
#'   \item **Configuration Objects**: labeling_args, llm_args, output_args
#'   \item **Control**: echo, silent
#' }
#'
#' @param variable_info Data frame with 'description' column (required) and optional
#'   'variable' column. If 'variable' is not provided, names will be auto-generated
#'   as V1, V2, V3, etc.
#' @param chat_session Chat session object or NULL. If NULL, creates temporary session
#' @param llm_provider Character. LLM provider (e.g., "anthropic", "openai", "ollama").
#'   Required when chat_session is NULL
#' @param llm_model Character or NULL. Model name. If NULL and chat_session is NULL,
#'   uses provider's default model
#' @param label_type Character. Type of labels: "short" (1-3 words), "phrase" (4-7 words),
#'   "acronym" (3-5 chars), or "custom" (default = "short")
#' @param max_words Integer or NULL. **Sets upper limit for word count** (overrides label_type
#'   presets EXCEPT for "acronym"). Instructs the LLM to generate labels with up to this many
#'   words. Also applies post-processing truncation if needed. More effective than using
#'   \code{max_words} in \code{reformat_labels()}. Ignored when label_type = "acronym".
#' @param max_chars Integer or NULL. **Sets upper limit for character count**. Instructs the LLM
#'   to generate labels within this character limit. Works with ALL label types including
#'   "acronym" (where it controls the acronym length). Also applies post-processing truncation
#'   if needed. More effective than using \code{max_chars} in \code{reformat_labels()}.
#' @param style_hint Character or NULL. Style guidance for LLM (e.g., "technical", "simple",
#'   "academic"). Influences the LLM's choice of terminology and phrasing.
#' @param case Character. Case transformation: "original", "lower", "upper", "title",
#'   "sentence", "snake", "camel", "constant" (default = "original").
#'   Post-processing only - does not affect LLM generation.
#' @param sep Character. Separator between words in final output (default = " ").
#'   Post-processing only - does not affect LLM generation.
#' @param remove_articles Logical. Remove articles (a, an, the) from labels (default = FALSE).
#'   Post-processing only - does not affect LLM generation.
#' @param remove_prepositions Logical. Remove prepositions (of, in, at, etc.) (default = FALSE).
#'   Post-processing only - does not affect LLM generation.
#' @param abbreviate Logical. Apply rule-based abbreviation to long words (default = FALSE).
#'   Post-processing only - does not affect LLM generation.
#' @param label_args List or label_args object. Labeling-specific configuration.
#'   Created with \code{\link{label_args}}. Direct parameters take precedence.
#' @param llm_args List or llm_args object. LLM configuration settings.
#'   Created with \code{\link{llm_args}}. Direct parameters take precedence.
#' @param output_args List or output_args object. Output configuration settings.
#'   Created with \code{\link{output_args}}. Direct parameters take precedence.
#' @param echo Character. Echo level: "none", "output", "all" (default = "none")
#' @param silent Integer or logical. Controls output verbosity (default = 0)
#'
#' @return A variable_labels object containing:
#'   \item{labels_formatted}{Data frame with formatted 'variable' and 'label' columns}
#'   \item{labels_parsed}{Data frame with unformatted LLM labels}
#'   \item{variable_info}{Data frame with original variable information (variable, description)}
#'   \item{llm_response}{Raw LLM response text for reformatting}
#'   \item{metadata}{List with label_type, timestamp, and token usage}
#'   \item{chat_session}{Chat session object for reuse or inspection}
#'
#' @details
#' The function works in two phases:
#' 1. **Semantic Generation**: LLM generates natural language labels based on descriptions
#' 2. **Format Processing**: Apply transformations (case, separators, abbreviation, etc.)
#'
#' Special case behaviors:
#' - \code{case = "snake"} automatically sets \code{sep = "_"} and lowercase
#' - \code{case = "camel"} automatically sets \code{sep = ""} and applies camelCase
#' - \code{case = "constant"} automatically sets \code{sep = "_"} and uppercase
#'
#' @examples
#' \dontrun{
#' # Basic usage with explicit variable names
#' labels <- label_variables(
#'   variable_info = data.frame(
#'     variable = c("q1", "q2", "q3"),
#'     description = c(
#'       "How satisfied are you with your job?",
#'       "Rate your work-life balance",
#'       "Years of experience"
#'     )
#'   ),
#'   llm_provider = "ollama",
#'   llm_model = "gpt-oss:20b-cloud"
#' )
#'
#' # Variable names are optional - will auto-generate V1, V2, V3, etc.
#' labels <- label_variables(
#'   variable_info = data.frame(
#'     description = c(
#'       "How satisfied are you with your job?",
#'       "Rate your work-life balance",
#'       "Years of experience"
#'     )
#'   ),
#'   llm_provider = "ollama",
#'   llm_model = "gpt-oss:20b-cloud"
#' )
#'
#' # Using configuration objects (dual-tier architecture)
#' label_config <- label_args(
#'   label_type = "short",
#'   case = "snake",
#'   remove_articles = TRUE
#' )
#'
#' llm_config <- llm_args(
#'   word_limit = 50,
#'   echo = "none"
#' )
#'
#' labels <- label_variables(
#'   variable_info,
#'   label_args = label_config,
#'   llm_args = llm_config,
#'   llm_provider = "ollama",
#'   llm_model = "gpt-oss:20b-cloud"
#' )
#'
#' # Direct parameters override config objects
#' labels <- label_variables(
#'   variable_info,
#'   label_args = label_config,  # says case = "snake"
#'   case = "camel",                 # This takes precedence!
#'   llm_provider = "ollama",
#'   llm_model = "gpt-oss:20b-cloud"
#' )
#'
#' # Reuse chat session for efficiency
#' chat <- chat_session("label", "ollama", "gpt-oss:20b-cloud")
#' labels1 <- label_variables(data1, chat_session = chat)
#' labels2 <- label_variables(data2, chat_session = chat)
#'
#' # Export results
#' export_labels(labels, "variable_labels.csv")
#' }
#'
#' @export
label_variables <- function(variable_info,
                           chat_session = NULL,
                           llm_provider = NULL,
                           llm_model = NULL,
                           label_type = "short",
                           max_words = NULL,
                           style_hint = NULL,
                           sep = " ",
                           case = "original",
                           remove_articles = FALSE,
                           remove_prepositions = FALSE,
                           max_chars = NULL,
                           abbreviate = FALSE,
                           label_args = NULL,
                           llm_args = NULL,
                           output_args = NULL,
                           echo = "none",
                           silent = 0) {

  # Capture start time
  start_time <- Sys.time()

  # ==========================================================================
  # STEP 1: VALIDATE INPUTS
  # ==========================================================================

  # Validate variable_info
  if (!is.data.frame(variable_info)) {
    cli::cli_abort("{.var variable_info} must be a data frame")
  }

  if (nrow(variable_info) == 0) {
    cli::cli_abort("{.var variable_info} must contain at least one row")
  }

  # Check for description column (required)
  if (!"description" %in% names(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} must contain a 'description' column",
        "i" = "The 'variable' column is optional and will be auto-generated if not provided"
      )
    )
  }

  # Auto-generate variable names if not provided
  if (!"variable" %in% names(variable_info)) {
    if (silent < 2) {
      cli::cli_alert_info("No 'variable' column provided, auto-generating names (V1, V2, ...)")
    }
    variable_info$variable <- paste0("V", seq_len(nrow(variable_info)))
  }

  # Reorder columns to ensure variable comes first
  variable_info <- variable_info[, c("variable", "description")]

  # Handle backward compatibility: Convert logical silent to integer
  if (is.logical(silent)) {
    silent <- ifelse(silent, 2, 0)
  }

  # ==========================================================================
  # EXTRACT PARAMETERS FROM CONFIG OBJECTS (DUAL-TIER ARCHITECTURE)
  # Direct parameters always take precedence over config objects
  # ==========================================================================

  # Extract label_args if provided
  if (!is.null(label_args)) {
    # Only use config values if direct parameter is at default
    if (label_type == "short" && !is.null(label_args$label_type)) {
      label_type <- label_args$label_type
    }
    if (is.null(max_words) && !is.null(label_args$max_words)) {
      max_words <- label_args$max_words
    }
    if (is.null(style_hint) && !is.null(label_args$style_hint)) {
      style_hint <- label_args$style_hint
    }
    if (sep == " " && !is.null(label_args$sep)) {
      sep <- label_args$sep
    }
    if (case == "original" && !is.null(label_args$case)) {
      case <- label_args$case
    }
    if (!remove_articles && !is.null(label_args$remove_articles)) {
      remove_articles <- label_args$remove_articles
    }
    if (!remove_prepositions && !is.null(label_args$remove_prepositions)) {
      remove_prepositions <- label_args$remove_prepositions
    }
    if (is.null(max_chars) && !is.null(label_args$max_chars)) {
      max_chars <- label_args$max_chars
    }
    if (!abbreviate && !is.null(label_args$abbreviate)) {
      abbreviate <- label_args$abbreviate
    }
  }

  # Extract llm_args if provided
  if (!is.null(llm_args)) {
    # Only use config values if direct parameter is at default
    if (echo == "none" && !is.null(llm_args$echo)) {
      echo <- llm_args$echo
    }
    # Could add other llm_args parameters here as needed
  }

  # Extract output_args if provided
  if (!is.null(output_args)) {
    # Only use config values if direct parameter is at default
    if (silent == 0 && !is.null(output_args$silent)) {
      silent <- output_args$silent
    }
    # Handle logical silent from output_args
    if (is.logical(silent)) {
      silent <- ifelse(silent, 2, 0)
    }
  }

  # Validate label_type
  valid_label_types <- c("short", "phrase", "acronym", "custom")
  if (!label_type %in% valid_label_types) {
    cli::cli_abort(
      c(
        "{.var label_type} must be one of: {.val {valid_label_types}}",
        "x" = "You supplied: {.val {label_type}}"
      )
    )
  }

  # ==========================================================================
  # STEP 2: INITIALIZE OR REUSE CHAT SESSION
  # ==========================================================================

  created_temp_session <- FALSE

  if (is.null(chat_session)) {
    # Need to create temporary session
    if (is.null(llm_provider)) {
      cli::cli_abort(
        c(
          "Either {.var chat_session} or {.var llm_provider} must be specified",
          "i" = "To create a reusable session: {.code chat <- chat_session('label', 'provider', 'model')}",
          "i" = "Or specify provider directly: {.code label_variables(..., llm_provider = 'ollama')}"
        )
      )
    }

    if (silent < 2) {
      cli::cli_alert_info("Creating temporary chat session for labeling...")
    }

    # Build system prompt for labeling
    system_prompt <- build_system_prompt.label(
      structure(list(), class = "label"),
      label_type = label_type,
      style_hint = style_hint,
      max_chars = max_chars
    )

    # Create temporary chat session
    chat_session <- chat_session(
      analysis_type = "label",
      llm_provider = llm_provider,
      llm_model = llm_model,
      system_prompt = system_prompt,
      echo = echo
    )

    created_temp_session <- TRUE
    chat_local <- chat_session$chat
  } else {
    # Validate chat_session
    if (!inherits(chat_session, "chat_session")) {
      cli::cli_abort("{.var chat_session} must be a chat_session object")
    }

    # Clone to avoid side effects
    chat_local <- chat_session$chat$clone()$set_turns(list())
  }

  # ==========================================================================
  # STEP 3: BUILD AND SEND PROMPT
  # ==========================================================================

  if (silent < 2) {
    cli::cli_alert_info("Generating labels for {nrow(variable_info)} variables...")
  }

  # Build user prompt
  user_prompt <- build_main_prompt.label(
    structure(list(), class = "label"),
    variable_info = variable_info,
    label_type = label_type,
    max_words = max_words,
    max_chars = max_chars
  )

  # Send to LLM
  response <- tryCatch({
    chat_local$chat(user_prompt, echo = echo)
  }, error = function(e) {
    cli::cli_abort(extract_llm_error_details(e))
  })

  # ==========================================================================
  # STEP 4: PARSE RESPONSE
  # ==========================================================================

  if (silent < 2) {
    cli::cli_alert_info("Parsing LLM response...")
  }

  parsed_labels <- parse_label_response(response, variable_info)

  # ==========================================================================
  # STEP 5: APPLY FORMATTING
  # ==========================================================================

  if (silent < 2) {
    cli::cli_alert_info("Applying formatting transformations...")
  }

  # Convert parsed labels (list of lists) to data frame
  parsed_labels_df <- data.frame(
    variable = sapply(parsed_labels, function(x) x$variable),
    label = sapply(parsed_labels, function(x) x$label),
    stringsAsFactors = FALSE
  )

  # Create formatted labels data frame
  labels_df <- parsed_labels_df

  # Apply formatting to each label
  labels_df$label <- sapply(labels_df$label, function(label) {
    format_label(
      label = label,
      sep = sep,
      case = case,
      remove_articles = remove_articles,
      remove_prepositions = remove_prepositions,
      max_chars = max_chars,
      abbreviate = abbreviate,
      max_words = max_words
    )
  }, USE.NAMES = FALSE)

  # ==========================================================================
  # STEP 6: TRACK TOKENS
  # ==========================================================================

  tokens_df <- chat_local$get_tokens()
  input_tokens <- 0
  output_tokens <- 0

  if (!is.null(tokens_df) && nrow(tokens_df) > 0 &&
      "tokens" %in% names(tokens_df) && "role" %in% names(tokens_df)) {
    input_tokens <- sum(tokens_df$tokens[tokens_df$role == "user"], na.rm = TRUE)
    output_tokens <- sum(tokens_df$tokens[tokens_df$role == "assistant"], na.rm = TRUE)
  }

  # Update session token counts if not temporary
  if (!created_temp_session) {
    chat_session$total_input_tokens <- chat_session$total_input_tokens + input_tokens
    chat_session$total_output_tokens <- chat_session$total_output_tokens + output_tokens
    chat_session$n_interpretations <- chat_session$n_interpretations + 1
  }

  # ==========================================================================
  # STEP 7: CREATE RESULT OBJECT
  # ==========================================================================

  metadata <- list(
    label_type = label_type,
    n_variables = nrow(variable_info),
    timestamp = Sys.time(),
    duration = as.numeric(difftime(Sys.time(), start_time, units = "secs")),
    llm_provider = chat_session$llm_provider,
    llm_model = chat_session$llm_model,
    tokens_used = list(
      input = input_tokens,
      output = output_tokens,
      total = input_tokens + output_tokens
    ),
    formatting = list(
      sep = sep,
      case = case,
      remove_articles = remove_articles,
      remove_prepositions = remove_prepositions,
      max_chars = max_chars,
      abbreviate = abbreviate,
      max_words = max_words
    )
  )

  result <- create_variable_labels(
    labels_df = labels_df,
    variable_info = variable_info,
    llm_response = response,
    parsed_labels = parsed_labels_df,  # Now a data.frame
    metadata = metadata,
    chat_session = chat_session
  )

  # ==========================================================================
  # STEP 8: OUTPUT RESULTS (IF NOT SILENT)
  # ==========================================================================

  if (silent < 2) {
    cli::cli_alert_success(
      "Generated labels for {nrow(variable_info)} variables in {round(metadata$duration, 1)}s"
    )

    if (silent == 0) {
      # Show the result
      print(result)
    }
  }

  return(result)
}