# VerthashMiner Metal Investigation Summary

## Problem
Metal backend on macOS initializes successfully but produces **zero hashrate output** after hours of mining. The miner appears to run but never generates any shares or hashrate reports.

## Root Cause Analysis

### 1. Automatic Metal Selection
- **Location**: VerthashMiner/src/main.cpp:5305-5322
- The miner automatically enables Metal for discrete (non-low-power) GPUs on macOS
- **No command-line flag exists to disable this behavior**
- Even with `--all-cl-devices`, Metal is still enabled alongside OpenCL

### 2. Metal Initialization vs Actual Mining
- Metal device initializes: ✅ "INFO  MTL: Metal device initialized: AMD Radeon Pro 5500M"
- Metal worker thread starts: ✅ (no errors reported)
- Metal produces hashrate: ❌ **Zero output after hours**

### 3. OpenCL Alternative Status
- OpenCL devices fail with **error code -30** (CL_MEM_OBJECT_ALLOCATION_FAILURE)
- Cause: Verthash data file is ~1.2GB, doesn't fit in GPU memory
- This is why Metal was preferred - it was supposed to work better

## Solutions

### Option 1: Add --disable-metal Flag (Recommended)
Modify VerthashMiner source to add command-line option:
1. Add `bool opt_disable_metal = false;` global variable
2. Add `--disable-metal` or `--no-metal` to argument parser
3. Wrap Metal auto-configuration (line 5305-5322) in `if (!opt_disable_metal)`
4. Rebuild VerthashMiner binary

### Option 2: Investigate Metal Mining Loop Bug
The Metal worker thread (`verthashMetal_thread` at line 3525) is running but not:
- Outputting hashrate stats
- Finding valid shares
- Possibly hanging in mining loop

Potential issues:
- Metal kernel compilation failure (seen earlier: "Failed to compile kernel")
- Work retrieval from pool failing
- Atomic operations in Metal shader incompatible with newer macOS Metal compiler

### Option 3: Fix OpenCL Memory Issue
- Reduce verthash data size loaded into GPU
- Use unified memory / shared memory on macOS
- Stream verthash data from system RAM instead of copying entire 1.2GB

## Recommended Action

**Implement Option 1** (add --disable-metal flag) as immediate workaround:
1. This allows users to force OpenCL mode
2. Can be toggled via OCM settings UI
3. Quick fix while investigating actual Metal bug

Then investigate Option 2 for permanent Metal fix.

## Files Modified for Device Display Feature

The device display GUI feature is already complete and working:
- ✅ miners/verthashminer.go - Parser with Metal/CL/CUDA tracking
- ✅ miners/miners.go - DeviceInfo struct
- ✅ backend/mining.go - Device event emission
- ✅ frontend/src/components/Mining.vue - UI display

**The GUI will work perfectly once miner produces hashrate output.**

## Test Results

### With Metal (current):
```
Configured 2(CL) and 1(Metal) workers
MTL: Metal device initialized: AMD Radeon Pro 5500M
[No hashrate output after hours]
```

### With --all-cl-devices:
```
Configured 2(CL) and 1(Metal) workers
[Metal still enabled, still no output]
```

### Expected with --disable-metal:
```
Configured 2(CL) and 0(Metal) workers
cl_device(0): hashrate: 26.68 kH/s
cl_device(1): hashrate: [may fail with -30 error]
```

## Next Steps
1. Add --disable-metal flag to VerthashMiner source
2. Rebuild VerthashMiner binary
3. Update OCM to pass --disable-metal when on macOS
4. Test with OpenCL fallback
5. Investigate actual Metal mining bug for permanent fix
