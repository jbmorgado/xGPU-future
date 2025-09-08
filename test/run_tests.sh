#!/bin/bash

# xGPU Texture Compatibility Test Runner
# This script runs both 1D and 2D texture tests and saves results

set -e  # Exit on any error

# Configuration
CUDA_ARCH=${CUDA_ARCH:-sm_61}
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$TEST_DIR/output"

echo "========================================="
echo "xGPU Texture Compatibility Test Runner"
echo "========================================="
echo "CUDA Architecture: $CUDA_ARCH"
echo "Test Directory: $TEST_DIR"
echo "Output Directory: $OUTPUT_DIR"
echo ""

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to run a test with specified texture dimension
run_test() {
    local texture_dim=$1
    local test_name="${texture_dim}D Texture Test"
    
    echo "========================================="
    echo "Running $test_name"
    echo "========================================="
    
    # Clean previous builds
    make -C "$TEST_DIR" clean
    
    # Build and run test
    make -C "$TEST_DIR" test-${texture_dim}d CUDA_ARCH="$CUDA_ARCH"
    
    echo "$test_name completed successfully"
    echo ""
}

# Function to display results summary
show_results() {
    echo "========================================="
    echo "Test Results Summary"
    echo "========================================="
    
    if [ -d "$OUTPUT_DIR" ] && [ "$(ls -A "$OUTPUT_DIR" 2>/dev/null)" ]; then
        echo "Results saved in $OUTPUT_DIR:"
        ls -la "$OUTPUT_DIR"
        echo ""
        
        # Show brief content of result files
        for file in "$OUTPUT_DIR"/results_*.txt; do
            if [ -f "$file" ]; then
                echo "--- $(basename "$file") ---"
                head -10 "$file"
                echo "... ($(wc -l < "$file") total lines)"
                echo ""
            fi
        done
    else
        echo "No result files found in $OUTPUT_DIR"
    fi
}

# Main execution
echo "Starting tests..."

# Check environment
echo "Checking environment..."
if ! command -v nvcc &> /dev/null && ! command -v /usr/local/cuda/bin/nvcc &> /dev/null; then
    echo "ERROR: nvcc not found in PATH or /usr/local/cuda/bin/"
    exit 1
fi

if ! command -v make &> /dev/null; then
    echo "ERROR: make not found in PATH" 
    exit 1
fi

echo "Environment OK"

# Run tests
run_test 1
run_test 2

# Show results
show_results

echo "========================================="
echo "All tests completed successfully!"
echo "========================================="
echo ""
echo "To copy results for comparison with another CUDA version:"
echo "  cp -r $OUTPUT_DIR /path/to/other/cuda/version/test/"
echo ""
echo "To compare results between CUDA versions:"
echo "  python3 compare_results.py output1/results_*.txt output2/results_*.txt"
