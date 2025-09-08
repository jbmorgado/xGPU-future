#ifndef MEMORY_MONITOR_H
#define MEMORY_MONITOR_H

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <cuda_runtime.h>

// Memory usage structure
typedef struct {
    // System memory (in MB)
    float peak_system_mb;
    float initial_system_mb;
    float current_system_mb;
    
    // GPU memory (in MB)
    float peak_gpu_mb;
    float initial_gpu_mb;
    float current_gpu_mb;
    float gpu_free_mb;
    float gpu_total_mb;
} MemoryUsage;

// Function declarations
void memory_monitor_init(MemoryUsage* mem);
void memory_monitor_update(MemoryUsage* mem);
void memory_monitor_finalize(MemoryUsage* mem);
void memory_monitor_print_report(const MemoryUsage* mem, const char* label);
float get_system_memory_mb();
void get_gpu_memory_mb(float* used, float* free, float* total);

#endif // MEMORY_MONITOR_H
