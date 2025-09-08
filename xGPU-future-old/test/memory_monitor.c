#include "memory_monitor.h"
#include <string.h>

// Get current system memory usage in MB
float get_system_memory_mb() {
    FILE* file = fopen("/proc/self/status", "r");
    if (!file) return -1.0f;
    
    char line[256];
    float vmrss_kb = 0.0f;
    
    while (fgets(line, sizeof(line), file)) {
        if (strncmp(line, "VmRSS:", 6) == 0) {
            sscanf(line, "VmRSS: %f kB", &vmrss_kb);
            break;
        }
    }
    fclose(file);
    
    return vmrss_kb / 1024.0f; // Convert KB to MB
}

// Get GPU memory information in MB
void get_gpu_memory_mb(float* used, float* free, float* total) {
    size_t free_bytes, total_bytes;
    cudaError_t err = cudaMemGetInfo(&free_bytes, &total_bytes);
    
    if (err == cudaSuccess) {
        *free = free_bytes / (1024.0f * 1024.0f);
        *total = total_bytes / (1024.0f * 1024.0f);
        *used = *total - *free;
    } else {
        *free = *total = *used = -1.0f;
    }
}

// Initialize memory monitoring
void memory_monitor_init(MemoryUsage* mem) {
    memset(mem, 0, sizeof(MemoryUsage));
    
    // Initialize system memory
    mem->initial_system_mb = get_system_memory_mb();
    mem->current_system_mb = mem->initial_system_mb;
    mem->peak_system_mb = mem->initial_system_mb;
    
    // Initialize GPU memory
    get_gpu_memory_mb(&mem->current_gpu_mb, &mem->gpu_free_mb, &mem->gpu_total_mb);
    mem->initial_gpu_mb = mem->current_gpu_mb;
    mem->peak_gpu_mb = mem->current_gpu_mb;
}

// Update memory monitoring (call periodically during execution)
void memory_monitor_update(MemoryUsage* mem) {
    // Update system memory
    mem->current_system_mb = get_system_memory_mb();
    if (mem->current_system_mb > mem->peak_system_mb) {
        mem->peak_system_mb = mem->current_system_mb;
    }
    
    // Update GPU memory
    float gpu_used, gpu_free, gpu_total;
    get_gpu_memory_mb(&gpu_used, &gpu_free, &gpu_total);
    mem->current_gpu_mb = gpu_used;
    mem->gpu_free_mb = gpu_free;
    mem->gpu_total_mb = gpu_total;
    
    if (mem->current_gpu_mb > mem->peak_gpu_mb) {
        mem->peak_gpu_mb = mem->current_gpu_mb;
    }
}

// Finalize memory monitoring (call at end)
void memory_monitor_finalize(MemoryUsage* mem) {
    memory_monitor_update(mem);
}

// Print memory usage report
void memory_monitor_print_report(const MemoryUsage* mem, const char* label) {
    printf("\n=======================================================\n");
    printf("Memory Usage Report - %s\n", label);
    printf("=======================================================\n");
    
    printf("System Memory (RAM):\n");
    printf("  Initial: %.1f MB\n", mem->initial_system_mb);
    printf("  Peak:    %.1f MB (+%.1f MB)\n", 
           mem->peak_system_mb, mem->peak_system_mb - mem->initial_system_mb);
    printf("  Final:   %.1f MB\n", mem->current_system_mb);
    
    printf("\nGPU Memory:\n");
    printf("  Total Available: %.1f MB\n", mem->gpu_total_mb);
    printf("  Initial Used:    %.1f MB\n", mem->initial_gpu_mb);
    printf("  Peak Used:       %.1f MB (+%.1f MB)\n", 
           mem->peak_gpu_mb, mem->peak_gpu_mb - mem->initial_gpu_mb);
    printf("  Final Used:      %.1f MB\n", mem->current_gpu_mb);
    printf("  Current Free:    %.1f MB\n", mem->gpu_free_mb);
    
    printf("\nMemory Efficiency:\n");
    printf("  GPU Utilization: %.1f%% (peak)\n", 
           (mem->peak_gpu_mb / mem->gpu_total_mb) * 100.0f);
    printf("  Memory Delta:    System +%.1f MB, GPU +%.1f MB\n",
           mem->peak_system_mb - mem->initial_system_mb,
           mem->peak_gpu_mb - mem->initial_gpu_mb);
    printf("=======================================================\n\n");
}
