#!/bin/bash

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$PROJECT_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

# Check if binary exists
if [ ! -f "build/vertcoin-ocm" ]; then
    print_error "Application not built yet!"
    echo ""
    echo "Please run the build script first:"
    echo "  ./build-macos.sh"
    echo ""
    exit 1
fi

print_info "Starting Vertcoin One-Click Miner..."
echo ""

# Run the application
./build/vertcoin-ocm
