# Test script for verifying token tracking fix (V3)
# This script demonstrates the expected behavior after the V3 fix
# See dev/token_tracking_fix_v3.md for implementation details

library(psychinterpreter)

# Test 1: Create persistent chat session
cat("=== Test 1: Create chat session ===\n")
chat <- chat_fa("anthropic", "claude-haiku-4-5-20251001")
print(chat)
# Expected output:
# Factor Analysis Chat Session
# Provider: anthropic
# Model: claude-haiku-4-5-20251001
# Created: [timestamp]
# Interpretations run: 0

cat("\n=== Test 2: First interpretation ===\n")
# Assuming you have loadings1 and var_info1 prepared
# result1 <- interpret_fa(loadings1, var_info1, chat_session = chat)
# print(result1)  # Report should show per-run tokens only
# print(chat)
# Expected output:
# Interpretations run: 1
# Total tokens - Input: [X], Output: [Y]

cat("\n=== Test 3: Access per-run tokens ===\n")
# result1$run_tokens
# Expected output:
# $input
# [1] [X]
# $output
# [1] [Y]

cat("\n=== Test 4: Second interpretation ===\n")
# result2 <- interpret_fa(loadings2, var_info2, chat_session = chat)
# print(result2)  # Report should show ONLY this run's tokens
# print(chat)
# Expected output:
# Interpretations run: 2
# Total tokens - Input: [X+A], Output: [Y+B]  # Cumulative

cat("\n=== Test 5: Verify per-run tokens are separate ===\n")
# result1$run_tokens  # Should still show run 1's tokens
# result2$run_tokens  # Should show run 2's tokens only

cat("\n=== Test 6: Reset session ===\n")
# chat <- reset.chat_fa(chat)
# print(chat)
# Expected output:
# Interpretations run: 0
# Total tokens - Input: 0, Output: 0

cat("\n=== Key Fixes Applied (V3) ===\n")
cat("1. chat_fa objects now use environments (reference semantics)\n")
cat("2. n_interpretations counter now persists across calls\n")
cat("3. Cumulative token tracking added to chat_fa objects\n")
cat("4. Per-run tokens captured and stored in results$run_tokens\n")
cat("5. Reports display per-run tokens, print(chat) shows cumulative\n")
cat("6. Token tracking uses two-tier approach with SEPARATE get_tokens() calls:\n")
cat("   - Cumulative: get_tokens(include_system_prompt = TRUE) with delta + max(0, ...)\n")
cat("   - Per-run: get_tokens(include_system_prompt = FALSE) for accurate message tokens\n")
cat("   - System prompt excluded from per-run counts (V3 fix)\n")
cat("   - Handles Ollama's system prompt caching correctly\n")

cat("\n=== How Token Tracking Works ===\n")
cat("Per-run tokens (results$run_tokens):\n")
cat("- Extracts tokens from the LAST user and assistant messages\n")
cat("- Accurate for all providers, including Ollama\n")
cat("- Shows actual tokens used in THIS specific interpretation\n\n")

cat("Cumulative tokens (print(chat)):\n")
cat("- Uses delta calculation with negative prevention\n")
cat("- May undercount with Ollama due to system prompt caching\n")
cat("- Shows approximate total across all interpretations\n\n")

cat("Best practice:\n")
cat("- Use results$run_tokens for accurate per-interpretation counts\n")
cat("- Use print(chat) for rough total usage estimates\n")
