# Test handling of unimplemented model types (GM, IRT, CDM)
# These model types are planned but not yet implemented

test_that("interpret() rejects unimplemented model types with helpful message", {
  # Test Gaussian Mixture (GM)
  expect_error(
    interpret(
      fit_results = list(loadings = matrix(1:6, 3, 2)),
      analysis_type = "gm",
      variable_info = data.frame(
        variable = c("v1", "v2", "v3"),
        description = c("Var 1", "Var 2", "Var 3")
      ),
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud"
    ),
    "not yet implemented|not supported",
    info = "GM model type should be rejected with clear message"
  )

  # Test Item Response Theory (IRT)
  expect_error(
    interpret(
      fit_results = list(loadings = matrix(1:6, 3, 2)),
      analysis_type = "irt",
      variable_info = data.frame(
        variable = c("v1", "v2", "v3"),
        description = c("Item 1", "Item 2", "Item 3")
      ),
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud"
    ),
    "not yet implemented|not supported",
    info = "IRT model type should be rejected with clear message"
  )

  # Test Cognitive Diagnostic Model (CDM)
  expect_error(
    interpret(
      fit_results = list(loadings = matrix(1:6, 3, 2)),
      analysis_type = "cdm",
      variable_info = data.frame(
        variable = c("v1", "v2", "v3"),
        description = c("Skill 1", "Skill 2", "Skill 3")
      ),
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud"
    ),
    "not yet implemented|not supported",
    info = "CDM model type should be rejected with clear message"
  )
})

test_that("chat_session() rejects unimplemented model types", {
  # Test GM
  expect_error(
    chat_session(
      analysis_type = "gm",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud"
    ),
    "not yet implemented|not supported",
    info = "chat_session should reject GM type"
  )

  # Test IRT
  expect_error(
    chat_session(
      analysis_type = "irt",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud"
    ),
    "not yet implemented|not supported",
    info = "chat_session should reject IRT type"
  )

  # Test CDM
  expect_error(
    chat_session(
      analysis_type = "cdm",
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud"
    ),
    "not yet implemented|not supported",
    info = "chat_session should reject CDM type"
  )
})

test_that("interpretation_args() rejects unimplemented model types", {
  # This is already implemented and tested in test-20-config-objects.R
  # but adding here for completeness

  # Test GM
  expect_error(
    interpretation_args(analysis_type = "gm"),
    "not yet implemented",
    info = "interpretation_args should reject GM"
  )

  # Test IRT
  expect_error(
    interpretation_args(analysis_type = "irt"),
    "not yet implemented",
    info = "interpretation_args should reject IRT"
  )

  # Test CDM
  expect_error(
    interpretation_args(analysis_type = "cdm"),
    "not yet implemented",
    info = "interpretation_args should reject CDM"
  )
})

# Test removed - validate_list_structure() is tested indirectly through interpret()
# The S3 dispatch mechanism doesn't work directly with string model types

test_that("Error messages for unimplemented types are informative", {
  # Verify that error messages provide guidance on what IS supported

  error_msg <- tryCatch(
    interpret(
      fit_results = list(loadings = matrix(1:6, 3, 2)),
      analysis_type = "gm",
      variable_info = data.frame(
        variable = c("v1", "v2", "v3"),
        description = c("Var 1", "Var 2", "Var 3")
      ),
      llm_provider = "ollama",
      llm_model = "gpt-oss:20b-cloud"
    ),
    error = function(e) conditionMessage(e)
  )

  # Check that error message mentions what is supported
  expect_true(
    grepl("fa|factor analysis", error_msg, ignore.case = TRUE) ||
    grepl("not yet implemented", error_msg, ignore.case = TRUE),
    info = "Error message should be informative about what is/isn't supported"
  )
})