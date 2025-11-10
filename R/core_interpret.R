#' Core Interpretation Engine (Model-Agnostic)
#'
#' Generic interpretation engine that coordinates LLM-based analysis interpretation
#' for any model type. Delegates model-specific logic to S3 methods.
#'
#' @param model_data List. Model-specific data structure (loadings, parameters, etc.)
#' @param model_type Character. Type of analysis ("fa", "gm", "irt", "cdm")
#' @param variable_info Data frame. Variable descriptions with 'variable' and 'description' columns
#' @param llm_provider Character. LLM provider (e.g., "anthropic", "openai", "ollama"). Required when chat_session is NULL (default = NULL)
#' @param llm_model Character or NULL. Model name
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
#' @param params ellmer params object or NULL
#' @param ... Additional arguments passed to model-specific methods
#'
#' @return Interpretation object with class c("\{model_type\}_interpretation", "interpretation", "list")
#'
#' @details
#' This function orchestrates the interpretation workflow:
#' 1. Build system prompt (model-specific via S3)
#' 2. Initialize or use existing chat session
#' 3. Build user prompt (model-specific via S3)
#' 4. Send to LLM and get response
#' 5. Parse JSON response (generic with model-specific validation)
#' 6. Create diagnostics (model-specific via S3)
#' 7. Build report (model-specific via S3)
#' 8. Return interpretation object
#'
#' @export
#' @keywords internal
interpret_core <- function(model_data = NULL,
                          fit_results = NULL,
                          model_type = NULL,
                          variable_info,
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
                          fa_args = NULL,
                          llm_args = NULL,
                          output_args = NULL,
                          ...) {

  # Capture start time
  start_time <- Sys.time()

  # Capture ... and remove FA-specific parameters to avoid duplicates
  # These will be passed explicitly from model_data
  dots <- list(...)
  fa_param_names <- c("cutoff", "n_emergency", "hide_low_loadings", "factor_cor_mat", "sort_loadings")
  dots_clean <- dots[!names(dots) %in% fa_param_names]

  # ==========================================================================
  # STEP 0: BUILD MODEL DATA (NEW PATH)
  # ==========================================================================

  # If fit_results provided, build model_data using build_model_data()
  if (!is.null(fit_results)) {
    if (!is.null(model_data)) {
      cli::cli_warn("Both fit_results and model_data provided; using fit_results")
    }

    # Call build_model_data() to extract and validate
    model_data <- build_model_data(
      fit_results = fit_results,
      variable_info = variable_info,
      model_type = model_type,
      fa_args = fa_args,
      ...
    )

  }

  # Extract FA-specific parameters from model_data for FA models
  # These are needed for build_main_prompt.fa()
  cutoff <- NULL
  n_emergency <- NULL
  hide_low_loadings <- NULL
  factor_cor_mat <- NULL

  if (!is.null(model_data$cutoff)) {
    cutoff <- model_data$cutoff
    n_emergency <- model_data$n_emergency
    hide_low_loadings <- model_data$hide_low_loadings
    factor_cor_mat <- model_data$factor_cor_mat
  }

  # Validate that we have model_data (either from fit_results or passed directly)
  if (is.null(model_data)) {
    cli::cli_abort(
      c(
        "Either {.arg fit_results} or {.arg model_data} must be provided",
        "i" = "New path: provide fit_results (fitted model object, matrix, or list)",
        "i" = "Legacy path: provide model_data (pre-built data structure)"
      )
    )
  }

  # ==========================================================================
  # STEP 1: VALIDATE INPUTS
  # ==========================================================================

  # Handle backward compatibility: Convert logical to integer
  if (is.logical(silent)) {
    silent <- ifelse(silent, 2, 0)  # FALSE -> 0, TRUE -> 2
  }

  # Extract parameters from config objects if provided
  if (!is.null(llm_args)) {
    if (is.null(llm_provider)) llm_provider <- llm_args$provider
    if (is.null(llm_model)) llm_model <- llm_args$model
  }
  if (!is.null(output_args)) {
    if (is.null(output_format)) output_format <- output_args$output_format
    if (is.null(heading_level)) heading_level <- output_args$heading_level
    if (is.null(suppress_heading)) suppress_heading <- output_args$suppress_heading
    if (is.null(max_line_length)) max_line_length <- output_args$max_line_length
  }

  # Validate existing chat session
  if (!is.null(chat_session) && !is.chat_session(chat_session)) {
    cli::cli_abort(
      c(
        "{.var chat_session} must be a chat_session object",
        "i" = "Create one with chat_session()"
      )
    )
  }

  # Validate and inherit model_type from chat_session
  if (!is.null(chat_session)) {
    # Early validation: Abort if there's a model_type mismatch
    # This prevents confusing errors later and provides clear guidance
    if (!is.null(model_type) && model_type != chat_session$model_type) {
      cli::cli_abort(
        c(
          "chat_session model_type mismatch",
          "x" = paste0(
            "chat_session has model_type '", chat_session$model_type, "' ",
            "but you requested interpretation for model_type '", model_type, "'"
          ),
          "i" = "Create a new chat_session with model_type = '{model_type}'",
          "i" = "Or use interpret() generic to let it route automatically"
        )
      )
    }
    model_type <- chat_session$model_type
  }

  # Error if both chat_session and model_type are NULL
  if (is.null(chat_session) && is.null(model_type)){
    cli::cli_abort(
      c(
        "{.var model_type} must be provided if {.var chat_session} is NULL",
        "i" = "Either provide a chat_session or specify the model_type"
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
    cli::cli_alert_info("Starting {model_type} interpretation...")
  }

  # Validate model_type
  valid_types <- c("fa", "gm", "irt", "cdm")
  if (!model_type %in% valid_types) {
    cli::cli_abort(
      c(
        "Invalid model_type: {.val {model_type}}",
        "i" = "Valid types: {.val {valid_types}}"
      )
    )
  }

  # Validate variable_info
  if (!is.data.frame(variable_info)) {
    cli::cli_abort("{.var variable_info} must be a data frame")
  }
  if (!"variable" %in% names(variable_info)) {
    cli::cli_abort("{.var variable_info} must contain a 'variable' column")
  }

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
  # STEP 2: BUILD SYSTEM PROMPT
  # ==========================================================================
  # Create dummy object with model_type class for S3 dispatch
  model_type_obj <- structure(list(), class = model_type)

  # Use custom system_prompt if provided, otherwise build model-specific default
  final_system_prompt <- if (!is.null(system_prompt)) {
    system_prompt
  } else {
    do.call(build_system_prompt, c(
      list(
        model_type = model_type_obj,
        word_limit = word_limit
      ),
      dots_clean
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
      model_type = model_type,
      provider = llm_provider,
      model = llm_model,
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

  # Build prompt args (use dots_clean to avoid duplicate FA params)
  prompt_args <- c(
    list(
      model_type = model_type_obj,
      model_data = model_data,
      variable_info = variable_info,
      word_limit = word_limit,
      additional_info = additional_info,
      cutoff = cutoff,
      n_emergency = n_emergency,
      hide_low_loadings = hide_low_loadings,
      factor_cor_mat = factor_cor_mat
    ),
    dots_clean
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
      model_type = model_type,
      model_data = model_data
    ),
    dots_clean
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
  if (!is.null(tokens_df) && nrow(tokens_df) > 0) {
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
  chat_session$n_interpretations <- chat_session$n_interpretations + 1L

  # ==========================================================================
  # STEP 8: CREATE DIAGNOSTICS
  # ==========================================================================
  if (silent < 2) {
    cli::cli_alert_info("Creating diagnostics...")
  }

  diagnostics <- do.call(create_diagnostics, c(
    list(
      model_type = model_type_obj,
      model_data = model_data,
      variable_info = variable_info
    ),
    dots_clean
  ))

  # ==========================================================================
  # STEP 9: ASSEMBLE INTERPRETATION OBJECT
  # ==========================================================================
  elapsed_time <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  interpretation <- list(
    model_type = model_type,
    model_data = model_data,
    component_summaries = parsed_result$component_summaries,
    suggested_names = parsed_result$suggested_names,
    llm_info = list(
      provider = chat_local$get_provider()@name,
      model = chat_local$get_model(),
      input_tokens = input_tokens,
      output_tokens = output_tokens,
      system_prompt = final_system_prompt,
      main_prompt = main_prompt
    ),
    chat = chat_session,
    diagnostics = diagnostics,
    elapsed_time = elapsed_time,
    params = c(
      list(
        word_limit = word_limit,
        output_format = output_format,
        additional_info = additional_info
      ),
      dots_clean
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
    paste0(model_type, "_interpretation"),
    "interpretation",
    "list"
  )

  # Add model-specific aliases for backward compatibility
  if (model_type == "fa") {
    interpretation$factor_summaries <- interpretation$component_summaries
  }

  # Add top-level token fields for backward compatibility
  interpretation$input_tokens <- input_tokens
  interpretation$output_tokens <- output_tokens

  # Add FA-specific formatted fields for backward compatibility
  if (model_type == "fa" && !is.null(model_data$loadings_df)) {
    # Format loading matrix: remove leading zeros (e.g., -0.456 -> -.456, 0.456 -> .456)
    loading_matrix <- model_data$loadings_df
    for (col in model_data$factor_cols) {
      loading_matrix[[col]] <- format_loading(loading_matrix[[col]])
    }
    interpretation$loading_matrix <- loading_matrix
    interpretation$factor_cor_mat <- model_data$factor_cor_mat
    interpretation$cutoff <- model_data$cutoff
  }

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
    dots_clean
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

#' Create Diagnostics (S3 Generic)
#'
#' Model-specific diagnostic analysis (cross-loadings, misfit items, cluster overlap, etc.)
#'
#' @param model_type Object with model type class
#' @param model_data List. Model-specific data
#' @param variable_info Data frame. Variable descriptions
#' @param ... Additional arguments for model-specific diagnostics
#'
#' @return List of diagnostic results
#' @export
#' @keywords internal
create_diagnostics <- function(model_type, model_data, variable_info, ...) {
  UseMethod("create_diagnostics")
}

#' Default method for create_diagnostics
#' @export
#' @keywords internal
create_diagnostics.default <- function(model_type, model_data, variable_info, ...) {
  # Get the class name
  model_class <- if (is.character(model_type)) {
    model_type
  } else {
    class(model_type)[1]
  }

  cli::cli_abort(
    c(
      "No diagnostics method for model type: {.val {model_class}}",
      "i" = "Available types: fa, gm, irt, cdm",
      "i" = "Implement create_diagnostics.{model_class}() in R/models/{model_class}/"
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
  model_type <- interpretation$model_type

  cli::cli_abort(
    c(
      "No report builder for model type: {.val {model_type}}",
      "i" = "Available types: fa, gm, irt, cdm",
      "i" = "Implement build_report.\\{model_type\\}_interpretation() in R/models/\\{model_type\\}/"
    )
  )
}
