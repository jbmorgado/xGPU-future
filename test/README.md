# xGPU Texture Compatibility Test Suite

This directory contains a self-contained test suite for comparing xGPU computation results across different CUDA versions and texture dimensions.

## Purpose

After updating xGPU to work with CUDA 12.x (which deprecated texture references in favor of texture objects), this test suite verifies that:
1. Both 1D and 2D texture modes produce consistent results
2. Results are consistent between CUDA 11.x and CUDA 12.x versions
3. The texture object migration maintains computational accuracy

## Files

- `texture_test.c` - Main test program that runs xGPU correlation with deterministic input
- `Makefile` - Build system for compiling tests with different texture dimensions  
- `run_tests.sh` - Shell script to run both 1D and 2D texture tests automatically
- `compare_results.py` - Python script to compare result files between different runs
- `output/` - Directory where test results are saved

## Quick Start

### Run tests on current system:
```bash
make test-both
```

### Run individual tests:
```bash
make test-1d    # Test with 1D textures
make test-2d    # Test with 2D textures
```

### Cross-CUDA version testing workflow:

1. **In your CUDA 12.x repository:**
   ```bash
   cd test/
   make test-both
   ```

2. **Copy test directory to CUDA 11.x repository:**
   ```bash
   cp -r test/ /path/to/cuda11/repo/
   ```

3. **In your CUDA 11.x repository:**
   ```bash
   cd test/
   make test-both
   ```

4. **Copy results back to CUDA 12.x for comparison:**
   ```bash
   cp -r output/ /path/to/cuda12/repo/test/output_cuda11/
   ```

5. **Compare results:**
   ```bash
   python3 compare_results.py output/results_*.txt output_cuda11/results_*.txt
   ```

## Build Configuration

### Environment Variables:
- `CUDA_ARCH` - GPU architecture (default: sm_61)
- `XGPU_SRC_DIR` - Path to xGPU source directory (default: ../src)

### Examples:
```bash
make test-both CUDA_ARCH=sm_75
make test-1d CUDA_ARCH=sm_80 XGPU_SRC_DIR=/custom/path/src
```

## Output Files

Test results are saved in `output/` with filenames like:
- `results_1d_cuda12.9.txt` - 1D texture test results
- `results_2d_cuda12.9.txt` - 2D texture test results

Each file contains:
- Test metadata (CUDA version, system info, test parameters)
- Complete correlation matrix output in high precision format

## Interpreting Results

### Successful test indicators:
- Both 1D and 2D tests complete without errors
- Result files are generated with expected number of data points
- Statistics (sum, max values) are within expected ranges

### Comparison tolerance:
The comparison script uses a default tolerance of 1e-10 for numerical differences. Results should be identical or very close between:
- Different CUDA versions with same texture dimension
- 1D vs 2D texture modes (small differences may be expected due to different memory access patterns)

## Troubleshooting

### Common issues:

**"nvcc not found":** Ensure CUDA toolkit is in PATH or specify full path in Makefile

**"libxgpu.so not found":** Ensure xGPU library is built in ../src/ directory

**GPU not found:** Check CUDA_ARCH matches your GPU architecture

**Segmentation fault:** Usually indicates memory allocation issues - ensure sufficient GPU memory

## Technical Details

The test program:
1. Initializes xGPU with device 0
2. Generates deterministic test data using fixed seed
3. Runs correlation computation
4. Saves complete output matrix with metadata
5. Calculates basic statistics for quick verification

The build system compiles separate executables for 1D and 2D texture modes using the TEXTURE_DIM preprocessor flag, allowing direct comparison of both approaches.
