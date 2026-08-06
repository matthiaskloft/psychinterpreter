# ==============================================================================
# TEST: Strict label parsing and session typing (F-07, F-08, F-11, F-18)
# ==============================================================================
# Purpose: The label prompt asks the LLM for a top-level JSON *array*, but
#          clean_json_response() sliced from the first "{" to the last "}",
#          stripping the enclosing brackets. A correctly-formatted response
#          therefore always failed the primary parser and degraded to a regex
#          tier that interpolates variable names as raw regular expressions -
#          so "a.b" matched the unrelated text "axb" and produced a
#          confidently wrong label. Nothing on the result distinguished a
#          parsed result from a fabricated one.
# Ref:     dev/CODE_REVIEW_CONSOLIDATED_2026-07-25.md (F-07, F-08, F-11, F-18)
# ==============================================================================

label_info_2 <- function() {
  data.frame(
    variable = c("v1", "v2"),
    description = c("how often the respondent feels tired",
                    "how often the respondent feels alert"),
    stringsAsFactors = FALSE
  )
}

# ------------------------------------------------------- F-07a: array survives

test_that("a top-level JSON array survives cleaning and parses", {
  # The core defect: the brackets the prompt itself requires were stripped.
  arr <- '[{"variable":"v1","label":"Job Satisfaction"},
           {"variable":"v2","label":"Work Balance"}]'
  cleaned <- clean_json_response(arr)
  expect_true(startsWith(cleaned, "["))
  expect_true(endsWith(cleaned, "]"))

  parsed <- try_parse_json(cleaned)
  expect_type(parsed, "list")
  expect_length(parsed, 2)
  expect_equal(parsed[[1]]$label, "Job Satisfaction")
})

test_that("a JSON object still survives cleaning and parses", {
  # The array fix must not regress the object path used by every interpret_*().
  obj <- '{"MR1": {"name": "A", "interpretation": "B"}}'
  parsed <- try_parse_json(clean_json_response(obj))
  expect_equal(parsed$MR1$name, "A")
})

test_that("JSON embedded in prose is still located", {
  wrapped <- 'Sure! Here you go:\n[{"variable":"v1","label":"Tiredness"}]\nHope that helps.'
  parsed <- try_parse_json(clean_json_response(wrapped))
  expect_equal(parsed[[1]]$label, "Tiredness")
})

test_that("a fenced code block is unwrapped", {
  fenced <- '```json\n[{"variable":"v1","label":"Tiredness"}]\n```'
  parsed <- try_parse_json(clean_json_response(fenced))
  expect_equal(parsed[[1]]$label, "Tiredness")
})

# --------------------------------------------- F-07b: string values unmangled

test_that("whitespace inside JSON string values is preserved", {
  # gsub("\\s+", " ", cleaned) ran unconditionally, collapsing runs of spaces
  # *inside* valid string values - corrupting the label before it was parsed.
  obj <- '[{"variable":"v1","label":"Self  Reported   Tiredness"}]'
  parsed <- try_parse_json(clean_json_response(obj))
  expect_equal(parsed[[1]]$label, "Self  Reported   Tiredness")
})

# ------------------------------------------ F-07c: identifiers are not regexes

test_that("a variable name containing a regex metacharacter is escaped", {
  # "a.b" is an ordinary R name. Unescaped, "." matched any character, so the
  # fallback happily claimed the unrelated text "axb".
  info <- data.frame(variable = "a.b", description = "some description",
                     stringsAsFactors = FALSE)
  out <- extract_labels_fallback('axb = "Wrong Match"', info)
  labels <- vapply(out, function(x) x$label, character(1))
  expect_false("Wrong Match" %in% labels)
})

test_that("a variable name that is not a valid regex does not error", {
  # "x[1" made regcomp() abort with 'Unknown collating element'.
  info <- data.frame(variable = "x[1", description = "some description",
                     stringsAsFactors = FALSE)
  expect_no_error(extract_labels_fallback('x[1: "Anxiety"', info))
})

test_that("the fallback still extracts a genuine match", {
  info <- data.frame(variable = "v1", description = "some description",
                     stringsAsFactors = FALSE)
  out <- extract_labels_fallback('"v1": "Tiredness"', info)
  expect_equal(out[[1]]$label, "Tiredness")
})

# ------------------------------------------------- F-07d: strict label schema

test_that("duplicate variables are rejected", {
  parsed <- list(list(variable = "v1", label = "A"),
                 list(variable = "v1", label = "B"),
                 list(variable = "v2", label = "C"))
  expect_false(validate_label_structure(parsed, label_info_2()))
})

test_that("an extra variable is rejected", {
  parsed <- list(list(variable = "v1", label = "A"),
                 list(variable = "v2", label = "B"),
                 list(variable = "v9", label = "Extra"))
  expect_false(validate_label_structure(parsed, label_info_2()))
})

test_that("a blank label is rejected", {
  parsed <- list(list(variable = "v1", label = ""),
                 list(variable = "v2", label = "B"))
  expect_false(validate_label_structure(parsed, label_info_2()))
})

test_that("a non-scalar label is rejected", {
  parsed <- list(list(variable = "v1", label = list("A", "B")),
                 list(variable = "v2", label = "C"))
  expect_false(validate_label_structure(parsed, label_info_2()))
})

test_that("an exact, well-formed set is accepted", {
  parsed <- list(list(variable = "v1", label = "A"),
                 list(variable = "v2", label = "B"))
  expect_true(validate_label_structure(parsed, label_info_2()))
})

test_that("labels are returned in variable_info order, not LLM order", {
  # Output was assembled in whatever order the LLM chose, so a reordered
  # response silently attached each label to the wrong variable downstream.
  info <- label_info_2()
  session <- fake_chat_session(
    "label",
    response = '[{"variable":"v2","label":"Alertness"},
                 {"variable":"v1","label":"Tiredness"}]'
  )
  res <- label_variables(variable_info = info, chat_session = session,
                         case = "original", verbosity = 0)
  expect_equal(res$labels_formatted$variable, c("v1", "v2"))
  expect_equal(res$labels_formatted$label, c("Tiredness", "Alertness"))
})

# ------------------------------------------------------ F-08: session typing

test_that("a chat session for the wrong analysis type is rejected", {
  info <- label_info_2()
  for (wrong in c("fa", "gm", "irt", "cdm")) {
    session <- fake_chat_session(wrong, response = fake_label_response(info$variable))
    expect_error(
      label_variables(variable_info = info, chat_session = session, verbosity = 0),
      class = "rlang_error"
    )
    # Nothing may be sent to the provider before the type check fires.
    expect_equal(fake_call_count(session), 0L)
  }
})

test_that("a label chat session is accepted", {
  info <- label_info_2()
  session <- fake_chat_session("label", response = fake_label_response(info$variable))
  expect_no_error(
    label_variables(variable_info = info, chat_session = session, verbosity = 0)
  )
  expect_equal(fake_call_count(session), 1L)
})

# ------------------------------------------------- F-11: parse observability

test_that("a clean response is reported as parsed", {
  info <- label_info_2()
  session <- fake_chat_session("label", response = fake_label_response(info$variable))
  res <- label_variables(variable_info = info, chat_session = session, verbosity = 0)
  expect_equal(res$metadata$parse_status, "parsed")
  expect_null(res$metadata$parse_error)
})

test_that("a response needing pattern extraction is reported as such", {
  info <- label_info_2()
  session <- fake_chat_session(
    "label",
    response = 'v1 = "Tiredness"\nv2 = "Alertness"'
  )
  res <- label_variables(variable_info = info, chat_session = session, verbosity = 0)
  expect_equal(res$metadata$parse_status, "pattern_extracted")
})

test_that("an unparseable response is reported as a fallback, with the reason", {
  info <- label_info_2()
  session <- fake_chat_session("label", response = "I'm sorry, I cannot help with that.")
  res <- suppressWarnings(
    label_variables(variable_info = info, chat_session = session, verbosity = 0)
  )
  expect_equal(res$metadata$parse_status, "default_fallback")
  # The jsonlite reason was discarded entirely, so a degraded result was
  # indistinguishable from a real one at any verbosity.
  expect_type(res$metadata$parse_error, "character")
  expect_gt(nchar(res$metadata$parse_error), 0)
})

# ------------------------------------------------------- F-18: type stability

test_that("a malformed record does not produce a list-column", {
  # sapply() over records missing `label` returned a list, silently making
  # labels_df$label a list-column instead of failing.
  info <- label_info_2()
  session <- fake_chat_session(
    "label",
    response = '[{"variable":"v1","label":"Tiredness"},{"variable":"v2"}]'
  )
  res <- suppressWarnings(
    label_variables(variable_info = info, chat_session = session, verbosity = 0)
  )
  expect_type(res$labels_formatted$label, "character")
  expect_length(res$labels_formatted$label, 2)
})
