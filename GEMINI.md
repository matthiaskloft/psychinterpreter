# Generic Guidance

Read AGENT.md for all a quick reference for a generic agent when helping users with the **psychinterpreter** R package. 
There you will find the contents you would typically find in GEMINI.md.

# Gemini-Specific Guidance
This document contains guidance specific to using the `psychinterpreter` package with Google's Gemini models.

## API Configuration

For Gemini models, you need to set your Google Cloud project. You also need to be authenticated with Google Cloud.

```r
# Set environment variables for Vertex AI
Sys.setenv(GOOGLE_CLOUD_PROJECT = "your-gcp-project-id")
```

You can authenticate by logging in with the `gcloud` CLI:
```sh
gcloud auth application-default login
```

## Model Names

When using Gemini models, you will typically use a model name like `"gemini-1.0-pro"` in the `llm_model` argument.
