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
#' @param word_limit Integer. Word limit for interpretations (default = 100)
#' @param additional_info Character or NULL. Additional context for LLM
#' @param output_format Character. Report format: "cli" or "markdown" (default = "cli")
#' @param heading_level Integer. Markdown heading level (default = 1)
#' @param suppress_heading Logical. Suppress report heading (default = FALSE)
#' @param max_line_length Integer. Maximum line length for text wrapping (default = 120)
#' @param silent Logical. Suppress status messages (default = FALSE)
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
interpret_generic <- function(model_data,
                          model_type = NULL,
                          variable_info,
                          llm_provider = NULL,
                          llm_model = NULL,
                          chat_session = NULL,
                          word_limit = 100,
                          additional_info = NULL,
                          output_format = "cli",
                          heading_level = 1,
                          suppress_heading = FALSE,
                          max_line_length = 120,
                          silent = FALSE,
                          echo = "none",
                          params = NULL,
                          ...) {

  # Capture start time
  start_time <- Sys.time()

  # ==========================================================================
  # STEP 1: VALIDATE INPUTS
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

  # Inherit model_type from chat_session
  if (!is.null(chat_session)) {
    if (!is.null(model_type)) {
      cli::cli_alert_info(
        "The inherited chat session model_type ({.val {chat_session$model_type}}) was used instead of the passed interpretation model_type",
        "i" = "The inherited chat session model_type ({.val {chat_session$model_type}}) was used instead of the passed interpretation model_type"
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

  if (!silent) {
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



  # ==========================================================================
  # STEP 2: BUILD SYSTEM PROMPT
  # ==========================================================================
  # Create dummy object with model_type class for S3 dispatch
  model_type_obj <- structure(list(), class = model_type)

  system_prompt <- build_system_prompt(
    model_type = model_type_obj,
    word_limit = word_limit,
    ...
  )

  # ==========================================================================
  # STEP 3: INITIALIZE OR USE EXISTING CHAT SESSION
  # ==========================================================================
  # Track whether we created a temporary session
  created_temp_session <- FALSE

  if (is.null(chat_session)) {
    # Create temporary chat session
    if (!silent) {
      cli::cli_alert_info("Creating temporary chat session...")
    }

    chat_session <- chat_session(
      model_type = model_type,
      provider = llm_provider,
      model = llm_model,
      system_prompt = system_prompt,
      params = params,
      echo = echo
    )

    created_temp_session <- TRUE
  }else{

    # Use existing chat session and ignore chat history
    chat <- chat_session$chat$clone()$set_turns(list())
  }


  # ==========================================================================
  # STEP 4: BUILD USER PROMPT
  # ==========================================================================
  if (!silent) {
    cli::cli_alert_info("Building prompt...")
  }

  main_prompt <- build_main_prompt(
    model_type = model_type_obj,
    model_data = model_data,
    variable_info = variable_info,
    word_limit = word_limit,
    additional_info = additional_info,
    ...
  )

  # ==========================================================================
  # STEP 5: SEND TO LLM AND GET RESPONSE
  # ==========================================================================
  if (!silent) {
    cli::cli_alert_info("Querying LLM...")
  }

  response <- tryCatch({
    chat_session$chat$chat(main_prompt, echo = echo)
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
  if (!silent) {
    cli::cli_alert_info("Parsing LLM response...")
  }

  parsed_result <- parse_llm_response(
    response = response,
    model_type = model_type,
    model_data = model_data,
    ...
  )

  # ==========================================================================
  # STEP 7: UPDATE TOKEN TRACKING
  # ==========================================================================
  # Track tokens for this interpretation
  tokens_df <- chat_session$chat$get_tokens()

  # Note: some providers / the ellmer wrapper do not reliably report `system` role
  # token counts. We intentionally only sum user/assistant tokens here and do NOT
  # include `system`/`system_prompt` tokens in package-level counters to avoid
  # inconsistent or double-counted totals.
  input_tokens <- sum(tokens_df$tokens[tokens_df$role == "user"], na.rm = TRUE)
  output_tokens <- sum(tokens_df$tokens[tokens_df$role == "assistant"], na.rm = TRUE)

  # Update session cumulative totals
  chat_session$total_input_tokens <- chat_session$total_input_tokens + input_tokens
  chat_session$total_output_tokens <- chat_session$total_output_tokens + output_tokens
  chat_session$n_interpretations <- chat_session$n_interpretations + 1L

  # ==========================================================================
  # STEP 8: CREATE DIAGNOSTICS
  # ==========================================================================
  if (!silent) {
    cli::cli_alert_info("Creating diagnostics...")
  }

  diagnostics <- create_diagnostics(
    model_type = model_type_obj,
    model_data = model_data,
    variable_info = variable_info,
    ...
  )

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
      provider = chat_session$chat$get_provider()@name,
      model = chat_session$chat$get_model(),
      input_tokens = input_tokens,
      output_tokens = output_tokens,
      system_prompt = system_prompt,
      main_prompt = main_prompt
    ),
    chat = chat_session,
    diagnostics = diagnostics,
    elapsed_time = elapsed_time,
    params = list(
      word_limit = word_limit,
      output_format = output_format,
      additional_info = additional_info,
      ...
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

  # ==========================================================================
  # STEP 10: BUILD REPORT
  # ==========================================================================
  if (!silent) {
    cli::cli_alert_info("Building report...")
  }

  interpretation$report <- build_report(
    interpretation = interpretation,
    output_format = output_format,
    heading_level = heading_level,
    suppress_heading = suppress_heading,
    ...
  )

  # ==========================================================================
  # STEP 11: PRINT REPORT (UNLESS SILENT)
  # ==========================================================================
  if (!silent) {
    cli::cli_alert_success("Interpretation complete!")
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
