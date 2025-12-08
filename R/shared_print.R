#' Print Utilities for Consistent Visual Output
#'
#' Shared formatting functions for print methods across the package.
#' These utilities always use CLI styling for interactive console output.
#'
#' @name shared_print
#' @keywords internal
NULL

# Constants
.PRINT_WIDTH_COMPACT <- 40
.PRINT_INDENT <- 2

#' Create compact header for config/session objects
#' @param title Header title text
#' @param width Width of the underline rule
#' @keywords internal
print_header <- function(title, width = .PRINT_WIDTH_COMPACT) {
  paste0(
    cli::col_cyan(cli::style_bold(title)), "\n",
    cli::rule(line = 1, line_col = "grey", width = width), "\n"
  )
}

#' Create key-value line
#' @param key The label/key
#' @param value The value to display
#' @param indent Number of spaces to indent
#' @keywords internal
print_kv <- function(key, value, indent = .PRINT_INDENT) {
  spaces <- strrep(" ", indent)
  paste0(spaces, cli::style_bold(paste0(key, ":")), " ", value, "\n")
}

#' Create section header (no underline)
#' @param title Section title
#' @param indent Number of spaces to indent
#' @keywords internal
print_section <- function(title, indent = 0) {
  spaces <- strrep(" ", indent)
  paste0("\n", spaces, cli::col_cyan(title), "\n")
}

#' Create bullet item
#' @param text Item text
#' @param indent Number of spaces to indent
#' @keywords internal
print_item <- function(text, indent = .PRINT_INDENT) {
  spaces <- strrep(" ", indent)
  paste0(spaces, cli::symbol$bullet, " ", text, "\n")
}
