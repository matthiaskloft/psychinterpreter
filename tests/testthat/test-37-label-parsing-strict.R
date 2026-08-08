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

test_that("a bracket in prose before the JSON does not hijack extraction", {
  # The scanner must not simply anchor on the first "{" or "[": LLM prose
  # routinely contains brackets, and "[3]" is itself valid JSON, so a parse
  # check alone would accept it in place of the real payload.
  resp <- paste0("Here is my interpretation. Note that item [3] loads ",
                 'negatively.\n{"MR1":{"name":"Anxiety","interpretation":"High."}}')
  parsed <- try_parse_json(clean_json_response(resp))
  expect_equal(parsed$MR1$name, "Anxiety")
})

test_that("set notation in prose before an array does not hijack extraction", {
  resp <- 'The item set {Q1, Q2} is key.\n[{"variable":"v1","label":"Tiredness"}]'
  parsed <- try_parse_json(clean_json_response(resp))
  expect_equal(parsed[[1]]$label, "Tiredness")
})

test_that("a multi-element character response is joined, not truncated", {
  parsed <- try_parse_json(
    clean_json_response(c('[{"variable":"v1",', '"label":"Tiredness"}]'))
  )
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
  # *inside* valid string values - corrupting the text before it was parsed.
  # This asserts the parser contract only. It is NOT observable through
  # label_variables(), because format_label() word-splits and rejoins every
  # label; see test-32-offline-fixture.R for the end-to-end case on the
  # interpretation path, where prose is passed through unmodified.
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

test_that("parsed records are reordered to variable_info order", {
  # Records were returned in whatever order the LLM chose. This must be
  # asserted on the parser: label_variables() masks it, because when tier 1
  # rejects a response the fallback rebuilds records by iterating
  # variable_info, which restores the order by accident.
  info <- label_info_2()
  parsed <- parse_label_response(
    '[{"variable":"v2","label":"Alertness"},{"variable":"v1","label":"Tiredness"}]',
    info
  )
  expect_equal(attr(parsed, "parse_status"), "parsed")
  expect_equal(vapply(parsed, function(x) x$variable, character(1)), c("v1", "v2"))
  expect_equal(vapply(parsed, function(x) x$label, character(1)),
               c("Tiredness", "Alertness"))
})

test_that("a reordered response labels each variable correctly end to end", {
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
  # It must get there by parsing, not by degrading into the fallback.
  expect_equal(res$metadata$parse_status, "parsed")
})

# ------------------------- valid JSON is recovered structurally, never scraped

test_that("a scalar non-string label is coerced rather than scraped", {
  # Regression: tier 1 rejected label = 5 as "not a string", the response then
  # went to the prose scraper, and pattern 4 matched across the record boundary
  # and returned the KEY name -- so v1's label became the literal "variable".
  info <- label_info_2()
  parsed <- parse_label_response(
    '[{"variable":"v1","label":5},{"variable":"v2","label":"B"}]', info)
  expect_equal(attr(parsed, "parse_status"), "parsed")
  expect_equal(vapply(parsed, function(x) x$label, character(1)), c("5", "B"))
})

test_that("an object keyed by variable name is recovered", {
  info <- label_info_2()
  parsed <- parse_label_response('{"v1":"Tiredness","v2":"Alertness"}', info)
  expect_equal(attr(parsed, "parse_status"), "parsed")
  expect_equal(vapply(parsed, function(x) x$label, character(1)),
               c("Tiredness", "Alertness"))
})

test_that("an array wrapped in a single key is recovered", {
  info <- label_info_2()
  parsed <- parse_label_response(
    '{"labels":[{"variable":"v1","label":"Tiredness"},
                {"variable":"v2","label":"Alertness"}]}', info)
  expect_equal(attr(parsed, "parse_status"), "parsed")
  expect_equal(vapply(parsed, function(x) x$variable, character(1)), c("v1", "v2"))
})

test_that("unrecoverable JSON goes to defaults, never to the prose scraper", {
  # Scraping structural JSON text yields key names and punctuation as labels.
  info <- label_info_2()
  parsed <- suppressWarnings(
    parse_label_response('{"unexpected":{"totally":"different"}}', info))
  expect_equal(attr(parsed, "parse_status"), "default_fallback")
  labels <- vapply(parsed, function(x) x$label, character(1))
  expect_false(any(labels %in% c("variable", "label", "unexpected", "totally")))
})

test_that("prose is still scraped, because it never parsed as JSON", {
  info <- label_info_2()
  parsed <- suppressWarnings(
    parse_label_response('v1 = "Tiredness"\nv2 = "Alertness"', info))
  expect_equal(attr(parsed, "parse_status"), "pattern_extracted")
  expect_equal(vapply(parsed, function(x) x$label, character(1)),
               c("Tiredness", "Alertness"))
})

# --------------------------------------- F-11: degraded results are announced

test_that("pattern extraction warns", {
  # Previously silent: a user given regex-scraped labels saw nothing at all.
  info <- label_info_2()
  expect_warning(
    parse_label_response('v1 = "Tiredness"\nv2 = "Alertness"', info),
    "pattern"
  )
})

test_that("print() reports a degraded parse and stays quiet on a clean one", {
  info <- label_info_2()

  clean <- fake_chat_session("label", response = fake_label_response(info$variable))
  res_clean <- label_variables(variable_info = info, chat_session = clean, verbosity = 0)
  expect_no_match(paste(capture.output(print(res_clean)), collapse = "\n"),
                  "Parsing")

  degraded <- fake_chat_session("label", response = 'v1 = "A"\nv2 = "B"')
  res_degraded <- suppressWarnings(
    label_variables(variable_info = info, chat_session = degraded, verbosity = 0))
  expect_match(paste(capture.output(print(res_degraded)), collapse = "\n"),
               "pattern_extracted")
})

# ------------------------------ duplicate variable names are rejected up front

test_that("duplicate variable names are rejected before any LLM call", {
  # With duplicates, no response can satisfy validate_label_structure() at
  # once: anyDuplicated() rejects a record per row, and setequal() rejects one
  # record for both. Tier 1 was therefore unreachable, and the fallback then
  # assigned the SAME label to every duplicated row. Failing up front is
  # honest; silently mislabelling is not.
  info <- data.frame(
    variable = c("v1", "v1"),
    description = c("how often the respondent feels tired",
                    "how often the respondent feels alert"),
    stringsAsFactors = FALSE
  )
  session <- fake_chat_session("label", response = fake_label_response(c("v1", "v1")))
  expect_error(
    label_variables(variable_info = info, chat_session = session, verbosity = 0),
    "duplicate"
  )
  expect_equal(fake_call_count(session), 0L)
})

test_that("auto-generated variable names are never duplicated", {
  # The V1..Vn fallback path must not trip the new check.
  info <- data.frame(
    description = c("how often the respondent feels tired",
                    "how often the respondent feels alert"),
    stringsAsFactors = FALSE
  )
  session <- fake_chat_session("label", response = fake_label_response(c("V1", "V2")))
  expect_no_error(
    label_variables(variable_info = info, chat_session = session, verbosity = 0)
  )
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
  res <- suppressWarnings(
    label_variables(variable_info = info, chat_session = session, verbosity = 0))
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
#
# Defence in depth, not a reproduced bug: no LLM response is currently known to
# reach label_records_to_df() with a field missing, because the parse tiers
# above guarantee complete records. These assert the guarantee is not silently
# lost if that ever changes, so they exercise the helper directly.

test_that("a record missing its label yields a character column, not a list", {
  info <- label_info_2()
  df <- label_records_to_df(
    list(list(variable = "v1", label = "Tiredness"), list(variable = "v2")),
    info
  )
  expect_type(df$label, "character")
  expect_equal(df$variable, c("v1", "v2"))
  # The gap is filled from the description we already hold.
  expect_true(nzchar(df$label[2]))
  expect_false(is.na(df$label[2]))
})

test_that("a record with a non-scalar label does not become a list-column", {
  info <- label_info_2()
  df <- label_records_to_df(
    list(list(variable = "v1", label = c("A", "B")),
         list(variable = "v2", label = "Alertness")),
    info
  )
  expect_type(df$label, "character")
  expect_length(df$label, 2)
})

test_that("well-formed records are passed through unchanged", {
  info <- label_info_2()
  df <- label_records_to_df(
    list(list(variable = "v1", label = "Tiredness"),
         list(variable = "v2", label = "Alertness")),
    info
  )
  expect_equal(df$label, c("Tiredness", "Alertness"))
})
