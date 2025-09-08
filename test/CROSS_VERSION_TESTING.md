# Cross-Version Compatibility Testing

This document describes the comprehensive testing system that compares computational results between the original xGPU (CUDA 11.x with texture references) and the modified xGPU (CUDA 12.x with texture objects).

## Overview

The cross-version test provides definitive proof that the CUDA 12.x migration maintains computational accuracy by:

1. **Cloning the original xGPU repository** from `https://github.com/GPU-correlators/xGPU`
2. **Building identical test environments** using different CUDA base images
3. **Running identical computations** with deterministic input data  
4. **Comparing results numerically** with high precision tolerance
5. **Generating comprehensive reports** for validation

## Quick Start

### Prerequisites

- Docker with GPU support (nvidia-docker2)
- Git for repository cloning
- NVIDIA GPU with CUDA support
- Internet connection for cloning repository

### Run Complete Test

```bash
# Run full cross-version comparison
./cross-version-test.sh

# Show results from previous test
./cross-version-test.sh --results-only

# Clean up test artifacts
./cross-version-test.sh --cleanup-only
```

## Test Architecture

### CUDA 11.x Test Environment
- **Base Image**: `nvidia/cuda:11.8.0-devel-ubuntu22.04`
- **Source**: Original repository (`https://github.com/GPU-correlators/xGPU`)
- **Texture Implementation**: Texture references (original CUDA approach)
- **Test Program**: Custom C program that replicates xGPU test framework functionality

### CUDA 12.x Test Environment  
- **Base Image**: `nvidia/cuda:12.9.1-devel-ubuntu22.04`
- **Source**: Local modified repository
- **Texture Implementation**: Texture objects (CUDA 12.x compatible)
- **Test Program**: Uses the existing test framework from `test/` directory

### Test Configuration
Both environments use identical test parameters:
- **GPU Architecture**: sm_61 (configurable)
- **Deterministic Seed**: 12345
- **Stations**: 256
- **Frequencies**: 10  
- **Time Samples**: 1024
- **Matrix Length**: 1,320,960 elements

## Workflow Details

### Phase 1: Environment Setup
1. **Clone original repository** to `/tmp/xgpu-cross-version-test/original-xgpu`
2. **Create Docker containers** for both CUDA versions
3. **Build xGPU libraries** in each environment
4. **Compile test programs** with identical configurations

### Phase 2: Test Execution
1. **Generate identical input data** using fixed seed (12345)
2. **Run correlation computations** on both versions
3. **Save results** to high-precision text format
4. **Log execution details** for debugging

### Phase 3: Result Comparison
1. **Load result matrices** from both test runs
2. **Compare numerical values** element-by-element  
3. **Calculate difference statistics** (max, mean, std deviation)
4. **Validate within tolerance** (default: 1e-10)
5. **Generate comprehensive report**

## Output Structure

Results are saved to `cross-version-results/` directory:

```
cross-version-results/
├── cuda11/                    # CUDA 11.x test outputs
│   └── results_cuda11.txt     # Original xGPU results
├── cuda12/                    # CUDA 12.x test outputs  
│   ├── results_1d_cuda12.6.txt
│   └── results_2d_cuda12.6.txt
├── logs/                      # Execution logs
│   ├── cuda11_test.log
│   └── cuda12_test.log
├── comparison/                # Comparison analysis
│   └── detailed_comparison.txt
└── cross_version_report.md    # Comprehensive report
```

## Result File Format

Each result file contains:
- **Metadata Header**: Test parameters, CUDA version, GPU info, timestamp
- **Data Matrix**: Index, real_part, imaginary_part (high precision)
- **Statistics**: Sum of real/imaginary parts, maximum magnitudes

Example format:
```
# xGPU Cross-Version Test Results
# Generated: Mon Sep 2 10:30:15 2024
# CUDA Version: 11.8 / 12.6
# GPU: Quadro P5000
# Test Seed: 12345
# Matrix Length: 1320960
# Data Format: index real_part imag_part
#
0 1.234567e+03 -2.345678e+02
1 5.678901e+04 1.098765e+03
...
```

## Validation Criteria

### Success Indicators
- ✅ Both test environments build successfully
- ✅ Both tests complete without CUDA errors
- ✅ Result files generated with expected data count
- ✅ Numerical differences within tolerance (≤ 1e-10)
- ✅ Statistical summaries match between versions

### Expected Results
The test should demonstrate:
- **Identical matrix dimensions** (1,320,960 elements)
- **Identical or near-identical values** for each matrix element
- **Identical statistical summaries** (sums, maximums)
- **No regression** in computational accuracy

## Troubleshooting

### Common Issues

**"Failed to clone original repository"**
- Check internet connection
- Verify repository URL is accessible
- Check if behind firewall blocking Git access

**"CUDA 11.x image build failed"**  
- Verify Docker has internet access to pull base images
- Check if nvidia/cuda:11.8.0-devel-ubuntu22.04 image exists
- Try alternative CUDA 11.x image versions

**"GPU not found in container"**
- Ensure nvidia-docker2 is installed and configured
- Check `docker run --rm --gpus all nvidia/cuda:11.8.0-base nvidia-smi`
- Verify GPU architecture matches sm_61 setting

**"Results differ between versions"**
- Review detailed comparison output for difference magnitude
- Check if differences are within floating-point precision
- Verify both tests used same input seed and parameters
- Compare GPU memory access patterns between texture methods

### Debug Commands

```bash
# Check Docker GPU access
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.9.1-base-ubuntu22.04 nvidia-smi

# Manual container inspection
docker run --rm -it --gpus all xgpu:cuda11-test bash
docker run --rm -it --gpus all xgpu:cuda12-test bash

# Check logs for detailed error info
cat cross-version-results/logs/cuda11_test.log
cat cross-version-results/logs/cuda12_test.log

# Manual result comparison  
diff cross-version-results/cuda11/results_cuda11.txt \
     cross-version-results/cuda12/results_1d_cuda12.6.txt
```

## Integration with CI/CD

The cross-version test can be integrated into continuous integration workflows:

### GitHub Actions Example
```yaml
name: Cross-Version Compatibility Test
on: 
  push:
    branches: [master]
  pull_request:
    branches: [master]

jobs:
  cross-version-test:
    runs-on: [self-hosted, linux, gpu]
    steps:
    - uses: actions/checkout@v3
    - name: Run Cross-Version Test
      run: |
        ./cross-version-test.sh
        # Upload results as artifacts
    - name: Upload Test Results
      uses: actions/upload-artifact@v3
      with:
        name: cross-version-results
        path: cross-version-results/
```

## Scientific Validation

This test provides rigorous scientific validation by:

1. **Eliminating Variables**: Same input data, same GPU, same test parameters
2. **Deterministic Testing**: Fixed random seed ensures reproducible results  
3. **High Precision Comparison**: Element-wise comparison with configurable tolerance
4. **Statistical Analysis**: Multiple validation metrics (sums, maxima, distributions)
5. **Comprehensive Logging**: Full audit trail of test execution
6. **Automated Reporting**: Structured results for peer review

The test serves as definitive proof that texture object migration maintains the mathematical correctness of the xGPU correlation engine across CUDA versions.

---

## Advanced Usage

### Custom GPU Architectures
```bash
# Edit the script to change GPU architecture
sed -i 's/CUDA_ARCH=sm_61/CUDA_ARCH=sm_75/' cross-version-test.sh
```

### Different CUDA Versions  
```bash
# Edit Dockerfile.cuda11 to use different base image
CUDA11_IMAGE="nvidia/cuda:11.8.0-devel-ubuntu22.04"
```

### Extended Test Parameters
```bash  
# Modify test program to use different matrix sizes
# Edit the embedded C code in create_cuda11_dockerfile()
```

For additional help or customization, refer to the embedded documentation within `cross-version-test.sh`.
