# Token Tracking Fix V2: Per-Run Input Tokens Showing as 0

> **⚠️ SUPERSEDED:** This document is kept for historical reference. See `token_tracking_fix_v3.md` for the current implementation, which fixes an additional issue with system prompt inclusion in per-run reporting.

## Issue Reported
```
**Tokens:**
  Input: 0
  Output: 3554
```

Per-run input tokens were showing as 0 in reports when using Ollama with persistent chat sessions.

## Root Cause

The initial fix (v1) used `max(0, delta)` to prevent negative token accumulation:

```r
run_input_tokens <- max(0, tokens_after$input - tokens_before$input)
```

**Problem:** With Ollama's system prompt caching:
- Run 1: delta = 5000 tokens (includes system prompt)
- Run 2: delta = -500 tokens (system prompt cached, not recounted)
- Run 3: delta = -300 tokens (still cached)

Using `max(0, negative_delta)` resulted in:
- Run 2: `max(0, -500) = 0` ← Input tokens show as 0 in report
- Run 3: `max(0, -300) = 0` ← Input tokens show as 0 in report

## Solution: Two-Tier Token Tracking

**Key Insight:** We need DIFFERENT calculations for:
1. **Cumulative tracking** (chat_session counters) - Use delta with max(0, ...) to prevent negative accumulation
2. **Per-run reporting** (results$run_tokens) - Extract actual tokens from most recent messages

### Implementation (R/interpret_fa.R:1041-1082)

```r
# Calculate delta for cumulative tracking (prevents negative accumulation)
delta_input <- max(0, tokens_after$input - tokens_before$input)
delta_output <- max(0, tokens_after$output - tokens_before$output)

# Get actual per-run tokens from most recent messages (for accurate reporting)
run_input_tokens <- delta_input  # Default to delta
run_output_tokens <- delta_output

if (!is.null(tokens_after$df) && nrow(tokens_after$df) > 0) {
  # Get the last user message tokens
  user_messages <- tokens_after$df[tokens_after$df$role == "user", ]
  if (nrow(user_messages) > 0) {
    last_user_tokens <- user_messages$tokens[nrow(user_messages)]
    if (!is.na(last_user_tokens) && last_user_tokens > 0) {
      run_input_tokens <- last_user_tokens  # Use actual message tokens
    }
  }

  # Get the last assistant message tokens
  assistant_messages <- tokens_after$df[tokens_after$df$role == "assistant", ]
  if (nrow(assistant_messages) > 0) {
    last_assistant_tokens <- assistant_messages$tokens[nrow(assistant_messages)]
    if (!is.na(last_assistant_tokens) && last_assistant_tokens > 0) {
      run_output_tokens <- last_assistant_tokens  # Use actual message tokens
    }
  }
}

# Update cumulative counters using DELTA values (prevents negatives)
if (!is.null(chat_session)) {
  chat_session$total_input_tokens <- chat_session$total_input_tokens + delta_input
  chat_session$total_output_tokens <- chat_session$total_output_tokens + delta_output
}

# Store PER-RUN tokens for reporting (uses actual message tokens)
results$run_tokens <- list(input = run_input_tokens, output = run_output_tokens)
```

## How It Works

### For Per-Run Reporting (results$run_tokens)

1. After LLM call, get `tokens_df <- chat$get_tokens()`
2. Extract dataframe with all messages and their token counts
3. Filter to user messages: `tokens_df[tokens_df$role == "user", ]`
4. Get LAST user message: `user_messages$tokens[nrow(user_messages)]`
5. This gives actual tokens for THIS run's prompt

**Result:** Accurate per-run tokens regardless of provider caching

### For Cumulative Tracking (chat_session counters)

1. Calculate delta: `tokens_after - tokens_before`
2. Use `max(0, delta)` to prevent negative accumulation
3. Add to cumulative counters

**Result:** Cumulative counts never go negative (may undercount with Ollama)

## Expected Behavior Now

### With Ollama (System Prompt Caching)

```r
chat <- chat_fa("ollama", "gpt-oss:20b-cloud")

# Run 1
result1 <- interpret_fa(..., chat_session = chat)
# Report shows: Input: 4500, Output: 1200 ✓ (actual message tokens)
result1$run_tokens  # $input: 4500, $output: 1200 ✓

print(chat)
# Total tokens - Input: 4500, Output: 1200 ✓

# Run 2 (system prompt cached)
result2 <- interpret_fa(..., chat_session = chat)
# Report shows: Input: 4200, Output: 1150 ✓ (actual message tokens)
result2$run_tokens  # $input: 4200, $output: 1150 ✓

print(chat)
# Total tokens - Input: 4500, Output: 2350 ✓
# (cumulative input may stay same due to caching, output increases)

# Run 3 (system prompt still cached)
result3 <- interpret_fa(..., chat_session = chat)
# Report shows: Input: 4100, Output: 1180 ✓ (actual message tokens)
result3$run_tokens  # $input: 4100, $output: 1180 ✓

print(chat)
# Total tokens - Input: 4500, Output: 3530 ✓
# (cumulative input unchanged, output continues to increase)
```

### With Cloud Providers (No Caching)

```r
chat <- chat_fa("anthropic", "claude-haiku-4-5-20251001")

# Run 1
result1 <- interpret_fa(..., chat_session = chat)
# Report shows: Input: 4500, Output: 1200 ✓
print(chat)  # Total tokens - Input: 4500, Output: 1200 ✓

# Run 2
result2 <- interpret_fa(..., chat_session = chat)
# Report shows: Input: 4200, Output: 1150 ✓
print(chat)  # Total tokens - Input: 8700, Output: 2350 ✓

# Run 3
result3 <- interpret_fa(..., chat_session = chat)
# Report shows: Input: 4100, Output: 1180 ✓
print(chat)  # Total tokens - Input: 12800, Output: 3530 ✓
```

## Files Modified

- **R/interpret_fa.R:1025-1082** - Implemented two-tier token tracking
- **dev/test_token_tracking.R** - Updated documentation
- **dev/token_tracking_fix_v2.md** - This documentation

## Testing

Run the following to verify:

```r
library(psychinterpreter)

chat <- chat_fa("ollama", "gpt-oss:20b-cloud")

result1 <- interpret_fa(loadings, var_info, chat_session = chat)
print(result1)  # Check that Input tokens are NOT 0

result1$run_tokens$input  # Should show actual input tokens
result1$run_tokens$output  # Should show actual output tokens
```

## Key Takeaways

1. **Per-run tokens** (in reports and `results$run_tokens`) now show ACTUAL message tokens
2. **Cumulative tokens** (in `print(chat)`) use safe delta calculation
3. Works correctly with all providers (Ollama, OpenAI, Anthropic, etc.)
4. No more "Input: 0" in reports ✓
