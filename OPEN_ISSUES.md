# Refactoring and Abstraction

- the argument model_type should be called interpretation_class which is more generic. The default needs to be NULL. Proper validation needs to be ensured

- we need to find a more generic name for "diagnostics" as in create_diagnostics. The diagnostics are in fact data and reports generated from fit_results in interpret(). 


# DEVELOPER_GUIDE.md

- "4. **Backward Compatibility**
   - Legacy APIs maintained via deprecation wrappers": all legacy API should be removed.

- "## 3.4 Output Format System
### Supported Formats": not up to date. options should be "cli" and "markdown"
