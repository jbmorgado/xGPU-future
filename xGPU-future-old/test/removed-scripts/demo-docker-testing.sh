#!/bin/bash
# xGPU Docker Testing Demo Script
# This script demonstrates the full Docker testing workflow

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE} xGPU CUDA 12.x Docker Testing Demo${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if script exists
if [ ! -f "$SCRIPT_DIR/docker-test.sh" ]; then
    echo "Error: docker-test.sh not found in test directory."
    exit 1
fi

echo -e "${YELLOW}Step 1: Building Docker image...${NC}"
"$SCRIPT_DIR/docker-test.sh" build

echo ""
echo -e "${YELLOW}Step 2: Running comprehensive test suite...${NC}"
echo "This will test both 1D and 2D texture modes"
"$SCRIPT_DIR/docker-test.sh" test

echo ""
echo -e "${YELLOW}Step 3: Showing results...${NC}"
"$SCRIPT_DIR/docker-test.sh" results

echo ""
echo -e "${YELLOW}Step 4: Comparing 1D vs 2D results...${NC}"
"$SCRIPT_DIR/docker-test.sh" compare

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Demo completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo "Next steps you can try:"
echo "  1. ./docker-test.sh interactive    # Interactive container access"
echo "  2. ./docker-test.sh test sm_75     # Test with different GPU architecture"  
echo "  3. ./docker-test.sh test sm_80 1d  # Test specific configuration"
echo ""

echo "Result files are in: docker-results/"
echo "Log files are in: docker-logs/"
