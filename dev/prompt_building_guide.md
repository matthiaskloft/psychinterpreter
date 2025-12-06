# Prompt Building Guide

This guide provides best practices for building system and user prompts in the psychinterpreter package. Recommendations are based on current prompt engineering research and domain-specific reporting standards.

## Sources

- [Lakera Prompt Engineering Guide 2025](https://www.lakera.ai/blog/prompt-engineering-guide)
- [Palantir Best Practices for LLM Prompt Engineering](https://www.palantir.com/docs/foundry/aip/best-practices-prompt-engineering)
- [SMART-LCA Checklist (tidySEM)](https://cjvanlissa.github.io/tidySEM/articles/SMART_LCA_checklist.html)
- [Cluster Analysis in Mental Health Research](https://www.sciencedirect.com/science/article/pii/S0165178123002159)
- [Cluster Analysis Reporting in Health Psychology](https://pubmed.ncbi.nlm.nih.gov/16238852/)
- [LPA Review and How-To Guide](https://www.sciencedirect.com/science/article/pii/S0001879120300701)
- [APA Guidelines for Psychological Assessment](https://www.apa.org/about/policy/guidelines-psychological-assessment-evaluation.pdf)
- [Standards for Educational and Psychological Testing](https://www.apa.org/science/programs/testing/standards)
- [JSON Prompting Best Practices](https://blog.promptlayer.com/is-json-prompting-a-good-strategy/)
- [Structured Output for LLMs](https://dev.to/rishabdugar/crafting-structured-json-responses-ensuring-consistent-output-from-any-llm-l9h)

---

# System Prompt

The system prompt establishes the LLM's role, expertise, and behavioral guidelines. It should be stable across requests and set the interpretive framework.

## Structure

Use clear section headers with markdown formatting:

```
# ROLE
[Who the LLM is and their expertise]

# TASK
[What they need to accomplish - use numbered steps]

# KEY CONCEPTS
[Definitions and interpretation thresholds]
```

## Best Practices

### 1. Define a Specific Persona

**Avoid**: Generic descriptions like "expert psychometrician"

**Prefer**: Specific expertise grounded in the analysis type

```r
# Good
"You are an expert in person-centered statistical methods, specifically
Gaussian mixture models (GMM) and latent profile analysis."

# Good
"You are an expert in psychometric measurement, specifically exploratory
and confirmatory factor analysis."
```

### 2. Use Numbered Task Steps

Break complex tasks into explicit, numbered steps. This improves task completion and ensures all components are addressed.

```r
# Good
"Interpret a GMM cluster analysis by:
1. Naming each cluster with a concise, descriptive label (2-4 words)
2. Characterizing each cluster's profile based on variable patterns
3. Explaining what distinguishes each cluster from others
4. Describing the practical or theoretical significance of each profile"

# Avoid
"Provide a comprehensive interpretation of a cluster analysis by naming
each cluster, explaining the profile, and identifying distinctions."
```

### 3. Provide Actionable Thresholds

Include concrete numerical cutoffs for interpretation. LLMs perform better with explicit decision rules.

```r
# Good - z-score interpretation
"Values near 0 = average; |z| > 0.5 = notable; |z| > 1 = substantial deviation"

# Good - correlation interpretation
"|r| 0.3-0.5 = weak, 0.5-0.7 = moderate, >0.7 = strong"

# Good - factor loading interpretation
"|loading| < 0.30 = weak, 0.30-0.50 = moderate, > 0.50 = strong"
```

### 4. Include Interpretation Principles

Add a section on how to think about interpretation, not just what to report:

```r
"## Interpretation Principles
- **Relative interpretation**: Describe clusters relative to each other
- **Pattern recognition**: Focus on overall profiles, not isolated variables
- **Practical significance**: Consider meaningful differences, not just statistical"
```

### 5. Add Caveats Where Appropriate

Per SMART-LCA guidelines, acknowledge limitations in naming:

```r
"Labels should be descriptive but acknowledge they are shorthand"
```

### 6. Keep Definitions Complete

Ensure all definitions are self-contained. Never leave definitions incomplete or cut off.

```r
# Good - complete definition
"- **Negative correlation**: Variables move in opposite directions
   (-0.3 to -0.5 = weak, -0.5 to -0.7 = moderate, < -0.7 = strong)"

# Bad - incomplete
"- **Negative correlation**: Variables that move in opposite directions (-0.3 to -0..."
```

## Template: System Prompt Structure

```r
build_system_prompt.{class} <- function(analysis_type, word_limit = 100, ...) {

paste0(
"# ROLE
You are an expert in [specific domain], specifically [specific methods].
You [brief description of what they do].

# TASK
[Verb] a [analysis type] by:
1. [First deliverable]
2. [Second deliverable]
3. [Third deliverable]
4. [Fourth deliverable if needed]

# KEY CONCEPTS

## [Category 1]
- **Term**: Definition with actionable thresholds
- **Term**: Definition with actionable thresholds

## [Category 2]
- **Term**: Definition with actionable thresholds

## Interpretation Principles
- **Principle 1**: Explanation
- **Principle 2**: Explanation
- **Principle 3**: Explanation
"
)
}
```

## Example: Improved GM System Prompt

```r
build_system_prompt.gm <- function(analysis_type, word_limit = 100, ...) {
  paste0(
    "# ROLE\n",
    "You are an expert in person-centered statistical methods, specifically ",
    "Gaussian mixture models (GMM) and latent profile analysis. You interpret ",
    "cluster solutions to identify meaningful subgroups within populations.\n\n",

    "# TASK\n",
    "Interpret a GMM cluster analysis by:\n",
    "1. Naming each cluster with a concise, descriptive label (2-4 words)\n",
    "2. Characterizing each cluster's profile based on variable patterns\n",
    "3. Explaining what distinguishes each cluster from others\n",
    "4. Describing the practical or theoretical significance of each profile\n\n",

    "# KEY CONCEPTS\n\n",
    "## Cluster Statistics\n",
    "- **Cluster mean**: Standardized average (z-score) of a variable within a cluster. ",
    "Values near 0 = average; |z| > 0.5 = notable; |z| > 1 = substantial deviation\n",
    "- **Cluster profile**: The distinctive pattern of means across all variables\n",
    "- **Cluster proportion**: Percentage of sample assigned to each cluster\n",
    "- **Classification uncertainty**: Ambiguity in cluster assignment ",
    "(lower = more distinct clusters)\n\n",

    "## Correlation Interpretation\n",
    "- **Positive correlation**: Variables increase/decrease together ",
    "(|r| 0.3-0.5 = weak, 0.5-0.7 = moderate, >0.7 = strong)\n",
    "- **Negative correlation**: Variables move in opposite directions ",
    "(same thresholds apply)\n",
    "- **Within-cluster correlation**: Relationship between variables among ",
    "cluster members\n\n",

    "## Interpretation Principles\n",
    "- **Relative interpretation**: Describe clusters relative to each other ",
    "and the overall sample\n",
    "- **Pattern recognition**: Focus on the overall profile, not isolated variables\n",
    "- **Distinguishing features**: Emphasize variables with largest ",
    "between-cluster differences\n",
    "- **Practical significance**: Consider whether differences are meaningful, ",
    "not just statistical\n",
    "- **Naming precision**: Labels should be descriptive but acknowledge ",
    "they are shorthand\n\n"
  )
}
```

---

# Main Prompt Structure

The main prompt (`build_main_prompt.{class}`) contains the specific data and context for each interpretation request. It follows a standardized 6-section structure that is consistent across all analysis types.

## 6-Section Structure

```
Section 1: # INTERPRETATION GUIDELINES
Section 2: # ADDITIONAL CONTEXT
Section 3: # MODEL INFORMATION
Section 4: # VARIABLE DESCRIPTIONS
Section 5: # [ANALYSIS-SPECIFIC DATA]
Section 6: # OUTPUT FORMAT + # CRITICAL REQUIREMENTS
```

This structure is implemented identically in:
- `R/fa_prompt_builder.R` (lines 68-158)
- `R/gm_prompt_builder.R` (lines 77-176)

---

# Interpretation Guidelines

The Interpretation Guidelines section (Section 1) tells the LLM **how** to approach the interpretation task. This section can be customized via the `interpretation_guidelines` parameter or uses sensible defaults.

## Placement in Prompt

This section appears **first** in the main prompt, before any data. This primes the LLM with the interpretive framework before it sees the numbers.

```r
# From build_main_prompt.gm (lines 105-132)
if (!is.null(interpretation_guidelines)) {
  prompt <- paste0(prompt, interpretation_guidelines)
} else {
  # Default interpretation guidelines...
}
```

## Required Subsections

The default interpretation guidelines have three subsections:

### 1. Naming Subsection

Guides how to create component names (factor names, cluster names).

```r
"## Factor Naming\n",
"- **Construct identification**: Identify the underlying construct each factor represents\n",
"- **Name creation**: Create 2-4 word names capturing the essence of each factor\n",
"- **Theoretical grounding**: Base names on domain knowledge and additional context\n\n"
```

**Best Practices:**
- Specify word count limits (2-4 words)
- Require theoretical grounding, not just statistical description
- Per SMART-LCA: "Assign informative class names while clarifying that these names are just shorthand"

### 2. Interpretation Subsection

Guides how to write the interpretation text.

```r
"## Cluster Interpretation\n",
"- **Distinguishing characteristics**: Focus on what makes each cluster unique\n",
"- **Variable patterns**: Examine both high and low means, especially for distinguishing variables\n",
"- **Within-cluster correlations**: Use correlations to understand trait co-occurrence patterns\n",
"- **Relative comparisons**: Describe clusters in relation to each other\n",
"- **Practical significance**: Consider meaningful differences, not just numerical values\n",
"- **Uncertainty awareness**: If provided, give more confidence to well-defined clusters\n\n"
```

**Best Practices:**

| Guideline | Purpose | Example |
|-----------|---------|---------|
| Distinguishing characteristics | Prevent generic descriptions | "Focus on what makes each cluster unique" |
| Variable patterns | Ensure comprehensive analysis | "Examine both high AND low means" |
| Relative comparisons | Enable contrast | "Describe clusters in relation to each other" |
| Practical significance | Avoid over-interpretation | "Consider meaningful differences, not just numerical" |
| Uncertainty awareness | Weight confidence | "Give more confidence to well-defined clusters" |

### 3. Output Requirements Subsection

Specifies writing style and constraints within the guidelines section.

```r
"## Output Requirements\n",
"- **Word target (Interpretation)**: Aim for ", round(word_limit * 0.8), "-", word_limit,
" words per interpretation (80%-100% of limit)\n",
"- **Writing style**: Be concise, precise, and domain-appropriate\n",
"- **Avoid jargon**: Use clear, accessible language\n\n"
```

**Best Practices:**
- Use dynamic word limits: `round(word_limit * 0.8)` to `word_limit`
- Specify a range (80-100%) rather than exact count
- Include writing style guidance (concise, precise, domain-appropriate)

## Template: Interpretation Guidelines

```r
# Default interpretation guidelines template
paste0(
  "# INTERPRETATION GUIDELINES\n\n",

  "## {Component} Naming\n",
  "- **{Construct/Profile} identification**: Identify the {underlying construct/behavioral profile} each {component} represents\n",
  "- **Name creation**: Create 2-4 word names capturing the essence of each {component}\n",
  "- **Theoretical grounding**: Base names on domain knowledge and additional context\n\n",

  "## {Component} Interpretation\n",
  "- **Distinguishing characteristics**: Focus on what makes each {component} unique\n",
  "- **{Data} patterns**: Examine {relevant patterns in your data type}\n",
  "- **Relative comparisons**: Describe {components} in relation to each other\n",
  "- **Practical significance**: Consider meaningful differences, not just numerical values\n\n",

  "## Output Requirements\n",
  "- **Word target (Interpretation)**: Aim for ", round(word_limit * 0.8), "-", word_limit,
  " words per interpretation (80%-100% of limit)\n",
  "- **Writing style**: Be concise, precise, and domain-appropriate\n",
  "- **Avoid jargon**: Use clear, accessible language\n\n"
)
```

## Custom Interpretation Guidelines

Users can override default guidelines via the `interpretation_guidelines` parameter:

```r
interpret(
  model,
  variable_info = var_info,
  interpretation_guidelines = "
# INTERPRETATION GUIDELINES

Focus on clinical implications. Each cluster should be described in terms of:
1. Risk profile for the outcome
2. Recommended intervention approach
3. Prognosis expectations

Use language appropriate for a clinical audience.
"
)
```

**When to Use Custom Guidelines:**
- Domain-specific terminology requirements
- Specialized audience (clinical, educational, organizational)
- Specific theoretical framework to apply
- Non-standard output requirements

---

# Output Requirements

The Output Requirements section (Section 6) specifies the exact JSON structure and constraints. This section is **critical** for reliable structured output.

## Why Output Requirements Matter

Per [JSON Prompting Best Practices](https://blog.promptlayer.com/is-json-prompting-a-good-strategy/):
- LLMs encounter millions of JSON examples during training
- Explicit format constraints dramatically improve compliance
- Ambiguity in output format leads to parsing failures

## Structure

The output requirements consist of two parts:

### Part 1: OUTPUT FORMAT

Specifies the exact JSON structure with a complete example.

```r
paste0(
  "# OUTPUT FORMAT\n",
  "Respond with ONLY valid JSON using cluster names as object keys:\n\n",
  "```json\n",
  "{\n",
  '  "Cluster_1": {\n',
  '    "name": "Generate name",\n',
  '    "interpretation": "Generate interpretation"\n',
  '  },\n',
  '  "Cluster_2": {\n',
  '    "name": "Generate name",\n',
  '    "interpretation": "Generate interpretation"\n',
  '  }\n',
  "}\n",
  "```\n\n"
)
```

### Part 2: CRITICAL REQUIREMENTS

Lists non-negotiable constraints as bullet points.

```r
paste0(
  "# CRITICAL REQUIREMENTS\n",
  "- Include ALL ", n_clusters, " clusters as object keys using their exact names: ",
  paste(cluster_names, collapse = ", "), "\n",
  "- Valid JSON syntax (proper quotes, commas, brackets)\n",
  "- No additional text before or after JSON\n",
  "- Cluster names: 2-4 words maximum\n",
  "- Cluster interpretations: target ", round(word_limit * 0.8), "-", word_limit,
  " words each (80%-100% of ", word_limit, " word limit)\n"
)
```

## Best Practices

### 1. Use Actual Component Names as Keys

Generate the JSON example dynamically using real component names:

```r
# Good - uses actual cluster names from the model
for (k in seq_len(analysis_data$n_clusters)) {
  instructions <- paste0(
    instructions,
    '  "', analysis_data$cluster_names[k], '": {\n',
    '    "name": "Generate name",\n',
    '    "interpretation": "Generate interpretation"\n',
    '  }'
  )
}

# Bad - uses generic placeholders
'  "cluster_name": {...}'
```

**Why:** Using actual names prevents key mismatches and parsing failures.

### 2. Provide Complete JSON Example

Show the full structure, not a truncated version:

```r
# Good - complete example for all components
{
  "Cluster_1": {"name": "...", "interpretation": "..."},
  "Cluster_2": {"name": "...", "interpretation": "..."},
  "Cluster_3": {"name": "...", "interpretation": "..."}
}

# Bad - truncated with ellipsis
{
  "Cluster_1": {"name": "...", "interpretation": "..."},
  ...
}
```

### 3. List Exact Key Names in Requirements

Explicitly enumerate all expected keys:

```r
"- Include ALL 3 clusters as object keys using their exact names: Cluster_1, Cluster_2, Cluster_3\n"
```

### 4. Include Syntax Requirements

Prevent common JSON errors:

```r
"- Valid JSON syntax (proper quotes, commas, brackets)\n",
"- No additional text before or after JSON\n"
```

### 5. Use Dynamic Values

Compute values from the data rather than hardcoding:

```r
# Good - dynamic
paste0("- Include ALL ", analysis_data$n_clusters, " clusters")
paste0("- target ", round(word_limit * 0.8), "-", word_limit, " words")

# Bad - hardcoded
"- Include ALL 3 clusters"
"- target 80-100 words"
```

### 6. Add Conditional Requirements

Include context-specific constraints when applicable:

```r
# Uncertainty weighting (GM only, when enabled)
if (analysis_data$weight_by_uncertainty && !is.null(analysis_data$uncertainty)) {
  instructions <- paste0(
    instructions,
    "- Give more confidence to clusters with lower uncertainty\n"
  )
}

# Emergency rule (FA only)
if (n_emergency == 0) {
  prompt_requirements <- paste0(
    prompt_requirements,
    "- For factors with no significant loadings: respond with \"undefined\" for name and \"NA\" for interpretation\n"
  )
}
```

### 7. Specify Content Constraints

Guide interpretation quality:

```r
"- Focus on what distinguishes each cluster from the others\n",
"- Describe the profile in terms of psychological or behavioral characteristics\n",
"- Be specific and concrete rather than vague or generic\n",
"- Use the variable descriptions to inform meaningful interpretations\n"
```

## Template: Output Instructions Function

```r
build_output_instructions.{class} <- function(analysis_data, word_limit) {

  # Part 1: JSON structure example
  instructions <- paste0(
    "# OUTPUT FORMAT\n",
    "Respond with ONLY valid JSON using {component} names as object keys:\n\n",
    "```json\n",
    "{\n"
  )

  # Generate example for each component dynamically
  for (k in seq_len(analysis_data$n_{components})) {
    instructions <- paste0(
      instructions,
      '  "', analysis_data${component}_names[k], '": {\n',
      '    "name": "Generate name",\n',
      '    "interpretation": "Generate interpretation"\n',
      '  }'
    )
    if (k < analysis_data$n_{components}) {
      instructions <- paste0(instructions, ',\n')
    } else {
      instructions <- paste0(instructions, '\n')
    }
  }

  instructions <- paste0(instructions, "}\n", "```\n\n")

  # Part 2: Critical requirements
  instructions <- paste0(
    instructions,
    "# CRITICAL REQUIREMENTS\n",
    "- Include ALL ", analysis_data$n_{components}, " {components} as object keys using their exact names: ",
    paste(analysis_data${component}_names, collapse = ", "), "\n",
    "- Valid JSON syntax (proper quotes, commas, brackets)\n",
    "- No additional text before or after JSON\n",
    "- {Component} names: 2-4 words maximum\n",
    "- {Component} interpretations: target ", round(word_limit * 0.8), "-", word_limit,
    " words each (80%-100% of ", word_limit, " word limit)\n",
    "- Focus on what distinguishes each {component} from the others\n",
    "- Describe the profile in terms of psychological or behavioral characteristics\n",
    "- Be specific and concrete rather than vague or generic\n",
    "- Use the variable descriptions to inform meaningful interpretations\n"
  )

  # Add conditional requirements here
  # if (condition) { instructions <- paste0(instructions, "- ...") }

  return(instructions)
}
```

## Error Prevention Strategies

| Error Type | Prevention Strategy |
|------------|---------------------|
| Missing keys | List ALL expected keys explicitly |
| Extra text | "No additional text before or after JSON" |
| Syntax errors | "Valid JSON syntax (proper quotes, commas, brackets)" |
| Wrong key names | Use actual component names in example |
| Truncated output | Use word limit range, not exact count |
| Generic content | "Be specific and concrete rather than vague or generic" |

---

# Common Pitfalls

| Pitfall | Problem | Solution |
|---------|---------|----------|
| Vague persona | LLM lacks domain grounding | Specify exact methods expertise |
| Single-sentence task | Steps may be missed | Use numbered task list |
| Missing thresholds | Inconsistent interpretation | Provide explicit cutoffs |
| Incomplete definitions | Confusion, errors | Ensure all text is complete |
| No output constraints | Rambling, wrong format | Specify JSON structure exactly |
| Generic language | Unspecific interpretations | Use domain terminology |
| Hardcoded values | Inflexible prompts | Use dynamic values from analysis_data |
| Missing component names | Key mismatches | List exact names in requirements |
| No conditional logic | Missing context | Add if-statements for optional features |

---

# Checklist for New Analysis Types

## System Prompt (`build_system_prompt.{class}`)

- [ ] Role specifies exact statistical method expertise
- [ ] Task is broken into 3-4 numbered steps
- [ ] All key terms have definitions with thresholds
- [ ] Interpretation principles are included
- [ ] No incomplete or cut-off text
- [ ] Spelling and grammar are correct

## Interpretation Guidelines (Section 1 of main prompt)

- [ ] Naming subsection with 2-4 word limit
- [ ] Interpretation subsection with distinguishing characteristics guidance
- [ ] Output requirements subsection with dynamic word limits
- [ ] Support for custom `interpretation_guidelines` parameter
- [ ] Writing style guidance included

## Output Requirements (Section 6 of main prompt)

- [ ] Complete JSON example with actual component names
- [ ] All component names listed explicitly in requirements
- [ ] JSON syntax requirements stated
- [ ] "No additional text" constraint included
- [ ] Word limit specified as range (80-100%)
- [ ] Content quality constraints (specific, concrete, not generic)
- [ ] Conditional requirements for optional features
- [ ] All values computed dynamically from `analysis_data`

## Main Prompt Structure

- [ ] Section 1: INTERPRETATION GUIDELINES
- [ ] Section 2: ADDITIONAL CONTEXT (if provided)
- [ ] Section 3: MODEL INFORMATION
- [ ] Section 4: VARIABLE DESCRIPTIONS
- [ ] Section 5: [ANALYSIS-SPECIFIC DATA]
- [ ] Section 6: OUTPUT FORMAT + CRITICAL REQUIREMENTS
- [ ] Clear `#` markdown headers for each section
- [ ] Data includes interpretation hints where helpful
