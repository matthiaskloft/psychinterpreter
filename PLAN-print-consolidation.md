# Print Method Consolidation Plan

## Current State Analysis

### Print Methods Inventory (9 total)

| Method | File | Output | Style | Category |
|--------|------|--------|-------|----------|
| `print.fa_interpretation` | fa_report.R:791 | cat() | CLI styled (colors, rules, wrapping) | Main result |
| `print.gm_interpretation` | gm_report.R:343 | cat() | CLI styled (colors, rules, wrapping) | Main result |
| `print.interpretation` | class_interpretation.R:44 | cat() | Plain text fallback | Main result |
| `print.chat_session` | class_chat_session.R:160 | cat() | Plain text, no styling | Session state |
| `print.variable_labels` | label_formatting.R:281 | message() | Custom sections `-- Name --` | Label result |
| `print.interpretation_args` | shared_config.R:457 | message() | Custom sections `-- Name --` | Config |
| `print.llm_args` | shared_config.R:506 | message() | Custom sections `-- Name --` | Config |
| `print.output_args` | shared_config.R:522 | message() | Custom sections `-- Name --` | Config |
| `print.label_args` | label_args.R:121 | message() | Custom sections `-- Name --` | Config |

### Current Visual Inconsistencies

1. **Section Headers**
   - FA/GM interpretations: `cli::col_cyan(cli::style_bold(title))` + `cli::rule()`
   - Config objects: `"-- Section Name --\n"`
   - variable_labels: `"\n-- Section Name --\n"`

2. **Bullet/List Markers**
   - FA/GM: `cli::symbol$bullet` (•)
   - Config objects: `"  * "` or `"  i "`
   - variable_labels: `"  * "`

3. **Key-Value Formatting**
   - FA/GM: `cli::style_bold("Key:")` + value
   - Config: `"  * Key: value"` or `"  i Key: value"`
   - chat_session: `"Key: value\n"` (no bullets)

4. **Output Mechanism**
   - Main results: `cat()` (correct for print methods)
   - Config/labels: `message()` (goes to stderr, not ideal)

5. **Color Usage**
   - FA/GM: cyan headers, green names, grey separators, yellow warnings
   - Others: no colors

6. **Line Width**
   - FA/GM: respects `max_line_length` (default 80), `wrap_text()`
   - Others: no width control

---

## Proposed Unified Design System

### Design Principles

1. **Consistent Visual Hierarchy**
   - Main title: bold + cyan + rule underline
   - Section headers: bold + cyan (no underline for sub-sections)
   - Key-value pairs: bold key, regular value
   - Lists: consistent bullet style

2. **Unified Color Palette**
   - Cyan: headers, titles
   - Green: success, names, highlights
   - Yellow: warnings
   - Grey: separators, secondary info
   - Red: errors only

3. **Consistent Structure**
   - All print methods use `cat()` (R convention for print methods)
   - All support `max_line_length` parameter where text wrapping needed
   - Config objects are compact (no wrapping needed)

4. **Two Visual Modes**
   - **Compact mode**: for config objects (simple key-value display)
   - **Report mode**: for interpretation results (full styled report)

---

## Implementation Plan

### Phase 1: Create Shared Print Utilities

Create new file `R/shared_print.R` with reusable components:

```r
# Compact header for config objects
print_compact_header <- function(title) {
  paste0(
    cli::col_cyan(cli::style_bold(title)), "\n",
    cli::rule(line = 1, line_col = "grey", width = 40), "\n"
  )
}

# Key-value line for config objects
print_keyval <- function(key, value, indent = 2) {
  spaces <- strrep(" ", indent)
  paste0(spaces, cli::style_bold(key), ": ", value, "\n")
}

# Section header for config objects
print_section <- function(title, indent = 0) {
  spaces <- strrep(" ", indent)
  paste0("\n", spaces, cli::col_cyan(title), "\n")
}

# Bullet item
print_bullet <- function(text, indent = 2) {
  spaces <- strrep(" ", indent)
  paste0(spaces, cli::symbol$bullet, " ", text, "\n")
}
```

### Phase 2: Refactor Config Print Methods

**print.chat_session** - Add styling:
```
Factor Analysis Chat Session
────────────────────────────────────────
  Provider: anthropic
  Model: claude-3-haiku
  Created: 2024-01-15 10:30:00
  Interpretations: 3
  Tokens: 1500 input, 800 output
```

**print.llm_args** - Consistent format:
```
LLM Configuration
────────────────────────────────────────
  Provider: anthropic
  Model: claude-3-haiku
  Word limit: 100
  System prompt: (default)
  Echo: none
```

**print.interpretation_args**, **print.output_args**, **print.label_args** - Same pattern

### Phase 3: Refactor print.variable_labels

Add CLI styling, use `cat()` instead of `message()`:
```
Variable Labels
────────────────────────────────────────
  Label type: descriptive
  Variables: 25
  LLM: anthropic / claude-3-haiku

Token Usage
  Input: 450 | Output: 120 | Total: 570

Formatting
  Case: snake_case | Separator: '_'

Labels
  Variable      Label
  ─────────────────────────────────────
  item_1        cognitive_flexibility
  item_2        emotional_regulation
  ...
```

### Phase 4: Ensure FA/GM Consistency

Both already use the shared formatting dispatch. Verify:
- Same rule widths (80)
- Same color scheme
- Same section structure
- Normalization of interpretation text (already fixed)

### Phase 5: Update print.interpretation Base Method

Make the fallback method styled to match:
```r
print.interpretation <- function(x, ...) {
  if (!is.null(x$report) && nchar(x$report) > 0) {
    cat(wrap_text(x$report, 80), "\n")
  } else {
    # Styled fallback
    cat(print_compact_header(paste(model_name, "Interpretation")))
    cat(print_keyval("Components", length(x$suggested_names)))
    cat(print_keyval("LLM", paste(provider, "/", model)))
  }
  invisible(x)
}
```

---

## Detailed Changes by File

### New File: R/shared_print.R

```r
#' Print Utilities for Consistent Visual Output
#'
#' Shared formatting functions for print methods across the package.

# Constants
.PRINT_WIDTH <- 40  # Width for config object rules
.PRINT_INDENT <- 2  # Standard indentation

#' Create compact header
#' @keywords internal
print_header <- function(title, width = .PRINT_WIDTH) {
  paste0(
    cli::col_cyan(cli::style_bold(title)), "\n",
    cli::rule(line = 1, line_col = "grey", width = width), "\n"
  )
}

#' Create key-value line
#' @keywords internal
print_kv <- function(key, value, indent = .PRINT_INDENT) {
  spaces <- strrep(" ", indent)
  paste0(spaces, cli::style_bold(paste0(key, ":")), " ", value, "\n")
}

#' Create section header
#' @keywords internal
print_section <- function(title, indent = 0) {
  spaces <- strrep(" ", indent)
  paste0("\n", spaces, cli::col_cyan(title), "\n")
}

#' Create bullet item
#' @keywords internal
print_item <- function(text, indent = .PRINT_INDENT) {
  spaces <- strrep(" ", indent)
  paste0(spaces, cli::symbol$bullet, " ", text, "\n")
}

#' Create info item (for secondary info)
#' @keywords internal
print_info <- function(text, indent = .PRINT_INDENT) {
  spaces <- strrep(" ", indent)
  paste0(spaces, cli::col_grey(cli::symbol$info), " ",
         cli::col_grey(text), "\n")
}
```

### R/class_chat_session.R

```r
print.chat_session <- function(x, ...) {
  analysis_names <- c(fa = "Factor Analysis", gm = "Gaussian Mixture",
                      irt = "Item Response Theory", cdm = "Cognitive Diagnosis")
  title <- paste(analysis_names[x$analysis_type] %||% x$analysis_type,
                 "Chat Session")

  output <- paste0(
    print_header(title),
    print_kv("Provider", x$llm_provider),
    print_kv("Model", x$llm_model %||% "(default)"),
    print_kv("Created", format(x$created_at, "%Y-%m-%d %H:%M")),
    print_kv("Interpretations", x$n_interpretations),
    print_kv("Tokens", paste0(x$total_input_tokens, " in, ",
                               x$total_output_tokens, " out"))
  )

  cat(output)
  invisible(x)
}
```

### R/shared_config.R

Update all three print methods (interpretation_args, llm_args, output_args) to use shared utilities.

### R/label_args.R

Update print.label_args to use shared utilities.

### R/label_formatting.R

Update print.variable_labels:
- Use `cat()` instead of `message()`
- Use shared header/section utilities
- Keep table formatting for labels

---

## Migration Strategy

1. **Create shared_print.R** with utilities (non-breaking)
2. **Update config print methods** one at a time
3. **Update variable_labels print**
4. **Update chat_session print**
5. **Verify FA/GM print methods** are consistent
6. **Update tests** to match new output format

---

## Visual Comparison

### Before (Current)

```
-- LLM Configuration --

  * Provider: anthropic
  * Model: claude-3-haiku
  * Word limit: 100
```

### After (Unified)

```
LLM Configuration
────────────────────────────────────────
  Provider: anthropic
  Model: claude-3-haiku
  Word limit: 100
```

---

## Testing Considerations

- Update test-21-print-methods.R and test-21b-print-methods-gm.R
- Test that output goes to stdout (not stderr from message())
- Verify CLI styling renders correctly in various terminals
- Ensure non-interactive environments get clean output

---

## Files to Modify

1. **New**: `R/shared_print.R` (create)
2. **Modify**: `R/class_chat_session.R` (print.chat_session)
3. **Modify**: `R/shared_config.R` (3 print methods)
4. **Modify**: `R/label_args.R` (print.label_args)
5. **Modify**: `R/label_formatting.R` (print.variable_labels)
6. **Modify**: `R/class_interpretation.R` (print.interpretation base)
7. **Verify**: `R/fa_report.R`, `R/gm_report.R` (already good)
8. **Update**: Test files for new output format
