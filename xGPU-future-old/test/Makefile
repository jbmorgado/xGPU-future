# xGPU Cross-Version Compatibility Test Makefile
# This Makefile can be copied to CUDA 11.x repositories for comparison testing

# Compiler settings
CC = gcc
CXX = g++
NVCC = nvcc

# Default CUDA architecture - should be set for your specific GPU
CUDA_ARCH ?= sm_61

# Default texture dimension - can be overridden
TEXTURE_DIM ?= 1

# CUDA paths (adjust if needed)
CUDA_LIBDIR = /usr/local/cuda/lib64
CUDA_INCDIR = /usr/local/cuda/include

# Compilation flags
CFLAGS = -O3 -Wall
CXXFLAGS = -O3 -Wall
NVCCFLAGS = -O3 -arch=$(CUDA_ARCH) --ptxas-options=-v

# Define directories
SRC_DIR = ../src
OUTPUT_DIR = output

# Test program
TEST_PROGRAM = texture_test

# Build targets
.PHONY: all clean test test-1d test-2d test-both help

all: $(TEST_PROGRAM)

# Build the test program
$(TEST_PROGRAM): $(TEST_PROGRAM).o memory_monitor.o libxgpu.so
	$(CXX) -o $@ $(TEST_PROGRAM).o memory_monitor.o -L. -lxgpu -L$(CUDA_LIBDIR) -lcudart

# Compile test program object file
$(TEST_PROGRAM).o: $(TEST_PROGRAM).c memory_monitor.h
	$(CC) $(CFLAGS) -I$(CUDA_INCDIR) -I$(SRC_DIR) -DTEXTURE_DIM=$(TEXTURE_DIM) -c -o $@ $<

# Compile memory monitor object file
memory_monitor.o: memory_monitor.c memory_monitor.h
	$(CC) $(CFLAGS) -I$(CUDA_INCDIR) -c -o $@ $<

# Build the xGPU library (copying from src directory)
libxgpu.so: $(SRC_DIR)/libxgpu.so
	cp $(SRC_DIR)/libxgpu.so .

# Build the xGPU library in src directory
$(SRC_DIR)/libxgpu.so:
	$(MAKE) -C $(SRC_DIR) TEXTURE_DIM=$(TEXTURE_DIM) CUDA_ARCH=$(CUDA_ARCH) libxgpu.so

# Test targets
test: test-both

test-1d:
	@echo "========================================="
	@echo "Running 1D Texture Test"
	@echo "========================================="
	$(MAKE) clean
	$(MAKE) TEXTURE_DIM=1 CUDA_ARCH=$(CUDA_ARCH)
	LD_LIBRARY_PATH=. ./$(TEST_PROGRAM)
	@echo "1D test completed. Check output/ directory for results."

test-2d:
	@echo "========================================="
	@echo "Running 2D Texture Test"
	@echo "========================================="
	$(MAKE) clean
	$(MAKE) TEXTURE_DIM=2 CUDA_ARCH=$(CUDA_ARCH)
	LD_LIBRARY_PATH=. ./$(TEST_PROGRAM)
	@echo "2D test completed. Check output/ directory for results."

test-both: test-1d test-2d
	@echo "========================================="
	@echo "Both tests completed!"
	@echo "========================================="
	@echo "Results are in the output/ directory:"
	@ls -la output/
	@echo ""
	@echo "You can now copy the output/ directory to compare with other CUDA versions."

# Clean targets
clean:
	rm -f $(TEST_PROGRAM) $(TEST_PROGRAM).o memory_monitor.o libxgpu.so

clean-all: clean
	rm -f output/*.txt

# Help target
help:
	@echo "xGPU Cross-Version Compatibility Test"
	@echo "====================================="
	@echo ""
	@echo "Usage:"
	@echo "  make test           - Run both 1D and 2D texture tests"
	@echo "  make test-1d        - Run only 1D texture test"
	@echo "  make test-2d        - Run only 2D texture test"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make clean-all      - Clean build artifacts and output files"
	@echo ""
	@echo "Options:"
	@echo "  CUDA_ARCH=sm_XX     - Set CUDA architecture (default: $(CUDA_ARCH))"
	@echo "  TEXTURE_DIM=X       - Set texture dimension 1 or 2 (default: $(TEXTURE_DIM))"
	@echo ""
	@echo "Examples:"
	@echo "  make test CUDA_ARCH=sm_75"
	@echo "  make test-1d CUDA_ARCH=sm_80"
	@echo ""
	@echo "Cross-version testing workflow:"
	@echo "  1. Run 'make test' in your CUDA 12.x repository"
	@echo "  2. Copy this test/ directory to your CUDA 11.x repository"  
	@echo "  3. Run 'make test' in the CUDA 11.x repository"
	@echo "  4. Copy the output/ directory back to CUDA 12.x repository"
	@echo "  5. Use scripts/compare_results.py to compare outputs"
