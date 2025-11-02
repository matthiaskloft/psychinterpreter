# Test script for verifying plot uses suggested factor names
# This demonstrates the expected behavior after the fix

library(psychinterpreter)

cat("=== Plot with Suggested Factor Names ===\n\n")

cat("Before the fix:\n")
cat("- plot(results) showed 'Factor 1', 'Factor 2', etc. on x-axis\n")
cat("- Generic factor names instead of meaningful LLM-generated names\n\n")

cat("After the fix:\n")
cat("- plot(results) now shows LLM-generated names like 'Extraversion', 'Neuroticism', etc.\n")
cat("- Factor names are automatically pulled from results$suggested_names\n")
cat("- Falls back to 'Factor 1', 'Factor 2' if suggested names not available\n\n")

cat("Example usage:\n")
cat("```r\n")
cat("# Get interpretation results\n")
cat("results <- interpret_fa(loadings, var_info, silent = TRUE)\n\n")

cat("# Plot will now use suggested names\n")
cat("plot(results)\n")
cat("# X-axis labels: 'Agreeableness', 'Conscientiousness', 'Extraversion', etc.\n")
cat("# Instead of: 'Factor 1', 'Factor 2', 'Factor 3', etc.\n\n")

cat("# You can still customize the plot\n")
cat("p <- plot(results)\n")
cat("p + ggplot2::labs(title = 'My Custom Title')\n\n")

cat("# Save to file with meaningful factor names\n")
cat("ggsave('loadings_with_names.png', p, width = 10, height = 8)\n")
cat("```\n\n")

cat("Implementation details:\n")
cat("- R/visualization.R:87-99 - Added name mapping logic\n")
cat("- Extracts suggested_names from fa_interpretation object\n")
cat("- Creates factor_name_map: list('Factor 1' = 'Extraversion', ...)\n")
cat("- Replaces factor names in plot data before visualization\n")
cat("- Backward compatible: works even if suggested_names is NULL\n\n")

cat("What gets replaced:\n")
cat("Original column names → Suggested names\n")
cat("'Factor 1'           → 'Extraversion'\n")
cat("'Factor 2'           → 'Agreeableness'\n")
cat("'Factor 3'           → 'Conscientiousness'\n")
cat("etc.\n")
