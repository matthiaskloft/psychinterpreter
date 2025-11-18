# Test Configuration for psychinterpreter

## Configuring LLM Provider and Model for Tests

By default, tests use **Ollama** with the **gpt-oss:20b-cloud** model. You can override these defaults using environment variables.

### Environment Variables

- **`TEST_LLM_PROVIDER`**: LLM provider to use (default: `"ollama"`)
- **`TEST_LLM_MODEL`**: LLM model to use (default: `"gpt-oss:20b-cloud"`)

### Usage Examples

#### Option 1: Set for Current R Session

```r
# Use Anthropic Claude
Sys.setenv(TEST_LLM_PROVIDER = "anthropic")
Sys.setenv(TEST_LLM_MODEL = "claude-3-5-haiku-20241022")

# Run tests
devtools::test()
```

#### Option 2: Set in .Renviron

Add to your `.Renviron` file (in project root or home directory):

```
TEST_LLM_PROVIDER=anthropic
TEST_LLM_MODEL=claude-3-5-haiku-20241022
```

Then restart R and run tests:

```r
devtools::test()
```

#### Option 3: Set for Single Test Run (Terminal)

```bash
# Linux/Mac
TEST_LLM_PROVIDER=openai TEST_LLM_MODEL=gpt-4o-mini R -e "devtools::test()"

# Windows (PowerShell)
$env:TEST_LLM_PROVIDER="openai"; $env:TEST_LLM_MODEL="gpt-4o-mini"; R -e "devtools::test()"
```

### Supported Providers

- **ollama** (default) - Requires local Ollama installation
- **anthropic** - Requires `ANTHROPIC_API_KEY` environment variable
- **openai** - Requires `OPENAI_API_KEY` environment variable

### Example Configurations

```r
# Anthropic Claude Haiku (fast, cheap)
Sys.setenv(
  TEST_LLM_PROVIDER = "anthropic",
  TEST_LLM_MODEL = "claude-3-5-haiku-20241022"
)

# OpenAI GPT-4o Mini (fast, cheap)
Sys.setenv(
  TEST_LLM_PROVIDER = "openai",
  TEST_LLM_MODEL = "gpt-4o-mini"
)

# Ollama with different model
Sys.setenv(
  TEST_LLM_PROVIDER = "ollama",
  TEST_LLM_MODEL = "llama3.1:8b"
)
```

### Rate Limiting

Tests automatically skip when encountering HTTP 429 (Too Many Requests) errors. If you hit rate limits:

1. Wait a few minutes and retry
2. Use a different provider/model
3. Run tests in smaller batches

### Verifying Configuration

Check current test configuration:

```r
# In R console or test file
psychinterpreter:::get_test_llm_provider()  # Shows current provider
psychinterpreter:::get_test_llm_model()     # Shows current model
```

---

**Last Updated**: 2025-11-18
