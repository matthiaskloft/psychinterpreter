# ==============================================================================
# REFACTORED INTERPRET_FA - Uses interpret_generic() architecture
# ==============================================================================

#' Interpret Exploratory Factor Analysis Results
#'
#' This function uses Large Language Models (LLMs) to automatically interpret FA results by
#' analyzing factor loadings and variable descriptions. It generates suggested factor names,
#' detailed interpretations, and identifies cross-loadings. Variance explained is automatically
#' calculated from the loadings (sum of squared loadings / number of variables).
#'
#' @param loadings A dataframe or matrix of factor loadings (variables x factors)
#'
#' @param variable_info A dataframe with at least two columns:
#'   - variable: variable names matching row names in loadings
#'   - description: labels or descriptions of the variables
#' @param cutoff Numeric. Minimum loading value to consider (default = 0.3)
#' @param n_emergency Integer. When a factor has no loadings above the cutoff, use the
#'   top N highest loadings (even if below cutoff) for interpretation. If set to 0,
#'   factors with no significant loadings are labeled as "undefined" and assigned NA
#'   interpretations (default = 2)
#' @param hide_low_loadings Logical. If TRUE, only variables with loadings at or above
#'   the cutoff are included in the data sent to the LLM. If FALSE, all loadings are
#'   included regardless of magnitude (default = FALSE)
#' @param llm_provider Character. Which LLM provider to use.
#'   Any provider supported by ellmer::chat() (e.g., "openai", "anthropic", "ollama", etc.)
#'   See ellmer documentation for the complete list of supported providers.
#' @param llm_model Character. Specific model to use (e.g., "gpt-4o-mini", "claude-3-5-sonnet-20241022", "gemma2:9b")
#' @param additional_info Character. Optional additional context for the LLM, such as theoretical background,
#'   research area information, or domain-specific knowledge to inform factor interpretation (default = NULL)
#' @param factor_cor_mat Matrix or data.frame. Optional factor correlation matrix for oblique rotations.
#'   Should have factor names as row and column names matching the loadings factor columns. Used to inform
#'   interpretation of factor relationships and enhance understanding of discriminant validity. Higher
#'   correlations suggest related constructs, while lower correlations indicate distinct factors.
#'   If NULL, factors are assumed to be orthogonal (default = NULL)
#' @param sort_loadings Logical. Sort variables by loading strength within factors (default = TRUE)
#' @param system_prompt Character or NULL. Optional custom system prompt text to override the package default
#'   psychometric system prompt. Use this to provide institution- or project-specific framing for the LLM
#'   (e.g., preferred terminology, audience level, or reporting conventions). If NULL the internal default
#'   system prompt is used (default = NULL). This will be ignored if chat_session is used.
#' @param interpretation_guidelines Character or NULL. Optional custom interpretation guidelines for the LMM that override
#'   the package default guidelines. If NULL, built-in interpretation
#'   guidelines are applied (default = NULL).
#' @param params Parameters for the LLM created using ellmer::params() function (e.g., params(temperature = 0.7, seed = 42)).
#'   Provides a provider-agnostic interface for setting model parameters like temperature, seed, max_tokens, etc.
#'   If NULL, uses provider defaults. See ellmer::params() documentation for supported parameters.
#' @param word_limit Integer. Maximum number of words for LLM interpretations (default = 150)
#' @param max_line_length Integer. Maximum line length for console output text wrapping (default = 80)
#' @param silent Integer or logical. Controls output verbosity:
#'   - 0 or FALSE: Show report and all messages (default)
#'   - 1: Show messages only, suppress report
#'   - 2 or TRUE: Completely silent, suppress all output
#'   For backward compatibility, logical values are accepted and converted to integers.
#' @param echo Character. Controls what is echoed during LLM interaction. One of "none" (no output),
#'   "output" (show only LLM responses), or "all" (show prompts and responses). Passed directly
#'   to the ellmer chat function for debugging and transparency (default = "none")
#' @param output_format Character. Output format for the report: "cli" or "markdown" (default = "cli")
#' @param heading_level Integer. Starting heading level for markdown output (default = 1). Used when output_format = "markdown"
#' @param suppress_heading Logical. If TRUE, suppresses the main "Exploratory Factor Analysis Interpretation"
#'   heading, allowing for better integration into existing documents that already have appropriate headings
#'   above the analysis output (default = FALSE)
#' @param chat_session A chat_fa object for reusing existing chat sessions. If provided, uses the existing
#'   chat session (avoiding resending the system prompt and reducing token costs). If NULL, creates a new
#'   chat session. Useful for processing multiple analyses efficiently (default = NULL)
#'
#' @details
#' This function uses advanced processing to minimize LLM API calls and costs. Instead of individual
#' factor interpretation calls, it processes all factors simultaneously in a single comprehensive prompt
#' with structured sections for optimal LLM comprehension.
#'
#' **Key Features:**
#' - **Structured LLM Prompting**: Uses organized sections (Factor Naming, Factor Interpretation,
#'   Factor Relationships, Output Requirements) for consistent, high-quality results
#' - **Factor Correlation Integration**: When factor_cor_mat is provided, incorporates factor
#'   relationships into interpretations for enhanced discriminant validity assessment
#' - **Optimized Word Targeting**: Targets 80%-100% of word limit for comprehensive interpretations
#' - **Emergency Rule**: Factors with no loadings above cutoff use top N highest loadings
#' - **Cross-loading Detection**: Identifies variables loading on multiple factors
#' - **Batch Processing**: Single API call processes all factors simultaneously
#'
#' **Technical Details:**
#' - Variance explained calculated as sum of squared loadings divided by number of variables
#' - Supports both orthogonal (factor_cor_mat = NULL) and oblique rotation results
#' - Uses compact vector format for efficient token usage in LLM prompts
#' - JSON output parsing with fallback extraction methods for robustness
#'
#' @note
#' This function requires:
#' - Internet connectivity for LLM API calls
#' - Valid API credentials for the chosen LLM provider (set via environment variables)
#' - The ellmer package for LLM communication
#'
#' @importFrom dplyr left_join select filter arrange mutate case_when rename sym desc
#' @importFrom ellmer chat params
#' @importFrom cli cli_abort cli_alert_info cli_alert_success cli_warn cli_inform
#' @importFrom jsonlite fromJSON toJSON
#' @importFrom utils head
#'
#' @export
#'
#' @return A fa_interpretation object (S3 class) containing:
#'   \describe{
#'     \item{factor_summaries}{List with detailed analysis for each factor, including variables,
#'       loadings, significance status, and variance_explained}
#'     \item{suggested_names}{Named list of LLM-generated factor names}
#'     \item{loading_matrix}{Formatted loading matrix with small loadings optionally suppressed}
#'     \item{report}{Complete formatted text/markdown report including factor correlations (when provided)}
#'     \item{llm_info}{List containing provider name and model used for interpretation}
#'     \item{chat}{Complete chat_fa object with full conversation history}
#'     \item{cross_loadings}{Data frame of variables loading significantly on multiple factors}
#'     \item{no_loadings}{Data frame of variables with no loadings above cutoff threshold}
#'     \item{elapsed_time}{Total analysis time as difftime object}
#'     \item{factor_cor_mat}{Factor correlation matrix (when provided)}
#'     \item{cutoff}{Numeric cutoff value used for determining significant loadings}
#'   }
#'
#' @examples
#' \dontrun{
#' # Set up API credentials first
#' Sys.setenv(OPENAI_API_KEY = "your-api-key-here")
#'
#' # Basic interpretation with OpenAI
#' interpretation <- interpret_fa(
#'   loadings = fa_results$loadings,
#'   variable_info = var_info,
#'   llm_provider = "openai",
#'   llm_model = "gpt-4o-mini"
#' )
#'
#' # Using persistent chat session for multiple analyses (efficient)
#' chat <- chat_fa("anthropic", "claude-haiku-4-5-20251001")
#' interpretation1 <- interpret_fa(
#'   loadings = fa_results1$loadings,
#'   variable_info = var_info1,
#'   chat_session = chat
#' )
#' print(chat)  # Check token usage
#'
#' # Advanced usage with factor correlations
#' interpretation_advanced <- interpret_fa(
#'   loadings = fa_results$loadings,
#'   variable_info = var_info,
#'   llm_provider = "ollama",
#'   llm_model = "llama3.1:8b",
#'   factor_cor_mat = fa_results$Phi,
#'   cutoff = 0.4,
#'   word_limit = 120,
#'   params = params(temperature = 0.3, seed = 123),
#'   output_format = "markdown"
#' )
#' }
interpret_fa <- function(loadings,
                         variable_info,
                         factor_cor_mat = NULL,
                         chat_session = NULL,
                         llm_provider = NULL,
                         llm_model = NULL,
                         params = NULL,
                         cutoff = 0.3,
                         n_emergency = 2,
                         hide_low_loadings = FALSE,
                         sort_loadings = TRUE,
                         system_prompt = NULL,
                         interpretation_guidelines = NULL,
                         additional_info = NULL,
                         word_limit = 150,
                         output_format = "cli",
                         heading_level = 1,
                         suppress_heading = FALSE,
                         max_line_length = 80,
                         silent = 0,
                         echo = "none") {

  # ==========================================================================
  # SECTION 1: PARAMETER VALIDATION
  # ==========================================================================

  # Handle backward compatibility: Convert logical to integer
  if (is.logical(silent)) {
    silent <- ifelse(silent, 2, 0)  # FALSE -> 0, TRUE -> 2
  }

  # Validate chat_session if provided
  if (!is.null(chat_session)) {
    # First check if it's a valid chat_session object
    if (!is.chat_session(chat_session)) {
      cli::cli_abort(
        c(
          "{.var chat_session} must be a chat_session object",
          "i" = "Create one with chat_session(model_type = 'fa', provider, model)"
        )
      )
    }

    # Then check model_type consistency
    if (chat_session$model_type != "fa") {
      cli::cli_abort(
        c(
          "chat_session model_type mismatch",
          "x" = paste0(
            "chat_session has model_type '", chat_session$model_type, "' ",
            "but interpret_fa requires model_type = 'fa'"
          ),
          "i" = "Create a new chat_session with model_type = 'fa'"
        )
      )
    }
  }

  # Inform user if chat_session overrides provider/model
  if (!is.null(chat_session) && (!is.null(llm_provider) || !is.null(llm_model))) {
    if (silent < 2) {
      cli::cli_inform(
        c("i" = "Using provided {.field chat_session} (overrides {.field llm_provider} and {.field llm_model} arguments)")
      )
    }
  }

  # Validate cutoff
  if (!is.numeric(cutoff) || length(cutoff) != 1) {
    cli::cli_abort(
      c("{.var cutoff} must be a single numeric value", "x" = "You supplied: {.val {cutoff}}")
    )
  }
  if (cutoff < 0 || cutoff > 1) {
    cli::cli_abort(
      c(
        "{.var cutoff} must be between 0 and 1",
        "x" = "You supplied: {.val {cutoff}}",
        "i" = "Common values are 0.3, 0.4, or 0.5"
      )
    )
  }

  # Validate n_emergency
  if (!is.numeric(n_emergency) || length(n_emergency) != 1) {
    cli::cli_abort(
      c("{.var n_emergency} must be a single integer value", "x" = "You supplied: {.val {n_emergency}}")
    )
  }
  if (n_emergency < 0 || n_emergency != as.integer(n_emergency)) {
    cli::cli_abort(
      c(
        "{.var n_emergency} must be a non-negative integer >= 0",
        "x" = "You supplied: {.val {n_emergency}}",
        "i" = "Typical values are 2 or 3. Use 0 to mark factors with no significant loadings as 'undefined'"
      )
    )
  }

  # Validate hide_low_loadings
  if (!is.logical(hide_low_loadings) || length(hide_low_loadings) != 1 || is.na(hide_low_loadings)) {
    cli::cli_abort(
      c(
        "{.var hide_low_loadings} must be a single logical value (TRUE or FALSE)",
        "x" = "You supplied: {.val {hide_low_loadings}}"
      )
    )
  }

  # Validate sort_loadings
  if (!is.logical(sort_loadings) || length(sort_loadings) != 1 || is.na(sort_loadings)) {
    cli::cli_abort(
      c(
        "{.var sort_loadings} must be a single logical value (TRUE or FALSE)",
        "x" = "You supplied: {.val {sort_loadings}}"
      )
    )
  }

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

  # Validate silent
  if (!is.numeric(silent) || length(silent) != 1 || is.na(silent) || !silent %in% c(0, 1, 2)) {
    cli::cli_abort(
      c(
        "{.var silent} must be 0, 1, or 2 (or logical TRUE/FALSE for backward compatibility)",
        "x" = "You supplied: {.val {silent}}",
        "i" = "0 = show report and messages, 1 = show messages only, 2 = completely silent"
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
  # SECTION 2: DATA PREPARATION AND VALIDATION
  # ==========================================================================

  # Convert loadings to dataframe if necessary
  if (is.matrix(loadings) || inherits(loadings, "loadings")) {
    loadings_df <- as.data.frame(unclass(loadings))
    loadings_df$variable <- rownames(loadings_df)
  } else {
    loadings_df <- loadings
    if (!"variable" %in% names(loadings_df)) {
      loadings_df$variable <- rownames(loadings_df)
    }
  }

  # Get factor names
  factor_cols <- setdiff(names(loadings_df), "variable")
  n_factors <- length(factor_cols)

  # Validate that there is at least one factor
  if (n_factors < 1) {
    cli::cli_abort(
      c(
        "{.var loadings} must contain at least one factor column",
        "x" = "Found only: {.field {names(loadings_df)}}",
        "i" = "Loadings should have variables as rows and factors as columns"
      )
    )
  }

  # Validate that loadings is not empty
  if (nrow(loadings_df) < 1) {
    cli::cli_abort(
      c("{.var loadings} must contain at least one variable", "x" = "Found 0 rows in loadings dataframe")
    )
  }

  # Validate variable_info
  if (!is.data.frame(variable_info)) {
    cli::cli_abort("{.var variable_info} must be a data frame")
  }
  if (!"variable" %in% names(variable_info)) {
    cli::cli_abort("{.var variable_info} must contain a variable column")
  }
  if (!"description" %in% names(variable_info)) {
    cli::cli_abort("{.var variable_info} must contain a description column")
  }

  # Check for variable matching
  missing_in_info <- setdiff(loadings_df$variable, variable_info$variable)
  missing_in_loadings <- setdiff(variable_info$variable, loadings_df$variable)

  if (length(missing_in_info) > 0 || length(missing_in_loadings) > 0) {
    if (length(missing_in_info) == nrow(loadings_df)) {
      cli::cli_abort(
        c(
          "No variables from {.var loadings} found in {.var variable_info}",
          "x" = "Check that the {.field variable} column matches",
          "i" = "First few variables in loadings: {.val {head(loadings_df$variable, 3)}}"
        )
      )
    }

    if (length(missing_in_info) > 0) {
      cli::cli_abort(
        c(
          "Variables in {.var loadings} not found in {.var variable_info}",
          "x" = "Missing: {.val {missing_in_info}}"
        )
      )
    }

    if (length(missing_in_loadings) > 0) {
      cli::cli_abort(
        c(
          "Variables in {.var variable_info} not found in {.var loadings}",
          "x" = "Missing: {.val {missing_in_loadings}}"
        )
      )
    }
  }

  # Merge with variable info
  loadings_with_info <- loadings_df |>
    dplyr::left_join(variable_info, by = "variable")

  # ==========================================================================
  # SECTION 2.5: LLM CONFIGURATION VALIDATION
  # ==========================================================================
  # These validations come after data validation to provide better error messages

  # Validate llm_provider (only if no chat_session)
  if (is.null(chat_session)) {
    if (is.null(llm_provider)) {
      cli::cli_abort(
        c(
          "{.var llm_provider} is required when {.var chat_session} is NULL",
          "i" = "Specify a provider like 'openai', 'anthropic', 'ollama', etc.",
          "i" = "Or provide an existing chat_session object"
        )
      )
    }
    if (!is.character(llm_provider) || length(llm_provider) != 1) {
      cli::cli_abort(
        c(
          "{.var llm_provider} must be a single character string",
          "x" = "You supplied: {.val {llm_provider}}"
        )
      )
    }
  }

  # Validate llm_model
  if (!is.null(llm_model) &&
      (!is.character(llm_model) || length(llm_model) != 1)) {
    cli::cli_abort(
      c(
        "{.var llm_model} must be a single character string or NULL",
        "x" = "You supplied: {.val {llm_model}}"
      )
    )
  }

  # Validate params
  if (!is.null(params) && !is.list(params)) {
    cli::cli_abort(
      c(
        "{.var params} must be created using ellmer::params() function",
        "x" = "You supplied a {.cls {class(params)}}",
        "i" = "Use params(temperature = 0.7, seed = 42)"
      )
    )
  }

  # Validate echo
  if (!is.character(echo) ||
      length(echo) != 1 || !echo %in% c("none", "output", "all")) {
    cli::cli_abort(
      c(
        "{.var echo} must be one of: 'none', 'output', or 'all'",
        "x" = "You supplied: {.val {echo}}"
      )
    )
  }

  # ==========================================================================
  # SECTION 3: CREATE FACTOR SUMMARIES
  # ==========================================================================

  factor_summaries <- list()
  n_variables <- nrow(loadings_df)

  for (i in 1:n_factors) {
    factor_name <- factor_cols[i]

    # Calculate variance explained
    variance_explained <- sum(loadings_df[[factor_name]]^2) / n_variables

    # Get loadings for this factor
    factor_data <- loadings_with_info |>
      dplyr::select(variable, description, !!dplyr::sym(factor_name)) |>
      dplyr::rename(loading = !!dplyr::sym(factor_name)) |>
      dplyr::filter(abs(loading) >= cutoff)

    if (sort_loadings) {
      factor_data <- factor_data |>
        dplyr::arrange(dplyr::desc(abs(loading)))
    }

    # Identify strength and direction
    factor_data <- factor_data |>
      dplyr::mutate(
        strength = dplyr::case_when(
          abs(loading) >= 0.7 ~ "Very Strong",
          abs(loading) >= 0.5 ~ "Strong",
          abs(loading) >= 0.4 ~ "Moderate",
          TRUE ~ "Weak"
        ),
        direction = ifelse(loading > 0, "Positive", "Negative")
      )

    # Check for significant loadings
    has_significant <- nrow(factor_data) > 0
    used_emergency_rule <- FALSE

    # Apply emergency rule if needed
    if (!has_significant) {
      if (n_emergency == 0) {
        # Leave empty
        factor_data <- data.frame(
          variable = character(0),
          description = character(0),
          loading = numeric(0),
          strength = character(0),
          direction = character(0)
        )
      } else {
        # Emergency rule: use top N
        used_emergency_rule <- TRUE
        factor_data <- loadings_with_info |>
          dplyr::select(variable, description, !!dplyr::sym(factor_name)) |>
          dplyr::rename(loading = !!dplyr::sym(factor_name)) |>
          dplyr::arrange(dplyr::desc(abs(loading))) |>
          utils::head(n_emergency) |>
          dplyr::mutate(
            strength = dplyr::case_when(
              abs(loading) >= 0.7 ~ "Very Strong",
              abs(loading) >= 0.5 ~ "Strong",
              abs(loading) >= 0.4 ~ "Moderate",
              TRUE ~ "Below Cutoff"
            ),
            direction = ifelse(loading > 0, "Positive", "Negative")
          )
      }
    }

    # Create factor header and body summary. The report builder is responsible
    # for formatting headers consistently, so we store the header separately and
    # keep the summary body without the header line.
    header_text <- paste0(
      "Factor ",
      i,
      " (",
      factor_name,
      ")"
    )

    # Body of the summary (exclude header line)
    summary_text <- paste0(
      "Number of significant loadings: ",
      ifelse(has_significant, nrow(factor_data), 0),
      "\n",
      "Variance explained: ",
      round(variance_explained * 100, 2),
      "%\n"
    )

    if (!has_significant) {
      if (n_emergency == 0) {
        summary_text <- paste0(
          summary_text,
          "WARNING: No variables load above cutoff (",
          cutoff,
          "). ",
          "Factor marked as undefined (n_emergency = 0).\n"
        )
      } else {
        summary_text <- paste0(
          summary_text,
          "WARNING: No variables load above cutoff (",
          cutoff,
          "). ",
          "Using top ",
          n_emergency,
          " variables below cutoff for interpretation.\n"
        )
      }
    }

    summary_text <- paste0(summary_text, "\nVariables:\n")

    # Add top variables
    if (nrow(factor_data) > 0) {
      for (j in 1:nrow(factor_data)) {
        var_desc <- ifelse(
          !is.na(factor_data$description[j]),
          factor_data$description[j],
          factor_data$variable[j]
        )
        summary_text <- paste0(
          summary_text,
          "  ",
          j,
          ". ",
          factor_data$variable[j],
          ", ",
          var_desc,
          " (",
          factor_data$direction[j],
          ", ",
          factor_data$strength[j],
          ", ",
          sub(
            "^(-?)0\\.",
            "\\1.",
            sprintf("%.3f", factor_data$loading[j])
          ),
          ")\n"
        )
      }
    } else {
      summary_text <- paste0(summary_text, "  No variables in this factor\n")
    }

    # Store factor summary
    factor_summaries[[factor_name]] <- list(
      header = header_text,
      summary = summary_text,
      variables = factor_data,
      n_loadings = ifelse(has_significant, nrow(factor_data), 0),
      has_significant = has_significant,
      used_emergency_rule = used_emergency_rule,
      variance_explained = variance_explained
    )
  }

  # ==========================================================================
  # SECTION 4: PREPARE MODEL_DATA AND CALL INTERPRET_CORE
  # ==========================================================================

  model_data <- list(
    loadings_df = loadings_df,
    factor_summaries = factor_summaries,
    factor_cols = factor_cols,
    n_factors = n_factors,
    n_variables = n_variables
  )

  # Call the generic interpretation engine
  result <- interpret_generic(
    model_data = model_data,
    model_type = "fa",
    variable_info = variable_info,
    llm_provider = llm_provider,
    llm_model = llm_model,
    chat_session = chat_session,
    cutoff = cutoff,
    n_emergency = n_emergency,
    hide_low_loadings = hide_low_loadings,
    word_limit = word_limit,
    additional_info = additional_info,
    interpretation_guidelines = interpretation_guidelines,
    factor_cor_mat = factor_cor_mat,
    output_format = output_format,
    heading_level = heading_level,
    suppress_heading = suppress_heading,
    max_line_length = max_line_length,
    silent = silent,
    echo = echo,
    params = params
  )

  # Add FA-specific fields to result
  # Format loading matrix: remove leading zeros (e.g., -0.456 -> -.456, 0.456 -> .456)
  loading_matrix <- loadings_df
  for (col in factor_cols) {
    loading_matrix[[col]] <- sub("^(-?)0\\.", "\\1.", sprintf("%.3f", loading_matrix[[col]]))
  }
  result$loading_matrix <- loading_matrix
  result$factor_cor_mat <- factor_cor_mat
  result$cutoff <- cutoff

  return(result)
}
