#!/bin/bash

# Force macOS to use the discrete AMD GPU for mining
# This prevents automatic graphics switching from powering down the AMD GPU

echo "======================================"
echo "Force Discrete GPU for Mining"
echo "======================================"
echo ""

# Check if running on battery
POWER_SOURCE=$(pmset -g batt | grep -o 'AC Power\|Battery Power')
if [ "$POWER_SOURCE" = "Battery Power" ]; then
    echo "⚠️  WARNING: Running on battery power!"
    echo "   Discrete GPU performance may be limited."
    echo "   Please plug in your MacBook for best results."
    echo ""
fi

# Disable automatic graphics switching (requires sudo)
echo "Checking automatic graphics switching status..."
SWITCHING_STATUS=$(pmset -g | grep -i "gpuswitch")

if [ ! -z "$SWITCHING_STATUS" ]; then
    echo "Current GPU switching: $SWITCHING_STATUS"
    echo ""
    echo "To disable automatic graphics switching:"
    echo "1. Go to System Preferences → Battery → Power Adapter"
    echo "2. Uncheck 'Automatic graphics switching'"
    echo ""
fi

# Create a helper process that forces the discrete GPU to stay active
echo "Forcing discrete GPU to activate..."

# Method 1: Use Metal to activate the discrete GPU
cat > /tmp/force_dgpu.swift << 'EOF'
import Metal
import Foundation

print("Activating discrete GPU...")

// Get all Metal devices
let devices = MTLCopyAllDevices()

for device in devices {
    print("Found GPU: \(device.name)")
    if device.name.contains("AMD") || device.name.contains("Radeon") {
        print("✓ AMD discrete GPU found and activated!")

        // Keep a reference to force it to stay active
        let commandQueue = device.makeCommandQueue()

        // Sleep to keep the process alive
        print("Keeping discrete GPU active...")
        print("Press Ctrl+C to stop and return to automatic switching")
        sleep(UInt32.max)
    }
}

print("No AMD GPU found")
EOF

# Check if swift is available
if command -v swift &> /dev/null; then
    echo ""
    echo "Starting GPU activation process..."
    echo "This will keep your AMD GPU active for mining."
    echo ""
    echo "Run this in a separate terminal, then start your miner:"
    echo "  swift /tmp/force_dgpu.swift"
    echo ""
else
    echo "Swift compiler not found. Using alternative method..."
fi

# Method 2: Alternative using pmset (requires admin)
echo "Alternative method using pmset:"
echo "  sudo pmset -a gpuswitch 1  # Force discrete GPU"
echo "  sudo pmset -a gpuswitch 2  # Return to automatic"
echo ""

# Method 3: Use a simple OpenCL program to keep GPU active
cat > /tmp/keep_gpu_active.c << 'EOF'
#ifdef __APPLE__
#include <OpenCL/opencl.h>
#else
#include <CL/cl.h>
#endif
#include <stdio.h>
#include <unistd.h>

int main() {
    cl_uint numPlatforms;
    clGetPlatformIDs(0, NULL, &numPlatforms);

    if (numPlatforms == 0) {
        printf("No OpenCL platforms found\n");
        return 1;
    }

    cl_platform_id *platforms = (cl_platform_id*)malloc(sizeof(cl_platform_id) * numPlatforms);
    clGetPlatformIDs(numPlatforms, platforms, NULL);

    cl_uint numDevices;
    clGetDeviceIDs(platforms[0], CL_DEVICE_TYPE_GPU, 0, NULL, &numDevices);

    printf("Found %d GPU device(s)\n", numDevices);

    cl_device_id *devices = (cl_device_id*)malloc(sizeof(cl_device_id) * numDevices);
    clGetDeviceIDs(platforms[0], CL_DEVICE_TYPE_GPU, numDevices, devices, NULL);

    for (int i = 0; i < numDevices; i++) {
        char deviceName[256];
        clGetDeviceInfo(devices[i], CL_DEVICE_NAME, sizeof(deviceName), deviceName, NULL);
        printf("GPU %d: %s\n", i, deviceName);

        // Create a context to keep the device active
        cl_int err;
        cl_context context = clCreateContext(NULL, 1, &devices[i], NULL, NULL, &err);
        if (err == CL_SUCCESS) {
            printf("✓ Activated: %s\n", deviceName);
        }
    }

    printf("\nKeeping GPUs active... Press Ctrl+C to exit\n");
    while(1) {
        sleep(60);
    }

    return 0;
}
EOF

# Compile the C program
echo "Compiling GPU activation utility..."
if gcc -framework OpenCL /tmp/keep_gpu_active.c -o /tmp/keep_gpu_active 2>/dev/null; then
    echo "✓ Compiled successfully!"
    echo ""
    echo "================================"
    echo "TO ACTIVATE YOUR AMD GPU:"
    echo "================================"
    echo ""
    echo "In a SEPARATE terminal window, run:"
    echo "  /tmp/keep_gpu_active"
    echo ""
    echo "Then start your miner in this window."
    echo "Keep both running while mining."
    echo ""
else
    echo "Could not compile GPU activation utility."
    echo ""
    echo "Please disable automatic graphics switching manually:"
    echo "System Preferences → Battery → Power Adapter → Uncheck 'Automatic graphics switching'"
    echo ""
fi

echo "================================"
echo "Quick Fix (Easiest):"
echo "================================"
echo ""
echo "1. Open System Preferences"
echo "2. Go to Battery → Power Adapter"
echo "3. UNCHECK 'Automatic graphics switching'"
echo "4. Restart the miner"
echo ""
echo "This will force your AMD GPU to stay active."
echo ""
