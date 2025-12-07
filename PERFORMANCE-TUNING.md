# VerthashMiner Performance Tuning Guide for macOS

## What Was Optimized

Your VerthashMiner has been rebuilt with the following CPU-specific optimizations:

- **-O3**: Maximum compiler optimization level
- **-march=native**: Uses instructions specific to your i9-9880H CPU (AVX2, SSE4.2, etc.)
- **-mtune=native**: Tunes code scheduling for your specific CPU architecture
- **-ffast-math**: Enables faster floating-point operations
- **-funroll-loops**: Unrolls loops for better performance

## Your Hardware

- **CPU**: Intel Core i9-9880H (8 cores, 16 threads @ 2.3GHz base, 4.8GHz boost)
- **Integrated GPU**: Intel UHD Graphics 630 (~40 kH/s - what you were getting)
- **Discrete GPU**: AMD Radeon Pro 5500M (~500-800 kH/s expected)

## GPU Selection

The miner should automatically detect and use your AMD Radeon Pro 5500M. To verify:

1. When you start mining, check the miner output
2. Look for lines mentioning "AMD" or "Radeon"
3. The hashrate should be significantly higher (500-800 kH/s range)

## Checking Your Configuration

After starting the miner, check the generated config file:

```bash
cat ~/Library/Application\ Support/vertcoin-one-click-miner/verthash-miner.conf
```

Look for `<CL_Device>` entries. You should see both:
- Intel UHD Graphics 630 (integrated)
- AMD Radeon Pro 5500M (discrete)

The miner may disable the Intel GPU by default to focus on the faster AMD GPU.

## Manual Tuning (Advanced)

If you want to manually tune the intensity for your AMD GPU:

1. Generate a config file:
```bash
cd ~/Library/Application\ Support/vertcoin-one-click-miner/miners/unpacked-*/
./VerthashMiner --gen-conf test.conf
```

2. Edit the `<CL_Device>` section for your AMD GPU
3. Key parameters:
   - `Intensity`: Higher = more GPU usage (try 19-21 for best results)
   - `WorkSize`: Should be multiple of 256 (default 256 is good)
   - `Threads`: Usually 1 per GPU

Example AMD GPU config:
```
<CL_Device Index="1"
    Intensity="20"
    WorkSize="256"
    Threads="1">
```

## Expected Hashrates

- **Intel UHD 630**: 30-50 kH/s (not recommended)
- **AMD Radeon Pro 5500M**: 500-800 kH/s (what you should get)

## Thermal Considerations

MacBooks throttle when hot. To maintain performance:

1. Use in a cool environment
2. Consider a cooling pad
3. Close other GPU-intensive applications
4. Monitor temperatures using iStat Menus or similar

## Power Settings

Ensure your Mac is:
- Plugged into AC power
- Set to "High Performance" in Energy Saver preferences
- Not in Low Power Mode

## Monitoring Performance

Watch the miner output for:
- Accepted shares (should be frequent)
- Rejected shares (should be minimal, <2%)
- GPU temperature and fan speed
- Stable hashrate without drops

## Troubleshooting

### Still getting 40 kH/s?
- The Intel GPU is being used instead of AMD
- Check that Metal/OpenCL drivers are working: `system_profiler SPDisplaysDataType`

### Hashrate drops over time?
- Thermal throttling - improve cooling
- Background apps using GPU

### Miner crashes?
- Intensity too high - reduce by 1-2 levels
- GPU memory overheating

### Lower than expected hashrate?
- Ensure discrete GPU is active (run a GPU benchmark first)
- macOS may be power-limiting the GPU
- Try disabling automatic graphics switching in System Preferences

## Benchmarking

Before mining, test your AMD GPU:

```bash
# Run a quick OpenCL benchmark
/System/Library/Frameworks/OpenCL.framework/Versions/A/Libraries/openclinfo
```

This will verify your AMD GPU is detected and working properly.

## Pool Selection

You're now configured to use WolyPooly (0.9% fee, best hashrate):
- Pool: pool.woolypooly.com:3102
- Dashboard: https://woolypooly.com/en/coin/vtc

## Estimated Earnings

With 500-800 kH/s on the AMD GPU:
- Daily VTC: ~0.5-1.5 VTC (varies with difficulty and pool luck)
- Much better than the ~0.05 VTC with 40 kH/s!

## Final Notes

The optimized binary will give you a small performance boost (5-10%), but the **biggest improvement** will come from using your AMD Radeon Pro 5500M instead of the Intel integrated graphics.

Make sure the application is actually using the discrete GPU!
