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
#'   \item **Control**: echo, verbosity
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
#'   Supplies \code{llm_provider}, \code{llm_model} and \code{echo}, plus
#'   \code{system_prompt} and \code{params}, which have no direct equivalent
#'   here and are used only when a temporary chat session is created.
#' @param output_args List or output_args object. Output configuration settings.
#'   Created with \code{\link{output_args}}. Direct parameters take precedence.
#' @param echo Character. Echo level: "none", "output", "all" (default = "none")
#' @param verbosity Integer. Controls output verbosity:
#'   - 0: Completely silent
#'   - 1: Show messages only
#'   - 2: Show messages and print results (default)
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
                           verbosity = 2) {

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
    variable_info$variable <- paste0("V", seq_len(nrow(variable_info)))
  }

  # Reorder columns to ensure variable comes first
  variable_info <- variable_info[, c("variable", "description")]

  # ==========================================================================
  # RESOLVE PARAMETERS ACROSS DIRECT ARGS AND CONFIG OBJECTS
  # ==========================================================================
  # Precedence: direct argument > config object > formal default.
  #
  # The previous implementation compared each parameter against its own default
  # to decide whether the caller had supplied it (`label_type == "short"`,
  # `echo == "none"`, `verbosity == 2`, `!remove_articles`). That inverts
  # precedence rather than merely ignoring the config: a caller who explicitly
  # asked for the default value was overridden by the config object, which is
  # the opposite of the documented "Direct parameters take precedence".
  #
  # See R/core_params.R; this is the same resolution interpret_core() uses.
  supplied_names <- names(match.call())

  label_params <- c("label_type", "max_words", "style_hint", "sep", "case",
                    "remove_articles", "remove_prepositions", "max_chars",
                    "abbreviate")
  label_resolved <- resolve_call_params(
    supplied = collect_supplied(label_params, supplied_names),
    config = label_args,
    defaults = mget(label_params)
  )
  label_type <- label_resolved$label_type
  max_words <- label_resolved$max_words
  style_hint <- label_resolved$style_hint
  sep <- label_resolved$sep
  case <- label_resolved$case
  remove_articles <- label_resolved$remove_articles
  remove_prepositions <- label_resolved$remove_prepositions
  max_chars <- label_resolved$max_chars
  abbreviate <- label_resolved$abbreviate

  # llm_args previously reached `echo` alone; llm_provider and llm_model were
  # dropped even though llm_args() exists to carry them.
  llm_params <- c("llm_provider", "llm_model", "echo")
  llm_resolved <- resolve_call_params(
    supplied = collect_supplied(llm_params, supplied_names),
    config = llm_args,
    defaults = mget(llm_params)
  )
  llm_provider <- llm_resolved$llm_provider
  llm_model <- llm_resolved$llm_model
  echo <- llm_resolved$echo

  # These two have no formal here, so they can only come from llm_args. Both
  # are advertised llm_args() fields that this function used to discard.
  configured_system_prompt <- llm_args$system_prompt
  configured_params <- llm_args$params

  output_resolved <- resolve_call_params(
    supplied = collect_supplied("verbosity", supplied_names),
    config = output_args,
    defaults = mget("verbosity")
  )
  verbosity <- output_resolved$verbosity

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

  if (verbosity > 0) {
    cli::cli_alert_info("Starting variable labeling ({nrow(variable_info)} variables)...")
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

    if (verbosity > 0) {
      cli::cli_alert_info("Creating temporary chat session...")
    }

    # Build system prompt for labeling, unless llm_args supplied one
    system_prompt <- configured_system_prompt %||% build_system_prompt.label(
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
      params = configured_params,
      echo = echo
    )

    created_temp_session <- TRUE
    chat_local <- chat_session$chat
  } else {
    # Validate chat_session. A bare inherits() check accepted an "fa" or "gm"
    # session, which would send labelling prompts through a factor-analysis
    # system prompt. This must run before anything reaches the provider.
    validate_chat_session_for_analysis_type(chat_session, "label")

    # Clone to avoid side effects
    chat_local <- chat_session$chat$clone()$set_turns(list())
  }

  # ==========================================================================
  # STEP 3: BUILD AND SEND PROMPT
  # ==========================================================================

  if (verbosity > 0) {
    cli::cli_alert_info("Building prompt...")
  }

  # Build user prompt
  user_prompt <- build_main_prompt.label(
    structure(list(), class = "label"),
    variable_info = variable_info,
    label_type = label_type,
    max_words = max_words,
    max_chars = max_chars
  )

  if (verbosity > 0) {
    cli::cli_alert_info("Querying LLM...")
  }

  # Send to LLM
  response <- tryCatch({
    chat_local$chat(user_prompt, echo = echo)
  }, error = function(e) {
    cli::cli_abort(extract_llm_error_details(e))
  })

  # ==========================================================================
  # STEP 4: PARSE RESPONSE
  # ==========================================================================

  if (verbosity > 0) {
    cli::cli_alert_info("Parsing LLM response...")
  }

  parsed_labels <- parse_label_response(response, variable_info)
  parse_status <- attr(parsed_labels, "parse_status")
  parse_error <- attr(parsed_labels, "parse_error")

  # ==========================================================================
  # STEP 5: APPLY FORMATTING
  # ==========================================================================

  if (verbosity > 0) {
    cli::cli_alert_info("Applying formatting...")
  }

  # Convert parsed labels (list of lists) to data frame. vapply, not sapply:
  # a record missing `label` made sapply() return a list, silently producing a
  # list-column instead of failing.
  record_field <- function(records, field) {
    vapply(
      records,
      function(x) {
        value <- x[[field]]
        if (is_nonempty_string(value)) as.character(value) else NA_character_
      },
      character(1)
    )
  }

  parsed_labels_df <- data.frame(
    variable = record_field(parsed_labels, "variable"),
    label = record_field(parsed_labels, "label"),
    stringsAsFactors = FALSE
  )

  # A degraded tier can leave a record without a usable label; fall back to the
  # description we already hold rather than carrying NA into formatting.
  missing_label <- is.na(parsed_labels_df$label)
  if (any(missing_label)) {
    parsed_labels_df$variable[is.na(parsed_labels_df$variable)] <-
      variable_info$variable[is.na(parsed_labels_df$variable)]
    parsed_labels_df$label[missing_label] <- vapply(
      which(missing_label),
      function(i) simplify_description(variable_info$description[i]),
      character(1)
    )
  }

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
  # See the note in interpret_core(): verbosity 0 means completely silent.
  token_counts <- extract_token_counts(tokens_df, warn = verbosity > 0)
  input_tokens <- token_counts$input_tokens
  output_tokens <- token_counts$output_tokens

  # Update session token counts if not temporary
  if (!created_temp_session) {
    update_session_tokens(chat_session, token_counts)
    chat_session$n_interpretations <- chat_session$n_interpretations + 1
  }

  # ==========================================================================
  # STEP 7: CREATE RESULT OBJECT
  # ==========================================================================

  metadata <- list(
    label_type = label_type,
    n_variables = nrow(variable_info),
    # Which parsing tier produced these labels, and why the strict parse
    # failed if it did. Without this a fabricated result is indistinguishable
    # from a real one.
    parse_status = parse_status,
    parse_error = parse_error,
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

  if (verbosity > 0) {
    cli::cli_alert_success("Labeling complete!")
  }

  if (verbosity == 2) {
    cat("\n")
    print(result)
  }

  return(result)
}