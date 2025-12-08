#' Create Labeling Arguments Configuration
#'
#' Create a configuration object for variable labeling parameters.
#' This follows the same pattern as interpretation_args() for other model types.
#'
#' @param label_type Character. Type of labels: "short" (1-3 words), "phrase" (4-7 words),
#'   "acronym" (3-5 chars), or "custom" (default = "short")
#' @param max_words Integer or NULL. Exact word count (overrides label_type preset)
#' @param style_hint Character or NULL. Style guidance for LLM (e.g., "technical", "simple")
#' @param sep Character. Separator between words in final output (default = " ")
#' @param case Character. Case transformation: "original", "lower", "upper", "title",
#'   "sentence", "snake", "camel", "constant" (default = "original")
#' @param remove_articles Logical. Remove articles (a, an, the) from labels (default = FALSE)
#' @param remove_prepositions Logical. Remove prepositions (of, in, at, etc.) (default = FALSE)
#' @param max_chars Integer or NULL. Maximum character length for labels. Has dual purpose:
#'   when `label_type = "acronym"`, sets maximum acronym length (minimum fixed at 3 chars);
#'   for all label types, applies post-processing truncation if label exceeds this length
#' @param abbreviate Logical. Apply rule-based abbreviation to long words (default = FALSE)
#'
#' @return A label_args object (list with class attribute)
#'
#' @examples
#' \dontrun{
#' # Create configuration for snake case labels
#' config <- label_args(
#'   label_type = "short",
#'   case = "snake",
#'   remove_articles = TRUE
#' )
#'
#' # Use with label_variables
#' labels <- label_variables(
#'   variable_info,
#'   label_args = config,
#'   llm_provider = "ollama"
#' )
#'
#' # Override specific parameters
#' labels <- label_variables(
#'   variable_info,
#'   label_args = config,
#'   max_words = 2,  # This overrides the config
#'   llm_provider = "ollama"
#' )
#' }
#'
#' @export
label_args <- function(label_type = "short",
                         max_words = NULL,
                         style_hint = NULL,
                         sep = " ",
                         case = "original",
                         remove_articles = FALSE,
                         remove_prepositions = FALSE,
                         max_chars = NULL,
                         abbreviate = FALSE) {

  # Validate label_type
  valid_types <- c("short", "phrase", "acronym", "custom")
  if (!label_type %in% valid_types) {
    cli::cli_abort(
      c(
        "{.var label_type} must be one of: {.val {valid_types}}",
        "x" = "You supplied: {.val {label_type}}"
      )
    )
  }

  # Validate case
  valid_cases <- c("original", "lower", "upper", "title", "sentence", "snake", "camel", "constant")
  if (!case %in% valid_cases) {
    cli::cli_abort(
      c(
        "{.var case} must be one of: {.val {valid_cases}}",
        "x" = "You supplied: {.val {case}}"
      )
    )
  }

  # Validate max_words if provided
  if (!is.null(max_words)) {
    if (!is.numeric(max_words) || max_words < 1 || max_words > 20) {
      cli::cli_abort(
        "{.var max_words} must be a number between 1 and 20"
      )
    }
  }

  # Validate max_chars if provided
  if (!is.null(max_chars)) {
    if (!is.numeric(max_chars) || max_chars < 1) {
      cli::cli_abort(
        "{.var max_chars} must be a positive number"
      )
    }
  }

  # Create configuration object
  config <- list(
    label_type = label_type,
    max_words = max_words,
    style_hint = style_hint,
    sep = sep,
    case = case,
    remove_articles = remove_articles,
    remove_prepositions = remove_prepositions,
    max_chars = max_chars,
    abbreviate = abbreviate
  )

  class(config) <- c("label_args", "list")
  return(config)
}

#' Print Label Arguments
#'
#' @param x A label_args object
#' @param ... Additional arguments (unused)
#'
#' @export
print.label_args <- function(x, ...) {
  output <- print_header("Label Configuration")

  # Core settings
  output <- paste0(output, print_kv("Label type", x$label_type))
  if (!is.null(x$max_words)) {
    output <- paste0(output, print_kv("Max words", x$max_words))
  }
  if (!is.null(x$style_hint)) {
    output <- paste0(output, print_kv("Style hint", x$style_hint))
  }

  # Formatting section
  output <- paste0(output, print_section("Formatting"))
  output <- paste0(output, print_kv("Separator", x$sep))
  output <- paste0(output, print_kv("Case", x$case))

  # Filters section (only if any active)
  if (x$remove_articles || x$remove_prepositions) {
    output <- paste0(output, print_section("Filters"))
    if (x$remove_articles) {
      output <- paste0(output, print_item("Remove articles"))
    }
    if (x$remove_prepositions) {
      output <- paste0(output, print_item("Remove prepositions"))
    }
  }

  # Length control section (only if any set)
  if (!is.null(x$max_chars) || x$abbreviate) {
    output <- paste0(output, print_section("Length Control"))
    if (!is.null(x$max_chars)) {
      output <- paste0(output, print_kv("Max characters", x$max_chars))
    }
    if (x$abbreviate) {
      output <- paste0(output, print_item("Abbreviate long words"))
    }
  }

  cat(output)
  invisible(x)
}