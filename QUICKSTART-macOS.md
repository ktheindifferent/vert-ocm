# Quick Start - Vertcoin OCM on macOS

## Prerequisites

Install Homebrew (if not already installed):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Install required tools:
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install Go and Node.js
brew install go node
```

## Build and Run (One Command!)

```bash
./build-macos.sh
```

That's it! The script will:
- ✅ Build VerthashMiner (if not already built)
- ✅ Package the miner binary
- ✅ Update miners.json automatically
- ✅ Build the OCM application

## Run the Application

```bash
./run-macos.sh
```

Or directly:
```bash
./build/vertcoin-ocm
```

## Build Script Options

**Default behavior** (skip VerthashMiner if already built):
```bash
./build-macos.sh
```

**Force rebuild VerthashMiner**:
```bash
./build-macos.sh --force-verthash
```

**Skip VerthashMiner entirely** (just rebuild OCM):
```bash
./build-macos.sh --skip-verthash
```

## Troubleshooting

### "No compatible GPUs detected"
- Update your GPU drivers
- Run: `system_profiler SPDisplaysDataType | grep -i opencl` to verify OpenCL support

### Build fails with OpenSSL errors
The build script automatically handles this, but if you build manually:
```bash
export NODE_OPTIONS=--openssl-legacy-provider
```

### "Command not found: wails"
```bash
export PATH=$PATH:$(go env GOPATH)/bin
```

## What Gets Built

- **VerthashMiner**: `VerthashMiner/install/VerthashMiner` (182KB)
- **VerthashMiner Package**: `binaries/VerthashMiner-0.7.2-darwin.tar.gz` (81KB)
- **OCM Application**: `build/vertcoin-ocm` (13MB)

## GPU Support

- ✅ AMD GPUs (Recommended) - Full OpenCL support
- ✅ Intel GPUs - Limited performance
- ❌ NVIDIA GPUs - Not supported (no CUDA on macOS)

Your system has:
- Intel UHD Graphics 630
- AMD Radeon Pro 5500M ← **Will use this for mining**

## Next Steps

1. Run the application: `./run-macos.sh`
2. Create a wallet password when prompted
3. Select a mining pool
4. Start mining!

## For Developers

Rebuild just the OCM app (after code changes):
```bash
./build-macos.sh --skip-verthash
```

View logs:
```bash
tail -f ~/Library/Application\ Support/vertcoin-ocm/vertcoin-ocm.log
```

## Important Notes

- This uses a **local** build of VerthashMiner (not from GitHub releases)
- The `miners.json` file points to local binaries via `file://` URLs
- Perfect for development and testing without needing public hosting
- Mining performance on macOS may be lower than Windows/Linux

Enjoy mining! ⛏️
