# ==============================================================================
# MAIN INTERPRETATION FUNCTION FOR FACTOR ANALYSIS
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
#' @param silent Logical. If TRUE, suppresses printing the interpretation report and progress bars to console (default = FALSE)
#' @param echo Character. Controls what is echoed during LLM interaction. One of "none" (no output),
#'   "output" (show only LLM responses), or "all" (show prompts and responses). Passed directly
#'   to the ellmer chat function for debugging and transparency (default = "none")
#' @param output_format Character. Output format for the report: "text" or "markdown" (default = "text")
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
#' @importFrom ellmer chat chat_openai chat_anthropic chat_azure chat_gemini params
#' @importFrom cli cli_abort cli_alert_info cli_alert_success cli_warn
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
#'     \item{chat}{Complete ellmer chat object with full conversation history and cost information}
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
#' # Assuming you have factor analysis results
#' library(psych)
#' fa_results <- psych::fa(mtcars[,1:4], nfactors = 2)
#'
#' # Create variable info dataframe with realistic descriptions
#' var_info <- data.frame(
#'   variable = c("mpg", "cyl", "disp", "hp"),
#'   description = c(
#'     "Miles per gallon fuel efficiency",
#'     "Number of engine cylinders",
#'     "Engine displacement in cubic inches",
#'     "Engine horsepower output"
#'   )
#' )
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
#'
#' # Multiple analyses with same chat session (saves tokens)
#' interpretation1 <- interpret_fa(
#'   loadings = fa_results1$loadings,
#'   variable_info = var_info1,
#'   chat_session = chat
#' )
#'
#' interpretation2 <- interpret_fa(
#'   loadings = fa_results2$loadings,
#'   variable_info = var_info2,
#'   chat_session = chat
#' )
#'
#' # Check total token usage
#' print(chat)
#'
#' # Advanced usage with factor correlations and custom settings
#' interpretation_advanced <- interpret_fa(
#'   loadings = fa_results$loadings,
#'   variable_info = var_info,
#'   llm_provider = "ollama",
#'   llm_model = "llama3.1:8b",
#'   additional_info = "This analysis examines automotive performance characteristics.",
#'   factor_cor_mat = fa_results$cor,  # Factor correlation matrix for oblique rotations
#'   cutoff = 0.4,
#'   word_limit = 120,
#'   params = params(temperature = 0.3, seed = 123),
#'   output_format = "markdown",
#'   heading_level = 2,
#'   silent = TRUE
#' )
#'
#' # Usage with factor correlations for oblique rotation
#' fa_oblique <- psych::fa(mtcars[,1:7], nfactors = 3, rotate = "oblimin")
#' interpretation_oblique <- interpret_fa(
#'   loadings = fa_oblique$loadings,
#'   variable_info = var_info,
#'   factor_cor_mat = fa_oblique$Phi,  # Use factor correlation matrix from oblique rotation
#'   llm_provider = "openai",
#'   llm_model = "gpt-4o-mini",
#'   additional_info = "Oblique rotation allowing correlated factors in automotive data"
#' )
#'
#' # For integration into existing Quarto/R Markdown documents
#' interpretation_embedded <- interpret_fa(
#'   loadings = fa_results$loadings,
#'   variable_info = var_info,
#'   llm_provider = "openai",
#'   llm_model = "gpt-4o-mini",
#'   params = params(temperature = 0.7, seed = 42),
#'   output_format = "markdown",
#'   heading_level = 3,  # Adjust to fit your document structure
#'   suppress_heading = TRUE  # Skip main heading for better integration
#' )
#'
#' # For debugging - see what prompts are sent to the LLM
#' interpretation_debug <- interpret_fa(
#'   loadings = fa_results$loadings,
#'   variable_info = var_info,
#'   llm_provider = "openai",
#'   llm_model = "gpt-4o-mini",
#'   echo = TRUE  # Display prompts and responses
#' )
#'
#' # Access results
#' print(interpretation$suggested_names)
#' print(interpretation$report)
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
                         output_format = "text",
                         heading_level = 1,
                         suppress_heading = FALSE,
                         max_line_length = 80,
                         silent = FALSE,
                         echo = "none") {
  # ============================================================================
  # SECTION 1: INITIALIZATION AND PARAMETER VALIDATION
  # ============================================================================
  # This section handles initial setup, timing, and validates all input parameters
  # to ensure they meet the function's requirements before processing begins.

  # Start timing
  start_time <- Sys.time()

  # NOTE: Defer validation of {.var llm_provider} until we actually need to
  # initialize a new chat session. This allows input-related validation errors
  # (e.g., invalid {.var cutoff}) to be reported first in tests that do not
  # provide an active chat session.


  # Validate llm_model parameter (allow NULL)
  if (!is.null(llm_model) &&
      (!is.character(llm_model) || length(llm_model) != 1)) {
    cli::cli_abort(
      c(
        "{.var llm_model} must be a single character string or NULL",
        "x" = "You supplied: {.val {llm_model}}"
      )
    )
  }

  # Validate params parameter
  if (!is.null(params)) {
    # Check if it's a list (which is what ellmer::params() returns)
    if (!is.list(params)) {
      cli::cli_abort(
        c(
          "{.var params} must be created using ellmer::params() function",
          "x" = "You supplied a {.cls {class(params)}}",
          "i" = "Use params(temperature = 0.7, seed = 42) to create parameters"
        )
      )
    }

    # Additional check: if it's a plain list without function call context, warn user
    if (is.list(params) && is.null(attr(params, "ellmer_params")) &&
        !any(c("temperature", "seed", "max_tokens") %in% names(params))) {
      cli::cli_alert_info(
        "Parameters should be created using ellmer::params() function. Use params(temperature = 0.7, seed = 42) instead of list()"
      )
    }
  }

  # Validate echo parameter
  if (!is.character(echo) ||
      length(echo) != 1 || !echo %in% c("none", "output", "all")) {
    cli::cli_abort(
      c(
        "{.var echo} must be one of: 'none', 'output', or 'all'",
        "x" = "You supplied: {.val {echo}}",
        "i" = "Use echo = 'all' to see prompts and responses, or echo = 'output' for responses only"
      )
    )
  }

  # ============================================================================
  # SECTION 2: LLM SYSTEM PROMPT CONFIGURATION
  # ============================================================================
  # Creates a sophisticated, structured prompt that guides the LLM in interpreting
  # factor analysis results. The prompt includes role definition, task structure,
  # key psychometric definitions, and detailed interpretation guidelines organized
  # into Factor Naming, Factor Interpretation, and Output Requirements sections.

  # use user system_prompt if provided
  if (!is.null(system_prompt)) {
    system_prompt <- system_prompt
  } else{
    # Set default system prompt
    system_prompt <- paste0(
      "# ROLE\n",
      "You are an expert psychometrician specializing in exploratory factor analysis.\n\n",

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
  }


  # ============================================================================
  # SECTION 3: COMPREHENSIVE INPUT VALIDATION
  # ============================================================================
  # Validates all function parameters including data types, ranges, and logical
  # constraints. Provides detailed error messages to help users correct issues.

  # Validate cutoff parameter
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

  # Validate n_emergency parameter
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

  # Validate hide_low_loadings parameter
  if (!is.logical(hide_low_loadings) || length(hide_low_loadings) != 1 || is.na(hide_low_loadings)) {
    cli::cli_abort(
      c(
        "{.var hide_low_loadings} must be a single logical value (TRUE or FALSE)",
        "x" = "You supplied: {.val {hide_low_loadings}}"
      )
    )
  }

  # Validate word_limit parameter
  if (!is.numeric(word_limit) || length(word_limit) != 1) {
    cli::cli_abort(
      c("{.var word_limit} must be a single numeric value", "x" = "You supplied: {.val {word_limit}}")
    )
  }
  if (word_limit < 20 || word_limit > 1000) {
    cli::cli_abort(
      c(
        "{.var word_limit} must be between 20 and 1000",
        "x" = "You supplied: {.val {word_limit}}",
        "i" = "Recommended range is 100-300 words for production use"
      )
    )
  }

  # Validate max_line_length parameter
  if (!is.numeric(max_line_length) ||
      length(max_line_length) != 1) {
    cli::cli_abort(
      c("{.var max_line_length} must be a single numeric value", "x" = "You supplied: {.val {max_line_length}}")
    )
  }
  if (max_line_length < 20 || max_line_length > 300) {
    cli::cli_abort(
      c(
        "{.var max_line_length} must be between 20 and 300",
        "x" = "You supplied: {.val {max_line_length}}",
        "i" = "Recommended range is 80-120 characters for readability"
      )
    )
  }

  # Validate output_format parameter
  if (!is.character(output_format) || length(output_format) != 1) {
    cli::cli_abort(
      c("{.var output_format} must be a single character string", "x" = "You supplied: {.val {output_format}}")
    )
  }
  if (!output_format %in% c("text", "markdown")) {
    cli::cli_abort(
      c(
        "{.var output_format} must be either 'text' or 'markdown'",
        "x" = "You supplied: {.val {output_format}}",
        "i" = "Supported formats: 'text', 'markdown'"
      )
    )
  }

  # Validate heading_level parameter
  if (!is.numeric(heading_level) || length(heading_level) != 1) {
    cli::cli_abort(
      c("{.var heading_level} must be a single numeric value", "x" = "You supplied: {.val {heading_level}}")
    )
  }
  if (heading_level < 1 ||
      heading_level > 6 ||
      heading_level != as.integer(heading_level)) {
    cli::cli_abort(
      c(
        "{.var heading_level} must be an integer between 1 and 6",
        "x" = "You supplied: {.val {heading_level}}",
        "i" = "Markdown supports heading levels 1 through 6"
      )
    )
  }

  # Validate variable_info parameter
  if (!is.data.frame(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} must be a data frame",
        "x" = "You supplied a {.cls {class(variable_info)}}",
        "i" = "Please provide a data frame with {.field variable} and {.field description} columns"
      )
    )
  }
  if (!"variable" %in% names(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} must contain a {.field variable} column",
        "i" = "Available columns: {.field {names(variable_info)}}"
      )
    )
  }
  if (!"description" %in% names(variable_info)) {
    cli::cli_abort(
      c(
        "{.var variable_info} must contain a {.field description} column",
        "i" = "Available columns: {.field {names(variable_info)}}"
      )
    )
  }

  # Check if description column is a factor and coerce to character
  if (is.factor(variable_info$description)) {
    if (!silent) {
      cli::cli_alert_info("The {.field description} column is a factor - converting to character")
    }
    variable_info$description <- as.character(variable_info$description)
  }

  # ============================================================================
  # SECTION 4: DATA PREPARATION AND PREPROCESSING
  # ============================================================================
  # Converts loadings data to standard format, extracts factor information,
  # validates data structure, and merges with variable descriptions.

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

  # Check for variable matching between loadings and variable_info
  missing_in_info <- setdiff(loadings_df$variable, variable_info$variable)
  missing_in_loadings <- setdiff(variable_info$variable, loadings_df$variable)

  # Check that variables in loadings and variable_info match exactly
  if (length(missing_in_info) > 0 ||
      length(missing_in_loadings) > 0) {
    if (length(missing_in_info) == nrow(loadings_df)) {
      # All variables missing - critical error
      cli::cli_abort(
        c(
          "No variables from {.var loadings} found in {.var variable_info}",
          "x" = "Check that the {.field variable} column in {.var variable_info} matches row names or variable names in {.var loadings}",
          "i" = "First few variables in loadings: {.val {head(loadings_df$variable, 3)}}"
        )
      )
    }

    # Report mismatches
    if (length(missing_in_info) > 0) {
      cli::cli_abort(
        c(
          "Variables in {.var loadings} not found in {.var variable_info}",
          "x" = "Missing in variable_info: {.val {missing_in_info}}",
          "i" = "All variables in loadings must have corresponding entries in variable_info"
        )
      )
    }

    if (length(missing_in_loadings) > 0) {
      cli::cli_abort(
        c(
          "Variables in {.var variable_info} not found in {.var loadings}",
          "x" = "Missing in loadings: {.val {missing_in_loadings}}",
          "i" = "All variables in variable_info must have corresponding entries in loadings"
        )
      )
    }
  }

  # Merge with variable info
  loadings_with_info <- loadings_df |>
    left_join(variable_info, by = "variable")

  # ============================================================================
  # SECTION 5: FACTOR ANALYSIS AND SUMMARY GENERATION
  # ============================================================================
  # Analyzes each factor individually, calculating variance explained, identifying
  # significant loadings, applying emergency rules for weak factors, and creating
  # detailed summaries with variable information and loading strengths.

  # Initialize results list
  results <- list()

  # Analyze each factor
  factor_summaries <- list()

  for (i in 1:n_factors) {
    factor_name <- factor_cols[i]

    # Calculate variance explained by this factor (sum of squared loadings / number of variables)
    n_variables <- nrow(loadings_df)
    variance_explained <- sum(loadings_df[[factor_name]]^2) / n_variables

    # Get loadings for this factor
    factor_data <- loadings_with_info |>
      dplyr::select(variable, description, !!sym(factor_name)) |>
      dplyr::rename(loading = !!sym(factor_name)) |>
      dplyr::filter(abs(loading) >= cutoff)

    if (sort_loadings) {
      factor_data <- factor_data |>
        arrange(desc(abs(loading)))
    }

    # Identify strong loadings (>= 0.5), moderate (0.3-0.5), and signs
    factor_data <- factor_data |>
      mutate(
        strength = case_when(
          abs(loading) >= 0.7 ~ "Very Strong",
          abs(loading) >= 0.5 ~ "Strong",
          abs(loading) >= 0.4 ~ "Moderate",
          TRUE ~ "Weak"
        ),
        direction = ifelse(loading > 0, "Positive", "Negative")
      )

    # If no significant loadings, apply emergency rule or mark as undefined
    has_significant <- nrow(factor_data) > 0
    used_emergency_rule <- FALSE

    if (!has_significant) {
      if (n_emergency == 0) {
        # Leave factor_data empty when n_emergency = 0
        factor_data <- data.frame(
          variable = character(0),
          description = character(0),
          loading = numeric(0),
          strength = character(0),
          direction = character(0)
        )
      } else {
        # Apply emergency rule: use top N variables below cutoff
        used_emergency_rule <- TRUE
        factor_data <- loadings_with_info |>
          dplyr::select(variable, description, !!sym(factor_name)) |>
          dplyr::rename(loading = !!sym(factor_name)) |>
          arrange(desc(abs(loading))) |>
          head(n_emergency) |>
          mutate(
            strength = case_when(
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

  results$factor_summaries <- factor_summaries

  # ============================================================================
  # SECTION 6: LLM INITIALIZATION AND CONNECTION
  # ============================================================================
  # Establishes connection to the specified LLM provider and model, with proper
  # error handling and user feedback about the selected model configuration.

  # Generate suggested factor names using LLM
  suggested_names <- list()

  # Initialize chat - use existing chat_session if provided, otherwise create new one
  if (!is.null(chat_session)) {
    # Validate chat_session
    if (!is.chat_fa(chat_session)) {
      cli::cli_abort(
        c(
          "chat_session must be a chat_fa object",
          "i" = "Create one with: chat_fa(provider, model)",
          "i" = "Or pass NULL to create a new session"
        )
      )
    }

    # Use existing chat session and ignore chat history
    chat <- chat_session$chat$clone()$set_turns(list())

    # Increment interpretation counter (persists due to environment reference semantics)
    chat_session$n_interpretations <- chat_session$n_interpretations + 1L

    # Inform user if they provided provider/model arguments that will be ignored
    if (!is.null(llm_provider) || !is.null(llm_model)) {
      cli::cli_inform(
        c("i" = "Using provided {.field chat_session} (overrides {.field llm_provider} and {.field llm_model} arguments)")
      )
    }

    cli::cli_alert_info(
      "Using existing chat session: {.strong {chat$get_provider()@name}} {.val {chat$get_model()}}"
    )

  } else {
    # Create new chat session using provider-specific functions
    # Validate llm_provider now that we are about to create a chat
    if (!is.character(llm_provider) || length(llm_provider) != 1) {
      cli::cli_abort(
        c("{.var llm_provider} must be a single character string", "x" = "You supplied: {.val {llm_provider}}")
      )
    }

    chat <- tryCatch({
      switch(
        llm_provider,
        "openai" = ellmer::chat_openai(
          model = llm_model,
          system_prompt = system_prompt,
          params = params
        ),
        "anthropic" = ellmer::chat_anthropic(
          model = llm_model,
          system_prompt = system_prompt,
          params = params
        ),
        "azure" = ellmer::chat_azure(
          model = llm_model,
          system_prompt = system_prompt,
          params = params
        ),
        "gemini" = ellmer::chat_gemini(
          model = llm_model,
          system_prompt = system_prompt,
          params = params
        ),
        # Fallback to generic chat for other providers
        {
          chat_name <- if (!is.null(llm_model)) {
            paste0(llm_provider, "/", llm_model)
          } else {
            llm_provider
          }
          ellmer::chat(name = chat_name,
                       system_prompt = system_prompt,
                       params = params)
        }
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

    cli::cli_alert_info(
      "Using {.strong {chat$get_provider()@name}} {.val {chat$get_model()}} for factor interpretation."
    )
  }

  # ============================================================================
  # SECTION 7: LLM FACTOR INTERPRETATION
  # ============================================================================
  # Constructs an optimized prompt with all factors, variable descriptions,
  # loadings in compact format, variance explained, and factor correlations (if provided).
  # Processes all factors simultaneously for efficiency and cost optimization.
  # Includes robust JSON parsing with multiple fallback methods.

  # Notify user of LLM processing
  if (!silent) {
    cli::cli_alert_info("Processing all {n_factors} factors...")
  }

  # Create optimized prompt with structured markdown
  n_variables <- nrow(loadings_df)

  # Build structured prompt sections
  prompt <- ""

  # use interpretation_guidelines provided by user if given, else use default
  if (!is.null(interpretation_guidelines)) {
    interpretation_guidelines <- interpretation_guidelines
  } else{
    # default INTERPRETATION GUIDELINES
    interpretation_guidelines <- paste0(
      "# INTERPRETATION GUIDELINES\n\n",
      "## Factor Naming\n",
      "- **Construct identification**: Identify the underlying construct each factor represents\n",
      "- **Name creation**: Create 2-4 word names capturing the essence of each factor\n",
      "- **Theoretical grounding**: Base names on domain knowledge and additional context\n\n",
      "## Factor Interpretation\n",
      "- **Convergent validity**: Explain why significantly loading variables belong together conceptually\n",
      "- **Loading patterns**: Examine both strong positive/negative loadings and notable weak loadings\n",
      "- **Construct meaning**: Describe what the factor measures and represents\n",
      "- **Factor Relationships**: Use correlation matrix and cross loadings to understand how factors relate to each other\n",
      "- **Discriminant validity**: Ensure factors represent meaningfully distinct constructs; explain how similar factors complement each other\n\n",
      "## Output Requirements\n",
      "- **Word target (Interpretation)**: Aim for ",
      round(word_limit * 0.8),
      "-",
      word_limit,
      " words per interpretation (80%-100% of limit)\n",
      "- **Writing style**: Be concise, precise, and domain-appropriate\n\n"
    )
  }


  # Add interpretation guidelines section
  prompt <- paste0(prompt, interpretation_guidelines)

  # Add additional context if provided (positioned after TASK in system prompt)
  if (!is.null(additional_info) && nchar(additional_info) > 0) {
    prompt <- paste0(prompt, "# ADDITIONAL CONTEXT\n", additional_info, "\n\n")
  }

  # Add variable descriptions section
  prompt <- paste0(prompt, "# VARIABLE DESCRIPTIONS\n")
  if (nrow(variable_info) > 0) {
    for (i in 1:min(nrow(variable_info), 1e3)) {
      var_desc <- ifelse(
        !is.na(variable_info$description[i]),
        variable_info$description[i],
        variable_info$variable[i]
      )
      prompt <- paste0(prompt, "- ", variable_info$variable[i], ": ", var_desc, "\n")
    }
  }
  prompt <- paste0(prompt, "\n")

  # Add factor loadings section with compact vector format
  prompt <- paste0(prompt, "# FACTOR LOADINGS\n")
  prompt <- paste0(
    prompt,
    "**Cutoff threshold**: ",
    cutoff,
    " (absolute value >=",
    cutoff,
    " considered significant)\n"
  )
  prompt <- paste0(
    prompt,
    "**Emergency rule**: Use top ",
    n_emergency,
    " variables if no significant loadings\n\n"
  )

  # Add each factor with compact vector format
  for (i in 1:n_factors) {
    factor_name <- factor_cols[i]

    # Build compact vector string for this factor
    loading_vector <- c()
    for (j in 1:nrow(loadings_df)) {
      var_name <- loadings_df$variable[j]
      loading_value <- loadings_df[[factor_name]][j]

      # Skip low loadings if hide_low_loadings is TRUE
      if (hide_low_loadings && abs(loading_value) < cutoff) {
        next
      }

      loading_val <- sub("^(-?)0\\.", "\\1.", sprintf("%.3f", loading_value))
      loading_vector <- c(loading_vector, paste0(var_name, "=", loading_val))
    }

    prompt <- paste0(prompt,
                     factor_name,
                     ": ",
                     paste(loading_vector, collapse = " "),
                     "\n")
  }

  # Add variance explained
  prompt <- paste0(prompt, "\n**Variance Explained**: ")
  variance_entries <- c()
  for (i in 1:n_factors) {
    factor_name <- factor_cols[i]
    variance_explained <- sum(loadings_df[[factor_name]]^2) / n_variables
    variance_entries <- c(variance_entries, paste0(factor_name, "=", round(variance_explained * 100, 1), "%"))
  }
  prompt <- paste0(prompt, paste(variance_entries, collapse = " "), "\n\n")

  # Add factor correlations section if provided
  if (!is.null(factor_cor_mat)) {
    prompt <- paste0(prompt, "# FACTOR CORRELATIONS\n")

    # Convert matrix to dataframe if needed and get factor names
    if (is.matrix(factor_cor_mat)) {
      cor_df <- as.data.frame(factor_cor_mat)
      cor_factors <- rownames(factor_cor_mat)
    } else {
      cor_df <- factor_cor_mat
      cor_factors <- rownames(cor_df)
    }

    # Add correlation matrix information in compact format
    prompt <- paste0(prompt,
                     "Factor correlations help understand relationships between factors:\n")
    for (i in 1:length(cor_factors)) {
      factor_name <- cor_factors[i]
      if (factor_name %in% names(cor_df)) {
        cor_vector <- c()
        for (j in 1:length(cor_factors)) {
          other_factor <- cor_factors[j]
          if (other_factor != factor_name &&
              other_factor %in% names(cor_df)) {
            cor_val <- round(cor_df[[other_factor]][i], 2)
            cor_formatted <- sprintf("%.2f", cor_val)
            cor_formatted <- sub("^(-?)0\\.", "\\1.", cor_formatted)  # Remove leading zero for consistency with LLM input
            cor_vector <- c(cor_vector,
                            paste0(other_factor, "=", cor_formatted))
          }
        }
        if (length(cor_vector) > 0) {
          prompt <- paste0(prompt,
                           factor_name,
                           " with: ",
                           paste(cor_vector, collapse = " "),
                           "\n")
        }
      }
    }
    prompt <- paste0(prompt, "\n")
  }

  # Check for factors with no significant loadings (n_emergency = 0 case)
  factors_with_no_vars <- 0
  undefined_factors <- c()

  for (i in 1:n_factors) {
    factor_name <- factor_cols[i]
    factor_vars <- factor_summaries[[factor_name]]$variables

    if (nrow(factor_vars) == 0) {
      if (n_emergency == 0 && !factor_summaries[[factor_name]]$has_significant) {
        # Mark as undefined when n_emergency = 0 and no significant loadings
        suggested_names[[factor_name]] <- "undefined"
        factor_summaries[[factor_name]]$llm_interpretation <- "NA"
        undefined_factors <- c(undefined_factors, factor_name)
      } else {
        # Default handling for truly empty factors
        suggested_names[[factor_name]] <- "No variables"
        factor_summaries[[factor_name]]$llm_interpretation <- "This factor has no variables."
      }
      factors_with_no_vars <- factors_with_no_vars + 1
    }
  }

  # Only proceed with LLM call if we have factors to analyze
  factors_to_analyze <- n_factors - factors_with_no_vars

  if (factors_to_analyze > 0) {
    # Add optimized output format instructions with factor names as keys
    prompt <- paste0(
      prompt,
      "# OUTPUT FORMAT\n",
      "Respond with ONLY valid JSON using factor names as object keys:\n\n",
      "```json\n",
      "{\n"
    )

    # Add example for each factor using actual factor names as keys
    for (i in 1:n_factors) {
      prompt <- paste0(
        prompt,
        '  "',
        factor_cols[i],
        '": {\n',
        '    "name": "Generate name",\n',
        '    "interpretation": "Generate interpretation"\n',
        '  }'
      )
      if (i < n_factors) {
        prompt <- paste0(prompt, ',\n')
      } else {
        prompt <- paste0(prompt, '\n')
      }
    }

    prompt_requirements <- paste0(
      "}\n",
      "```\n\n",
      "# CRITICAL REQUIREMENTS\n",
      "- Include ALL ",
      n_factors,
      " factors as object keys using their exact names: ",
      paste(factor_cols, collapse = ", "),
      "\n",
      "- Valid JSON syntax (proper quotes, commas, brackets)\n",
      "- No additional text before or after JSON\n",
      "- Factor names: 2-4 words maximum\n",
      "- Factor interpretations: target ",
      round(word_limit * 0.8),
      "-",
      word_limit,
      " words each (80%-100% of ",
      word_limit,
      " word limit)\n"
    )

    # Add emergency rule or undefined factor instructions
    if (n_emergency == 0) {
      prompt_requirements <- paste0(
        prompt_requirements,
        "- For factors with no significant loadings: respond with \"undefined\" for name and \"NA\" for interpretation\n"
      )
    } else {
      prompt_requirements <- paste0(
        prompt_requirements,
        "- Emergency rule: Use top ",
        n_emergency,
        " variables if no significant loadings\n"
      )
    }

    # Add undefined factors note if applicable
    if (length(undefined_factors) > 0) {
      prompt_requirements <- paste0(
        prompt_requirements,
        "- The following factors have no significant loadings and should receive \"undefined\" for name and \"NA\" for interpretation: ",
        paste(undefined_factors, collapse = ", "),
        "\n"
      )
    }

    prompt <- paste0(prompt, prompt_requirements)

    ### Call LLM ###############################################################

    # Get LLM response with error handling
    response <- tryCatch({
      chat$chat(prompt, echo = echo)
    }, error = function(e) {
      cli::cli_warn("Failed to get factor analysis: {e$message}")
      NULL
    })
    ###########################################################################

    # Parse hierarchical JSON response
    if (!is.null(response)) {
      # Clean the response to extract JSON content
      cleaned_response <- response

      # Try to extract JSON block if response contains extra text
      json_match <- regexpr('\\{[\\s\\S]*\\}', response)
      if (json_match > 0) {
        cleaned_response <- regmatches(response, json_match)
      }

      # Remove common prefixes/suffixes that LLMs might add
      cleaned_response <- gsub("^[^{]*", "", cleaned_response)  # Remove text before first {
      cleaned_response <- gsub("[^}]*$", "", cleaned_response)  # Remove text after last }

      # Fix common JSON formatting issues specific to small models
      cleaned_response <- gsub("\\n\\s*", " ", cleaned_response)  # Remove newlines and extra spaces
      cleaned_response <- gsub("\\s+", " ", cleaned_response)    # Collapse multiple spaces
      cleaned_response <- gsub('(\\})\\s*("\\w+")\\s*:', '\\1, \\2:', cleaned_response)  # Add missing commas between objects
      cleaned_response <- gsub(',\\s*}', '}', cleaned_response)  # Remove trailing commas

      # Try parsing the cleaned response
      parsed_response <- tryCatch({
        jsonlite::fromJSON(cleaned_response)
      }, error = function(e) {
        # If that fails, try the original response
        tryCatch({
          jsonlite::fromJSON(response)
        }, error = function(e2) {
          cli::cli_warn(
            c("Batch JSON parsing failed: {e$message}", "i" = "Consider using a larger model (e.g., 'gemma2:9b', 'llama3.1:8b') for better JSON generation")
          )
          NULL
        })
      })

      if (!is.null(parsed_response) && is.list(parsed_response)) {
        # Successfully parsed object-based JSON with factor names as keys

        # Process each factor from the response using factor names as keys
        for (i in 1:n_factors) {
          factor_name <- factor_cols[i]

          # Check if this factor exists in the parsed response
          if (factor_name %in% names(parsed_response)) {
            factor_data <- parsed_response[[factor_name]]

            # Extract name and interpretation
            suggested_name <- if (!is.null(factor_data$name) &&
                                  !is.na(factor_data$name) &&
                                  nchar(trimws(factor_data$name)) > 0) {
              name_text <- trimws(factor_data$name)
              # Add (n.s.) suffix if emergency rule was used and name is not "NA"
              if (factor_summaries[[factor_name]]$used_emergency_rule &&
                  !grepl("^NA$|^na$|^N/A$|^n/a$", name_text, ignore.case = FALSE)) {
                paste0(name_text, " (n.s.)")
              } else {
                name_text
              }
            } else {
              paste("Factor", i)
            }

            interpretation <- if (!is.null(factor_data$interpretation) &&
                                  !is.na(factor_data$interpretation) &&
                                  nchar(trimws(factor_data$interpretation)) > 0) {
              trimws(factor_data$interpretation)
            } else {
              "Unable to generate interpretation"
            }

            # Check word count and inform if exceeded
            word_count <- count_words(interpretation)
            if (word_count > word_limit) {
              cli::cli_inform(
                c(
                  "LLM interpretation for {factor_name} exceeded word limit",
                  "!" = "Expected: {word_limit} words, Got: {word_count} words",
                  "i" = "Consider using a more restrictive model or adjusting the prompt"
                )
              )
            }

            # Store results
            suggested_names[[factor_name]] <- suggested_name
            factor_summaries[[factor_name]]$llm_interpretation <- interpretation
          } else {
            # Factor missing from response - set defaults
            suggested_names[[factor_name]] <- paste("Factor", i)
            factor_summaries[[factor_name]]$llm_interpretation <- "Missing from LLM response"
          }
        }

      } else {
        # Fallback: parse using alternative methods if object parsing fails
        cli::cli_alert_info("Object-based JSON parsing failed, attempting alternative extraction")

        # Try to extract factor information using patterns for the new object structure
        # Look for factor names as keys with nested objects
        for (i in 1:n_factors) {
          factor_name <- factor_cols[i]

          # Pattern: Look for "FactorName": { "name": "...", "interpretation": "..." }
          pattern <- paste0(
            '"',
            factor_name,
            '"\\s*:\\s*\\{[^{}]*"name"[^{}]*"interpretation"[^{}]*\\}'
          )
          match <- regexpr(pattern, response, perl = TRUE)

          if (match > 0) {
            # Extract the matched factor object
            factor_text <- regmatches(response, match)

            # Try to parse this individual factor
            parsed_factor <- tryCatch({
              # Extract just the object part (everything after the factor name)
              object_match <- regexpr('\\{[^{}]*\\}', factor_text, perl = TRUE)
              if (object_match > 0) {
                object_text <- regmatches(factor_text, object_match)
                jsonlite::fromJSON(object_text)
              } else {
                NULL
              }
            }, error = function(e)
              NULL)

            if (!is.null(parsed_factor) && is.list(parsed_factor)) {
              # Successfully parsed individual factor
              suggested_names[[factor_name]] <- if (!is.null(parsed_factor$name)) {
                name_text <- trimws(parsed_factor$name)
                # Add (n.s.) suffix if emergency rule was used and name is not "NA"
                if (factor_summaries[[factor_name]]$used_emergency_rule &&
                    !grepl("^NA$|^na$|^N/A$|^n/a$", name_text, ignore.case = FALSE)) {
                  paste0(name_text, " (n.s.)")
                } else {
                  name_text
                }
              } else {
                paste("Factor", i)
              }

              interpretation <- if (!is.null(parsed_factor$interpretation)) {
                trimws(parsed_factor$interpretation)
              } else {
                "Unable to parse interpretation"
              }

              factor_summaries[[factor_name]]$llm_interpretation <- interpretation
            } else {
              # Parsing failed for this factor
              suggested_names[[factor_name]] <- paste("Factor", i)
              factor_summaries[[factor_name]]$llm_interpretation <- "Unable to extract from response"
            }
          } else {
            # No match found for this factor
            suggested_names[[factor_name]] <- paste("Factor", i)
            factor_summaries[[factor_name]]$llm_interpretation <- "Not found in response"
          }
        }
      }
    } else {
      # No response from LLM - set defaults for all factors
      for (i in 1:n_factors) {
        factor_name <- factor_cols[i]
        if (is.null(suggested_names[[factor_name]])) {
          suggested_names[[factor_name]] <- paste("Factor", i)
          factor_summaries[[factor_name]]$llm_interpretation <- "Unable to generate interpretation due to LLM error"
        }
      }
    }
  }

  # Notify completion
  if (!silent) {
    cli::cli_alert_success("Factor interpretation complete")
  }

  results$suggested_names <- suggested_names
  results$llm_info <- list(provider = llm_provider, model = chat$get_model())
  results$chat <- chat
  # token tracking
  tokens_df <- chat$get_tokens()
  # Note: some providers / the ellmer wrapper do not reliably report `system` role
  # token counts. We intentionally only sum user/assistant tokens here and do NOT
  # include `system`/`system_prompt` tokens in package-level counters to avoid
  # inconsistent or double-counted totals.
  results$input_tokens <- sum(tokens_df$tokens[tokens_df$role == "user"], na.rm = TRUE)
  results$output_tokens <- sum(tokens_df$tokens[tokens_df$role == "assistant"], na.rm = TRUE)
  # if chat_session was used, increment total tokens
  tokens_df <- chat$get_tokens()
  chat_session$total_input_tokens <- chat_session$total_input_tokens + results$input_tokens
  chat_session$total_output_tokens <- chat_session$total_output_tokens + results$output_tokens


  # ============================================================================
  # SECTION 8: OUTPUT FORMATTING AND COMPREHENSIVE REPORT GENERATION
  # ============================================================================
  # Formats loading matrices, calculates execution time, identifies cross-loadings
  # and no-loading variables, generates final reports using the helper function,
  # and returns comprehensive results structure.

  # Create formatted loading matrix
  loading_matrix <- loadings_df

  # Format all loadings
  for (col in factor_cols) {
    loading_matrix[[col]] <- sub("^(-?)0\\.", "\\1.", sprintf("%.3f", loading_matrix[[col]]))
  }

  results$loading_matrix <- loading_matrix

  # Calculate elapsed time
  end_time <- Sys.time()
  elapsed_time <- end_time - start_time

  # Check for cross-loadings
  cross_loadings <- find_cross_loadings(loadings_df, factor_cols, cutoff)

  # Check for variables with no loadings above cutoff
  no_loadings <- find_no_loadings(loadings_df, factor_cols, cutoff)

  # Merge with variable_info to get descriptions
  if (nrow(cross_loadings) > 0) {
    # Select only variable and description columns from variable_info
    var_info_subset <- variable_info |>
      dplyr::select(variable, description)

    cross_loadings <- cross_loadings |>
      left_join(var_info_subset, by = "variable")
  }

  # Merge no_loadings with variable_info
  if (nrow(no_loadings) > 0) {
    var_info_subset <- variable_info |>
      dplyr::select(variable, description)

    no_loadings <- no_loadings |>
      left_join(var_info_subset, by = "variable")
  }

  # Store results before building report (needed for helper function)
  results$factor_summaries <- factor_summaries
  results$suggested_names <- suggested_names
  results$llm_info <- list(provider = llm_provider, model = chat$get_model())
  results$chat <- chat
  results$used_chat_session <- !is.null(chat_session)
  # store the system_prompt from chat_session if applicable (defensive)
  if (!is.null(chat_session)) {
    results$system_prompt <- tryCatch({
      if (!is.null(chat_session$chat$get_system_prompt) && is.function(chat_session$chat$get_system_prompt)) {
        chat_session$chat$get_system_prompt()
      } else if (!is.null(chat_session$chat$system_prompt)) {
        chat_session$chat$system_prompt
      } else {
        system_prompt
      }
    }, error = function(e) system_prompt)
  } else {
    results$system_prompt <- system_prompt
  }
  results$prompt <- prompt
  results$cross_loadings <- cross_loadings
  results$no_loadings <- no_loadings
  results$elapsed_time <- elapsed_time
  results$factor_cor_mat <- factor_cor_mat
  results$cutoff <- cutoff

  # Generate interpretation report using helper function
  report <- build_fa_report(
    interpretation_results = results,
    output_format = output_format,
    heading_level = heading_level,
    n_factors = n_factors,
    cutoff = cutoff,
    suppress_heading = suppress_heading
  )

  results$report <- report

  # Set S3 class for proper method dispatch
  class(results) <- c("fa_interpretation", "list")

  # Print report to console unless silent
  if (!silent) {
    print(results, max_line_length = max_line_length)
  }

  # Return results
  return(results)
}
