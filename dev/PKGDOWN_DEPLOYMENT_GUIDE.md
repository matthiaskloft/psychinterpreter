# pkgdown Site Deployment Guide

This guide explains how to deploy the psychinterpreter package website using pkgdown and GitHub Pages.

## Overview

The package website is automatically built and deployed using GitHub Actions whenever you push to the `main` branch. The site will be available at:

**https://matthiaskloft.github.io/psychinterpreter/**

## Files Created

### 1. `_pkgdown.yml`
Main configuration file for the pkgdown site. Includes:
- **Template**: Bootstrap 5 with Flatly theme
- **Navbar**: Navigation structure with links to reference, articles, and GitHub
- **Reference**: Functions organized into logical sections:
  - Main Interpretation Functions
  - Visualization
  - Export Functions
  - Utility Functions
  - Print Methods
- **Articles**: Getting Started guide
- **Footer**: Credits and links

### 2. `README.md`
Enhanced package homepage with:
- Feature highlights
- Installation instructions
- Quick start examples
- Multi-analysis workflow examples
- LLM provider configuration
- Documentation links
- Citation information

### 3. `NEWS.md`
Comprehensive changelog documenting:
- New features
- Improvements
- Bug fixes
- Technical details
- Known issues

### 4. `.github/workflows/pkgdown.yaml`
GitHub Actions workflow that:
- Triggers on push to main/master, pull requests, releases, or manual dispatch
- Sets up R environment with dependencies
- Builds pkgdown site
- Deploys to gh-pages branch

### 5. `.github/workflows/R-CMD-check.yaml`
GitHub Actions workflow for continuous integration:
- Runs R CMD check on multiple OS (macOS, Windows, Ubuntu)
- Tests on multiple R versions (devel, release, oldrel-1)
- Provides badges for README

## Setup Instructions

### Step 1: Enable GitHub Pages

1. Go to your repository on GitHub: https://github.com/matthiaskloft/psychinterpreter
2. Click **Settings** → **Pages**
3. Under "Source", select:
   - Branch: `gh-pages`
   - Folder: `/ (root)`
4. Click **Save**

### Step 2: Trigger Initial Deployment

You have two options:

**Option A: Push to main branch**
```bash
git add .
git commit -m "Add pkgdown configuration"
git push
```

**Option B: Manual trigger**
1. Go to **Actions** tab on GitHub
2. Select "pkgdown.yaml" workflow
3. Click "Run workflow" → "Run workflow"

### Step 3: Wait for Deployment

1. Go to the **Actions** tab
2. Watch the "pkgdown.yaml" workflow run
3. Once complete (green checkmark), your site should be live
4. Visit: https://matthiaskloft.github.io/psychinterpreter/

## Local Development

### Build Site Locally

To preview the site before deploying:

```r
# Install pkgdown if needed
install.packages("pkgdown")

# Build the site
pkgdown::build_site()

# Preview in browser
pkgdown::preview_site()
```

The site will be built in the `docs/` directory (which is gitignored).

### Build Individual Components

```r
# Just the reference documentation
pkgdown::build_reference()

# Just the articles
pkgdown::build_articles()

# Just the home page
pkgdown::build_home()

# Just the news/changelog
pkgdown::build_news()
```

## Customization

### Update Theme Colors

Edit `_pkgdown.yml`:

```yaml
template:
  bslib:
    primary: "#0054AD"  # Change this hex color
```

### Add New Articles

1. Create new `.qmd` or `.Rmd` file in `vignettes/articles/`
2. Add to `_pkgdown.yml`:

```yaml
articles:
  - title: Getting Started
    contents:
      - 01-Basic_Usage
      - 02-Advanced-Features  # Add new article
```

### Reorganize Reference

Edit the `reference:` section in `_pkgdown.yml`:

```yaml
reference:
  - title: "New Section"
    desc: "Description of this section"
    contents:
      - function_name_1
      - function_name_2
```

### Change Navbar Links

Edit `_pkgdown.yml`:

```yaml
navbar:
  structure:
    left: [intro, reference, articles, news, changelog]  # Add/remove items
```

## Troubleshooting

### Site Not Deploying

1. **Check Actions tab** for error messages
2. **Verify gh-pages branch exists**:
   ```bash
   git branch -r | grep gh-pages
   ```
3. **Check GitHub Pages settings** are correct
4. **Review workflow logs** for specific errors

### Build Errors

Common issues:

1. **Missing dependencies**:
   - Add to `DESCRIPTION` file under `Suggests:`
   - Update `.github/workflows/pkgdown.yaml` if needed

2. **Broken links in documentation**:
   - Check roxygen2 documentation
   - Verify article/vignette file paths

3. **Theme/styling issues**:
   - Validate YAML syntax in `_pkgdown.yml`
   - Check Bootstrap version compatibility

### Badge Not Showing

If the pkgdown badge in README shows as failing:

1. Wait for first successful deployment
2. Verify workflow name matches in README and `.github/workflows/`
3. Check workflow is not disabled in repository settings

## File Structure

After deployment, your repository will have:

```
psychinterpreter/
├── _pkgdown.yml              # Site configuration
├── README.md                 # Homepage content
├── NEWS.md                   # Changelog
├── .github/
│   └── workflows/
│       ├── pkgdown.yaml      # Deployment workflow
│       └── R-CMD-check.yaml  # CI workflow
├── vignettes/
│   └── articles/
│       └── 01-Basic_Usage.qmd
├── docs/                     # Built site (local only, gitignored)
└── [other package files]
```

## Updating the Site

The site automatically rebuilds when you:

1. Push to main/master branch
2. Create a new release
3. Manually trigger the workflow

**Important files to update:**

- `NEWS.md` - Add new version entries
- `_pkgdown.yml` - Update navigation/structure
- `README.md` - Update examples/features
- Roxygen documentation in R files
- Articles in `vignettes/articles/`

## Additional Resources

- [pkgdown documentation](https://pkgdown.r-lib.org/)
- [GitHub Pages documentation](https://docs.github.com/en/pages)
- [Bootstrap themes](https://bootswatch.com/)
- [r-lib/actions](https://github.com/r-lib/actions)

## Next Steps

1. ✅ Files created and configured
2. ⏳ Push changes to GitHub
3. ⏳ Enable GitHub Pages in repository settings
4. ⏳ Wait for first deployment
5. ⏳ Visit your site!

Once deployed, share your site URL:
**https://matthiaskloft.github.io/psychinterpreter/**
