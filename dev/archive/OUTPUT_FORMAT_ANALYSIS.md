# Comprehensive Analysis: "output_format" Parameter Usage in psychinterpreter

## Executive Summary

The `output_format` parameter is used throughout the psychinterpreter package to control report generation format. Currently supports "text" and "markdown". A comprehensive search found **19 files** where this parameter appears. This document provides a complete mapping of all locations and the changes needed to add a "cli" format option.

---

## 1. Core Function Files (Active R Code)

### 1.1 R/fa_interpret.R (645 lines)
**Function:** `interpret_fa()`

**Parameter Definition:**
- Line 53: `output_format Character. Output format for the report: "text" or "markdown" (default = "text")`
- Line 163: Default parameter in function signature: `output_format = "text"`

**Validation:**
- Lines 304-314: Validates output_format is either "text" or "markdown"
  ```r
  if (!is.character(output_format) ||
      length(output_format) != 1 ||
      !output_format %in% c("text", "markdown")) {
    cli::cli_abort(...)
  }
  ```

**Usage:**
- Line 625: Passed to `interpret_generic()` function call

**Impact Level:** CRITICAL - Must update validation to accept "cli"

---

### 1.2 R/generic_interpret.R (392 lines)
**Function:** `interpret_generic()`

**Parameter Definition:**
- Line 14: `@param output_format Character. Report format: "text" or "markdown" (default = "text")`
- Line 46: Default parameter in function signature: `output_format = "text"`

**Usage:**
- Line 262: Stored in `params` list: `output_format = output_format`
- Line 300-302: Passed to `build_report()` S3 function

**Impact Level:** CRITICAL - Core orchestration function

---

### 1.3 R/report_fa.R (838 lines)
**Function 1: `build_fa_report()` (Internal, ~630 lines)**

**Parameter Definition:**
- Line 9: `@param output_format Character. Output format: "text" or "markdown" (default = "text")`
- Line 19: Default parameter: `output_format = "text"`

**Logic Flow:**
- Lines 38-281: **HUGE conditional block** that branches on format:
  ```r
  if (output_format == "markdown") {
    # [Lines 38-280: 242 lines of markdown-specific logic]
  } else {
    # [Lines 281-476: 195 lines of text-specific logic]
  }
  ```

**Format-Specific Logic Differences:**

| Aspect | Text Format | Markdown Format |
|--------|------------|-----------------|
| Headings | `==== SECTION NAME ====` | `# Section Name` |
| Emphasis | Plain text | `**bold**`, `*italic*` |
| Links | None | Markdown links |
| Code blocks | Indentation | ``` markdown code blocks ``` |
| Lists | Numbered/bullet | Markdown list syntax |
| Line breaks | `\n` | `  \n` (soft breaks) |

**Critical Sections with Format Checks:**
- Lines 38-39: Main format branching (if/else)
- Lines 480, 498, 509: Format checks for cross-loadings section
- Lines 527, 549, 560: Format checks for no-loadings section
- Lines 576-579: Format-specific final spacing
- Lines 584-629: Elapsed time insertion differs by format
- Lines 635-639: Text format specific line break fixes

**Function 2: `print.fa_interpretation()` (S3 method, ~120 lines)**

**Parameter Definition:**
- Line 654: `@param output_format Character. Output format: "text", "markdown", or NULL (default = NULL)`
- Line 686: Default parameter: `output_format = NULL`

**Special Behavior:**
- Lines 725-743: Validates output_format ∈ {NULL, "text", "markdown"}
- Lines 763-788: If output_format specified AND factor_summaries exist, regenerates report
- Lines 795-801: Post-processing:
  - Text: Wraps using `wrap_text()` function
  - Markdown: Prints without wrapping to preserve formatting

**Impact Level:** CRITICAL - Must add logic for "cli" format generation

**Function 3: `build_report.fa_interpretation()` (S3 method, ~18 lines)**

**Purpose:** Integrates with `build_report()` generic

**Parameter Definition:**
- Line 812: `@param output_format Character. "text" or "markdown"`
- Line 821: Default: `output_format = "text"`

**Implementation:**
- Lines 830-837: Delegates to `build_fa_report()`, passing through all parameters

---

### 1.4 R/export_functions.R (132 lines)
**Function:** `export_interpretation()`

**Parameter Definition:**
- Line 8: `@param format Character. Export format: "txt" for plain text or "md" for markdown`
- Line 66: Default: `format = "txt"`

**Key Implementation:**
- Line 110: Converts export format to output_format:
  ```r
  output_format <- if (format == "txt") "text" else "markdown"
  ```

**Usage:**
- Lines 114-121: Calls `build_fa_report()` with converted output_format

**Impact Level:** LOW-MEDIUM - Only affects export, not core logic

---

## 2. Test Files

### 2.1 tests/testthat/test-interpret_fa.R

**Tests:**
1. Invalid output_format validation (expects error for "invalid" value)
   ```r
   expect_error(
     interpret_fa(loadings, var_info, output_format = "invalid"),
     "must be either"
   )
   ```

**Impact Level:** HIGH - Tests must be updated to verify "cli" is accepted

---

### 2.2 tests/testthat/test-print_methods.R

**Test Suite: print.fa_interpretation (14 tests)**

1. **output_format validation tests** (lines 54-72):
   - Tests invalid values: "invalid", vector c("text", "markdown"), numeric 123
   - Expects error: "must be either 'text' or 'markdown'"

2. **Format regeneration test** (lines 128-137):
   - Regenerates report in markdown format
   - Verifies markdown headers present

3. **Heading level tests** (lines 163-178):
   - Tests heading_level parameter only works with markdown
   - Verifies different heading levels produce different output

4. **Suppress heading tests** (lines 180-193):
   - Tests suppress_heading parameter with markdown output

**Impact Level:** HIGH - Multiple tests validate output_format options

---

### 2.3 tests/testthat/test-export_functions.R

**Tests:**
- General validation and file I/O tests
- No specific output_format tests (uses default "txt"→"text" conversion)

**Impact Level:** LOW - Not directly testing output_format

---

## 3. Documentation Files

### 3.1 man/interpret_fa.Rd

- **Lines:** Parameter definition for output_format
- **Current:** Documents "text" or "markdown" options
- **Example:** Shows usage with `output_format = "markdown"`

### 3.2 man/generic_interpret.Rd

- Documents output_format as "text" or "markdown"

### 3.3 man/print.fa_interpretation.Rd

- Extensive documentation of output_format parameter
- Documents NULL behavior for using existing report
- Shows examples of format conversion

### 3.4 man/build_report.Rd & build_report.fa_interpretation.Rd

- Parameter documentation for output_format

### 3.5 man/build_report.default.Rd

- Generic documentation

### 3.6 man/export_interpretation.Rd

- Documents format parameter (converted to output_format internally)

---

## 4. Vignettes and Examples

### 4.1 vignettes/articles/01-Basic_Usage.qmd

- Documentation file (no code-level changes needed unless examples added)
- Could include example of "cli" format usage

---

## 5. Archive Files (Do NOT Modify)

These contain old/redundant code. Ignore for this task:
- R/archive/fa_report_functions.R
- R/archive/interpret_fa.R.backup
- R/archive/utils_export.R
- R/archive/interpret_fa.R.old

---

## Summary of Changes Required

### MUST CHANGE (Critical)

1. **R/fa_interpret.R** (Line 307):
   - Update validation: `!output_format %in% c("text", "markdown")` → `!output_format %in% c("text", "markdown", "cli")`

2. **R/generic_interpret.R** (Lines 14, 46):
   - Update parameter documentation
   - Keep default as "text"

3. **R/report_fa.R - build_fa_report()** (Lines 38-639):
   - Add new `else if (output_format == "cli")` branch
   - Implement CLI formatting logic for:
     - Headers (use cli::rule())
     - Emphasis (use cli formatting)
     - Colors/styling (use cli::cli_text() with inline markup)
   - Update all format checks (lines 480, 498, 509, 527, 549, 560, 576, 584)

4. **R/report_fa.R - print.fa_interpretation()** (Lines 725-801):
   - Update validation to accept "cli"
   - Add CLI handling in post-processing logic
   - Determine if wrapping applies to CLI (likely no, like markdown)

5. **R/report_fa.R - build_report.fa_interpretation()** (Line 812):
   - Update parameter documentation

6. **tests/testthat/test-interpret_fa.R**:
   - Update validation test to accept "cli" as valid format

7. **tests/testthat/test-print_methods.R** (Lines 54-193):
   - Update validation tests
   - Add new tests for "cli" format output
   - Add heading/suppress_heading behavior for CLI

### SHOULD CHANGE (Documentation)

8. **man/*.Rd files**:
   - Update parameter documentation to include "cli" as option
   - Add examples showing CLI format usage

9. **vignettes/articles/01-Basic_Usage.qmd**:
   - Could add example demonstrating CLI format

### OPTIONAL (Enhancement)

10. **R/export_functions.R**:
    - Consider adding support for exporting to CLI-formatted text
    - Current focus is txt/md; would need:
      - Format parameter adjustment (add "cli" option)
      - Implementation logic to render CLI markup to plain text for file output

---

## "Text" Format Example Output

```
==========================================
FACTOR ANALYSIS INTERPRETATION
==========================================

Number of factors: 3
Loading cutoff: 0.3

LLM used: anthropic - claude-haiku-4-5-20251001

SUGGESTED FACTOR NAMES:
=======================

Factor 1 (33.5%): Openness to Experience
Factor 2 (25.2%): Conscientiousness
Factor 3 (18.9%): Extraversion

...

DETAILED FACTOR INTERPRETATIONS:
=================================

Factor 1 - Openness to Experience:
Number of significant loadings: 5
Variance explained: 33.5%

Variables:
  1. Enjoys new experiences (loading: 0.678)
  2. Imaginative (loading: 0.645)
  ...
```

---

## "Markdown" Format Example Output

```markdown
# Factor Analysis Interpretation

**Number of factors:** 3  
**Loading cutoff:** 0.3  
**LLM used:** anthropic - claude-haiku-4-5-20251001  

## Suggested Factor Names

- **Factor 1 (33.5%):** *Openness to Experience*
- **Factor 2 (25.2%):** *Conscientiousness*
- **Factor 3 (18.9%):** *Extraversion*

...

## Detailed Factor Interpretations

### Factor 1: Openness to Experience

**Number of significant loadings:** 5  
**Variance explained:** 33.5%  

**Variables:**

1. Enjoys new experiences (loading: 0.678)
2. Imaginative (loading: 0.645)
...
```

---

## "CLI" Format Specification (Proposed)

The CLI format would use R's `cli` package features for:

### Headers
```r
cli::rule("Factor Analysis Interpretation")  # Full-width separator
cli::rule("Factor 1: Openness", line = 1)    # Heading style
```

### Emphasis
```r
cli::cli_text("{.strong Number of factors:} 3")
cli::cli_text("{.emph Openness to Experience}")
cli::cli_text("{.code 0.678}")  # For loadings
```

### Lists with colors
```r
cli::cli_ul(c(
  "{.strong Factor 1 (33.5%):} {.emph Openness to Experience}",
  "{.strong Factor 2 (25.2%):} {.emph Conscientiousness}"
))
```

### Structure example
```
┌─────────────────────────────────────────────────────────┐
│ Factor Analysis Interpretation                          │
└─────────────────────────────────────────────────────────┘

Number of factors: 3
Loading cutoff: 0.3
LLM used: anthropic - claude-haiku-4-5-20251001

─── Suggested Factor Names ─────────────────────────────

• Factor 1 (33.5%): Openness to Experience
• Factor 2 (25.2%): Conscientiousness
• Factor 3 (18.9%): Extraversion

─── Detailed Factor Interpretations ────────────────────

• • • Factor 1: Openness to Experience

Number of significant loadings: 5
Variance explained: 33.5%

Variables:
 1 Enjoys new experiences ................................. 0.678
 2 Imaginative ............................................. 0.645
```

---

## File Locations (Absolute Paths)

**Core Implementation:**
- `/mnt/c/Users/Matze/Documents/GitHub/psychinterpreter/R/fa_interpret.R`
- `/mnt/c/Users/Matze/Documents/GitHub/psychinterpreter/R/generic_interpret.R`
- `/mnt/c/Users/Matze/Documents/GitHub/psychinterpreter/R/report_fa.R`
- `/mnt/c/Users/Matze/Documents/GitHub/psychinterpreter/R/export_functions.R`

**Tests:**
- `/mnt/c/Users/Matze/Documents/GitHub/psychinterpreter/tests/testthat/test-interpret_fa.R`
- `/mnt/c/Users/Matze/Documents/GitHub/psychinterpreter/tests/testthat/test-print_methods.R`
- `/mnt/c/Users/Matze/Documents/GitHub/psychinterpreter/tests/testthat/test-export_functions.R`

**Documentation:**
- `/mnt/c/Users/Matze/Documents/GitHub/psychinterpreter/man/interpret_fa.Rd`
- `/mnt/c/Users/Matze/Documents/GitHub/psychinterpreter/man/generic_interpret.Rd`
- `/mnt/c/Users/Matze/Documents/GitHub/psychinterpreter/man/print.fa_interpretation.Rd`
- `/mnt/c/Users/Matze/Documents/GitHub/psychinterpreter/man/build_report.fa_interpretation.Rd`
- `/mnt/c/Users/Matze/Documents/GitHub/psychinterpreter/man/build_report.default.Rd`
- `/mnt/c/Users/Matze/Documents/GitHub/psychinterpreter/man/build_report.Rd`
- `/mnt/c/Users/Matze/Documents/GitHub/psychinterpreter/man/export_interpretation.Rd`

**Vignette:**
- `/mnt/c/Users/Matze/Documents/GitHub/psychinterpreter/vignettes/articles/01-Basic_Usage.qmd`

---

## Complexity Assessment

### HIGH Complexity
- **R/report_fa.R - build_fa_report()**: Massive if/else branching logic (630+ lines). Adding CLI requires:
  - Understanding current text/markdown flow
  - Identifying all 15+ format-specific locations
  - Creating new CLI-specific branch
  - Testing all edge cases (cross-loadings, empty factors, etc.)

### MEDIUM Complexity
- **R/report_fa.R - print.fa_interpretation()**: Moderate changes needed for validation and post-processing
- **Tests**: Multiple test files need updates and new test cases

### LOW Complexity
- **R/fa_interpret.R & R/generic_interpret.R**: Simple validation updates
- **Documentation**: Straightforward parameter documentation changes

---

## Testing Strategy

1. **Unit tests** needed for:
   - Validation accepts "cli" format
   - CLI format generates valid output
   - CLI format produces expected structure (headers, emphasis, etc.)
   - Print method handles CLI format correctly

2. **Integration tests**:
   - Full interpretation pipeline with CLI output
   - Export functionality (if extended to support CLI)

3. **Edge cases**:
   - Factors with no loadings (emergency rule)
   - Cross-loading factors
   - Long variable descriptions
   - Factor correlations integration

---

## Implementation Order (Recommended)

1. Update validation in R/fa_interpret.R (easy, enables testing)
2. Update generic_interpret.R parameter docs
3. Implement build_fa_report() CLI branch (core work)
4. Update print.fa_interpretation() for CLI handling
5. Update tests with new validations
6. Add CLI format tests
7. Update documentation files
8. Update vignette example

