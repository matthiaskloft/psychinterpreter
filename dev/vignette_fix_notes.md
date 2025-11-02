# Vignette Configuration Fix

## Issue
R CMD check was reporting:
```
WARNING
Files in the 'vignettes' directory but no files in 'inst/doc':
  'articles/01-Basic_Usage.qmd'
Package has no Sweave vignette sources and no VignetteBuilder field.
```

## Root Cause
The package had Quarto vignettes (.qmd files) in `vignettes/articles/` but:
1. No `VignetteBuilder` field declared in DESCRIPTION
2. Missing `knitr` and `rmarkdown` in Suggests dependencies

## Fix Applied

### 1. DESCRIPTION file (lines 24-28)
Added VignetteBuilder and required packages:
```
Suggests:
  testthat (>= 3.0.0),
  knitr,
  rmarkdown
VignetteBuilder: knitr
```

### 2. .Rbuildignore (lines 8-9)
Added patterns to exclude Quarto build artifacts:
```
^vignettes/.*\.rmarkdown$
^vignettes/.*_files/
```

This prevents intermediate files from being included in the package build.

### 3. CLAUDE.md (line 215)
Updated documentation to reflect actual vignette filename:
```
└── 01-Basic_Usage.qmd   # Example usage with BFI dataset
```

## Files Modified
- `DESCRIPTION` - Added VignetteBuilder and dependencies
- `.Rbuildignore` - Added Quarto artifact patterns
- `CLAUDE.md` - Corrected vignette filename

## Verification
Run `R CMD check` or `devtools::check()` to verify the warning is resolved.

## Notes
- The vignette is in `vignettes/articles/` which is used for pkgdown articles
- These articles will appear on the pkgdown website but not in R's vignette system
- For official R vignettes (accessible via `vignette()`), files should be in `vignettes/` directly
- Current setup is appropriate for pkgdown-only documentation
