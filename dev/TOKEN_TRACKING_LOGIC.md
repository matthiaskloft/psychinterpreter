# Token Tracking Logic

## Overview

The psychinterpreter package implements a **dual-tier token tracking system** to accurately monitor LLM API usage across single and multiple factor analysis interpretations. This system handles provider-specific behaviors, particularly system prompt caching.

## Two Tracking Tiers

### 1. Cumulative Tracking (chat_fa objects)
- **Purpose**: Track total tokens across multiple interpretations using a persistent chat session
- **Storage**: `chat_fa$total_input_tokens` and `chat_fa$total_output_tokens`
- **Implementation**: Updated after each `interpret_fa()` call when `chat_session` parameter is provided

### 2. Per-Run Tracking (fa_interpretation results)
- **Purpose**: Report tokens used by individual interpretations
- **Storage**: `results$run_tokens` (list with `input` and `output` fields)
- **Implementation**: Extracted per-message from the chat object

## The System Prompt Caching Problem

**Issue**: LLM providers (Anthropic, Ollama, Azure, etc.) cache system prompts to reduce costs and latency. In persistent chat sessions:
- First call: System prompt tokens counted
- Subsequent calls: System prompt tokens NOT counted (cached)

**Consequence**: Naive token delta calculations can produce negative values:
```r
# Without protection:
delta = tokens_after - tokens_before  # May be negative if system prompt was cached!
```

## The Solution: Dual-Method Token Extraction

### For Cumulative Tracking (prevents negative accumulation)
```r
# Capture before LLM call
tokens_before <- chat$get_tokens(include_system_prompt = TRUE)

# ... make LLM call ...

# Capture after LLM call
tokens_after <- chat$get_tokens(include_system_prompt = TRUE)

# Calculate delta with max(0, ...) protection
delta_input <- max(0, tokens_after$input - tokens_before$input)
delta_output <- max(0, tokens_after$output - tokens_before$output)

# Update cumulative counters
chat_session$total_input_tokens <- chat_session$total_input_tokens + delta_input
chat_session$total_output_tokens <- chat_session$total_output_tokens + delta_output
```

### For Per-Run Reporting (accurate per-message counts)
```r
# Extract per-message tokens WITHOUT system prompt
tokens_per_message <- chat$get_tokens(include_system_prompt = FALSE)

# Get last user message tokens (the prompt just sent)
run_input_tokens <- last_user_message$tokens

# Get last assistant message tokens (the response just received)
run_output_tokens <- last_assistant_message$tokens
```

## Fallback Mechanism

If per-message token extraction fails (provider doesn't support it or returns incomplete data):
```r
if (run_input_tokens == 0 && delta_input > 0) {
  run_input_tokens <- delta_input
}
if (run_output_tokens == 0 && delta_output > 0) {
  run_output_tokens <- delta_output
}
```

## Code Locations

- **chat_fa.R** (lines 117-121): Initialize cumulative token counters
- **interpret_fa.R** (lines 1003-1104): Full token tracking implementation
  - Lines 1005-1025: Capture tokens before LLM call
  - Lines 1029-1041: Capture tokens after LLM call
  - Lines 1051-1052: Calculate delta with `max(0, ...)` protection
  - Lines 1062-1088: Extract per-message tokens for accurate per-run reporting
  - Lines 1092-1097: Fallback to delta if per-message extraction fails
  - Lines 1101-1104: Update cumulative counters in chat_fa object

## Why This Design?

1. **Prevents negative accumulation**: `max(0, ...)` ensures cumulative counters never decrease
2. **Accurate per-run reporting**: Per-message extraction without system prompt gives true per-analysis costs
3. **Robust fallback**: Works even when providers don't support per-message token tracking
4. **Handles caching**: Correctly accounts for cached system prompts across multiple interpretations

## Token Counting Caveats

- **Ollama**: Often returns 0 tokens (no tracking support)
- **Anthropic**: Caches system prompts aggressively; cumulative input tokens may undercount
- **OpenAI**: Generally accurate token reporting
- **Output tokens**: Typically accurate across all providers

Users can check `results$run_tokens` for per-interpretation counts and `print(chat_session)` for cumulative totals.
