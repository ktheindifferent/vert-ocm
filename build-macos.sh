#!/bin/bash

set -e  # Exit on error

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$PROJECT_ROOT"

# Parse arguments
SKIP_VERTHASH=false
FORCE_VERTHASH=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-verthash)
            SKIP_VERTHASH=true
            shift
            ;;
        --force-verthash)
            FORCE_VERTHASH=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--skip-verthash] [--force-verthash]"
            exit 1
            ;;
    esac
done

echo "======================================"
echo "Vertcoin OCM - macOS Build Script"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

# Check if VerthashMiner needs to be built
VERTHASH_BINARY="VerthashMiner/install/VerthashMiner"
BUILD_VERTHASH=false

if [ "$SKIP_VERTHASH" = true ]; then
    if [ ! -f "$VERTHASH_BINARY" ]; then
        print_error "VerthashMiner binary not found and --skip-verthash specified!"
        exit 1
    fi
    print_info "Skipping VerthashMiner build (--skip-verthash)"
elif [ "$FORCE_VERTHASH" = true ]; then
    print_info "Force rebuilding VerthashMiner (--force-verthash)"
    BUILD_VERTHASH=true
elif [ ! -f "$VERTHASH_BINARY" ]; then
    print_info "VerthashMiner binary not found. Will build it."
    BUILD_VERTHASH=true
else
    print_status "VerthashMiner binary exists at $VERTHASH_BINARY"
    print_info "Skipping VerthashMiner rebuild (use --force-verthash to rebuild)"
fi

# Build VerthashMiner if needed
if [ "$BUILD_VERTHASH" = true ]; then
    print_info "Building VerthashMiner..."

    # Check if repo exists
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

    # Build VerthashMiner
    print_info "Configuring VerthashMiner build..."
    mkdir -p VerthashMiner/build
    cd VerthashMiner/build

    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=../install \
        -DOPENSSL_ROOT_DIR=/usr/local/opt/openssl@3 \
        > /dev/null 2>&1

    print_info "Compiling VerthashMiner (this may take a few minutes)..."
    make clean > /dev/null 2>&1 || true
    make -j$(sysctl -n hw.ncpu) > /dev/null 2>&1
    make install > /dev/null 2>&1

    cd "$PROJECT_ROOT"
    print_status "VerthashMiner built successfully"
fi

# Package VerthashMiner
print_info "Packaging VerthashMiner..."
mkdir -p binaries
cd VerthashMiner/install
tar -czf "$PROJECT_ROOT/binaries/VerthashMiner-0.7.2-darwin.tar.gz" VerthashMiner kernels
cd "$PROJECT_ROOT"
print_status "VerthashMiner packaged"

# Calculate hash
print_info "Calculating SHA256 hash..."
HASH=$(shasum -a 256 binaries/VerthashMiner-0.7.2-darwin.tar.gz | awk '{print $1}')
print_status "SHA256: $HASH"

# Update miners.json with correct path and hash
print_info "Updating miners.json..."
BINARY_PATH="$PROJECT_ROOT/binaries/VerthashMiner-0.7.2-darwin.tar.gz"

# Create a temporary Python script to update the JSON
python3 - <<EOF
import json
import sys

miners_file = 'miners.json'
with open(miners_file, 'r') as f:
    miners = json.load(f)

# Remove existing darwin entries
miners = [m for m in miners if m.get('platform') != 'darwin']

# Add new darwin entries
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

# Build OCM frontend and backend
print_info "Building Vertcoin One-Click Miner..."

# Check if wails is installed
if ! command -v wails &> /dev/null; then
    print_info "Installing Wails CLI..."
    go install github.com/wailsapp/wails/cmd/wails@latest
    export PATH=$PATH:$(go env GOPATH)/bin
fi

# Clean previous build
print_info "Cleaning previous build..."
rm -rf build/vertcoin-ocm

# Build with legacy OpenSSL provider for Node.js compatibility
print_info "Building application (this may take a few minutes)..."
export NODE_OPTIONS=--openssl-legacy-provider
export PATH=$PATH:$(go env GOPATH)/bin

if wails build > /dev/null 2>&1; then
    print_status "Build completed successfully!"
else
    print_error "Build failed. Running again with verbose output..."
    wails build
    exit 1
fi

echo ""
echo "======================================"
print_status "Build Complete!"
echo "======================================"
echo ""
echo "Binary location: $PROJECT_ROOT/build/vertcoin-ocm"
echo "VerthashMiner:   $PROJECT_ROOT/$VERTHASH_BINARY"
echo ""
echo "To run the application:"
echo "  ./build/vertcoin-ocm"
echo ""
