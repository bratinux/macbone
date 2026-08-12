import AppKit
import Foundation
import CoreAudio
import AudioToolbox

let version = "0.3.0"

@main
struct Macbone {
    static func main() {
        let args = CommandLine.arguments

        if args.count == 2 && (args[1] == "--version" || args[1] == "version") {
            print("macbone version \(version)")
            return
        }

        guard args.count > 1 else {
            printUsage()
            exit(1)
        }

        let command = args[1]
        let subArgs = Array(args.dropFirst(2))

        switch command {
        case "dark":           handleDark(subArgs)
        case "battery":        handleBattery(subArgs)
        case "audio":          handleAudio(subArgs)
        case "sleep":          handleSleep()
        case "lock":           handleLock()
        case "trash":          handleTrash(subArgs)
        case "finder":         handleFinder(subArgs)
        case "wallpaper":      handleWallpaper(subArgs)
        case "cpu":            handleCPU()
        case "memory":         handleMemory()
        case "thermal":        handleThermal()
        case "info":           handleInfo()
        case "help", "--help": printUsage()
        default:
            print("Unknown command: \(command)")
            printUsage()
            exit(1)
        }
    }

    static func printUsage() {
        let usage = """
        macbone \(version) — The backbone of your Mac

        USAGE: macbone <command> [options]

        COMMANDS:
          dark          on | off | toggle | status
          battery       Show battery charge and status
          battery health Show battery health and cycle count
          audio volume  0-100 | status | up | down
          audio mute    on | off | toggle | status
          wallpaper     set <path>
          sleep         Put the Mac to sleep immediately
          lock          Lock the screen
          trash empty   Empty the Trash
          finder showhidden  on | off | toggle | status
          cpu           Show CPU information and load
          memory        Show memory usage and pressure
          thermal       Show thermal state
          info          Show system information
          version       Print version
        """
        print(usage)
    }
}

func handleDark(_ args: [String]) {
    let mode = args.first ?? "status"

    let getStateScript = "tell application \"System Events\" to tell appearance preferences to return dark mode"
    guard let getState = NSAppleScript(source: getStateScript) else {
        print("Error: could not create AppleScript")
        exit(1)
    }
    var error: NSDictionary?
    let currentResult = getState.executeAndReturnError(&error)
    let currentlyDark = currentResult.booleanValue

    if let error = error {
        print("Error reading dark mode state: \(error)")
        exit(1)
    }

    if mode == "status" {
        print(currentlyDark ? "Dark mode is on" : "Dark mode is off")
        return
    }

    if mode == "on" {
        if currentlyDark {
            print("Dark mode is already on")
            return
        }
    } else if mode == "off" {
        if !currentlyDark {
            print("Dark mode is already off")
            return
        }
    } else if mode != "toggle" {
        print("Unknown dark mode option: \(mode)")
        exit(1)
    }

    let targetState: Bool
    if mode == "on" {
        targetState = true
    } else if mode == "off" {
        targetState = false
    } else {
        targetState = !currentlyDark
    }

    let setScript: String
    if targetState {
        setScript = "tell application \"System Events\" to tell appearance preferences to set dark mode to true"
    } else {
        setScript = "tell application \"System Events\" to tell appearance preferences to set dark mode to false"
    }

    guard let appleScript = NSAppleScript(source: setScript) else {
        print("Error: could not create AppleScript")
        exit(1)
    }
    error = nil
    appleScript.executeAndReturnError(&error)
    if let error = error {
        print("Error setting dark mode: \(error)")
        exit(1)
    }

    print("Dark mode is now \(targetState ? "on" : "off")")
}

func handleBattery(_ args: [String]) {
    if args.first == "health" {
        handleBatteryHealth()
        return
    }

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    task.arguments = ["-g", "batt"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else {
        print("Could not read battery information")
        exit(1)
    }

    var foundBattery = false
    for line in output.components(separatedBy: "\n") {
        if line.contains("-InternalBattery") || line.contains("-Battery") {
            foundBattery = true
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 2 else { continue }
            let info = parts[1].trimmingCharacters(in: .whitespaces)

            let semicolons = info.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard semicolons.count >= 2 else { continue }

            let percentStr = semicolons[0].replacingOccurrences(of: "%", with: "")
            let percent = Int(percentStr) ?? 0

            let state = semicolons[1].lowercased()
            var statusText = ""
            var timeRemaining = ""

            if semicolons.count >= 3 {
                let rawRemainder = semicolons[2]
                let remainder = rawRemainder.trimmingCharacters(in: .whitespaces)

                if remainder.contains("remaining") {
                    timeRemaining = remainder.replacingOccurrences(of: " remaining", with: "")
                } else if remainder.contains("(no estimate)") {
                    timeRemaining = ""
                } else if remainder.contains(":") {
                    timeRemaining = remainder
                } else {
                    timeRemaining = ""
                }
            }

            if state.contains("discharging") {
                statusText = "on battery"
                if !timeRemaining.isEmpty {
                    statusText += " (\(timeRemaining) remaining)"
                }
            } else if state.contains("charging") {
                statusText = "charging"
            } else if state.contains("ac attached") || state.contains("charged") {
                statusText = "not charging (AC attached)"
            } else {
                statusText = state
            }

            print("Battery: \(percent)% (\(statusText))")
        }
    }

    if !foundBattery {
        let model = getModelIdentifier()
        if model.contains("Macmini") || model.contains("iMac") || model.contains("MacPro") || model.contains("MacStudio") {
            print("No battery – this Mac is a desktop (AC power only)")
        } else {
            print("No internal battery found")
        }
    }
}

func handleBatteryHealth() {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
    task.arguments = ["SPPowerDataType"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else {
        print("Could not read battery health information")
        exit(1)
    }

    var healthPercent = ""
    var cycleCount = ""

    for line in output.components(separatedBy: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("Health Information:") {
            continue
        }
        if trimmed.hasPrefix("Cycle Count:") {
            cycleCount = trimmed.replacingOccurrences(of: "Cycle Count:", with: "").trimmingCharacters(in: .whitespaces)
        }
        if trimmed.hasPrefix("Maximum Capacity:") {
            healthPercent = trimmed.replacingOccurrences(of: "Maximum Capacity:", with: "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "")
        }
    }

    if healthPercent.isEmpty || cycleCount.isEmpty {
        let model = getModelIdentifier()
        if model.contains("Macmini") || model.contains("iMac") || model.contains("MacPro") || model.contains("MacStudio") {
            print("No battery – this Mac is a desktop (AC power only)")
        } else {
            print("No internal battery found")
        }
    } else {
        print("Battery Health: \(healthPercent)% (cycle count: \(cycleCount))")
    }
}

func getModelIdentifier() -> String {
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var model = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &model, &size, nil, 0)
    let modelData = Data(bytes: model, count: size)
    return String(data: modelData, encoding: .utf8) ?? "Unknown"
}

func handleAudio(_ args: [String]) {
    guard let sub = args.first else {
        print("audio requires a subcommand: volume, mute")
        exit(1)
    }
    switch sub {
    case "volume":  handleVolume(Array(args.dropFirst()))
    case "mute":    handleMute(Array(args.dropFirst()))
    default:
        print("Unknown audio subcommand: \(sub)")
        exit(1)
    }
}

func handleVolume(_ args: [String]) {
    var defaultOutput = AudioDeviceID()
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &defaultOutput)

    if args.isEmpty || (args.count == 1 && args[0] == "status") {
        var left: Float32 = 0
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(defaultOutput, &volumeAddress, 0, nil, &size, &left)
        let percent = Int(left * 100)
        print("Volume is \(percent)%")
        return
    }

    if args.first == "up" || args.first == "down" {
        var left: Float32 = 0
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(defaultOutput, &volumeAddress, 0, nil, &size, &left)
        var current = Int(left * 100)

        if args.first == "up" {
            current = min(100, current + 10)
        } else {
            current = max(0, current - 10)
        }

        var newVolume: Float32 = Float32(current) / 100.0
        let setStatus = AudioObjectSetPropertyData(defaultOutput, &volumeAddress, 0, nil, UInt32(MemoryLayout<Float32>.size), &newVolume)
        if setStatus == noErr {
            print("Volume set to \(current)%")
        } else {
            print("Failed to set volume")
            exit(1)
        }
        return
    }

    guard let volStr = args.first, let vol = Int(volStr), (0...100).contains(vol) else {
        print("Volume must be between 0 and 100, or use up/down/status")
        exit(1)
    }

    var left: Float32 = Float32(vol) / 100.0
    var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectSetPropertyData(defaultOutput, &volumeAddress, 0, nil, UInt32(MemoryLayout<Float32>.size), &left)
    if status == noErr {
        print("Volume set to \(vol)%")
    } else {
        print("Failed to set volume")
        exit(1)
    }
}

func handleMute(_ args: [String]) {
    guard let action = args.first else {
        print("mute requires on | off | toggle | status")
        exit(1)
    }

    var defaultOutput = AudioDeviceID()
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &defaultOutput)

    var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    var isMuted: UInt32 = 0
    var propSize = UInt32(MemoryLayout<UInt32>.size)
    AudioObjectGetPropertyData(defaultOutput, &muteAddress, 0, nil, &propSize, &isMuted)

    if action == "status" {
        print(isMuted == 1 ? "Audio is muted" : "Audio is not muted")
        return
    }

    let newMute: UInt32
    switch action {
    case "on":      newMute = 1
    case "off":     newMute = 0
    case "toggle":  newMute = isMuted == 1 ? 0 : 1
    default:
        print("Unknown mute option: \(action)")
        exit(1)
    }

    var muteVal = newMute
    AudioObjectSetPropertyData(defaultOutput, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muteVal)

    if newMute == 1 {
        print("Audio is now muted")
    } else {
        print("Audio is now unmuted")
    }
}

func handleSleep() {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    task.arguments = ["sleepnow"]
    task.launch()
    task.waitUntilExit()
}

func handleLock() {
    let cgSessionPath = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
    if FileManager.default.isExecutableFile(atPath: cgSessionPath) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: cgSessionPath)
        task.arguments = ["-suspend"]
        task.launch()
        task.waitUntilExit()
    } else {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "ScreenSaverEngine"]
        task.launch()
        task.waitUntilExit()
    }
}

func handleTrash(_ args: [String]) {
    guard let sub = args.first, sub == "empty" else {
        print("trash empty   — empty the Trash")
        exit(1)
    }

    let script = "tell application \"Finder\" to empty trash"
    guard let appleScript = NSAppleScript(source: script) else {
        print("Failed to create AppleScript")
        exit(1)
    }
    var error: NSDictionary?
    appleScript.executeAndReturnError(&error)
    if let error = error {
        let errorNumber = error[NSAppleScript.errorNumber] as? Int
        if errorNumber == -128 {
            print("Trash is already empty")
        } else {
            print("Failed to empty trash: \(error)")
        }
        exit(1)
    }
    print("Trash emptied successfully")
}

func handleFinder(_ args: [String]) {
    guard args.count >= 2, args[0] == "showhidden" else {
        print("finder showhidden on | off | toggle | status")
        exit(1)
    }
    let action = args[1]

    let getStateTask = Process()
    getStateTask.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    getStateTask.arguments = ["read", "com.apple.finder", "AppleShowAllFiles"]
    let getPipe = Pipe()
    getStateTask.standardOutput = getPipe
    getStateTask.launch()
    getStateTask.waitUntilExit()
    let data = getPipe.fileHandleForReading.readDataToEndOfFile()
    let currentState = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
    let currentlyShowing = (currentState == "1" || currentState == "YES")

    if action == "status" {
        print(currentlyShowing ? "Hidden files are visible" : "Hidden files are hidden")
        return
    }

    let targetShow: Bool
    switch action {
    case "on":
        targetShow = true
    case "off":
        targetShow = false
    case "toggle":
        targetShow = !currentlyShowing
    default:
        print("Invalid option: \(action)")
        exit(1)
    }

    if targetShow == currentlyShowing {
        if targetShow {
            print("Hidden files are already visible")
        } else {
            print("Hidden files are already hidden")
        }
        return
    }

    let cmd: String
    if targetShow {
        cmd = "defaults write com.apple.finder AppleShowAllFiles -bool YES && killall Finder"
    } else {
        cmd = "defaults write com.apple.finder AppleShowAllFiles -bool NO && killall Finder"
    }

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    task.arguments = ["-c", cmd]
    task.launch()
    task.waitUntilExit()

    if targetShow {
        print("Hidden files are now visible")
    } else {
        print("Hidden files are now hidden")
    }
}

func handleWallpaper(_ args: [String]) {
    guard args.count >= 2, args[0] == "set" else {
        print("wallpaper set <path>")
        exit(1)
    }

    let path = args[1]
    let url = URL(fileURLWithPath: path)

    guard FileManager.default.fileExists(atPath: path) else {
        print("File not found: \(path)")
        exit(1)
    }

    do {
        for screen in NSScreen.screens {
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
        }
        print("Wallpaper set to \(path)")
    } catch {
        print("Failed to set wallpaper: \(error.localizedDescription)")
        exit(1)
    }
}

func handleCPU() {
    let brand = runSysctlString("machdep.cpu.brand_string")

    let perfCores = runSysctlInt("hw.perflevel0.logicalcpu") ?? 0
    let effCores = runSysctlInt("hw.perflevel1.logicalcpu") ?? 0
    let totalCores = runSysctlInt("hw.ncpu") ?? 0

    var coreDescription: String
    if perfCores > 0 && effCores > 0 {
        coreDescription = "\(perfCores) performance, \(effCores) efficiency cores"
    } else if totalCores > 0 {
        coreDescription = "\(totalCores) cores"
    } else {
        coreDescription = "unknown cores"
    }

    var loadInfo = "unknown"
    var loadavg = [Double](repeating: 0.0, count: 3)
    if getloadavg(&loadavg, 3) != -1 {
        let loadPercent = Int((loadavg[0] / Double(totalCores)) * 100)
        loadInfo = "\(loadPercent)%"
    }

    print("CPU: \(brand) (\(coreDescription))")
    print("Load: \(loadInfo)")
}

func handleMemory() {
    let totalBytes = runSysctlUInt64("hw.memsize") ?? 0
    let totalGB = Double(totalBytes) / 1_000_000_000.0

    let pageSize = runSysctlInt("hw.pagesize") ?? 16384
    var vmStat = vm_statistics64()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &vmStat) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
        }
    }

    var usedBytes: UInt64 = 0
    if result == KERN_SUCCESS {
        usedBytes = UInt64(vmStat.active_count + vmStat.wire_count + vmStat.compressor_page_count) * UInt64(pageSize)
    }
    let usedGB = Double(usedBytes) / 1_000_000_000.0
    let usedPercent = totalBytes > 0 ? Int((Double(usedBytes) / Double(totalBytes)) * 100) : 0

    var pressureLevel = "Unknown"
    var pressureInt: Int32 = 0
    var pressureSize = MemoryLayout<Int32>.size
    if sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureInt, &pressureSize, nil, 0) == 0 {
        switch pressureInt {
        case 1: pressureLevel = "Normal"
        case 2: pressureLevel = "Warning"
        case 4: pressureLevel = "Critical"
        default: pressureLevel = "Unknown"
        }
    }

    print(String(format: "Memory: %.1f GB total, %.1f GB used (\(usedPercent)%%)", totalGB, usedGB))
    print("Pressure: \(pressureLevel)")
}

func handleThermal() {
    let state = ProcessInfo.processInfo.thermalState
    let stateString: String
    switch state {
    case .nominal:  stateString = "Nominal"
    case .fair:     stateString = "Fair"
    case .serious:  stateString = "Serious"
    case .critical: stateString = "Critical"
    @unknown default: stateString = "Unknown"
    }
    print("Thermal State: \(stateString)")
}

func handleInfo() {
    let processInfo = ProcessInfo.processInfo
    let osVersion = processInfo.operatingSystemVersionString
    let hostName = processInfo.hostName
    let uptime = processInfo.systemUptime

    let modelStr = getModelIdentifier()

    let serial: String
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
    task.arguments = ["SPHardwareDataType"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
        if let range = output.range(of: "Serial Number (system): ") {
            let start = range.upperBound
            let end = output[start...].firstIndex(of: "\n") ?? output.endIndex
            serial = String(output[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            serial = "Unknown"
        }
    } else {
        serial = "Unknown"
    }

    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.day, .hour, .minute]
    formatter.unitsStyle = .abbreviated
    let uptimeStr = formatter.string(from: uptime) ?? "\(Int(uptime)) sec"

    print("""
    Host:        \(hostName)
    OS:          \(osVersion)
    Model:       \(modelStr)
    Serial:      \(serial)
    Uptime:      \(uptimeStr)
    """)
}

func runSysctlString(_ name: String) -> String {
    var size = 0
    if sysctlbyname(name, nil, &size, nil, 0) != 0 {
        return "Unknown"
    }
    var value = [CChar](repeating: 0, count: size)
    if sysctlbyname(name, &value, &size, nil, 0) != 0 {
        return "Unknown"
    }
    let data = Data(bytes: value, count: size)
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) ?? "Unknown"
}

func runSysctlInt(_ name: String) -> Int? {
    var value: Int32 = 0
    var size = MemoryLayout<Int32>.size
    if sysctlbyname(name, &value, &size, nil, 0) == 0 {
        return Int(value)
    }
    return nil
}

func runSysctlUInt64(_ name: String) -> UInt64? {
    var value: UInt64 = 0
    var size = MemoryLayout<UInt64>.size
    if sysctlbyname(name, &value, &size, nil, 0) == 0 {
        return value
    }
    return nil
}
