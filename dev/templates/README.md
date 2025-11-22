# Code Templates for New Model Types

**Purpose**: Ready-to-use templates for implementing new model types in psychinterpreter.

**Last Updated**: 2025-11-22

---

## Need Help?

**New to the package architecture?** Start with these resources:

1. **[`/dev/COMMON_ARCHITECTURE_PATTERNS.md`](../COMMON_ARCHITECTURE_PATTERNS.md)** - **NEW! Start here**
   - Documented patterns from FA and GM implementations
   - Common structures across all model types
   - S3 dispatch patterns and data structures
   - Integration points and checklist

2. **[`/dev/MODEL_IMPLEMENTATION_GUIDE.md`](../MODEL_IMPLEMENTATION_GUIDE.md)** - Detailed guide
   - Step-by-step implementation instructions
   - Common patterns and their rationale
   - Comprehensive troubleshooting guidance
   - Testing strategies and best practices

**Use all resources together**: Patterns for architecture → Templates for code → Guide for details.

---

## Available Templates

| Template File | Purpose | Estimated Lines |
|---------------|---------|-----------------|
| `TEMPLATE_model_data.R` | Extract and validate data from fitted models | ~250-400 |
| `TEMPLATE_prompt_builder.R` | Build LLM system and user prompts | ~200-350 |
| `TEMPLATE_json.R` | Parse and validate LLM JSON responses | ~200-250 |
| `TEMPLATE_diagnostics.R` | Perform model-specific diagnostic checks | ~150-300 |
| `TEMPLATE_report.R` | Format user-facing reports | ~400-800 |
| `TEMPLATE_config_additions.R` | Add configuration object to shared_config.R | ~150-200 |

---

## How to Use These Templates

### Step 1: Define Your Replacements

Create a replacement mapping for your model type:

| Placeholder | Description | Example (Gaussian Mixture) |
|-------------|-------------|----------------------------|
| `{MODEL}` | Full model name (title case) | Gaussian Mixture |
| `{MODEL_FULL_NAME}` | Descriptive name | Gaussian mixture modeling |
| `{model}` | Abbreviation (lowercase) | gm |
| `{CLASS}` | Primary fitted model class | Mclust |
| `{PACKAGE}` | Package name | mclust |
| `{COMPONENT}` | Component name (singular) | Cluster |
| `{COMPONENT_LOWER}` | Component name (lowercase) | cluster |
| `{PARAM1}` | First analysis parameter name | covariance_type |
| `{PARAM2}` | Second analysis parameter name | n_clusters |
| `{DATA_TYPE}` | What the model analyzes | cluster statistics |
| `{DATA_FIELD1}` | First data field name | means |
| `{DATA_FIELD2}` | Second data field name | covariances |

---

⚠️ **IMPORTANT: Parameter Types**

There are THREE types of parameters in psychinterpreter:

1. **Analysis-specific parameters** (go in `interpretation_args`) - Examples:
   - FA: `cutoff`, `n_emergency`, `hide_low_loadings`, `sort_loadings`
   - GM: `covariance_type`, `n_components` (when user-specified)
   - IRT: `model_spec`, `n_factors`
   - **These are what `{PARAM1}` and `{PARAM2}` represent in templates**

2. **LLM settings** (go in `llm_args`) - Always the same:
   - `word_limit`, `llm_provider`, `llm_model`, `additional_info`, `echo`
   - **Do NOT add these to your analysis-specific parameters**

3. **Output settings** (go in `output_args`) - Always the same:
   - `format`, `silent`
   - **Do NOT add these to your analysis-specific parameters**

When using templates, `{PARAM1}` and `{PARAM2}` represent ANALYSIS-SPECIFIC parameters ONLY.
The LLM and output settings are handled separately by the package infrastructure and should not be duplicated in your model implementation.

---

### Step 2: Copy and Replace

For each template file:

1. **Copy to your working directory**:
   ```bash
   cp dev/templates/TEMPLATE_model_data.R R/gm_model_data.R
   ```

2. **Replace all placeholders** using find-and-replace:
   - Replace `{MODEL}` → `Gaussian Mixture`
   - Replace `{model}` → `gm`
   - Replace `{CLASS}` → `Mclust`
   - etc.

3. **Fill in TODO sections** with model-specific logic:
   - Data extraction from fitted models
   - Prompt formatting
   - Validation rules
   - Diagnostic checks

### Step 3: Customize Model-Specific Sections

Each template has sections marked with:
```r
# THIS IS MODEL-SPECIFIC - implement your logic here
# TODO: Replace with your model-specific implementation
```

Focus on these sections for customization.

---

## Template Usage Order

Follow this order for implementation:

1. **`TEMPLATE_config_additions.R`** → Add to `R/shared_config.R`
   - Creates `{model}_args()` constructor
   - Enables parameter grouping

2. **`TEMPLATE_model_data.R`** → Create `R/{model}_model_data.R`
   - Implements data extraction
   - Can test without LLM

3. **`TEMPLATE_prompt_builder.R`** → Create `R/{model}_prompt_builder.R`
   - Builds LLM prompts
   - Can test prompt output without LLM calls

4. **`TEMPLATE_json.R`** → Create `R/{model}_json.R`
   - Handles JSON parsing
   - Can test with mock JSON

5. **`TEMPLATE_diagnostics.R`** → Create `R/{model}_diagnostics.R`
   - Performs diagnostic checks
   - Can test with sample data

6. **`TEMPLATE_report.R`** → Create `R/{model}_report.R`
   - Formats reports
   - Test with cached interpretation

---

## Example: Implementing Gaussian Mixture (GM)

### 1. Create Replacement Script

```r
# scripts/create_gm_files.R

# Define replacements for your model type
replacements <- list(
  "\\{MODEL\\}" = "Gaussian Mixture",
  "\\{MODEL_FULL_NAME\\}" = "Gaussian mixture modeling",
  "\\{model\\}" = "gm",
  "\\{CLASS\\}" = "Mclust",
  "\\{PACKAGE\\}" = "mclust",
  "\\{COMPONENT\\}" = "Cluster",
  "\\{COMPONENT_LOWER\\}" = "cluster",
  "\\{PARAM1\\}" = "covariance_type",  # Analysis parameter, not LLM parameter
  "\\{PARAM2\\}" = "n_clusters",        # Analysis parameter, not LLM parameter
  "\\{DATA_TYPE\\}" = "cluster statistics",
  "\\{DATA_FIELD1\\}" = "means",
  "\\{DATA_FIELD2\\}" = "covariances"
)

# Function to apply replacements
apply_replacements <- function(template_file, output_file, replacements) {
  content <- readLines(template_file)

  for (pattern in names(replacements)) {
    replacement <- replacements[[pattern]]
    content <- gsub(pattern, replacement, content)
  }

  writeLines(content, output_file)
}

# Apply to all templates
templates <- c(
  "model_data" = "TEMPLATE_model_data.R",
  "prompt_builder" = "TEMPLATE_prompt_builder.R",
  "json" = "TEMPLATE_json.R",
  "diagnostics" = "TEMPLATE_diagnostics.R",
  "report" = "TEMPLATE_report.R"
)

for (name in names(templates)) {
  template_path <- file.path("dev/templates", templates[name])
  output_path <- file.path("R", paste0("gm_", name, ".R"))

  apply_replacements(template_path, output_path, replacements)
  cat("Created:", output_path, "\n")
}
```

### 2. Run Replacement Script

```r
source("scripts/create_gm_files.R")
```

### 3. Customize Model-Specific Sections

Open each file and search for `TODO:` comments. Implement the model-specific logic.

---

## Testing Your Implementation

After creating files from templates:

1. **Test data extraction** (no LLM required):
   ```r
   devtools::load_all()
   fit <- mclust::Mclust(iris[, 1:4], G = 3)
   var_info <- data.frame(
     variable = colnames(iris[, 1:4]),
     description = paste("Description for", colnames(iris[, 1:4]))
   )

   analysis_data <- build_analysis_data(fit, var_info, analysis_type = "gm")
   str(analysis_data)
   ```

2. **Test prompt building** (no LLM required):
   ```r
   system_prompt <- build_system_prompt("gm")
   cat(system_prompt)

   user_prompt <- build_main_prompt("gm", analysis_data, word_limit = 50, variable_info = var_info)
   cat(user_prompt)
   ```

3. **Test end-to-end** (requires LLM):
   ```r
   interpretation <- interpret(
     fit_results = fit,
     variable_info = var_info,
     llm_provider = "ollama",
     llm_model = "gpt-oss:20b-cloud",
     word_limit = 20  # Minimum for testing
   )

   print(interpretation)
   ```

---

## Common Customization Points

### In `model_data.R`:

**Data Extraction** (lines ~120-150):
```r
# Example for GM:
means <- fit_results$parameters$mean
covariances <- fit_results$parameters$variance$sigma
probabilities <- fit_results$z

# Example for IRT:
item_params <- mirt::coef(fit_results, simplify = TRUE)$items
ability_estimates <- mirt::fscores(fit_results)
```

**Validation** (lines ~180-220):
```r
# Model-specific validation
if (n_components < 2) {
  cli::cli_abort("Model must have at least 2 clusters")
}
```

### In `prompt_builder.R`:

**Data Formatting** (lines ~130-200):
```r
# Format cluster means
for (k in 1:n_clusters) {
  data_section <- paste0(
    data_section,
    "Cluster ", k, ":\n",
    format_cluster_means(means[, k], variable_names),
    "\n"
  )
}
```

### In `json.R`:

**Expected Keys Generation** (lines ~50-60):
```r
# For clusters:
expected_keys <- paste0("Cluster_", seq_len(n_components))

# For items:
expected_keys <- paste0("Item_", seq_len(n_items))
```

### In `diagnostics.R`:

**Diagnostic Checks** (lines ~30-100):
```r
# Example: Check cluster separation
if (min_cluster_separation < 0.1) {
  diagnostics$has_warnings <- TRUE
  diagnostics$warnings <- c(
    diagnostics$warnings,
    "Warning: Clusters show poor separation..."
  )
}
```

### In `report.R`:

**Additional Data Section** (lines ~200-300):
```r
# Example: Format cluster statistics
formatted_stats <- format_cluster_stats(
  cluster_sizes = analysis_data$cluster_sizes,
  cluster_probs = analysis_data$cluster_probs
)
```

---

## Checklist After Using Templates

After creating files from templates, verify:

- [ ] All `{PLACEHOLDER}` values replaced
- [ ] All `TODO:` sections implemented
- [ ] Model-specific data extraction works
- [ ] Prompts format correctly
- [ ] JSON validation handles expected structure
- [ ] Diagnostics detect relevant issues
- [ ] Report sections display correctly
- [ ] Tests created for each component
- [ ] Documentation updated (`devtools::document()`)
- [ ] Files added to git

---

## Additional Resources

- **Full Implementation Guide**: `dev/MODEL_IMPLEMENTATION_GUIDE.md`
- **FA Reference Implementation**: `R/fa_*.R` files
- **Developer Guide**: `dev/DEVELOPER_GUIDE.md`
- **Testing Guidelines**: `dev/TESTING_GUIDELINES.md`

---

## Dispatch Table Integration

As of 2025-11-16, the psychinterpreter package uses a **centralized dispatch table system** for routing analysis types, output formats, and export formats. When implementing a new model type, you'll need to integrate with these dispatch tables:

### Key Dispatch Tables (in `R/shared_config.R`):

1. **`.ANALYSIS_TYPE_DISPLAY_NAMES`**: Maps model abbreviations to human-readable names
   - Example: `fa = "Factor Analysis"`, `gm = "Gaussian Mixture"`

2. **`.VALID_INTERPRETATION_PARAMS`**: Maps analysis types to their valid parameter names
   - Example: `fa = c("cutoff", "n_emergency", "hide_low_loadings", "sort_loadings")`

3. **`.INTERPRETATION_ARGS_DISPATCH`**: Maps analysis types to handler functions
   - Example: `fa = interpretation_args_fa`

### Model Type Dispatch (in `R/aaa_model_type_dispatch.R`):

The `get_model_dispatch_table()` function provides:
- Model class mappings (e.g., `Mclust` for GM)
- Validators (e.g., `validate_psych_model()`)
- Extractors (e.g., `extract_psych_loadings()`)

### When Implementing a New Model Type:

1. **Register in dispatch tables** (Phase 7 in IMPLEMENTATION_CHECKLIST.md)
2. **Add parameter registry entries** for your model's configuration object
3. **Reference dispatch table documentation** (see `dev/archive/DISPATCH_TABLE_SUMMARY.md`)

This dispatch-driven architecture makes adding new model types straightforward—just register the handler function and the dispatch system handles the routing.

---

## Questions or Issues?

If you encounter issues with the templates:

1. Review the FA implementation (`R/fa_*.R`) for working examples
2. Check `dev/MODEL_IMPLEMENTATION_GUIDE.md` for detailed explanations
3. Run `devtools::check()` to identify documentation issues
4. Test incrementally - don't implement everything at once

---

**Last Updated**: 2025-11-16
**Maintainer**: Update when templates are modified or improved
