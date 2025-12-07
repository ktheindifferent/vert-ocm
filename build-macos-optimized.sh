#!/bin/bash

set -e  # Exit on error

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$PROJECT_ROOT"

echo "======================================"
echo "Vertcoin OCM - Optimized macOS Build"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

# Check if VerthashMiner repo exists
if [ ! -d "VerthashMiner" ]; then
    print_info "Cloning VerthashMiner repository..."
    git clone https://github.com/CryptoGraphics/VerthashMiner.git
fi

# Check dependencies
print_info "Checking build dependencies..."
if ! command -v brew &> /dev/null; then
    print_error "Homebrew not found. Please install it from https://brew.sh"
    exit 1
fi

if ! brew list jansson &> /dev/null; then
    print_info "Installing jansson..."
    brew install jansson
fi

if ! brew list openssl@3 &> /dev/null; then
    print_info "Installing openssl@3..."
    brew install openssl@3
fi

# Detect CPU architecture
CPU_ARCH=$(sysctl -n machdep.cpu.brand_string)
print_info "Detected CPU: $CPU_ARCH"

# Build VerthashMiner with optimizations
print_info "Building VerthashMiner with CPU-specific optimizations..."
rm -rf VerthashMiner/build
mkdir -p VerthashMiner/build
cd VerthashMiner/build

# Set aggressive optimization flags
export CFLAGS="-O3 -march=native -mtune=native -ffast-math -funroll-loops -finline-functions"
export CXXFLAGS="-O3 -march=native -mtune=native -ffast-math -funroll-loops -finline-functions"

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../install \
    -DCMAKE_C_FLAGS="$CFLAGS" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
    -DOPENSSL_ROOT_DIR=/usr/local/opt/openssl@3

print_info "Compiling VerthashMiner with optimizations (this may take a few minutes)..."
make clean || true
make -j$(sysctl -n hw.ncpu)
make install

cd "$PROJECT_ROOT"
print_status "VerthashMiner built successfully with optimizations"

# Package VerthashMiner
print_info "Packaging VerthashMiner..."
mkdir -p binaries
cd VerthashMiner/install
tar -czf "$PROJECT_ROOT/binaries/VerthashMiner-0.7.2-darwin-optimized.tar.gz" VerthashMiner kernels
cd "$PROJECT_ROOT"
print_status "VerthashMiner packaged"

# Calculate hash
print_info "Calculating SHA256 hash..."
HASH=$(shasum -a 256 binaries/VerthashMiner-0.7.2-darwin-optimized.tar.gz | awk '{print $1}')
print_status "SHA256: $HASH"

# Update miners.json with optimized binary
print_info "Updating miners.json..."
BINARY_PATH="$PROJECT_ROOT/binaries/VerthashMiner-0.7.2-darwin-optimized.tar.gz"

python3 - <<EOF
import json

miners_file = 'miners.json'
with open(miners_file, 'r') as f:
    miners = json.load(f)

# Remove existing darwin entries
miners = [m for m in miners if m.get('platform') != 'darwin']

# Add new darwin entries with optimized binary
darwin_configs = [
    {
        "platform": "darwin",
        "gpuplatform": "AMD",
        "url": "file://${BINARY_PATH}",
        "sha256": "${HASH}",
        "mainExecutableName": "VerthashMiner",
        "closedSource": False,
        "testnet": False,
        "blockHeightMin": 1499999,
        "blockHeightMax": -1,
        "multiGPUMiner": True
    },
    {
        "platform": "darwin",
        "gpuplatform": "INTEL",
        "url": "file://${BINARY_PATH}",
        "sha256": "${HASH}",
        "mainExecutableName": "VerthashMiner",
        "closedSource": False,
        "testnet": False,
        "blockHeightMin": 1499999,
        "blockHeightMax": -1,
        "multiGPUMiner": True
    },
    {
        "platform": "darwin",
        "gpuplatform": "AMD",
        "url": "file://${BINARY_PATH}",
        "sha256": "${HASH}",
        "mainExecutableName": "VerthashMiner",
        "closedSource": False,
        "testnet": True,
        "multiGPUMiner": True
    },
    {
        "platform": "darwin",
        "gpuplatform": "INTEL",
        "url": "file://${BINARY_PATH}",
        "sha256": "${HASH}",
        "mainExecutableName": "VerthashMiner",
        "closedSource": False,
        "testnet": True,
        "multiGPUMiner": True
    }
]

miners.extend(darwin_configs)

with open(miners_file, 'w') as f:
    json.dump(miners, f, indent=4)

print("miners.json updated successfully")
EOF

print_status "miners.json updated"

echo ""
echo "======================================"
print_status "Optimized Build Complete!"
echo "======================================"
echo ""
print_info "Optimization flags used:"
echo "  -O3              : Maximum optimization"
echo "  -march=native    : CPU-specific instructions"
echo "  -mtune=native    : CPU-specific tuning"
echo "  -ffast-math      : Faster floating-point math"
echo "  -funroll-loops   : Loop unrolling"
echo ""
print_info "Next steps:"
echo "  1. Rebuild the OCM application: ./build-macos.sh --skip-verthash"
echo "  2. Run the miner and test performance"
echo ""
