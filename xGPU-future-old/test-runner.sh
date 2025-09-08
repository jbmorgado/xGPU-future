#!/bin/bash

# xGPU Test Runner - Wrapper to run tests from project root
# This script forwards all arguments to the test scripts in the test/ directory

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/test"

# Print usage if no arguments provided
if [[ $# -eq 0 ]]; then
    echo "xGPU Test Runner"
    echo "================"
    echo ""
    echo "Available test scripts:"
    echo "  basic           - Run basic test suite (direct testing, no Docker)"
    echo "  cross-version   - Run cross-version CUDA compatibility tests (Docker-based)"
    echo ""
    echo "Usage:"
    echo "  $0 basic                         # Quick local testing without Docker"
    echo "  $0 cross-version [options]      # Comprehensive CUDA migration validation"
    echo ""
    echo "Examples:"
    echo "  $0 basic                                 # Run quick 1D/2D texture tests"
    echo "  $0 cross-version --comprehensive        # Run all cross-version configurations"
    echo "  $0 cross-version -c micro               # Run micro configuration"
    echo "  $0 cross-version --help                 # Show cross-version test options"
    echo ""
    echo "Test Strategy:"
    echo "  - Use 'basic' for fast development iteration and quick verification"
    echo "  - Use 'cross-version' for comprehensive CUDA 11→12 migration validation"
    exit 0
fi

# Parse the first argument to determine which test to run
TEST_TYPE="$1"
shift

case "$TEST_TYPE" in
    cross-version|cv)
        echo "Running cross-version CUDA compatibility tests..."
        exec "$TEST_DIR/cross-version-test.sh" "$@"
        ;;
    basic|b)
        echo "Running basic test suite..."
        exec "$TEST_DIR/run_tests.sh" "$@"
        ;;
    *)
        echo "Error: Unknown test type '$TEST_TYPE'"
        echo ""
        echo "Available test types: cross-version, basic"
        echo "Run '$0' without arguments to see usage information."
        exit 1
        ;;
esac
