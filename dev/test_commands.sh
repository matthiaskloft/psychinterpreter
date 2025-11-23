#!/bin/bash
# Quick test commands for psychinterpreter development
# Usage: source dev/test_commands.sh

# Quick smoke test (< 5 seconds)
alias test-quick='Rscript -e "source(\"tests/test_config.R\"); test_smoke()"'

# Fast unit tests only (< 30 seconds)
alias test-fast='PARALLEL_TESTS=true Rscript -e "source(\"tests/test_config.R\"); test_fast()"'

# Integration tests with LLM (2-3 minutes)
alias test-integration='PARALLEL_TESTS=true Rscript -e "source(\"tests/test_config.R\"); test_integration()"'

# Full test suite with parallel execution (< 1 minute)
alias test-all='PARALLEL_TESTS=true Rscript -e "devtools::test()"'

# R CMD check with parallel tests
alias test-check='PARALLEL_TESTS=true R CMD check .'

# Performance benchmarks (opt-in)
alias test-perf='Rscript -e "testthat::test_file(\"tests/testthat/test-zzz-performance.R\")"'

echo "Test aliases loaded:"
echo "  test-quick       - Smoke test (< 5s)"
echo "  test-fast        - Unit tests only (< 30s)"
echo "  test-integration - LLM tests (2-3 min)"
echo "  test-all         - Full suite (< 1 min)"
echo "  test-check       - R CMD check"
echo "  test-perf        - Performance benchmarks"
