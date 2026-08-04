# ==============================================================================
# CALL PARAMETER RESOLUTION
# ==============================================================================
# Every interpretation parameter can arrive by two routes: as a direct argument
# (`word_limit = 250`) or inside a config object (`llm_args(word_limit = 250)`).
# Precedence is: direct argument > config object > registry default.
#
# The previous implementation decided "did the caller supply this?" by testing
# `is.null(x)`. That is only ever TRUE for a parameter whose default is NULL, so
# it silently ignored every config field backed by a non-NULL default -
# output_args was inert in its entirety - and it could not distinguish
# "not supplied" from "supplied as NULL". Where the default was not NULL the
# code fell back to comparing against the default value itself
# (`verbosity == 2`), which inverted precedence: a caller who explicitly asked
# for the default was overridden by the config object.
#
# The reliable test is which names appear in `match.call()`. Resolution happens
# once, up front, before any parameter is reassigned.
# ==============================================================================

#' Collect the values of arguments the caller actually supplied
#'
#' @param param_names Character vector of formal argument names to inspect.
#' @param supplied_names Argument names from the caller's `match.call()`.
#' @param env The function frame holding the values; defaults to the caller.
#'
#' @return A named list of the supplied values. Arguments left at their default
#'   are absent from the list; an argument explicitly supplied as `NULL` is
#'   present with a `NULL` value.
#'
#' @keywords internal
collect_supplied <- function(param_names, supplied_names, env = parent.frame()) {
  supplied <- list()
  for (param in intersect(param_names, supplied_names)) {
    # Single-bracket assignment with list() so that a NULL value is STORED
    # rather than deleting the element, which `[[<-` would do.
    supplied[param] <- list(get(param, envir = env))
  }
  supplied
}

#' Resolve parameters across direct arguments, a config object, and defaults
#'
#' @param supplied Named list of directly supplied arguments, from
#'   [collect_supplied()].
#' @param config A config object (`llm_args`, `output_args`) or plain list, or
#'   `NULL`.
#' @param defaults Named list giving the full set of parameters to resolve and
#'   their fallback values. Keys absent from `defaults` are ignored, so an
#'   unrelated config field can never be injected into the call.
#'
#' @return A named list with exactly the names of `defaults`.
#'
#' @keywords internal
resolve_call_params <- function(supplied, config, defaults) {
  resolved <- defaults

  for (param in names(defaults)) {
    if (!is.null(config) && param %in% names(config)) {
      resolved[param] <- list(config[[param]])
    }
  }

  for (param in names(defaults)) {
    if (param %in% names(supplied)) {
      resolved[param] <- list(supplied[[param]])
    }
  }

  resolved
}
