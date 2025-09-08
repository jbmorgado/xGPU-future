#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/utsname.h>
#include <time.h>
#include <math.h>
#include <cuda_runtime.h>
#include "xgpu.h"
#include "memory_monitor.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#define TEST_SEED 12345

// Function to get CUDA version string
void get_cuda_version(char* version_str, size_t len) {
    FILE* fp = popen("/usr/local/cuda/bin/nvcc --version 2>/dev/null | grep 'release' | head -1", "r");
    if (fp == NULL) {
        // Try alternative path
        fp = popen("nvcc --version 2>/dev/null | grep 'release' | head -1", "r");
    }
    if (fp == NULL) {
        snprintf(version_str, len, "unknown");
        return;
    }
    
    if (fgets(version_str, len, fp) == NULL) {
        snprintf(version_str, len, "unknown");
    } else {
        // Extract version number from release line
        char* release_pos = strstr(version_str, "release ");
        if (release_pos) {
            release_pos += 8; // Skip "release "
            char* comma_pos = strchr(release_pos, ',');
            if (comma_pos) {
                *comma_pos = '\0';
            }
            // Move the version to beginning of string
            memmove(version_str, release_pos, strlen(release_pos) + 1);
        }
        // Remove trailing newline
        char* newline = strchr(version_str, '\n');
        if (newline) *newline = '\0';
    }
    
    pclose(fp);
}

// Function to get system info
void get_system_info(char* info_str, size_t len) {
    struct utsname sys_info;
    if (uname(&sys_info) == 0) {
        snprintf(info_str, len, "%s %s", sys_info.sysname, sys_info.release);
    } else {
        snprintf(info_str, len, "unknown");
    }
}

// Function to generate deterministic test data using same algorithm as xGPU library
void generate_test_data(ComplexInput *array, size_t length, unsigned int seed) {
    srand(seed);
    
    // Use Box-Muller transform like xgpuRandomComplex does
    double stddev = 2.5;
    for(size_t i = 0; i < length; i++) {
        double u1 = (rand() / (double)(RAND_MAX));
        double u2 = (rand() / (double)(RAND_MAX));
        if(u1 == 0.0) u1 = 0.5/RAND_MAX;
        if(u2 == 0.0) u2 = 0.5/RAND_MAX;
        
        // Do Box-Muller transform
        double r = stddev * sqrt(-2.0*log(u1));
        double theta = 2*M_PI*u2;
        double a = r * cos(theta);
        double b = r * sin(theta);
        
        // Quantize (unbiased rounding)
        a = round(a);
        b = round(b);
        
        // Saturate to range -7.0 to +7.0
        if(a >  7.0) a =  7.0;
        if(a < -7.0) a = -7.0;
        if(b >  7.0) b =  7.0;
        if(b < -7.0) b = -7.0;

#ifndef FIXED_POINT
        // Simulate 4 bit data that has been converted to floats
        array[i].real = a;
        array[i].imag = b;
#else
        // Simulate 4 bit data multiplied by 16 (left shift by 4)
        array[i].real = ((int)a) << 4;
        array[i].imag = ((int)b) << 4;
#endif
    }
}

// Function to save results to file with metadata
int save_results(Complex *matrix_data, size_t matrix_len, const char *filename, double exec_time) {
    FILE *fp = fopen(filename, "w");
    if (!fp) {
        perror("Failed to open output file");
        return -1;
    }
    
    char cuda_version[64];
    char system_info[256];
    time_t current_time;
    
    get_cuda_version(cuda_version, sizeof(cuda_version));
    get_system_info(system_info, sizeof(system_info));
    time(&current_time);
    
    // Write header information
    fprintf(fp, "# xGPU Texture Compatibility Test Results\n");
    fprintf(fp, "# Generated: %s", ctime(&current_time));
    fprintf(fp, "# CUDA Version: %s\n", cuda_version);
    fprintf(fp, "# System: %s\n", system_info);
#ifdef TEXTURE_DIM
    fprintf(fp, "# Texture Dimension: %d\n", TEXTURE_DIM);
#else
    fprintf(fp, "# Texture Dimension: undefined\n");
#endif
    fprintf(fp, "# Matrix Length: %zu\n", matrix_len);
    fprintf(fp, "# Test Seed: %d\n", TEST_SEED);
    fprintf(fp, "# Execution Time: %.6f seconds\n", exec_time);
    fprintf(fp, "# Data Format: index real_part imag_part\n");
    
    // Write matrix data
    for(size_t i = 0; i < matrix_len; i++) {
        fprintf(fp, "%zu %.15e %.15e\n", i, 
                matrix_data[i].real, matrix_data[i].imag);
    }
    
    fclose(fp);
    printf("Results saved to %s\n", filename);
    return 0;
}

int main(int argc, char** argv) {
    XGPUContext context;
    XGPUInfo xgpu_info;
    int error = XGPU_OK;
    char filename[256];
    MemoryUsage memory_usage;
    
    // Initialize memory monitoring
    memory_monitor_init(&memory_usage);
    
    printf("=======================================================\n");
    printf("xGPU Texture Compatibility Test\n");
    printf("=======================================================\n");
    
    // Get system info for display
    char cuda_version[64];
    get_cuda_version(cuda_version, sizeof(cuda_version));
    
    printf("CUDA Version: %s\n", cuda_version);
#ifdef TEXTURE_DIM
    printf("Texture Dimension: %d\n", TEXTURE_DIM);
#else
    printf("Texture Dimension: undefined\n");
#endif
    
    // Get xGPU info
    xgpuInfo(&xgpu_info);
    
    printf("xGPU Configuration:\n");
    printf("  Stations: %d\n", xgpu_info.nstation);
    printf("  Frequencies: %d\n", xgpu_info.nfrequency);
    printf("  Time samples: %d\n", xgpu_info.ntime);
    printf("  Matrix length: %llu\n", (unsigned long long)xgpu_info.matLength);
    
    // Initialize context to NULL to let xGPU allocate memory
    memset(&context, 0, sizeof(context));
    
    // Initialize xGPU
    error = xgpuInit(&context, 0);
    if(error != XGPU_OK) {
        fprintf(stderr, "ERROR: xgpuInit failed with error %d\n", error);
        return error;
    }
    
    printf("xGPU initialized successfully\n");
    
    // Monitor memory after initialization
    memory_monitor_update(&memory_usage);
    
    // Generate deterministic test data
    generate_test_data(context.array_h, xgpu_info.vecLength, TEST_SEED);
    printf("Generated test data with seed %d\n", TEST_SEED);
    
    // Clear output matrix
    memset(context.matrix_h, 0, xgpu_info.matLength * sizeof(Complex));
    
    // Run correlation
    printf("Running xGPU correlation...\n");
    
    // Monitor memory before correlation
    memory_monitor_update(&memory_usage);
    
    // Timing measurement
    clock_t start_time = clock();
    error = xgpuCudaXengine(&context, SYNCOP_DUMP);
    clock_t end_time = clock();
    
    // Monitor memory after correlation
    memory_monitor_update(&memory_usage);
    
    if(error != XGPU_OK) {
        fprintf(stderr, "ERROR: xgpuCudaXengine failed with error %d\n", error);
        xgpuFree(&context);
        return error;
    }

    double execution_time = ((double)(end_time - start_time)) / CLOCKS_PER_SEC;
    printf("Correlation completed successfully\n");
    printf("Execution time: %.6f seconds\n", execution_time);
    
    // Save results to output directory
#ifdef TEXTURE_DIM
    snprintf(filename, sizeof(filename), "output/results_%dd_cuda%s.txt", 
             TEXTURE_DIM, cuda_version);
#else
    snprintf(filename, sizeof(filename), "output/results_unknown_cuda%s.txt", 
             cuda_version);
#endif
    
    if(save_results(context.matrix_h, xgpu_info.matLength, filename, execution_time) != 0) {
        xgpuFree(&context);
        return -1;
    }
    
    // Calculate some basic statistics for verification
    double sum_real = 0.0, sum_imag = 0.0;
    double max_real = 0.0, max_imag = 0.0;
    
    for(size_t i = 0; i < xgpu_info.matLength; i++) {
        sum_real += context.matrix_h[i].real;
        sum_imag += context.matrix_h[i].imag;
        
        double abs_real = fabs(context.matrix_h[i].real);
        double abs_imag = fabs(context.matrix_h[i].imag);
        
        if(abs_real > max_real) max_real = abs_real;
        if(abs_imag > max_imag) max_imag = abs_imag;
    }
    
    printf("Output Statistics:\n");
    printf("  Sum of real parts: %.6e\n", sum_real);
    printf("  Sum of imag parts: %.6e\n", sum_imag);
    printf("  Max real magnitude: %.6e\n", max_real);
    printf("  Max imag magnitude: %.6e\n", max_imag);
    
    // Finalize memory monitoring and print report
    memory_monitor_finalize(&memory_usage);
    memory_monitor_print_report(&memory_usage, "xGPU Correlator");
    
    // Clean up
    xgpuFree(&context);
    
    printf("\n=======================================================\n");
    printf("Test completed successfully!\n");
    printf("Results saved to: %s\n", filename);
    printf("=======================================================\n");
    
    return 0;
}
