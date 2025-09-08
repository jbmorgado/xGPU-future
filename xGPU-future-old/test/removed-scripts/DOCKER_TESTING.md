# xGPU Docker Testing Guide

This directory contains Docker-based testing infrastructure for validating xGPU CUDA 12.x compatibility in isolated, reproducible environments.

## Quick Start

### Prerequisites

1. **Docker**: Install Docker Engine
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install docker.io docker-compose
   
   # Add your user to docker group (requires logout/login)
   sudo usermod -aG docker $USER
   ```

2. **NVIDIA Docker Runtime**: Required for GPU access in containers
   ```bash
   # Ubuntu/Debian
   distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
   curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
   curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
     sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
     sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
   
   sudo apt-get update
   sudo apt-get install -y nvidia-docker2
   sudo systemctl restart docker
   ```

3. **Verify Installation**:
   ```bash
   # Test Docker with GPU access
   docker run --rm --gpus all nvidia/cuda:12.9.1-base-ubuntu22.04 nvidia-smi
   ```

### Simple Usage

1. **Run complete test suite:**
   ```bash
   ./docker-test.sh build    # Build the container image
   ./docker-test.sh test     # Run both 1D and 2D texture tests
   ```

2. **Check results:**
   ```bash
   ./docker-test.sh results  # Show test output summary
   ```

3. **Interactive debugging:**
   ```bash
   ./docker-test.sh interactive  # Start interactive container
   ```

## Detailed Usage

### Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `build` | Build Docker image | `./docker-test.sh build` |
| `test [ARCH] [TYPE]` | Run tests | `./docker-test.sh test sm_75 1d` |
| `interactive [ARCH]` | Interactive shell | `./docker-test.sh interactive sm_80` |
| `results` | Show test results | `./docker-test.sh results` |
| `compare` | Compare 1D vs 2D results | `./docker-test.sh compare` |
| `clean [all]` | Clean up containers | `./docker-test.sh clean all` |

### GPU Architecture Options

| Architecture | GPU Series | Example Cards |
|--------------|------------|---------------|
| `sm_61` | GTX 10xx (default) | GTX 1060, 1070, 1080 |
| `sm_75` | RTX 20xx | RTX 2060, 2070, 2080 |
| `sm_80` | RTX 30xx | RTX 3060, 3070, 3080 |
| `sm_86` | RTX 40xx | RTX 4060, 4070, 4080 |

### Test Types

- `1d` - Only 1D texture tests
- `2d` - Only 2D texture tests  
- `both` - Both 1D and 2D tests (default)

## Testing Workflow

### Basic Cross-Architecture Testing

```bash
# Test on different GPU architectures
./docker-test.sh test sm_61    # GTX 10xx series
./docker-test.sh test sm_75    # RTX 20xx series  
./docker-test.sh test sm_80    # RTX 30xx series

# Results are saved in architecture-specific directories
ls docker-results*/
```

### Comprehensive Validation

```bash
# 1. Build container
./docker-test.sh build

# 2. Run all test combinations
for arch in sm_61 sm_75 sm_80; do
  echo "Testing $arch architecture..."
  ./docker-test.sh test $arch both
  mv docker-results docker-results-$arch
  mv docker-logs docker-logs-$arch
done

# 3. Compare results across architectures
python3 test/compare_results.py \
  docker-results-sm_61/results_1d_*.txt \
  docker-results-sm_75/results_1d_*.txt \
  docker-results-sm_80/results_1d_*.txt
```

### Development and Debugging

```bash
# Start interactive container for development
./docker-test.sh interactive sm_75

# Inside container:
cd /xgpu/src
make clean
make CUDA_ARCH=sm_75 libxgpu.so

cd /xgpu/test  
make clean
make test-1d CUDA_ARCH=sm_75
```

## Docker Compose Alternative

For more complex testing scenarios, use docker-compose:

```bash
# Run default test service
docker-compose up xgpu-test

# Run specific architecture
docker-compose up xgpu-test-sm75

# Interactive development
docker-compose up -d xgpu-dev
docker-compose exec xgpu-dev bash
```

## File Structure

```
xGPU/
├── Dockerfile              # Container definition
├── docker-compose.yml      # Multi-service configuration  
├── docker-test.sh          # Simplified test runner script
├── docker-results/         # Test outputs (created automatically)
├── docker-logs/            # Build and test logs
└── DOCKER_TESTING.md       # This documentation
```

### Generated Directories

- `docker-results/` - Test result files (`.txt` outputs)
- `docker-logs/` - Compilation and execution logs
- `docker-results-sm*/` - Architecture-specific results
- `docker-logs-sm*/` - Architecture-specific logs

## Container Environment

The Docker container includes:

- **Base**: NVIDIA CUDA 12.6 development image with Ubuntu 22.04
- **Tools**: gcc, nvcc, python3, git, vim
- **Python**: numpy, matplotlib for result analysis
- **xGPU**: Complete source code and test framework
- **CUDA**: Full CUDA 12.6 toolkit with texture object support

### Environment Variables

- `CUDA_ARCH` - Target GPU architecture (default: sm_61)
- `TEXTURE_DIM` - Texture dimension mode (1 or 2)
- `NVIDIA_VISIBLE_DEVICES` - GPU devices to use (default: all)

## Result Analysis

### Output Files

Test results are saved with descriptive names:
```
docker-results/
├── results_1d_cuda12.6.txt    # 1D texture test results
├── results_2d_cuda12.6.txt    # 2D texture test results  
└── xgpu_results_*.txt         # Additional result files
```

### Log Files

Detailed logs for troubleshooting:
```
docker-logs/
├── 1d_test.log                # 1D test compilation and execution
├── 2d_test.log                # 2D test compilation and execution
└── build.log                  # Library build logs
```

### Result Verification

Each result file contains:
- Test metadata (CUDA version, architecture, timestamp)
- Complete correlation matrix output  
- Statistical summaries (sums, max values)
- Test parameters and configuration

Expected indicators of successful tests:
- No compilation errors in logs
- Result files generated with expected data
- Statistical values within reasonable ranges
- Consistent results between 1D and 2D modes

## Troubleshooting

### Common Issues

**"nvidia-smi not found"**
- Install NVIDIA drivers on host system
- Ensure nvidia-docker2 is installed and configured

**"Failed to initialize NVML"**  
- Restart Docker daemon: `sudo systemctl restart docker`
- Check GPU is not in use by other processes

**"No CUDA-capable device"**
- Verify GPU architecture in CUDA_ARCH matches your hardware
- Check `nvidia-smi` shows available GPU

**Container builds but tests fail**
- Check docker-logs/ for detailed error messages
- Verify CUDA architecture compatibility
- Ensure sufficient GPU memory available

### Debug Commands

```bash
# Check GPU access in container
docker run --rm --gpus all nvidia/cuda:12.9.1-base-ubuntu22.04 nvidia-smi

# Manual container inspection
docker run --rm -it --gpus all \
  -v $(pwd):/xgpu \
  nvidia/cuda:12.9.1-devel-ubuntu22.04 bash

# Container logs
docker logs xgpu-cuda12-test

# Check container resource usage
docker stats xgpu-cuda12-test
```

## Performance Considerations

- **GPU Memory**: Tests require ~1GB GPU memory for typical configurations
- **Build Time**: Initial image build takes 5-10 minutes 
- **Test Duration**: Complete test suite runs in 1-2 minutes
- **Storage**: Container image ~3GB, results ~10-50MB per test

## Integration with CI/CD

Example GitHub Actions workflow:

```yaml
name: CUDA 12.x Compatibility Test
on: [push, pull_request]

jobs:
  cuda-test:
    runs-on: [self-hosted, linux, gpu]
    steps:
    - uses: actions/checkout@v3
    - name: Build and Test
      run: |
        ./docker-test.sh build
        ./docker-test.sh test
    - name: Upload Results
      uses: actions/upload-artifact@v3
      with:
        name: cuda-test-results
        path: docker-results/
```

## Security Notes

- Container runs with GPU access privileges
- Mount points are read-only except for results/logs directories
- No network access required for testing
- Base image sourced from official NVIDIA repositories

---

For additional help or issues, check the logs in `docker-logs/` directory or run `./docker-test.sh interactive` for manual debugging.
