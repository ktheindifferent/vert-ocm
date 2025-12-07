package miners

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"

	"github.com/vertcoin-project/one-click-miner-vnext/logging"
	"github.com/vertcoin-project/one-click-miner-vnext/util"
)

// Compile time assertion on interface
var _ MinerImpl = &VerthashMinerImpl{}

var cfgPath = "verthash-miner-tmpl.conf"

type VerthashMinerImpl struct {
	binaryRunner  *BinaryRunner
	clhashRates   map[int64]uint64
	cuhashRates   map[int64]uint64
	mtlhashRates  map[int64]uint64
	clDeviceNames map[int64]string
	cuDeviceNames map[int64]string
	mtlDeviceNames map[int64]string
	hashRatesLock sync.Mutex
}

func (l *VerthashMinerImpl) generateTempConf() error {
	os.Remove(filepath.Join(util.DataDirectory(), cfgPath))
	err := l.binaryRunner.launch([]string{"--gen-conf", filepath.Join(util.DataDirectory(), cfgPath)}, false)
	var err2 error
	if l.binaryRunner.cmd != nil {
		err2 = l.binaryRunner.cmd.Wait()
	}
	if err != nil {
		return err
	}
	if err2 != nil {
		return err2
	}
	return nil
}

func NewVerthashMinerImpl(br *BinaryRunner) MinerImpl {
	return &VerthashMinerImpl{
		binaryRunner: br,
		clhashRates: map[int64]uint64{},
		cuhashRates: map[int64]uint64{},
		mtlhashRates: map[int64]uint64{},
		clDeviceNames: map[int64]string{},
		cuDeviceNames: map[int64]string{},
		mtlDeviceNames: map[int64]string{},
		hashRatesLock: sync.Mutex{},
	}
}

func (l *VerthashMinerImpl) Configure(args BinaryArguments) error {
	err := l.generateTempConf()
	if err != nil {
		return err
	}

	if !l.binaryRunner.cmd.ProcessState.Success() {
		return fmt.Errorf("Was unable to configure VerthashMiner. Exit code %d", l.binaryRunner.cmd.ProcessState.ExitCode())
	}

	in, err := os.Open(filepath.Join(util.DataDirectory(), "verthash-miner-tmpl.conf"))
	if err != nil {
		logging.Error(err)
		return err
	}
	defer in.Close()

	os.Remove(filepath.Join(util.DataDirectory(), "verthash-miner.conf"))
	out, err := os.Create(filepath.Join(util.DataDirectory(), "verthash-miner.conf"))
	if err != nil {
		logging.Error(err)
		return err
	}
	defer func() {
		err := out.Close()
		if err != nil {
			logging.Error(err)
		}
	}()

	var parsedDevices map[int]util.VerthashMinerDeviceConfig

	scanner := bufio.NewScanner(in)
	skip := false
	insideDeviceBlock := false
	deviceBlockStr := ""

	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "#") {
			skip = false
		}
		if strings.HasPrefix(line, "<Connection") {
			_, err = out.WriteString(fmt.Sprintf("<Connection Url = \"%s\"\n\tUsername = \"%s\"\n\tPassword = \"%s\"\n\tAlgorithm = \"Verthash\">\n\n", args.StratumUrl, args.StratumUsername, args.StratumPassword))
			if err != nil {
				return err
			}
			skip = true
		}
		if strings.HasPrefix(line, "<Global") {
			_, err = out.WriteString(fmt.Sprintf("<Global Debug=\"false\" VerthashDataFileVerification=\"false\" VerthashDataFile=\"%s\">\n\n", filepath.Join(util.DataDirectory(), "verthash.dat")))
			if err != nil {
				return err
			}
			skip = true
		}

		if strings.Contains(line, "OpenCL device config") || strings.Contains(line, "CUDA Device config") {
			logging.Debug("Entering device block")
			insideDeviceBlock = true
		} else if insideDeviceBlock {
			deviceBlockStr += line + "\n"
		}

		if strings.Contains(line, "#-#-#-#-#-#-#-#-#-#-#-") && insideDeviceBlock {
			insideDeviceBlock = false
			parsedDevices = util.ParseVerthashMinerDeviceCfg(deviceBlockStr)
			logging.Debug("Exiting device block")
			logging.Debug(parsedDevices[0])
			deviceBlockStr = ""
		}

		if strings.HasPrefix(line, "<CL_Device") {
			words := strings.SplitAfter(line, " ")
			thisDeviceIndexNumber, _ := strconv.Atoi(strings.Trim(words[3], "\""))

			if device, ok := parsedDevices[thisDeviceIndexNumber]; ok {
				if strings.Contains(device.Platform, "Intel") && !args.EnableIntegrated {
					logging.Debug("Intel disabled.")
					skip = true
				}
			}
		}

		if !skip {
			_, err = out.WriteString(fmt.Sprintf("%s\n", line))
			if err != nil {
				return err
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return err
	}
	return nil
}

func (l *VerthashMinerImpl) ParseOutput(line string) {
	if l.binaryRunner.Debug {
		logging.Debugf("[VerthashMiner] %s\n", line)
	}
	line = strings.TrimSpace(line)

	// Parse Metal device initialization: "Configured Metal worker for discrete GPU: AMD Radeon Pro 5500M"
	if strings.Contains(line, "Configured Metal worker for discrete GPU:") {
		parts := strings.Split(line, ": ")
		if len(parts) >= 2 {
			deviceName := parts[len(parts)-1]
			l.hashRatesLock.Lock()
			l.mtlDeviceNames[0] = deviceName  // Currently single Metal device
			l.hashRatesLock.Unlock()
		}
	}

	// Parse Metal hashrate: "mtl_device: hashrate: X.XX kH/s"
	if strings.Contains(line, "mtl_device:") && strings.HasSuffix(line, "H/s") {
		logging.Debugf("[Metal Hashrate] Matched line: %s", line)
		startMHs := strings.LastIndex(line, ": ")
		if startMHs > -1 {
			hashRateUnit := strings.ToUpper(line[len(line)-4 : len(line)-3])
			hrStr := line[startMHs+2 : len(line)-5]
			logging.Debugf("[Metal Hashrate] Extracted: %s %sH/s", hrStr, hashRateUnit)
			f, err := strconv.ParseFloat(hrStr, 64)
			if err != nil {
				logging.Errorf("Error parsing Metal hashrate: %s\n", err.Error())
			} else {
				if hashRateUnit == "K" {
					f = f * 1000
				} else if hashRateUnit == "M" {
					f = f * 1000 * 1000
				} else if hashRateUnit == "G" {
					f = f * 1000 * 1000 * 1000
				}

				l.hashRatesLock.Lock()
				l.mtlhashRates[0] = uint64(f)  // Currently single Metal device
				l.hashRatesLock.Unlock()
				logging.Debugf("[Metal Hashrate] Set mtlhashRates[0] = %d", uint64(f))
			}
		}
	}

	// Parse OpenCL/CUDA hashrates: "cl_device(0): hashrate: X.XX kH/s"
	if strings.Contains(line, "_device(") && strings.HasSuffix(line, "H/s") {
		logging.Debugf("[CL/CU Hashrate] Matched line: %s", line)
		startMHs := strings.LastIndex(line, ": ")
		if startMHs > -1 {
			deviceIdxStart := strings.Index(line, "_device(") + 8
			deviceTypeStart := strings.Index(line, "_device(") - 2
			deviceIdxEnd := strings.Index(line[deviceIdxStart:], ")")
			deviceIdxString := line[deviceIdxStart : deviceIdxStart+deviceIdxEnd]
			deviceIdx, _ := strconv.ParseInt(deviceIdxString, 10, 64)
			deviceType := line[deviceTypeStart : deviceTypeStart+2]

			hashRateUnit := strings.ToUpper(line[len(line)-4 : len(line)-3])
			hrStr := line[startMHs+2 : len(line)-5]
			logging.Debugf("[CL/CU Hashrate] Device: %s(%d), Extracted: %s %sH/s", deviceType, deviceIdx, hrStr, hashRateUnit)
			f, err := strconv.ParseFloat(hrStr, 64)
			if err != nil {
				logging.Errorf("Error parsing hashrate: %s\n", err.Error())
			} else {
				if hashRateUnit == "K" {
					f = f * 1000
				} else if hashRateUnit == "M" {
					f = f * 1000 * 1000
				} else if hashRateUnit == "G" {
					f = f * 1000 * 1000 * 1000
				}

				l.hashRatesLock.Lock()
				if deviceType == "cu" {
					l.cuhashRates[deviceIdx] = uint64(f)
					logging.Debugf("[CL/CU Hashrate] Set cuhashRates[%d] = %d", deviceIdx, uint64(f))
				} else {
					l.clhashRates[deviceIdx] = uint64(f)
					logging.Debugf("[CL/CU Hashrate] Set clhashRates[%d] = %d", deviceIdx, uint64(f))
				}
				l.hashRatesLock.Unlock()
			}
		}
	}
}

func (l *VerthashMinerImpl) HashRate() uint64 {
	totalHash := uint64(0)
	l.hashRatesLock.Lock()
	for _, h := range l.cuhashRates {
		totalHash += h
	}
	for _, h := range l.clhashRates {
		totalHash += h
	}
	for _, h := range l.mtlhashRates {
		totalHash += h
	}
	l.hashRatesLock.Unlock()

	return totalHash
}

func (l *VerthashMinerImpl) ConstructCommandlineArgs(args BinaryArguments) []string {
	return []string{"--conf", filepath.Join(util.DataDirectory(), "verthash-miner.conf")}
}

func (l *VerthashMinerImpl) AvailableGPUs() int8 {
	logging.Debugf("AvailableGPUs called\n")
	tmpCfg := filepath.Join(util.DataDirectory(), "verthash-miner-tmp.conf")
	err := l.binaryRunner.launch([]string{"--gen-conf", tmpCfg}, false)
	err2 := l.binaryRunner.cmd.Wait()
	if err != nil {
		logging.Error(err)
		return 0
	}
	if err2 != nil {
		logging.Error(err)
		return 0
	}

	if !l.binaryRunner.cmd.ProcessState.Success() {
		logging.Errorf("Process state: %d", l.binaryRunner.cmd.ProcessState)
		return 0
	}

	in, err := os.Open(tmpCfg)
	if err != nil {
		logging.Error(err)
		return 0
	}
	gpu := int8(0)
	scanner := bufio.NewScanner(in)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "<CL_Device") {
			gpu++
		}
		if strings.HasPrefix(line, "<CU_Device") {
			gpu++
		}
	}
	in.Close()
	os.Remove(tmpCfg)
	return gpu
}

func (l *VerthashMinerImpl) GetDevices() []DeviceInfo {
	devices := []DeviceInfo{}

	l.hashRatesLock.Lock()
	defer l.hashRatesLock.Unlock()

	logging.Debugf("[GetDevices] CL: %d, CU: %d, MTL: %d devices", len(l.clhashRates), len(l.cuhashRates), len(l.mtlhashRates))

	// Add OpenCL devices
	for id, hr := range l.clhashRates {
		name := l.clDeviceNames[id]
		if name == "" {
			name = fmt.Sprintf("OpenCL Device %d", id)
		}
		devices = append(devices, DeviceInfo{
			DeviceID:     id,
			DeviceName:   name,
			DeviceType:   "OpenCL",
			HashRate:     hr,
			HashRateStr:  formatHashRate(hr),
		})
	}

	// Add CUDA devices
	for id, hr := range l.cuhashRates {
		name := l.cuDeviceNames[id]
		if name == "" {
			name = fmt.Sprintf("CUDA Device %d", id)
		}
		devices = append(devices, DeviceInfo{
			DeviceID:     id,
			DeviceName:   name,
			DeviceType:   "CUDA",
			HashRate:     hr,
			HashRateStr:  formatHashRate(hr),
		})
	}

	// Add Metal devices
	for id, hr := range l.mtlhashRates {
		name := l.mtlDeviceNames[id]
		if name == "" {
			name = fmt.Sprintf("Metal Device %d", id)
		}
		devices = append(devices, DeviceInfo{
			DeviceID:     id,
			DeviceName:   name,
			DeviceType:   "Metal",
			HashRate:     hr,
			HashRateStr:  formatHashRate(hr),
		})
	}

	return devices
}

func formatHashRate(hashrate uint64) string {
	hashrateFloat := float64(hashrate)
	hashrateUnit := "H/s"

	if hashrateFloat > 1000 {
		hashrateFloat = hashrateFloat / 1000
		hashrateUnit = "kH/s"
	}
	if hashrateFloat > 1000 {
		hashrateFloat = hashrateFloat / 1000
		hashrateUnit = "MH/s"
	}
	if hashrateFloat > 1000 {
		hashrateFloat = hashrateFloat / 1000
		hashrateUnit = "GH/s"
	}
	if hashrateFloat > 1000 {
		hashrateFloat = hashrateFloat / 1000
		hashrateUnit = "TH/s"
	}

	return fmt.Sprintf("%0.2f %s", hashrateFloat, hashrateUnit)
}
