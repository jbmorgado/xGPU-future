#!/usr/bin/env python3
"""
xGPU Texture Compatibility Results Comparison Tool

This script compares output files from different CUDA versions and texture dimensions
to verify compatibility and identify any differences in computation results.

Usage:
    python3 compare_results.py file1.txt file2.txt [file3.txt ...]
    
Example:
    python3 compare_results.py output/results_1d_cuda11*.txt output/results_1d_cuda12*.txt
    python3 compare_results.py output/results_1d_*.txt output/results_2d_*.txt
"""

import sys
import os
import re
import argparse
from collections import defaultdict
import math

def parse_result_file(filepath):
    """Parse a result file and extract metadata and data"""
    
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"File not found: {filepath}")
    
    metadata = {}
    data = []
    
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            
            # Skip empty lines
            if not line:
                continue
                
            # Parse metadata (lines starting with #)
            if line.startswith('#'):
                if ':' in line:
                    key, value = line[1:].split(':', 1)
                    metadata[key.strip()] = value.strip()
                continue
            
            # Parse data lines (index real_part imag_part)
            parts = line.split()
            if len(parts) == 3:
                try:
                    index = int(parts[0])
                    real = float(parts[1])
                    imag = float(parts[2])
                    data.append((index, complex(real, imag)))
                except ValueError:
                    continue  # Skip invalid lines
    
    return metadata, data

def compare_datasets(dataset1, dataset2, tolerance=1e-10):
    """Compare two datasets and return statistics"""
    
    if len(dataset1) != len(dataset2):
        return {
            'equal': False,
            'error': f'Different lengths: {len(dataset1)} vs {len(dataset2)}'
        }
    
    differences = []
    max_diff = 0.0
    equal_count = 0
    
    for i, ((idx1, val1), (idx2, val2)) in enumerate(zip(dataset1, dataset2)):
        if idx1 != idx2:
            return {
                'equal': False,
                'error': f'Index mismatch at position {i}: {idx1} vs {idx2}'
            }
        
        diff = abs(val1 - val2)
        differences.append(diff)
        max_diff = max(max_diff, diff)
        
        if diff <= tolerance:
            equal_count += 1
    
    if not differences:
        return {
            'equal': True,
            'total_points': 0,
            'equal_points': 0,
            'max_difference': 0.0,
            'mean_difference': 0.0,
            'std_difference': 0.0,
            'tolerance': tolerance
        }
    
    mean_diff = sum(differences) / len(differences)
    variance = sum((d - mean_diff)**2 for d in differences) / len(differences)
    std_diff = math.sqrt(variance)
    
    return {
        'equal': max_diff <= tolerance,
        'total_points': len(dataset1),
        'equal_points': equal_count,
        'max_difference': max_diff,
        'mean_difference': mean_diff,
        'std_difference': std_diff,
        'tolerance': tolerance
    }

def format_comparison_report(file1, file2, meta1, meta2, comparison):
    """Format a comparison report"""
    
    report = []
    report.append("=" * 80)
    report.append(f"COMPARISON: {os.path.basename(file1)} vs {os.path.basename(file2)}")
    report.append("=" * 80)
    
    # Metadata comparison
    report.append("\nMETADATA COMPARISON:")
    report.append("-" * 40)
    
    all_keys = set(meta1.keys()) | set(meta2.keys())
    for key in sorted(all_keys):
        val1 = meta1.get(key, "N/A")
        val2 = meta2.get(key, "N/A")
        if val1 == val2:
            report.append(f"  {key:20}: {val1}")
        else:
            report.append(f"  {key:20}: {val1} ≠ {val2}")
    
    # Data comparison
    report.append("\nDATA COMPARISON:")
    report.append("-" * 40)
    
    if 'error' in comparison:
        report.append(f"  ERROR: {comparison['error']}")
    else:
        if comparison['equal']:
            report.append(f"  ✓ IDENTICAL within tolerance")
        else:
            report.append(f"  ✗ DIFFERENCES FOUND")
        
        report.append(f"  Total points:     {comparison['total_points']:,}")
        report.append(f"  Equal points:     {comparison['equal_points']:,}")
        report.append(f"  Max difference:   {comparison['max_difference']:.2e}")
        report.append(f"  Mean difference:  {comparison['mean_difference']:.2e}")
        report.append(f"  Std difference:   {comparison['std_difference']:.2e}")
        report.append(f"  Tolerance:        {comparison['tolerance']:.2e}")
    
    report.append("")
    return "\n".join(report)

def main():
    parser = argparse.ArgumentParser(
        description="Compare xGPU texture compatibility test results",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Compare 1D texture results between CUDA versions
  python3 compare_results.py output/results_1d_cuda11*.txt output/results_1d_cuda12*.txt
  
  # Compare 1D vs 2D texture results from same CUDA version  
  python3 compare_results.py output/results_1d_*.txt output/results_2d_*.txt
  
  # Compare multiple result files
  python3 compare_results.py output/results_*.txt
        """
    )
    
    parser.add_argument('files', nargs='+', 
                       help='Result files to compare')
    parser.add_argument('--tolerance', type=float, default=1e-10,
                       help='Tolerance for numerical comparison (default: 1e-10)')
    parser.add_argument('--output', type=str,
                       help='Save report to file instead of stdout')
    
    args = parser.parse_args()
    
    if len(args.files) < 2:
        print("ERROR: At least 2 files are required for comparison")
        return 1
    
    # Parse all files
    datasets = []
    for filepath in args.files:
        try:
            metadata, data = parse_result_file(filepath)
            datasets.append((filepath, metadata, data))
            print(f"Loaded {len(data)} data points from {os.path.basename(filepath)}")
        except Exception as e:
            print(f"ERROR loading {filepath}: {e}")
            return 1
    
    # Generate all pairwise comparisons
    report_lines = []
    
    for i in range(len(datasets)):
        for j in range(i + 1, len(datasets)):
            file1, meta1, data1 = datasets[i]
            file2, meta2, data2 = datasets[j]
            
            comparison = compare_datasets(data1, data2, args.tolerance)
            report = format_comparison_report(file1, file2, meta1, meta2, comparison)
            report_lines.append(report)
    
    # Output report
    full_report = "\n".join(report_lines)
    
    if args.output:
        with open(args.output, 'w') as f:
            f.write(full_report)
        print(f"Report saved to {args.output}")
    else:
        print(full_report)
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
