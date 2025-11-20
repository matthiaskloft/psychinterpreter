#' Core Interpretation Engine (Model-Agnostic)
#'
#' Generic interpretation engine that coordinates LLM-based analysis interpretation
#' for any model type. Delegates model-specific logic to S3 methods.
#'
#' @param analysis_data List. Model-specific data structure (loadings, parameters, etc.)
#' @param fit_results Fitted model object or structured list. Used for extracting analysis_data
#'   if analysis_data is NULL. Can be psych::fa(), mclust::Mclust(), or structured list.
#' @param analysis_type Character. Type of analysis ("fa" and "gm" implemented; "irt", "cdm" planned)
#' @param llm_provider Character. LLM provider (e.g., "anthropic", "openai", "ollama"). Required when chat_session is NULL (default = NULL)
#' @param llm_model Character or NULL. Model name. If NULL and chat_session is NULL, uses
#'   provider's default model. Ignored if chat_session is provided (default = NULL)
#' @param chat_session Chat session object or NULL. If NULL, creates temporary session
#' @param system_prompt Character or NULL. Optional custom system prompt to override the package default.
#'   If NULL, uses model-specific default system prompt. Ignored if chat_session is provided (default = NULL)
#' @param word_limit Integer. Word limit for interpretations (default = 100)
#' @param additional_info Character or NULL. Additional context for LLM
#' @param output_format Character. Report format: "cli" or "markdown" (default = "cli")
#' @param heading_level Integer. Markdown heading level (default = 1)
#' @param suppress_heading Logical. Suppress report heading (default = FALSE)
#' @param max_line_length Integer. Maximum line length for text wrapping (default = 120)
#' @param silent Integer or logical. Controls output verbosity:
#'   - 0 or FALSE: Show report and all messages (default)
#'   - 1: Show messages only, suppress report
#'   - 2 or TRUE: Completely silent, suppress all output
#'   For backward compatibility, logical values are accepted and converted to integers.
#' @param echo Character. Echo level: "none", "output", "all" (default = "none")
#' @param params ellmer params object or NULL. Advanced ellmer configuration. Most users
#'   should use llm_args() instead. Note: Some providers may not support all parameters
#'   (e.g., Ollama doesn't support 'seed'). Unsupported parameters will generate warnings
#'   from ellmer but won't affect functionality. (default = NULL)
#' @param interpretation_args List or interpretation_args object. Model-specific interpretation
#'   configuration. Created with \code{\link{interpretation_args}} (default = NULL)
#' @param llm_args List or llm_args object. LLM configuration settings. Created with
#'   \code{\link{llm_args}} (default = NULL)
#' @param output_args List or output_args object. Output configuration settings. Created
#'   with \code{\link{output_args}} (default = NULL)
#' @param ... Additional arguments passed to model-specific methods, including variable_info
#'   (data frame with 'variable' and 'description' columns, required for FA and recommended for GM)
#'
#' @return Interpretation object with class c("<model>_interpretation", "interpretation", "list")
#'   where <model> is the analysis type (e.g., "fa_interpretation", "gm_interpretation")
#'
#' @details
#' This function orchestrates the interpretation workflow:
#' 1. Build system prompt (model-specific via S3)
#' 2. Initialize or use existing chat session
#' 3. Build user prompt (model-specific via S3)
#' 4. Send to LLM and get response
#' 5. Parse JSON response (generic with model-specific validation)
#' 6. Create fit summary (model-specific via S3)
#' 7. Build report (model-specific via S3)
#' 8. Return interpretation object
#'
#' Export functionality is available via \code{\link{export_interpretation}}, which supports
#' both FA and GM interpretations. Use \code{export_interpretation(result, format = "md")}
#' or \code{export_interpretation(result, format = "txt")} to save results.
#'
#' @keywords internal
#' @noRd
interpret_core <- function(analysis_data = NULL,
                          fit_results = NULL,
                          analysis_type = NULL,
                          llm_provider = NULL,
                          llm_model = NULL,
                          chat_session = NULL,
                          system_prompt = NULL,
                          word_limit = 100,
                          additional_info = NULL,
                          output_format = "cli",
                          heading_level = 1,
                          suppress_heading = FALSE,
                          max_line_length = 120,
                          silent = 0,
                          echo = "none",
                          params = NULL,
                          interpretation_args = NULL,
                          llm_args = NULL,
                          output_args = NULL,
                          ...) {

  # Capture start time
  start_time <- Sys.time()

  # Capture ... and extract variable_info (model-specific parameter)
  dots <- list(...)
  variable_info <- dots$variable_info  # May be NULL for models that don't need it

  # ==========================================================================
  # STEP 0A: EXTRACT PARAMETERS FROM CONFIG OBJECTS (EARLY)
  # ==========================================================================
  # Do this before building analysis_data so we have analysis_type validated early

  # Handle backward compatibility: Convert logical to integer
  if (is.logical(silent)) {
    silent <- ifelse(silent, 2, 0)  # FALSE -> 0, TRUE -> 2
  }

  # Extract parameters from config objects if provided
  if (!is.null(llm_args)) {
    if (is.null(llm_provider)) llm_provider <- llm_args$llm_provider
    if (is.null(llm_model)) llm_model <- llm_args$llm_model
  }
  if (!is.null(output_args)) {
    if (is.null(output_format)) output_format <- output_args$format
    if (is.null(heading_level)) heading_level <- output_args$heading_level
    if (is.null(suppress_heading)) suppress_heading <- output_args$suppress_heading
    if (is.null(max_line_length)) max_line_length <- output_args$max_line_length
    if (is.null(silent)) silent <- output_args$silent
  }

  # Extract analysis_type from interpretation_args if not provided directly
  if (is.null(analysis_type) && !is.null(interpretation_args)) {
    if (is.list(interpretation_args) && "analysis_type" %in% names(interpretation_args)) {
      analysis_type <- interpretation_args$analysis_type
    }
  }

  # ==========================================================================
  # STEP 0B: VALIDATE FIT_RESULTS/ANALYSIS_DATA (EARLY)
  # ==========================================================================
  # Check this first so we can give a clear error if neither is provided
  if (is.null(fit_results) && is.null(analysis_data)) {
    cli::cli_abort(
      c(
        "Either {.arg fit_results} or {.arg analysis_data} must be provided",
        "i" = "New path: provide fit_results (fitted model object, matrix, or list)",
        "i" = "Legacy path: provide analysis_data (pre-built data structure)"
      )
    )
  }

  # ==========================================================================
  # STEP 0C: VALIDATE CHAT SESSION AND ANALYSIS_TYPE (EARLY)
  # ==========================================================================

  # Validate existing chat session
  if (!is.null(chat_session) && !is.chat_session(chat_session)) {
    cli::cli_abort(
      c(
        "{.var chat_session} must be a chat_session object",
        "i" = "Create one with chat_session()"
      )
    )
  }

  # Validate and inherit analysis_type from chat_session
  if (!is.null(chat_session)) {
    # Early validation: Abort if there's an analysis_type mismatch
    # This prevents confusing errors later and provides clear guidance
    if (!is.null(analysis_type) && analysis_type != chat_session$analysis_type) {
      cli::cli_abort(
        c(
          "chat_session analysis_type mismatch",
          "x" = paste0(
            "chat_session has analysis_type '", chat_session$analysis_type, "' ",
            "but you requested interpretation for analysis_type '", analysis_type, "'"
          ),
          "i" = "Create a new chat_session with analysis_type = '{analysis_type}'",
          "i" = "Or use interpret() generic to let it route automatically"
        )
      )
    }
    analysis_type <- chat_session$analysis_type
  }

  # Error if both chat_session and analysis_type are NULL
  if (is.null(chat_session) && is.null(analysis_type)){
    cli::cli_abort(
      c(
        "{.var analysis_type} must be provided if {.var chat_session} is NULL",
        "i" = "Either provide a chat_session or specify the analysis_type"
      )
    )
  }

  # Validate llm_provider when chat_session is NULL
  if (is.null(chat_session) && is.null(llm_provider)) {
    cli::cli_abort(
      c(
        "{.var llm_provider} is required when {.var chat_session} is NULL",
        "i" = "Specify llm_provider (e.g., 'anthropic', 'openai', 'ollama', 'gemini')",
        "i" = "Or provide a chat_session created with chat_session()"
      )
    )
  }

  if (silent < 2) {
    cli::cli_alert_info("Starting {analysis_type} interpretation...")
  }

  # Validate analysis_type
  validate_analysis_type(analysis_type)

  # Note: variable_info validation removed - now handled by model-specific methods
  # Models that require variable_info will validate it in their validate_model_requirements() methods

  # ========================================================================
  # Common Parameter Validation (Sprint 2: moved from model-specific functions)
  # ========================================================================

  # Validate word_limit
  if (!is.numeric(word_limit) || length(word_limit) != 1) {
    cli::cli_abort(
      c("{.var word_limit} must be a single numeric value", "x" = "You supplied: {.val {word_limit}}")
    )
  }
  if (word_limit < 20 || word_limit > 500) {
    cli::cli_abort(
      c(
        "{.var word_limit} must be between 20 and 500",
        "x" = "You supplied: {.val {word_limit}}",
        "i" = "Recommended range is 50-200 words for detailed interpretations"
      )
    )
  }

  # Validate max_line_length
  if (!is.numeric(max_line_length) || length(max_line_length) != 1) {
    cli::cli_abort(
      c("{.var max_line_length} must be a single numeric value", "x" = "You supplied: {.val {max_line_length}}")
    )
  }
  if (max_line_length < 40 || max_line_length > 300) {
    cli::cli_abort(
      c(
        "{.var max_line_length} must be between 40 and 300",
        "x" = "You supplied: {.val {max_line_length}}",
        "i" = "Recommended range is 80-120 for console output"
      )
    )
  }

  # Validate output_format
  if (!is.character(output_format) ||
      length(output_format) != 1 ||
      !output_format %in% c("cli", "markdown")) {
    cli::cli_abort(
      c(
        "{.var output_format} must be either 'cli' or 'markdown'",
        "x" = "You supplied: {.val {output_format}}"
      )
    )
  }

  # Validate heading_level
  if (!is.numeric(heading_level) || length(heading_level) != 1) {
    cli::cli_abort(
      c("{.var heading_level} must be a single integer value", "x" = "You supplied: {.val {heading_level}}")
    )
  }
  if (heading_level < 1 || heading_level > 6 || heading_level != as.integer(heading_level)) {
    cli::cli_abort(
      c(
        "{.var heading_level} must be an integer between 1 and 6",
        "x" = "You supplied: {.val {heading_level}}",
        "i" = "Heading levels correspond to markdown: 1 = #, 2 = ##, etc."
      )
    )
  }

  # Validate suppress_heading
  if (!is.logical(suppress_heading) || length(suppress_heading) != 1 || is.na(suppress_heading)) {
    cli::cli_abort(
      c(
        "{.var suppress_heading} must be a single logical value (TRUE or FALSE)",
        "x" = "You supplied: {.val {suppress_heading}}"
      )
    )
  }

  # ==========================================================================
  # STEP 1: BUILD MODEL DATA (AFTER VALIDATION)
  # ==========================================================================

  # If fit_results provided, build analysis_data using build_analysis_data()
  if (!is.null(fit_results)) {
    if (!is.null(analysis_data)) {
      cli::cli_warn("Both fit_results and analysis_data provided; using fit_results")
    }

    # Call build_analysis_data() to extract and validate
    # variable_info passed through ... (model-specific)
    analysis_data <- build_analysis_data(
      fit_results = fit_results,
      analysis_type = analysis_type,
      interpretation_args = interpretation_args,
      ...  # Includes variable_info
    )

  }

  # Double-check that we have analysis_data (should have been guaranteed by earlier validation)
  if (is.null(analysis_data)) {
    cli::cli_abort(
      c(
        "Internal error: analysis_data is NULL after build_analysis_data()",
        "i" = "This should never happen. Please file a bug report with reproduction steps."
      )
    )
  }

  # ==========================================================================
  # STEP 1B: VALIDATE MODEL-SPECIFIC REQUIREMENTS
  # ==========================================================================
  # Create dummy object with analysis_type class for S3 dispatch
  analysis_type_obj <- structure(list(), class = analysis_type)

  # Validate model-specific requirements (e.g., variable_info for FA)
  # This uses the new S3 generic to keep core model-agnostic
  validate_model_requirements(analysis_type_obj, variable_info = variable_info, ...)

  # ==========================================================================
  # STEP 1C: EXTRACT MODEL-SPECIFIC PARAMETERS
  # ==========================================================================
  # Extract model-specific parameters using S3 generic
  # This replaces the hardcoded FA parameter extraction
  model_params <- extract_model_parameters(analysis_type_obj, interpretation_args)

  # Add model parameters to analysis_data for downstream use
  if (length(model_params) > 0) {
    analysis_data <- c(analysis_data, model_params)
  }

  # ==========================================================================
  # STEP 2: BUILD SYSTEM PROMPT
  # =========================================================================

  # Use custom system_prompt if provided, otherwise build model-specific default
  final_system_prompt <- if (!is.null(system_prompt)) {
    system_prompt
  } else {
    do.call(build_system_prompt, c(
      list(
        analysis_type = analysis_type_obj,
        word_limit = word_limit
      ),
      dots
    ))
  }

  # ==========================================================================
  # STEP 3: INITIALIZE OR USE EXISTING CHAT SESSION
  # ==========================================================================
  # Track whether we created a temporary session
  created_temp_session <- FALSE

  if (is.null(chat_session)) {
    # Create temporary chat session
    if (silent < 2) {
      cli::cli_alert_info("Creating temporary chat session...")
    }

    chat_session <- chat_session(
      analysis_type = analysis_type,
      llm_provider = llm_provider,
      llm_model = llm_model,
      system_prompt = final_system_prompt,
      params = params,
      echo = echo
    )

    created_temp_session <- TRUE
    chat_local <- chat_session$chat
  } else {
    # Use existing chat session but ignore chat history
    # Clone to preserve original chat_session state (avoid side effects)
    # then clear turns to start fresh interpretation
    chat_local <- chat_session$chat$clone()$set_turns(list())
  }


  # ==========================================================================
  # STEP 4: BUILD USER PROMPT
  # ==========================================================================
  if (silent < 2) {
    cli::cli_alert_info("Building prompt...")
  }

  # Build prompt args (analysis_data contains all model-specific parameters)
  prompt_args <- c(
    list(
      analysis_type = analysis_type_obj,
      analysis_data = analysis_data,
      variable_info = variable_info,
      word_limit = word_limit,
      additional_info = additional_info
    ),
    dots
  )

  main_prompt <- do.call(build_main_prompt, prompt_args)

  # ==========================================================================
  # STEP 5: SEND TO LLM AND GET RESPONSE
  # ==========================================================================
  if (silent < 2) {
    cli::cli_alert_info("Querying LLM...")
  }

  response <- tryCatch({
    chat_local$chat(main_prompt, echo = echo)
  }, error = function(e) {
    cli::cli_abort(
      c(
        "LLM request failed",
        "x" = "Error: {e$message}",
        "i" = "Check your API credentials and model availability"
      )
    )
  })

  # ==========================================================================
  # STEP 6: PARSE JSON RESPONSE
  # ==========================================================================
  if (silent < 2) {
    cli::cli_alert_info("Parsing LLM response...")
  }

  parsed_result <- do.call(parse_llm_response, c(
    list(
      response = response,
      analysis_type = analysis_type,
      analysis_data = analysis_data
    ),
    dots
  ))

  # ==========================================================================
  # STEP 7: UPDATE TOKEN TRACKING
  # ==========================================================================
  # Track tokens for this interpretation
  tokens_df <- chat_local$get_tokens()

  # Note: Token tracking reliability varies by provider:
  # - Some providers/ellmer wrapper do not reliably report `system` role token counts
  # - Ollama often returns 0 tokens (no tracking support)
  # - Anthropic caches system prompts; cumulative input tokens may undercount
  # - OpenAI generally has accurate token reporting
  #
  # We intentionally only sum user/assistant tokens here and do NOT include
  # `system`/`system_prompt` tokens in package-level counters to avoid
  # inconsistent or double-counted totals.
  # Extract token counts from the tokens dataframe
  # Use normalize_token_count() to ensure we always get valid numeric values
  if (!is.null(tokens_df) && nrow(tokens_df) > 0 &&
      "tokens" %in% names(tokens_df) && "role" %in% names(tokens_df)) {
    input_tokens <- normalize_token_count(
      sum(tokens_df$tokens[tokens_df$role == "user"], na.rm = TRUE)
    )
    output_tokens <- normalize_token_count(
      sum(tokens_df$tokens[tokens_df$role == "assistant"], na.rm = TRUE)
    )
  } else {
    # No token data available (some providers don't support token tracking)
    input_tokens <- 0
    output_tokens <- 0
  }

  # Update session cumulative totals
  # Note: These may remain 0 for providers without token tracking support (e.g., Ollama)
  chat_session$total_input_tokens <- chat_session$total_input_tokens + input_tokens
  chat_session$total_output_tokens <- chat_session$total_output_tokens + output_tokens
  chat_session$cumulative_tokens$input_tokens <- chat_session$total_input_tokens
  chat_session$cumulative_tokens$output_tokens <- chat_session$total_output_tokens
  chat_session$cumulative_tokens$total_tokens <- chat_session$total_input_tokens + chat_session$total_output_tokens
  chat_session$n_interpretations <- chat_session$n_interpretations + 1L

  # ==========================================================================
  # STEP 8: CREATE DIAGNOSTICS
  # ==========================================================================
  if (silent < 2) {
    cli::cli_alert_info("Creating fit summary...")
  }

  # Filter dots to avoid parameter conflicts
  # Remove parameters that are explicitly set in the named list
  dots_filtered <- dots[!names(dots) %in% c("analysis_type", "analysis_data", "variable_info")]

  fit_summary <- do.call(create_fit_summary, c(
    list(
      analysis_type = analysis_data$analysis_type,
      analysis_data = analysis_data,
      variable_info = variable_info
    ),
    dots_filtered
  ))

  # ==========================================================================
  # STEP 9: ASSEMBLE INTERPRETATION OBJECT
  # ==========================================================================
  elapsed_time <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  interpretation <- list(
    analysis_type = analysis_type,
    analysis_data = analysis_data,
    component_summaries = parsed_result$component_summaries,
    suggested_names = parsed_result$suggested_names,
    timestamp = start_time,
    input_tokens = input_tokens,
    output_tokens = output_tokens,
    total_tokens = input_tokens + output_tokens,
    token_usage = list(
      input_tokens = input_tokens,
      output_tokens = output_tokens,
      total_tokens = input_tokens + output_tokens
    ),
    llm_info = list(
      llm_provider = chat_local$get_provider()@name,
      model = chat_local$get_model(),
      input_tokens = input_tokens,
      output_tokens = output_tokens,
      system_prompt = final_system_prompt,
      main_prompt = main_prompt
    ),
    chat = chat_session,
    fit_summary = fit_summary,
    elapsed_time = elapsed_time,
    params = c(
      list(
        word_limit = word_limit,
        output_format = output_format,
        additional_info = additional_info
      ),
      dots
    ),
    variable_info = variable_info
  )

  # Add model-specific fields from parsed_result
  for (field in names(parsed_result)) {
    if (!field %in% c("component_summaries", "suggested_names")) {
      interpretation[[field]] <- parsed_result[[field]]
    }
  }

  # Set class: model-specific first, then base, then list
  class(interpretation) <- c(
    paste0(analysis_type, "_interpretation"),
    "interpretation",
    "list"
  )

  # ==========================================================================
  # STEP 10: BUILD REPORT
  # ==========================================================================
  if (silent < 2) {
    cli::cli_alert_info("Building report...")
  }

  interpretation$report <- do.call(build_report, c(
    list(
      interpretation = interpretation,
      output_format = output_format,
      heading_level = heading_level,
      suppress_heading = suppress_heading
    ),
    dots
  ))

  # ==========================================================================
  # STEP 11: PRINT REPORT (UNLESS SILENT)
  # ==========================================================================
  if (silent < 2) {
    cli::cli_alert_success("Interpretation complete!")
  }

  if (silent == 0) {
    cat("\n")
    print(interpretation, max_line_length = max_line_length)
  }

  return(interpretation)
}

#' Create Fit Summary (S3 Generic)
#'
#' Model-specific summary analysis (cross-loadings, misfit items, cluster overlap, etc.)
#'
#' @param analysis_type Character. Analysis type ("fa", "gm", "irt", "cdm")
#' @param analysis_data List. Model-specific data
#' @param ... Additional arguments for model-specific summaries
#'
#' @return List of summary results
#' @export
#' @keywords internal
create_fit_summary <- function(analysis_type, analysis_data, ...) {
  # Validate analysis_type is a character string
  if (!is.character(analysis_type) || length(analysis_type) != 1) {
    cli::cli_abort(
      c(
        "Invalid analysis_type in create_fit_summary",
        "x" = "analysis_type must be a single character string",
        "i" = "Received: {class(analysis_type)} of length {length(analysis_type)}"
      )
    )
  }

  # Create dispatch object with analysis_type class
  dispatch_obj <- structure(
    list(),
    class = c(analysis_type, "fit_summary_dispatcher")
  )

  UseMethod("create_fit_summary", dispatch_obj)
}

#' Default method for create_fit_summary
#' @export
#' @keywords internal
create_fit_summary.default <- function(analysis_type, analysis_data, ...) {
  # Get the class name
  analysis_class <- if (is.character(analysis_type)) {
    analysis_type
  } else {
    class(analysis_type)[1]
  }

  cli::cli_abort(
    c(
      "No fit summary method for analysis type: {.val {analysis_class}}",
      "i" = "Available types: fa, gm, irt, cdm",
      "i" = "Implement create_fit_summary.{analysis_class}() in R/models/{analysis_class}/"
    )
  )
}

#' Build Report (S3 Generic)
#'
#' Model-specific report building
#'
#' @param interpretation Interpretation object
#' @param output_format Character. "cli" or "markdown"
#' @param heading_level Integer. Markdown heading level
#' @param suppress_heading Logical. Suppress report heading
#' @param ... Additional arguments for model-specific report building
#'
#' @return Character. Formatted report
#' @export
#' @keywords internal
build_report <- function(interpretation,
                        output_format = "cli",
                        heading_level = 1,
                        suppress_heading = FALSE,
                        ...) {
  UseMethod("build_report")
}

#' Default method for build_report
#' @export
#' @keywords internal
build_report.default <- function(interpretation,
                                 output_format = "cli",
                                 heading_level = 1,
                                 suppress_heading = FALSE,
                                 ...) {
  analysis_type <- interpretation$analysis_type %||% "unknown"

  cli::cli_abort(
    c(
      "No report builder for analysis type: {.val {analysis_type}}",
      "i" = "Available types: fa, gm, irt, cdm",
      "i" = "Implement build_report.{analysis_type}_interpretation() method"
    )
  )
}
