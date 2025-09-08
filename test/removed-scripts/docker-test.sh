#!/bin/bash
# Docker Test Runner for xGPU CUDA 12.x Compatibility
# This script simplifies running CUDA compatibility tests in Docker containers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_ARCH="sm_61"
DEFAULT_CUDA_VERSION="12.6.0"
DOCKER_IMAGE="xgpu:cuda12-test"
CONTAINER_NAME="xgpu-cuda12-test"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check docker and nvidia-docker
check_requirements() {
    print_status "Checking requirements..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker --version &> /dev/null; then
        print_error "Cannot run docker commands"
        exit 1
    fi
    
    # Check if nvidia runtime is available
    if ! docker info | grep -q nvidia &> /dev/null; then
        print_warning "NVIDIA Docker runtime may not be installed"
        print_warning "You may need to install nvidia-docker2 package"
    fi
    
    print_success "Requirements check passed"
}

# Function to build the Docker image
build_image() {
    local cuda_version=${1:-$DEFAULT_CUDA_VERSION}
    print_status "Building Docker image with CUDA $cuda_version..."
    
    # Change to project root for build context
    cd "$PROJECT_ROOT"
    
    if docker build --build-arg CUDA_VERSION=$cuda_version -f test/Dockerfile -t $DOCKER_IMAGE .; then
        print_success "Docker image built successfully with CUDA $cuda_version"
    else
        print_error "Failed to build Docker image"
        cd "$SCRIPT_DIR"
        exit 1
    fi
    
    # Return to test directory
    cd "$SCRIPT_DIR"
}

# Function to create necessary directories
create_directories() {
    print_status "Creating output directories..."
    mkdir -p docker-results docker-logs
    mkdir -p docker-results-sm75 docker-logs-sm75
    mkdir -p docker-results-sm80 docker-logs-sm80
    print_success "Directories created"
}

# Function to run tests in container
run_tests() {
    local arch=${1:-$DEFAULT_ARCH}
    local test_type=${2:-"both"}
    
    print_status "Running tests with CUDA architecture: $arch"
    print_status "Test type: $test_type"
    
    # Remove existing container if it exists
    docker rm -f $CONTAINER_NAME &>/dev/null || true
    
    # Map test_type to container arguments
    local container_args=""
    case "$test_type" in
        "1d") container_args="1d" ;;
        "2d") container_args="2d" ;;
        "both"|"") container_args="" ;;  # Empty means run both tests (default)
        *) container_args="$test_type" ;;
    esac
    
    # Run the container
    if docker run --rm --gpus all \
        --name $CONTAINER_NAME \
        -e CUDA_ARCH=$arch \
        -v "$(pwd)/docker-results:/xgpu/results" \
        -v "$(pwd)/docker-logs:/xgpu/logs" \
        $DOCKER_IMAGE $container_args; then
        print_success "Tests completed successfully"
        show_results
    else
        print_error "Tests failed"
        print_status "Check logs in docker-logs/ directory"
        exit 1
    fi
}

# Function to show test results
show_results() {
    print_status "Test Results:"
    echo "================================================="
    
    if [ -d "docker-results" ] && [ "$(ls -A docker-results 2>/dev/null)" ]; then
        echo "Result files:"
        ls -la docker-results/
        echo ""
        
        # Show file summaries
        for file in docker-results/results_*.txt; do
            if [ -f "$file" ]; then
                echo "$(basename "$file"):"
                echo "  Lines: $(wc -l < "$file")"
                echo "  Size: $(du -h "$file" | cut -f1)"
            fi
        done
    else
        print_warning "No result files found in docker-results/"
    fi
    
    echo ""
    if [ -d "docker-logs" ] && [ "$(ls -A docker-logs 2>/dev/null)" ]; then
        echo "Log files:"
        ls -la docker-logs/
    else
        print_warning "No log files found in docker-logs/"
    fi
}

# Function to run interactive container
run_interactive() {
    local arch=${1:-$DEFAULT_ARCH}
    
    print_status "Starting interactive container with CUDA architecture: $arch"
    
    docker run --rm -it --gpus all \
        --name "${CONTAINER_NAME}-interactive" \
        -e CUDA_ARCH=$arch \
        -v "$(pwd)/docker-results:/xgpu/results" \
        -v "$(pwd)/docker-logs:/xgpu/logs" \
        -v "$(pwd)/src:/xgpu/src" \
        -v "$(pwd)/test:/xgpu/test" \
        $DOCKER_IMAGE bash
}

# Function to compare results (if comparison script exists)
compare_results() {
    if [ -f "test/compare_results.py" ]; then
        print_status "Comparing results..."
        if ls docker-results/results_1d_*.txt &>/dev/null && ls docker-results/results_2d_*.txt &>/dev/null; then
            python3 test/compare_results.py docker-results/results_1d_*.txt docker-results/results_2d_*.txt
        else
            print_warning "Not enough result files for comparison"
        fi
    else
        print_warning "Comparison script not found"
    fi
}

# Function to clean up Docker resources
cleanup() {
    print_status "Cleaning up Docker resources..."
    docker rm -f $CONTAINER_NAME "${CONTAINER_NAME}-interactive" &>/dev/null || true
    
    if [ "$1" = "all" ]; then
        print_status "Removing Docker image..."
        docker rmi $DOCKER_IMAGE &>/dev/null || true
        
        print_status "Removing result directories..."
        rm -rf docker-results docker-logs
        rm -rf docker-results-* docker-logs-*
    fi
    
    print_success "Cleanup completed"
}

# Function to show usage
show_usage() {
    cat << EOF
xGPU Docker Test Runner

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  build [CUDA_VER]          Build the Docker image (default: 12.6.0)
  test [ARCH] [TYPE]        Run tests (default: sm_61, both)
  interactive [ARCH]        Start interactive container (default: sm_61)
  results                   Show current test results
  compare                   Compare test results
  clean [all]               Clean up (all = remove image and results)
  
GPU Architectures:
  sm_61    - GTX 10xx series (default)
  sm_75    - RTX 20xx series  
  sm_80    - RTX 30xx series
  sm_86    - RTX 40xx series
  
Test Types:
  1d       - Run only 1D texture tests
  2d       - Run only 2D texture tests  
  both     - Run both 1D and 2D tests (default)

Examples:
  $0 build
  $0 build 12.5.1
  $0 test
  $0 test sm_75
  $0 test sm_80 1d
  $0 interactive sm_75
  $0 results
  $0 compare
  $0 clean

Prerequisites:
  - Docker installed and running
  - NVIDIA Docker runtime (nvidia-docker2)
  - NVIDIA GPU with compatible drivers

EOF
}

# Main script logic
case "${1:-}" in
    "build")
        check_requirements
        create_directories
        build_image "$2"
        ;;
    "test")
        check_requirements
        create_directories
        # Check if image exists
        if ! docker image inspect $DOCKER_IMAGE &>/dev/null; then
            print_status "Image not found, building..."
            build_image
        fi
        run_tests "${2:-$DEFAULT_ARCH}" "${3:-}"
        ;;
    "interactive"|"shell"|"bash")
        check_requirements
        create_directories
        if ! docker image inspect $DOCKER_IMAGE &>/dev/null; then
            print_status "Image not found, building..."
            build_image
        fi
        run_interactive "${2:-$DEFAULT_ARCH}"
        ;;
    "results"|"show")
        show_results
        ;;
    "compare")
        compare_results
        ;;
    "clean"|"cleanup")
        cleanup "$2"
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    "")
        print_error "No command specified"
        echo ""
        show_usage
        exit 1
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
