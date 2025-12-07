# Vertcoin One-Click Miner - macOS Port

This is a macOS port of the Vertcoin One-Click Miner. The port includes a locally-built VerthashMiner binary compiled for macOS with OpenCL support.

## System Requirements

- macOS 10.13 or later
- Compatible GPU:
  - AMD GPU (GCN 1.0 or later) - **Recommended**
  - Intel GPU (limited performance)
- 2GB+ VRAM
- Homebrew package manager
- Go 1.16 or later
- Node.js 14+ (with npm)
- Git
- Xcode Command Line Tools

## Quick Start

### 1. Install Prerequisites

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Xcode Command Line Tools
xcode-select --install

# Install Go (if not already installed)
brew install go

# Install Node.js (if not already installed)
brew install node
```

### 2. Build and Run

Simply run the build script:

```bash
./build-macos.sh
```

This script will:
- Clone and build VerthashMiner for macOS
- Install required dependencies (jansson, openssl)
- Package the VerthashMiner binary
- Update miners.json with local paths
- Build the OCM application

Then run the application:

```bash
./run-macos.sh
```

Or directly:

```bash
./build/vertcoin-ocm
```

## Manual Build Instructions

If you prefer to build manually:

### Step 1: Build VerthashMiner

```bash
# Install dependencies
brew install jansson openssl@3 cmake

# Clone VerthashMiner
git clone https://github.com/CryptoGraphics/VerthashMiner.git

# Build
cd VerthashMiner
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=../install -DOPENSSL_ROOT_DIR=/usr/local/opt/openssl@3
make -j$(sysctl -n hw.ncpu)
make install
cd ../..

# Package
mkdir -p binaries
cd VerthashMiner/install
tar -czf ../../binaries/VerthashMiner-0.7.2-darwin.tar.gz VerthashMiner kernels
cd ../..

# Get hash
shasum -a 256 binaries/VerthashMiner-0.7.2-darwin.tar.gz
```

### Step 2: Update miners.json

Update the `miners.json` file to include darwin entries pointing to your local binary with the correct hash.

### Step 3: Build OCM

```bash
# Install Wails
go install github.com/wailsapp/wails/cmd/wails@latest

# Build OCM (with legacy OpenSSL support for Node.js)
export NODE_OPTIONS=--openssl-legacy-provider
export PATH=$PATH:$(go env GOPATH)/bin
wails build
```

## Important Notes

### GPU Support

- **AMD GPUs**: Fully supported via OpenCL. Best performance.
- **Intel GPUs**: Supported but with limited mining performance.
- **NVIDIA GPUs**: Not supported on macOS (no CUDA support).
- **Apple Silicon (M1/M2)**: May work via Rosetta 2 (untested).

### Known Limitations

1. VerthashMiner officially states "macOS is not supported", but it compiles and runs with OpenCL
2. Performance may be lower than Windows/Linux due to macOS OpenCL implementation
3. CUDA is not available on macOS, so only OpenCL backend is used

### Troubleshooting

**Build fails with OpenSSL errors:**
```bash
export NODE_OPTIONS=--openssl-legacy-provider
```

**"Command not found: wails":**
```bash
export PATH=$PATH:$(go env GOPATH)/bin
```

**VerthashMiner crashes on start:**
- Check that your GPU drivers are up to date
- Verify OpenCL is available: `system_profiler SPDisplaysDataType | grep -i opencl`

**No compatible GPUs detected:**
- Update your GPU drivers
- Check GPU compatibility with: `VerthashMiner/install/VerthashMiner --device-list`

## File Structure

```
one-click-miner-vnext/
├── build-macos.sh          # All-in-one build script
├── run-macos.sh            # Run script
├── miners.json             # Miner configurations (includes darwin entries)
├── VerthashMiner/          # VerthashMiner source and build
│   ├── install/
│   │   ├── VerthashMiner   # Compiled miner binary
│   │   └── kernels/        # OpenCL kernels
│   └── build/              # Build artifacts
├── binaries/               # Packaged miner binaries
│   └── VerthashMiner-0.7.2-darwin.tar.gz
└── build/                  # OCM build output
    └── vertcoin-ocm        # Main application binary
```

## Development

To rebuild just the OCM app (without rebuilding VerthashMiner):

```bash
export NODE_OPTIONS=--openssl-legacy-provider
export PATH=$PATH:$(go env GOPATH)/bin
wails build
```

To rebuild just VerthashMiner:

```bash
cd VerthashMiner/build
make clean
make -j$(sysctl -n hw.ncpu)
make install
cd ../..
# Re-run packaging steps from build-macos.sh
```

## Credits

- Original OCM: [Vertcoin Project](https://github.com/vertcoin-project/one-click-miner-vnext)
- VerthashMiner: [CryptoGraphics](https://github.com/CryptoGraphics/VerthashMiner)
- macOS Port: Community contribution

## License

Same as the original Vertcoin One-Click Miner project.
