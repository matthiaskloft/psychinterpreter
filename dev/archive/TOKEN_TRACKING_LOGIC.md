# Token Tracking Logic

## Overview

The psychinterpreter package implements a **dual-tier token tracking system** to accurately monitor LLM API usage across single and multiple factor analysis interpretations. This system handles provider-specific behaviors, particularly system prompt caching, and conditionally includes system prompt tokens based on session type.

## Two Tracking Tiers

### 1. Cumulative Tracking (chat_fa objects)
- **Purpose**: Track total tokens across multiple interpretations using a persistent chat session
- **Storage**:
  - `chat_fa$total_input_tokens`: Cumulative user prompt tokens (excludes system prompt)
  - `chat_fa$total_output_tokens`: Cumulative assistant response tokens
  - `chat_fa$system_prompt_tokens`: One-time system prompt cost (tracked separately)
- **Implementation**: Updated after each `interpret_fa()` call when `chat_session` parameter is provided

### 2. Per-Run Tracking (fa_interpretation results)
- **Purpose**: Report tokens used by individual interpretations
- **Storage**:
  - `results$run_tokens`: List with `input` and `output` fields
  - `results$used_chat_session`: Boolean flag indicating if persistent session was used
- **Implementation**: Extracted per-message from the chat object, conditionally including system prompt

## The System Prompt Caching Problem

**Issue**: LLM providers (Anthropic, Ollama, Azure, etc.) cache system prompts to reduce costs and latency. In persistent chat sessions:
- First call: System prompt tokens counted
- Subsequent calls: System prompt tokens NOT counted (cached)

**Consequence**: Naive token delta calculations can produce negative values:
```r
# Without protection:
delta = tokens_after - tokens_before  # May be negative if system prompt was cached!
```

## The Solution: Conditional Token Extraction + Dual-Method Tracking

### For Cumulative Tracking (prevents negative accumulation)
```r
# Capture before LLM call (WITH system prompt for delta calculation)
tokens_before <- chat$get_tokens(include_system_prompt = TRUE)

# ... make LLM call ...

# Capture after LLM call (WITH system prompt for delta calculation)
tokens_after <- chat$get_tokens(include_system_prompt = TRUE)

# Calculate delta with max(0, ...) protection
delta_input <- max(0, tokens_after$input - tokens_before$input)
delta_output <- max(0, tokens_after$output - tokens_before$output)

# Update cumulative counters (only if using persistent chat_session)
if (!is.null(chat_session)) {
  chat_session$total_input_tokens <- chat_session$total_input_tokens + delta_input
  chat_session$total_output_tokens <- chat_session$total_output_tokens + delta_output
}
```

### For Per-Run Reporting (conditional system prompt inclusion)
```r
# CONDITIONAL: Include system prompt based on session type
# - Temporary session (chat_session = NULL): Include system prompt (it's part of THIS run)
# - Persistent session (chat_session provided): Exclude system prompt (sent previously)
tokens_per_message <- chat$get_tokens(include_system_prompt = is.null(chat_session))

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

- **chat_fa.R**:
  - Lines 109-119: Extract and store system prompt tokens
  - Lines 131-136: Initialize cumulative token counters and system prompt field
  - Lines 157-162: Display token counts in print method (including system prompt)
- **interpret_fa.R**:
  - Lines 1003-1104: Full token tracking implementation
  - Lines 1005-1025: Capture tokens before LLM call (include_system_prompt = TRUE)
  - Lines 1029-1041: Capture tokens after LLM call (include_system_prompt = TRUE)
  - Lines 1051-1052: Calculate delta with `max(0, ...)` protection
  - Lines 1063-1067: Extract per-message tokens with CONDITIONAL system prompt inclusion
  - Lines 1069-1088: Parse per-message token data for last user/assistant messages
  - Lines 1092-1097: Fallback to delta if per-message extraction fails
  - Lines 1101-1104: Update cumulative counters in chat_fa object
  - Line 1327: Store session type flag (`used_chat_session`)
- **fa_report_functions.R**:
  - Lines 67-84: Markdown format fallback (conditional system prompt)
  - Lines 280-297: Text format fallback (conditional system prompt)

## Why This Design?

1. **Prevents negative accumulation**: `max(0, ...)` ensures cumulative counters never decrease
2. **Accurate per-run reporting**: Conditional system prompt inclusion ensures correct per-analysis costs
   - Temporary sessions: System prompt IS part of the run cost → included in run_tokens
   - Persistent sessions: System prompt was sent previously → excluded from run_tokens
3. **Transparent system prompt cost**: Separate `system_prompt_tokens` field shows one-time cost
4. **Robust fallback**: Works even when providers don't support per-message token tracking
5. **Handles caching**: Correctly accounts for cached system prompts across multiple interpretations
6. **Backwards compatible**: Fallback uses `!isTRUE(used_chat_session)` which defaults to TRUE for old results

## Expected Output Behavior

### print(interpretation) - Per-Run Tokens
Shows tokens for THIS specific interpretation:
- **Temporary session** (no chat_session): Includes system prompt + user prompt + assistant response
- **Persistent session** (with chat_session): Excludes system prompt, only user prompt + assistant response

### print(chat) - Cumulative Tokens
Shows tokens across ALL interpretations in this session:
- **Total tokens - Input**: Sum of all user prompts (excludes system prompt)
- **Total tokens - Output**: Sum of all assistant responses
- **System prompt tokens**: One-time cost of system prompt (tracked separately)

**Example output:**
```
Factor Analysis Chat Session
Provider: anthropic
Model: claude-haiku-4-5-20251001
Created: 2025-11-03 14:32:10
Interpretations run: 3
Total tokens - Input: 1250, Output: 890
System prompt tokens: 487
```

## Token Counting Caveats

- **Ollama**: Often returns 0 tokens (no tracking support)
- **Anthropic**: Caches system prompts aggressively; cumulative input tokens may undercount
- **OpenAI**: Generally accurate token reporting
- **Output tokens**: Typically accurate across all providers

Users can check:
- `results$run_tokens` for per-interpretation counts
- `print(interpretation)` to see per-run token display
- `print(chat_session)` for cumulative totals with separate system prompt cost
