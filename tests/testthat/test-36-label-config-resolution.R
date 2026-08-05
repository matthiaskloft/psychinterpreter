# ==============================================================================
# TEST: Config resolution in label_variables() (F-06, second call site)
# ==============================================================================
# Purpose: label_variables() documents "Direct parameters take precedence" for
#          all three config objects, but decided "was this supplied?" by
#          comparing against the default value (`label_type == "short"`,
#          `echo == "none"`, `verbosity == 2`). A caller who explicitly asked
#          for the default was therefore overridden by the config object - the
#          precedence was inverted, not merely ignored. llm_args was also
#          consulted for `echo` alone.
# Ref:     dev/CODE_REVIEW_CONSOLIDATED_2026-07-25.md (F-06)
# ==============================================================================

fixture_label_info <- function() {
  data.frame(
    variable = c("v1", "v2"),
    description = c("how often the respondent feels tired",
                    "how often the respondent feels alert"),
    stringsAsFactors = FALSE
  )
}

label_session <- function(labels = NULL) {
  info <- fixture_label_info()
  fake_chat_session(
    "label",
    response = fake_label_response(info$variable, labels)
  )
}

run_labels <- function(..., labels = NULL) {
  session <- label_session(labels)
  result <- label_variables(
    variable_info = fixture_label_info(), chat_session = session, ...
  )
  list(result = result, prompt = fake_prompts(session)[[1]],
       echo = fake_echos(session)[[1]], session = session)
}

# ------------------------------------------------------------- label_args

test_that("a directly supplied label_type beats label_args", {
  # The regression: `label_type == "short"` was used as the not-supplied test,
  # so explicitly asking for "short" handed control to the config object.
  res <- run_labels(label_type = "short", label_args = list(label_type = "acronym"),
                    verbosity = 0)
  expect_equal(res$result$metadata$label_type, "short")
})

test_that("label_args still applies when the caller says nothing", {
  res <- run_labels(label_args = list(label_type = "acronym"), verbosity = 0)
  expect_equal(res$result$metadata$label_type, "acronym")
})

test_that("a directly supplied formatting argument beats label_args", {
  # `case` used `case == "original"` as its not-supplied test, and the boolean
  # flags used `!remove_articles` - same inversion, different types.
  direct <- run_labels(
    case = "original", label_args = list(case = "upper"), verbosity = 0
  )
  expect_equal(direct$result$labels_formatted$label,
               c("Fake Label 1", "Fake Label 2"))
  expect_equal(direct$result$metadata$formatting$case, "original")

  from_config <- run_labels(label_args = list(case = "upper"), verbosity = 0)
  expect_equal(from_config$result$labels_formatted$label,
               c("FAKE LABEL 1", "FAKE LABEL 2"))
})

test_that("a directly supplied FALSE beats a config TRUE", {
  # `!remove_articles` means supplying FALSE explicitly looks identical to not
  # supplying it, so the config value won.
  session <- label_session(labels = c("the tired scale", "the alert scale"))
  result <- label_variables(
    variable_info = fixture_label_info(), chat_session = session,
    remove_articles = FALSE, label_args = list(remove_articles = TRUE),
    verbosity = 0
  )
  expect_true(all(grepl("^the ", result$labels_formatted$label)))
  expect_false(result$metadata$formatting$remove_articles)
})

# ---------------------------------------------------------------- llm_args

test_that("llm_args$echo no longer overrides an explicit echo", {
  # echo is not recorded in the result, so assert on what actually reached
  # chat$chat() - the fixture records it.
  res <- run_labels(echo = "none",
                    llm_args = list(llm_provider = "ollama", echo = "all"),
                    verbosity = 0)
  expect_equal(res$echo, "none")
})

test_that("llm_args$echo still applies when the caller says nothing", {
  res <- run_labels(llm_args = list(llm_provider = "ollama", echo = "all"),
                    verbosity = 0)
  expect_equal(res$echo, "all")
})

test_that("llm_args supplies llm_provider when no chat_session is given", {
  # llm_provider/llm_model were dropped entirely, so a caller who configured
  # them through llm_args() - the object that exists to carry them - was told
  # the provider was missing. An unknown provider fails during initialisation
  # without any network call, which is what distinguishes the two errors.
  info <- fixture_label_info()

  expect_error(
    label_variables(variable_info = info, verbosity = 0),
    "must be specified"
  )
  expect_error(
    label_variables(
      variable_info = info,
      llm_args = list(llm_provider = "not_a_provider"), verbosity = 0
    ),
    "Failed to initialize"
  )
})

# -------------------------------------------------------------- output_args

test_that("an explicit verbosity beats output_args", {
  # `verbosity == 2` as the not-supplied test meant asking for 2 explicitly
  # handed control to output_args. Verbosity 2 prints; 0 is silent.
  expect_silent(
    run_labels(verbosity = 0, output_args = list(verbosity = 2))
  )
})

test_that("output_args$verbosity still applies when the caller says nothing", {
  expect_silent(run_labels(output_args = list(verbosity = 0)))
})

# ------------------------------------------------------------------ metadata

test_that("labels are still produced correctly through the resolved path", {
  # Guards against the resolution rewrite quietly dropping a parameter.
  res <- run_labels(verbosity = 0)
  expect_s3_class(res$result, "variable_labels")
  expect_equal(nrow(res$result$labels_formatted), 2)
  expect_equal(res$result$labels_formatted$variable, c("v1", "v2"))
})
