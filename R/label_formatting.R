#' Label Formatting Utilities
#'
#' Helper functions for formatting and transforming variable labels.
#'
#' @name label_formatting
#' @keywords internal
#' @importFrom utils head
NULL

#' Format Label with Post-Processing
#'
#' Apply formatting transformations to a label.
#'
#' @param label Character. Original label text
#' @param sep Character. Separator between words
#' @param case Character. Case transformation to apply
#' @param remove_articles Logical. Remove articles (a, an, the)
#' @param remove_prepositions Logical. Remove prepositions
#' @param max_chars Integer or NULL. Maximum character length
#' @param abbreviate Logical. Apply rule-based abbreviation
#' @param max_words Integer or NULL. Maximum word count
#'
#' @return Character. Formatted label
#' @export
#' @keywords internal
format_label <- function(label,
                        sep = " ",
                        case = "original",
                        remove_articles = FALSE,
                        remove_prepositions = FALSE,
                        max_chars = NULL,
                        abbreviate = FALSE,
                        max_words = NULL) {

  # Start with original label
  formatted <- label

  # Step 1: Remove articles if requested
  if (remove_articles) {
    formatted <- remove_label_articles(formatted)
  }

  # Step 2: Remove prepositions if requested
  if (remove_prepositions) {
    formatted <- remove_label_prepositions(formatted)
  }

  # Step 3: Split into words
  words <- strsplit(trimws(formatted), "\\s+")[[1]]

  # Step 4: Apply max_words if specified
  if (!is.null(max_words) && length(words) > max_words) {
    words <- head(words, max_words)
  }

  # Step 5: Apply abbreviation if requested
  if (abbreviate) {
    words <- sapply(words, abbreviate_word, USE.NAMES = FALSE)
  }

  # Step 6: Apply case transformation
  words <- apply_case_transform(words, case)

  # Step 7: Handle special cases that override sep
  if (case == "snake") {
    sep <- "_"
    words <- tolower(words)
  } else if (case == "constant") {
    sep <- "_"
    words <- toupper(words)
  } else if (case == "camel") {
    sep <- ""
    # camelCase: first word lowercase, rest title case
    if (length(words) > 0) {
      words[1] <- tolower(words[1])
      if (length(words) > 1) {
        for (i in 2:length(words)) {
          words[i] <- paste0(toupper(substr(words[i], 1, 1)),
                            tolower(substr(words[i], 2, nchar(words[i]))))
        }
      }
    }
  }

  # Step 8: Join with separator
  formatted <- paste(words, collapse = sep)

  # Step 9: Apply max_chars if specified
  if (!is.null(max_chars) && nchar(formatted) > max_chars) {
    formatted <- substr(formatted, 1, max_chars)
  }

  return(formatted)
}

#' Remove Articles from Label
#'
#' @param text Character. Label text
#' @return Character. Text without articles
#' @keywords internal
remove_label_articles <- function(text) {
  # Remove common articles (case-insensitive, word boundaries)
  gsub("\\b(a|an|the)\\b", "", text, ignore.case = TRUE) |>
    trimws() |>
    gsub("\\s+", " ", x = _)  # Collapse multiple spaces
}

#' Remove Prepositions from Label
#'
#' @param text Character. Label text
#' @return Character. Text without prepositions
#' @keywords internal
remove_label_prepositions <- function(text) {
  # Common prepositions to remove
  prepositions <- c("of", "in", "on", "at", "to", "for", "with", "by",
                   "from", "about", "into", "through", "during", "before",
                   "after", "above", "below", "between", "under", "over")

  pattern <- paste0("\\b(", paste(prepositions, collapse = "|"), ")\\b")
  gsub(pattern, "", text, ignore.case = TRUE) |>
    trimws() |>
    gsub("\\s+", " ", x = _)  # Collapse multiple spaces
}

#' Apply Case Transformation
#'
#' @param words Character vector. Words to transform
#' @param case Character. Case style to apply
#' @return Character vector. Transformed words
#' @keywords internal
apply_case_transform <- function(words, case) {
  switch(case,
    "lower" = tolower(words),
    "upper" = toupper(words),
    "title" = tools::toTitleCase(words),
    "sentence" = {
      # First word capitalized, rest lowercase
      if (length(words) > 0) {
        words[1] <- paste0(toupper(substr(words[1], 1, 1)),
                          tolower(substr(words[1], 2, nchar(words[1]))))
        if (length(words) > 1) {
          words[2:length(words)] <- tolower(words[2:length(words)])
        }
      }
      words
    },
    words  # "original" or any other value
  )
}

#' Abbreviate Word Using Rules
#'
#' Rule-based word abbreviation system.
#'
#' @param word Character. Single word to abbreviate
#' @param min_length Integer. Minimum word length to abbreviate
#'
#' @return Character. Abbreviated word
#' @export
#' @keywords internal
abbreviate_word <- function(word, min_length = 8) {

  # Don't abbreviate short words
  if (nchar(word) < min_length) {
    return(word)
  }

  # Preserve original case pattern
  original_case <- detect_case_pattern(word)
  word_lower <- tolower(word)

  # Step 1: Remove common suffixes
  suffixes <- c("ation", "ization", "isation", "ment", "ness",
               "ance", "ence", "able", "ible", "ical",
               "ized", "ised", "ing", "ion", "ity",
               "ous", "ive", "ful", "ness", "less",
               "ship", "ward", "wise", "like", "erly",
               "est", "er", "ed", "ly", "al", "ic")

  # Sort by length (longest first) to match greedily
  suffixes <- suffixes[order(nchar(suffixes), decreasing = TRUE)]
  pattern <- paste0("(", paste(suffixes, collapse = "|"), ")$")
  word_root <- gsub(pattern, "", word_lower)

  # Step 2: Apply length-based truncation
  if (nchar(word_root) <= 4) {
    abbrev <- word_root
  } else if (nchar(word_root) <= 6) {
    abbrev <- substr(word_root, 1, 4)
  } else {
    # Keep first 3-4 chars, try to include next consonant
    first_part <- substr(word_root, 1, 3)
    rest <- substring(word_root, 4)

    # Look for consonant to create natural break
    consonant_match <- regexpr("^[^aeiou]", rest)
    if (consonant_match > 0) {
      next_char <- substr(rest, 1, 1)
      abbrev <- paste0(first_part, next_char)
    } else {
      abbrev <- substr(word_root, 1, 4)
    }
  }

  # Step 3: Apply original case pattern
  abbrev <- restore_case_pattern(abbrev, original_case)

  return(abbrev)
}

#' Detect Case Pattern of Word
#'
#' @param word Character. Word to analyze
#' @return Character. Case pattern identifier
#' @keywords internal
detect_case_pattern <- function(word) {
  if (word == toupper(word)) {
    return("upper")
  } else if (word == tolower(word)) {
    return("lower")
  } else if (substr(word, 1, 1) == toupper(substr(word, 1, 1))) {
    return("title")
  } else {
    return("mixed")
  }
}

#' Restore Case Pattern to Word
#'
#' @param word Character. Word to transform
#' @param pattern Character. Case pattern to apply
#' @return Character. Word with case pattern applied
#' @keywords internal
restore_case_pattern <- function(word, pattern) {
  switch(pattern,
    "upper" = toupper(word),
    "lower" = tolower(word),
    "title" = paste0(toupper(substr(word, 1, 1)),
                    tolower(substr(word, 2, nchar(word)))),
    word  # mixed or unknown
  )
}

#' Create Variable Labels Object
#'
#' @param labels_df Data frame. Formatted labels with variable and label columns
#' @param variable_info Data frame. Original variable information with 'variable'
#'   and 'description' columns
#' @param llm_response Character. Raw LLM response text
#' @param parsed_labels Data frame. Parsed labels from LLM (before formatting)
#'   with 'variable' and 'label' columns
#' @param metadata List. Additional metadata
#'
#' @return variable_labels object
#' @export
#' @keywords internal
create_variable_labels <- function(labels_df, variable_info,
                                   llm_response = NULL, parsed_labels = NULL,
                                   metadata = list(), chat_session = NULL) {

  result <- list(
    labels_formatted = labels_df,                 # Formatted labels (data.frame)
    labels_parsed = parsed_labels,                # Unformatted LLM labels (data.frame)
    variable_info = variable_info,                # Original variable information (data.frame)
    llm_response = llm_response,                  # Raw LLM text
    metadata = metadata,
    chat_session = chat_session                   # Chat session object
  )

  class(result) <- c("variable_labels", "list")
  return(result)
}

#' Print Variable Labels Object
#'
#' @param x variable_labels object
#' @param silent Integer. Controls output verbosity (0, 1, 2). Default = 0
#' @param ... Additional arguments
#'
#' @export
print.variable_labels <- function(x, silent = 0, ...) {

  # Handle backward compatibility
  if (is.logical(silent)) {
    silent <- ifelse(silent, 2, 0)
  }

  # Completely silent - return nothing
  if (silent == 2) {
    return(invisible(x))
  }

  # CLI-formatted output
  cli::cli_rule("Variable Labels Report")
  cli::cli_text("")

  # Metadata section
  cli::cli_h2("Labeling Details")

  if (!is.null(x$metadata$label_type)) {
    cli::cli_bullets(c(
      "*" = "Label type: {.field {x$metadata$label_type}}"
    ))
  }

  # Show max_words if specified (LLM instruction)
  if (!is.null(x$metadata$formatting$max_words)) {
    cli::cli_bullets(c(
      "*" = "Max words: {.val {x$metadata$formatting$max_words}}"
    ))
  }

  if (!is.null(x$metadata$n_variables)) {
    cli::cli_bullets(c(
      "*" = "Variables labeled: {.val {x$metadata$n_variables}}"
    ))
  }

  if (!is.null(x$metadata$llm_provider)) {
    cli::cli_bullets(c(
      "*" = "LLM provider: {.field {x$metadata$llm_provider}}"
    ))
  }

  if (!is.null(x$metadata$llm_model)) {
    cli::cli_bullets(c(
      "*" = "Model: {.field {x$metadata$llm_model}}"
    ))
  }

  # Token usage (second section)
  if (!is.null(x$metadata$tokens_used)) {
    tokens <- x$metadata$tokens_used
    cli::cli_text("")
    cli::cli_h2("Token Usage")
    cli::cli_bullets(c(
      "*" = "Input: {.val {tokens$input}}",
      "*" = "Output: {.val {tokens$output}}",
      "*" = "Total: {.val {tokens$total}}"
    ))
  }

  # Formatting settings (third section)
  if (!is.null(x$metadata$formatting)) {
    fmt <- x$metadata$formatting
    cli::cli_text("")
    cli::cli_h2("Formatting Applied")

    format_details <- character()

    if (!is.null(fmt$case) && fmt$case != "original") {
      format_details <- c(format_details, paste0("Case: ", fmt$case))
    }

    if (!is.null(fmt$sep) && fmt$sep != " ") {
      sep_display <- if (fmt$sep == "") "none" else fmt$sep
      format_details <- c(format_details, paste0("Separator: '", sep_display, "'"))
    }

    if (!is.null(fmt$remove_articles) && fmt$remove_articles) {
      format_details <- c(format_details, "Articles removed")
    }

    if (!is.null(fmt$remove_prepositions) && fmt$remove_prepositions) {
      format_details <- c(format_details, "Prepositions removed")
    }

    if (!is.null(fmt$abbreviate) && fmt$abbreviate) {
      format_details <- c(format_details, "Abbreviation enabled")
    }

    # max_words moved to Labeling Details section (it's an LLM instruction, not formatting)

    if (!is.null(fmt$max_chars)) {
      format_details <- c(format_details, paste0("Max chars: ", fmt$max_chars))
    }

    if (length(format_details) > 0) {
      for (detail in format_details) {
        cli::cli_bullets(c("*" = detail))
      }
    } else {
      cli::cli_text("{.emph No special formatting applied}")
    }
  }

  # Generated labels
  cli::cli_text("")
  cli::cli_h2("Generated Labels")
  cli::cli_text("")

  # Format as aligned columns
  max_var_width <- max(nchar(x$labels_formatted$variable))
  max_label_width <- max(nchar(x$labels_formatted$label))

  # Header
  cli::cli_text(
    "{.strong {format('Variable', width = max_var_width)}}  {.strong Label}"
  )
  cli::cli_text(
    "{strrep('-', max_var_width)}  {strrep('-', max_label_width)}"
  )

  # Labels
  for (i in seq_len(nrow(x$labels_formatted))) {
    var_padded <- format(x$labels_formatted$variable[i], width = max_var_width)
    cli::cli_text("{.field {var_padded}}  {x$labels_formatted$label[i]}")
  }

  # Footer
  if (!is.null(x$metadata$reformatted) && x$metadata$reformatted) {
    cli::cli_text("")
    cli::cli_alert_info("Labels were reformatted from original LLM output")
  }

  cli::cli_text("")
  cli::cli_rule()

  invisible(x)
}

#' Reformat Variable Labels
#'
#' Apply new formatting to existing variable labels without calling the LLM again.
#' This allows you to experiment with different formatting options efficiently.
#'
#' **Note on max_words/max_chars:** When used here, these parameters only perform
#' post-processing truncation (cutting existing labels). For better results, use
#' \code{max_words} and \code{max_chars} in \code{\link{label_variables}()} to
#' guide the LLM to generate appropriately-sized labels from the start.
#'
#' @param labels variable_labels object from label_variables()
#' @param sep Character. New separator between words
#' @param case Character. New case transformation
#' @param remove_articles Logical. Remove articles (a, an, the)
#' @param remove_prepositions Logical. Remove prepositions (of, in, at, etc.)
#' @param max_chars Integer or NULL. Maximum character length (post-processing truncation).
#'   For better results, use in \code{label_variables()} instead to guide LLM.
#' @param abbreviate Logical. Apply rule-based abbreviation to long words
#' @param max_words Integer or NULL. Maximum word count (post-processing truncation).
#'   For better results, use in \code{label_variables()} instead to guide LLM.
#' @param label_args label_args object. Configuration (direct params take precedence)
#'
#' @return Updated variable_labels object with new formatting
#'
#' @examples
#' \dontrun{
#' # Generate labels once
#' labels <- label_variables(variable_info, llm_provider = "ollama")
#'
#' # Try different formats without calling LLM again
#' labels_snake <- reformat_labels(labels, case = "snake")
#' labels_camel <- reformat_labels(labels, case = "camel")
#' labels_abbrev <- reformat_labels(labels, abbreviate = TRUE, max_words = 2)
#' }
#'
#' @export
reformat_labels <- function(labels,
                           sep = " ",
                           case = "original",
                           remove_articles = FALSE,
                           remove_prepositions = FALSE,
                           max_chars = NULL,
                           abbreviate = FALSE,
                           max_words = NULL,
                           label_args = NULL) {

  # Validate input
  if (!inherits(labels, "variable_labels")) {
    cli::cli_abort("{.var labels} must be a variable_labels object")
  }

  if (is.null(labels$labels_parsed)) {
    cli::cli_abort("Cannot reformat: no parsed labels stored in object")
  }

  # Validate labels_parsed structure
  if (!is.data.frame(labels$labels_parsed)) {
    cli::cli_abort("Cannot reformat: labels_parsed must be a data.frame")
  }

  # Extract parameters from label_args if provided (direct params take precedence)
  if (!is.null(label_args)) {
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
    if (is.null(max_words) && !is.null(label_args$max_words)) {
      max_words <- label_args$max_words
    }
  }

  # Get unformatted labels from labels_parsed (now a data.frame)
  unformatted_labels <- labels$labels_parsed$label

  # Apply new formatting
  formatted_labels <- sapply(unformatted_labels, function(label) {
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

  # Create new labels data frame
  new_labels_df <- data.frame(
    variable = labels$labels_parsed$variable,
    label = formatted_labels,
    stringsAsFactors = FALSE
  )

  # Update metadata with new formatting settings
  new_metadata <- labels$metadata
  new_metadata$formatting <- list(
    sep = sep,
    case = case,
    remove_articles = remove_articles,
    remove_prepositions = remove_prepositions,
    max_chars = max_chars,
    abbreviate = abbreviate,
    max_words = max_words
  )
  new_metadata$reformatted <- TRUE
  new_metadata$reformat_time <- Sys.time()

  # Create updated object
  result <- create_variable_labels(
    labels_df = new_labels_df,
    variable_info = labels$variable_info,
    llm_response = labels$llm_response,
    parsed_labels = labels$labels_parsed,
    metadata = new_metadata,
    chat_session = labels$chat_session
  )

  return(result)
}

# Export functions moved to label_export.R