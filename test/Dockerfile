# xGPU CUDA 12.x Compatibility Test Container
# This Dockerfile creates a container with CUDA 12.x for testing xGPU texture compatibility

# Use NVIDIA's CUDA 12.x development image with Ubuntu
ARG CUDA_VERSION=12.9.1
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_ARCH=sm_61
ENV TEXTURE_DIM=1

# Set working directory
WORKDIR /xgpu

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    python3 \
    python3-pip \
    git \
    vim \
    htop \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages for result comparison
RUN pip3 install numpy matplotlib

# Create directories for output and results
RUN mkdir -p /xgpu/test/output \
    && mkdir -p /xgpu/results \
    && mkdir -p /xgpu/logs

# Copy the entire xGPU source code
COPY . /xgpu/

# Set proper permissions
RUN chmod +x /xgpu/test/run_tests.sh \
    && chmod +x /xgpu/src/gen_xgpu_version.sh

# Build the xGPU library first
RUN cd /xgpu/src && \
    make clean && \
    make CUDA_ARCH=$CUDA_ARCH libxgpu.so && \
    echo "xGPU library built successfully"

# Create entrypoint script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "================================================="\n\
echo "xGPU CUDA 12.x Compatibility Test Container"\n\
echo "================================================="\n\
echo "CUDA Version: $(nvcc --version | grep release)"\n\
echo "GPU Architecture: $CUDA_ARCH"\n\
echo "Container Hostname: $(hostname)"\n\
echo "Date: $(date)"\n\
echo "================================================="\n\
\n\
# Function to run tests with error handling\n\
run_test() {\n\
    local test_type=$1\n\
    echo ""\n\
    echo "Running $test_type test..."\n\
    echo "----------------------------------------"\n\
    \n\
    if cd /xgpu/test && make test-$test_type CUDA_ARCH=$CUDA_ARCH 2>&1 | tee /xgpu/logs/${test_type}_test.log; then\n\
        echo "$test_type test completed successfully"\n\
        # Copy results to persistent location\n\
        cp -v /xgpu/test/output/*.txt /xgpu/results/ 2>/dev/null || echo "No results files to copy for $test_type"\n\
        return 0\n\
    else\n\
        echo "ERROR: $test_type test failed!"\n\
        return 1\n\
    fi\n\
}\n\
\n\
# Default behavior: run both tests\n\
if [ $# -eq 0 ]; then\n\
    echo "Running both 1D and 2D texture tests..."\n\
    \n\
    run_test "1d"\n\
    run_test "2d"\n\
    \n\
    echo ""\n\
    echo "========================================"\n\
    echo "All Tests Completed!"\n\
    echo "========================================"\n\
    echo "Results saved in /xgpu/results/"\n\
    ls -la /xgpu/results/\n\
    \n\
    echo ""\n\
    echo "Logs saved in /xgpu/logs/"\n\
    ls -la /xgpu/logs/\n\
    \n\
    # Show summary of results\n\
    echo ""\n\
    echo "Test Summary:"\n\
    echo "----------------------------------------"\n\
    for file in /xgpu/results/results_*.txt; do\n\
        if [ -f "$file" ]; then\n\
            echo "File: $(basename $file)"\n\
            echo "  Lines: $(wc -l < $file)"\n\
            echo "  Size: $(du -h $file | cut -f1)"\n\
        fi\n\
    done\n\
\n\
elif [ "$1" = "bash" ]; then\n\
    # Interactive mode\n\
    echo "Starting interactive shell..."\n\
    exec bash\n\
\n\
elif [ "$1" = "1d" ] || [ "$1" = "2d" ]; then\n\
    # Run specific test\n\
    run_test "$1"\n\
\n\
elif [ "$1" = "build" ]; then\n\
    # Just build without testing\n\
    echo "Building xGPU library..."\n\
    cd /xgpu/src && make clean && make CUDA_ARCH=$CUDA_ARCH\n\
    cd /xgpu/test && make clean && make CUDA_ARCH=$CUDA_ARCH\n\
    echo "Build completed successfully"\n\
\n\
else\n\
    echo "Usage: $0 [1d|2d|build|bash]"\n\
    echo "  (no args)  - Run both 1D and 2D tests (default)"\n\
    echo "  1d         - Run only 1D texture test"\n\
    echo "  2d         - Run only 2D texture test" \n\
    echo "  build      - Build libraries without testing"\n\
    echo "  bash       - Start interactive shell"\n\
    exit 1\n\
fi\n\
' > /xgpu/entrypoint.sh && chmod +x /xgpu/entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/xgpu/entrypoint.sh"]

# Default command (run both tests)
CMD []

# Add labels for documentation
LABEL maintainer="xGPU Team"
LABEL description="CUDA 12.x compatibility testing container for xGPU"
LABEL version="1.0"
LABEL cuda.version="12.6"
