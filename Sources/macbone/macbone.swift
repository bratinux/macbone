import AppKit
import Foundation
import CoreAudio
import AudioToolbox

let version = "0.7.0"

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
        case "disk":           handleDisk(subArgs)
        case "process":        handleProcess(subArgs)
        case "notify":         handleNotify(subArgs)
        case "openwith":       handleOpenWith(subArgs)
        case "eject":          handleEject(subArgs)
        case "ejectall":       handleEjectAll()
        case "network":        handleNetwork()
        case "updates":        handleUpdates()
        case "proxy":          handleProxy()
        case "airdrop":        handleAirDrop(subArgs)
        case "dock":           handleDock(subArgs)
        case "accent":         handleAccent(subArgs)
        case "highlight":      handleHighlight(subArgs)
        case "gatekeeper":     handleGatekeeper(subArgs)
        case "noidle":         handleNoidle(subArgs)
        case "displaysleep":   handleDisplaySleep(subArgs)
        case "boottime":       handleBootTime()
        case "shutdown":       handleShutdown()
        case "reboot":         handleReboot()
        case "purge":          handlePurge()
        case "restart":        handleRestart(subArgs)
        case "kill":           handleKill(subArgs)
        case "search":         handleSearch(subArgs)
        case "du":             handleDu(subArgs)
        case "fileinfo":       handleFileInfo(subArgs)
        case "hide":           handleHide(subArgs)
        case "unhide":         handleUnhide(subArgs)
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
          disk          Show system volume usage
          disk list     Show all mounted volumes
          process       Show process by name
          process top   Show top processes by CPU or memory
          notify        Send a notification
          openwith      Open file with specific app
          eject         Eject a volume
          ejectall      Eject all removable volumes
          network       Show current network info
          updates       List available macOS updates
          proxy         Show proxy settings
          airdrop       on | off | status
          dock          autohide | magnification on|off|toggle|status
          accent        <color> | status
          highlight     <color> | status
          gatekeeper    enable | disable | status
          noidle        <minutes>  Prevent sleep for N minutes
          displaysleep  <minutes>  Set display sleep timeout
          boottime      Show last boot time
          shutdown      Shut down the Mac
          reboot        Reboot the Mac
          purge         Purge inactive memory (requires sudo)
          restart       finder | dock | controlcenter | audio
          kill          <name> | --force <name>
          search        <query> | --name <filename> | --path <dir> --name <pat> | --all
          du            <path> | --top <path>
          fileinfo      <path>
          hide          <path>
          unhide        <path>
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
    do {
        try task.run()
    } catch {
        print("Failed to run pmset: \(error.localizedDescription)")
        exit(1)
    }
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
    do {
        try task.run()
    } catch {
        print("Failed to run system_profiler: \(error.localizedDescription)")
        exit(1)
    }
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
    do {
        try task.run()
    } catch {
        print("Failed to run pmset: \(error.localizedDescription)")
        exit(1)
    }
    task.waitUntilExit()
}

func handleLock() {
    let cgSessionPath = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
    if FileManager.default.isExecutableFile(atPath: cgSessionPath) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: cgSessionPath)
        task.arguments = ["-suspend"]
        do {
            try task.run()
        } catch {
            print("Failed to lock screen: \(error.localizedDescription)")
            exit(1)
        }
        task.waitUntilExit()
    } else {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "ScreenSaverEngine"]
        do {
            try task.run()
        } catch {
            print("Failed to lock screen: \(error.localizedDescription)")
            exit(1)
        }
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
    do {
        try getStateTask.run()
    } catch {
        print("Failed to read Finder state: \(error.localizedDescription)")
        exit(1)
    }
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
    do {
        try task.run()
    } catch {
        print("Failed to set Finder state: \(error.localizedDescription)")
        exit(1)
    }
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
    do {
        try task.run()
    } catch {
        print("Failed to run system_profiler: \(error.localizedDescription)")
        exit(1)
    }
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

func handleDisk(_ args: [String]) {
    if args.first == "list" {
        listDisks()
    } else {
        showMainDisk()
    }
}

func showMainDisk() {
    let mainVolumeURL = URL(fileURLWithPath: "/")
    guard let values = try? mainVolumeURL.resourceValues(forKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]) else {
        print("Could not read volume info")
        exit(1)
    }
    let total = Int64(values.volumeTotalCapacity ?? 0)
    let available = Int64(values.volumeAvailableCapacity ?? 0)
    let used = total - available
    let percent = total > 0 ? Int((Double(used) / Double(total)) * 100) : 0
    let name = values.volumeName ?? "System"
    print("\(name): \(formatBytes(used)) used of \(formatBytes(total)) (\(percent)%) — \(formatBytes(available)) free")
}

func listDisks() {
    guard let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey], options: [.skipHiddenVolumes]) else {
        print("Could not list volumes")
        exit(1)
    }
    for volume in volumes {
        guard let values = try? volume.resourceValues(forKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]) else { continue }
        let name = values.volumeName ?? volume.lastPathComponent
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let available = Int64(values.volumeAvailableCapacity ?? 0)
        if total <= 0 { continue }
        print("\(name)\t\(formatBytes(total)) total, \(formatBytes(available)) free")
    }
}

func formatBytes(_ bytes: Int64) -> String {
    let gb = Double(bytes) / 1_000_000_000.0
    return String(format: "%.1f GB", gb)
}

func handleProcess(_ args: [String]) {
    guard let sub = args.first else {
        print("process <name> or process top [--cpu|--memory] [--count N]")
        exit(1)
    }
    if sub == "top" {
        processTop(Array(args.dropFirst()))
    } else {
        processSearch(sub)
    }
}

func processSearch(_ name: String) {
    let (output, _, status) = runCommand("/bin/ps", ["-axo", "pid=,%cpu=,%mem=,comm="])
    guard status == 0 else {
        print("Failed to list processes")
        exit(1)
    }
    let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
    let filtered = lines.filter { line in
        let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
        guard parts.count >= 4 else { return false }
        let comm = parts[3]
        return comm.localizedCaseInsensitiveContains(name)
    }
    if filtered.isEmpty {
        print("No processes found matching '\(name)'")
        return
    }
    print("PID   CPU%   MEM%   NAME")
    for line in filtered {
        print(line)
    }
}

func processTop(_ args: [String]) {
    var sortBy = "cpu"
    var count = 10
    var i = 0
    while i < args.count {
        if args[i] == "--cpu" { sortBy = "cpu" }
        else if args[i] == "--memory" { sortBy = "memory" }
        else if args[i] == "--count", i+1 < args.count, let n = Int(args[i+1]) { count = max(1, n); i += 1 }
        else { print("Unknown option: \(args[i])"); exit(1) }
        i += 1
    }

    let (output, _, status) = runCommand("/bin/ps", ["-axo", "pid=,%cpu=,%mem=,comm="])
    guard status == 0 else {
        print("Failed to list processes")
        exit(1)
    }
    let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
    var parsed: [(pid: String, cpu: Double, mem: Double, name: String)] = []
    for line in lines {
        let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
        guard parts.count >= 4 else { continue }
        guard let cpu = Double(parts[1]), let mem = Double(parts[2]) else { continue }
        parsed.append((String(parts[0]), cpu, mem, String(parts[3])))
    }
    parsed.sort {
        if sortBy == "cpu" {
            return $0.cpu > $1.cpu
        } else {
            return $0.mem > $1.mem
        }
    }
    let top = Array(parsed.prefix(count))
    print("PID   CPU%   MEM%   NAME")
    for p in top {
        print("\(p.pid.padding(toLength: 8, withPad: " ", startingAt: 0)) \(String(format: "%.1f", p.cpu).padding(toLength: 6, withPad: " ", startingAt: 0)) \(String(format: "%.1f", p.mem).padding(toLength: 6, withPad: " ", startingAt: 0)) \(p.name)")
    }
}

func handleNotify(_ args: [String]) {
    var message = ""
    var title = "macbone"
    var i = 0
    while i < args.count {
        if args[i] == "--title", i+1 < args.count {
            title = args[i+1]
            i += 2
        } else {
            message = args[i]
            i += 1
        }
    }
    guard !message.isEmpty else {
        print("notify <message> [--title <text>]")
        exit(1)
    }
    let escapedMessage = message.replacingOccurrences(of: "\"", with: "\\\"")
    let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
    let script = "display notification \"\(escapedMessage)\" with title \"\(escapedTitle)\""
    let (_, err, status) = runCommand("/usr/bin/osascript", ["-e", script])
    if status != 0 {
        print("Failed to send notification: \(err)")
        exit(1)
    }
    print("Notification sent")
}

func handleOpenWith(_ args: [String]) {
    guard args.count >= 2 else {
        print("openwith <app> <file>")
        exit(1)
    }
    let app = args[0]
    let file = args[1]
    guard FileManager.default.fileExists(atPath: file) else {
        print("File not found: \(file)")
        exit(1)
    }
    let (_, err, status) = runCommand("/usr/bin/open", ["-a", app, file])
    if status != 0 {
        print("Failed to open \(file) with \(app): \(err)")
        exit(1)
    }
    print("Opening \(file) with \(app)")
}

func handleEject(_ args: [String]) {
    guard args.count == 1 else {
        print("eject <mountpoint>")
        exit(1)
    }
    let mountPoint = args[0]
    let url = URL(fileURLWithPath: mountPoint)
    do {
        try NSWorkspace.shared.unmountAndEjectDevice(at: url)
        print("Ejected \(mountPoint)")
    } catch {
        print("Failed to eject \(mountPoint): \(error.localizedDescription)")
        exit(1)
    }
}

func handleEjectAll() {
    guard let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey], options: [.skipHiddenVolumes]) else {
        print("Could not list volumes")
        exit(1)
    }
    var ejected = 0
    for volume in volumes {
        guard let values = try? volume.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey]) else { continue }
        if values.volumeIsRemovable == true || values.volumeIsEjectable == true {
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: volume)
                ejected += 1
            } catch {
                print("Failed to eject \(volume.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }
    print("Ejected \(ejected) volume\(ejected == 1 ? "" : "s")")
}

func handleNetwork() {
    let (wifiOut, _, wifiStatus) = runCommand("/usr/sbin/networksetup", ["-getinfo", "Wi-Fi"])
    if wifiStatus == 0 && wifiOut.contains("IP address") {
        printNetworkInfo(from: wifiOut, service: "Wi-Fi")
        return
    }

    let (ethOut, _, ethStatus) = runCommand("/usr/sbin/networksetup", ["-getinfo", "Ethernet"])
    if ethStatus == 0 && ethOut.contains("IP address") {
        printNetworkInfo(from: ethOut, service: "Ethernet")
        return
    }

    print("No active network connection found")
    exit(1)
}

func printNetworkInfo(from output: String, service: String) {
    let ip = extractValue(output, prefix: "IP address:")
    let router = extractValue(output, prefix: "Router:")

    var ssid = ""
    if service == "Wi-Fi" {
        let (ssidOut, _, _) = runCommand("/usr/sbin/networksetup", ["-getairportnetwork", "en0"])
        ssid = extractValue(ssidOut, prefix: "Current Wi-Fi Network:") ?? ""
    }

    var dns = ""
    let (dnsOut, _, _) = runCommand("/usr/sbin/scutil", ["--dns"])
    dns = extractValue(dnsOut, prefix: "nameserver[0] :") ?? ""

    print("Service:   \(service)")
    if !ssid.isEmpty { print("SSID:      \(ssid)") }
    if let ip = ip, !ip.isEmpty { print("IP:        \(ip)") }
    if let router = router, !router.isEmpty { print("Router:    \(router)") }
    if !dns.isEmpty { print("DNS:       \(dns)") }
}

func extractValue(_ output: String, prefix: String) -> String? {
    for line in output.components(separatedBy: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix(prefix) {
            return trimmed.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespaces)
        }
    }
    return nil
}

func handleUpdates() {
    let (output, err, status) = runCommand("/usr/sbin/softwareupdate", ["--list"])
    if status != 0 {
        print("Failed to list updates: \(err)")
        exit(1)
    }
    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        print("No updates available")
    } else {
        print(trimmed)
    }
}

func handleProxy() {
    let (output, _, status) = runCommand("/usr/sbin/scutil", ["--proxy"])
    guard status == 0 else {
        print("Failed to read proxy settings")
        exit(1)
    }

    let httpEnabled = extractValue(output, prefix: "HTTPEnable :") == "1"
    let httpsEnabled = extractValue(output, prefix: "HTTPSEnable :") == "1"
    let socksEnabled = extractValue(output, prefix: "SOCKSEnable :") == "1"

    print("Proxy settings:")
    if httpEnabled, let p = extractValue(output, prefix: "HTTPProxy :"), let port = extractValue(output, prefix: "HTTPPort :") {
        print("  HTTP:  \(p):\(port)")
    } else {
        print("  HTTP:  off")
    }

    if httpsEnabled, let p = extractValue(output, prefix: "HTTPSProxy :"), let port = extractValue(output, prefix: "HTTPSPort :") {
        print("  HTTPS: \(p):\(port)")
    } else {
        print("  HTTPS: off")
    }

    if socksEnabled, let p = extractValue(output, prefix: "SOCKSProxy :"), let port = extractValue(output, prefix: "SOCKSPort :") {
        print("  SOCKS: \(p):\(port)")
    } else {
        print("  SOCKS: off")
    }
}

func handleAirDrop(_ args: [String]) {
    guard let action = args.first else {
        print("airdrop on | off | status")
        exit(1)
    }

    if action == "status" {
        let (out, _, status) = runCommand("/usr/bin/defaults", ["read", "com.apple.NetworkBrowser", "DisableAirDrop"])
        let disabled = status == 0 && out.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
        print(disabled ? "AirDrop is disabled" : "AirDrop is enabled")
        return
    }

    let target: String
    switch action {
    case "on":  target = "false"
    case "off": target = "true"
    default:
        print("Invalid airdrop option: \(action)")
        exit(1)
    }

    let (_, err, status) = runCommand("/usr/bin/defaults", ["write", "com.apple.NetworkBrowser", "DisableAirDrop", "-bool", target])
    if status != 0 {
        print("Failed to set AirDrop: \(err)")
        exit(1)
    }
    _ = runCommand("/usr/bin/killall", ["Finder"])
    print("AirDrop is now \(action == "on" ? "enabled" : "disabled")")
}

func handleDock(_ args: [String]) {
    guard args.count >= 2 else {
        print("dock autohide|magnification on|off|toggle|status")
        exit(1)
    }
    let feature = args[0]
    let action = args[1]
    let key = feature == "autohide" ? "autohide" : "magnification"

    let (out, _, status) = runCommand("/usr/bin/defaults", ["read", "com.apple.dock", key])
    let current = status == 0 && out.trimmingCharacters(in: .whitespacesAndNewlines) == "1"

    let displayName = feature == "autohide" ? "Dock auto-hide" : "Dock magnification"

    if action == "status" {
        print(current ? "\(displayName) is on" : "\(displayName) is off")
        return
    }

    let target: Bool
    switch action {
    case "on": target = true
    case "off": target = false
    case "toggle": target = !current
    default:
        print("Invalid dock option: \(action)")
        exit(1)
    }

    if target == current {
        print("\(displayName) is already \(target ? "on" : "off")")
        return
    }

    let (_, err, writeStatus) = runCommand("/usr/bin/defaults", ["write", "com.apple.dock", key, "-bool", target ? "true" : "false"])
    if writeStatus != 0 {
        print("Failed to set \(displayName): \(err)")
        exit(1)
    }
    _ = runCommand("/usr/bin/killall", ["Dock"])
    print("\(displayName) is now \(target ? "on" : "off")")
}

func handleAccent(_ args: [String]) {
    let colorMap: [String: Int] = [
        "blue": 4,
        "purple": 5,
        "pink": 6,
        "red": 0,
        "orange": 1,
        "yellow": 2,
        "green": 3,
        "graphite": -1
    ]

    if args.first == "status" {
        let (out, _, status) = runCommand("/usr/bin/defaults", ["read", "-g", "AppleAccentColor"])
        if status == 0 {
            let value = Int(out.trimmingCharacters(in: .whitespacesAndNewlines)) ?? -999
            if let name = colorMap.first(where: { $0.value == value })?.key {
                print("Accent color is \(name)")
            } else {
                print("Accent color is custom")
            }
        } else {
            print("Accent color is default")
        }
        return
    }

    guard let colorName = args.first, let colorValue = colorMap[colorName] else {
        print("accent <blue|purple|pink|red|orange|yellow|green|graphite> | status")
        exit(1)
    }

    let (_, err, status) = runCommand("/usr/bin/defaults", ["write", "-g", "AppleAccentColor", "-int", "\(colorValue)"])
    if status != 0 {
        print("Failed to set accent color: \(err)")
        exit(1)
    }
    _ = runCommand("/usr/bin/killall", ["Dock"])
    print("Accent color set to \(colorName)")
}

func handleHighlight(_ args: [String]) {
    let colorMap: [String: String] = [
        "blue": "0.698039 0.843137 1.000000",
        "purple": "0.968627 0.831373 1.000000",
        "pink": "1.000000 0.749020 0.823529",
        "red": "1.000000 0.733333 0.721569",
        "orange": "1.000000 0.874510 0.701961",
        "yellow": "1.000000 0.937255 0.690196",
        "green": "0.752941 0.964706 0.678431",
        "graphite": "0.847059 0.847059 0.862745"
    ]

    if args.first == "status" {
        let (out, _, status) = runCommand("/usr/bin/defaults", ["read", "-g", "AppleHighlightColor"])
        if status == 0 {
            let value = out.trimmingCharacters(in: .whitespacesAndNewlines)
            if let name = colorMap.first(where: { $0.value == value })?.key {
                print("Highlight color is \(name)")
            } else {
                print("Highlight color is custom")
            }
        } else {
            print("Highlight color is default")
        }
        return
    }

    guard let colorName = args.first, let colorValue = colorMap[colorName] else {
        print("highlight <blue|purple|pink|red|orange|yellow|green|graphite> | status")
        exit(1)
    }

    let (_, err, status) = runCommand("/usr/bin/defaults", ["write", "-g", "AppleHighlightColor", "-string", colorValue])
    if status != 0 {
        print("Failed to set highlight color: \(err)")
        exit(1)
    }
    _ = runCommand("/usr/bin/killall", ["Dock"])
    print("Highlight color set to \(colorName)")
}

func handleGatekeeper(_ args: [String]) {
    guard let action = args.first else {
        print("gatekeeper enable | disable | status")
        exit(1)
    }

    if action == "status" {
        let (out, _, status) = runCommand("/usr/sbin/spctl", ["--status"])
        if status == 0 {
            if out.lowercased().contains("disabled") {
                print("Gatekeeper is disabled")
            } else {
                print("Gatekeeper is enabled")
            }
        } else {
            print("Failed to read Gatekeeper status")
            exit(1)
        }
        return
    }

    let masterFlag: String
    let message: String
    switch action {
    case "enable":
        masterFlag = "--master-enable"
        message = "Gatekeeper is now enabled"
    case "disable":
        masterFlag = "--master-disable"
        message = "Gatekeeper is now disabled"
    default:
        print("Invalid gatekeeper option: \(action)")
        exit(1)
    }

    let script = "do shell script \"/usr/sbin/spctl \(masterFlag)\" with administrator privileges"
    let (_, err, status) = runCommand("/usr/bin/osascript", ["-e", script])
    if status != 0 {
        print("Failed to \(action) Gatekeeper: \(err)")
        exit(1)
    }
    print(message)
}

func handleNoidle(_ args: [String]) {
    guard let minutesStr = args.first, let minutes = Int(minutesStr), minutes > 0 else {
        print("noidle <minutes>")
        exit(1)
    }
    let seconds = minutes * 60
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
    task.arguments = ["-t", "\(seconds)"]
    do {
        try task.run()
    } catch {
        print("Failed to prevent sleep: \(error.localizedDescription)")
        exit(1)
    }
    print("Preventing sleep for \(minutes) minute\(minutes == 1 ? "" : "s"). To stop early, run 'killall caffeinate'.")
}

func handleDisplaySleep(_ args: [String]) {
    guard let minutesStr = args.first, let minutes = Int(minutesStr), minutes >= 0 else {
        print("displaysleep <minutes>")
        exit(1)
    }
    let script = "do shell script \"/usr/bin/pmset -a displaysleep \(minutes)\" with administrator privileges"
    let (_, err, status) = runCommand("/usr/bin/osascript", ["-e", script])
    if status != 0 {
        print("Failed to set display sleep: \(err). This may require sudo.")
        exit(1)
    }
    print("Display sleep set to \(minutes) minutes")
}

func handleBootTime() {
    let (output, err, status) = runCommand("/usr/sbin/sysctl", ["-n", "kern.boottime"])
    guard status == 0 else {
        print("Failed to read boot time: \(err)")
        exit(1)
    }
    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
    let secString = trimmed.components(separatedBy: ",").first?.replacingOccurrences(of: "{ sec = ", with: "") ?? ""
    if let seconds = TimeInterval(secString), seconds > 0 {
        let date = Date(timeIntervalSince1970: seconds)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        print("Last boot: \(formatter.string(from: date))")
    } else {
        print("Boot time unavailable")
    }
}

func handleShutdown() {
    let script = "tell application \"System Events\" to shut down"
    let (_, err, status) = runCommand("/usr/bin/osascript", ["-e", script])
    if status != 0 {
        print("Failed to shut down: \(err)")
        exit(1)
    }
    print("Shutting down...")
}

func handleReboot() {
    let script = "tell application \"System Events\" to restart"
    let (_, err, status) = runCommand("/usr/bin/osascript", ["-e", script])
    if status != 0 {
        print("Failed to reboot: \(err)")
        exit(1)
    }
    print("Rebooting...")
}

func handlePurge() {
    let script = "do shell script \"/usr/sbin/purge\" with administrator privileges"
    let (_, err, status) = runCommand("/usr/bin/osascript", ["-e", script])
    if status != 0 {
        print("Failed to purge memory: \(err)")
        exit(1)
    }
    print("Memory purged")
}

func handleRestart(_ args: [String]) {
    guard let target = args.first else {
        print("restart finder | dock | controlcenter | audio")
        exit(1)
    }

    if target == "audio" {
        let script = "do shell script \"/usr/bin/killall coreaudiod\" with administrator privileges"
        let (_, err, status) = runCommand("/usr/bin/osascript", ["-e", script])
        if status != 0 {
            print("Failed to restart audio: \(err). This may require sudo.")
            exit(1)
        }
        print("audio restarted")
        return
    }

    let processName: String
    switch target {
    case "finder":
        processName = "Finder"
    case "dock":
        processName = "Dock"
    case "controlcenter":
        processName = "ControlCenter"
    default:
        print("Unknown restart target: \(target)")
        exit(1)
    }

    let (_, err, status) = runCommand("/usr/bin/killall", [processName])
    if status != 0 {
        print("Failed to restart \(target): \(err)")
        exit(1)
    }
    print("\(target) restarted")
}

func handleKill(_ args: [String]) {
    var force = false
    var name: String?
    var yes = false
    var i = 0
    while i < args.count {
        if args[i] == "--force" {
            force = true
            i += 1
        } else if args[i] == "--yes" {
            yes = true
            i += 1
        } else {
            name = args[i]
            i += 1
        }
    }

    guard let processName = name else {
        print("kill <name> | --force <name>")
        exit(1)
    }

    let (output, _, status) = runCommand("/bin/ps", ["-axo", "pid=,comm="])
    guard status == 0 else {
        print("Failed to list processes")
        exit(1)
    }

    var matches: [(pid: String, name: String)] = []
    for line in output.components(separatedBy: "\n").filter({ !$0.isEmpty }) {
        let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { continue }
        let pid = String(parts[0])
        let comm = String(parts[1])
        if comm.localizedCaseInsensitiveContains(processName) {
            matches.append((pid, comm))
        }
    }

    if matches.isEmpty {
        print("No processes found matching '\(processName)'")
        exit(1)
    }

    print("Matching processes:")
    for match in matches {
        print("  PID \(match.pid): \(match.name)")
    }

    if matches.count > 1 && !yes {
        print("Multiple matches found. Use --yes to terminate all.")
        exit(1)
    }

    let signal = force ? "-9" : "-15"
    var killed = 0
    for match in matches {
        let (_, err, killStatus) = runCommand("/bin/kill", [signal, match.pid])
        if killStatus == 0 {
            killed += 1
        } else {
            print("Failed to kill PID \(match.pid): \(err)")
        }
    }

    print("Terminated \(killed) process\(killed == 1 ? "" : "es")")
}

func handleSearch(_ args: [String]) {
    var query = ""
    var path: String?
    var name: String?
    var useAll = false
    var i = 0

    while i < args.count {
        switch args[i] {
        case "--name":
            guard i + 1 < args.count else {
                print("search --name requires a filename")
                exit(1)
            }
            name = args[i + 1]
            i += 2
        case "--path":
            guard i + 1 < args.count else {
                print("search --path requires a directory")
                exit(1)
            }
            path = args[i + 1]
            i += 2
        case "--all":
            useAll = true
            i += 1
        default:
            if query.isEmpty {
                query = args[i]
            } else {
                query += " " + args[i]
            }
            i += 1
        }
    }

    if let name = name {
        query = "kMDItemFSName == '\(name)'"
    }

    guard !query.isEmpty else {
        print("search <query> | --name <filename> | --path <dir> --name <pat> | --all")
        exit(1)
    }

    var mdfindArgs = [String]()
    if let path = path {
        guard FileManager.default.fileExists(atPath: path) else {
            print("Directory not found: \(path)")
            exit(1)
        }
        mdfindArgs += ["-onlyin", path]
    } else if !useAll {
        let currentDir = FileManager.default.currentDirectoryPath
        mdfindArgs += ["-onlyin", currentDir]
    }

    mdfindArgs.append(query)

    let (output, err, status) = runCommand("/usr/bin/mdfind", mdfindArgs)
    if status != 0 {
        print("Search failed: \(err)")
        exit(2)
    }

    let results = output.components(separatedBy: "\n").filter { !$0.isEmpty }
    if results.isEmpty {
        print("No results found")
        exit(1)
    }

    for result in results {
        print(result)
    }
}

func handleDu(_ args: [String]) {
    if args.first == "--top" {
        guard args.count >= 2 else {
            print("du --top <path>")
            exit(1)
        }
        let dirPath = args[1]
        guard FileManager.default.fileExists(atPath: dirPath) else {
            print("Directory not found: \(dirPath)")
            exit(1)
        }

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: dirPath) else {
            print("Could not read directory: \(dirPath)")
            exit(1)
        }

        for item in contents.sorted() {
            let fullPath = (dirPath as NSString).appendingPathComponent(item)
            let (out, _, status) = runCommand("/usr/bin/du", ["-sh", fullPath])
            if status == 0 {
                print(out.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        return
    }

    guard let path = args.first else {
        print("du <path> | --top <path>")
        exit(1)
    }

    guard FileManager.default.fileExists(atPath: path) else {
        print("File or directory not found: \(path)")
        exit(1)
    }

    let (out, err, status) = runCommand("/usr/bin/du", ["-sh", path])
    if status != 0 {
        print("Failed to get size: \(err)")
        exit(1)
    }
    print(out.trimmingCharacters(in: .whitespacesAndNewlines))
}

func handleFileInfo(_ args: [String]) {
    guard let path = args.first else {
        print("fileinfo <path>")
        exit(1)
    }

    guard FileManager.default.fileExists(atPath: path) else {
        print("File not found: \(path)")
        exit(1)
    }

    let (output, err, status) = runCommand("/usr/bin/mdls", [path])
    if status != 0 {
        print("Failed to read file info: \(err)")
        exit(1)
    }

    let prefixes = [
        "kMDItemFSName",
        "kMDItemDisplayName",
        "kMDItemFSSize",
        "kMDItemContentType",
        "kMDItemDateAdded",
        "kMDItemContentModificationDate"
    ]

    for line in output.components(separatedBy: "\n") {
        for prefix in prefixes where line.hasPrefix(prefix) {
            print(line)
        }
    }
}

func handleHide(_ args: [String]) {
    guard let path = args.first else {
        print("hide <path>")
        exit(1)
    }

    guard FileManager.default.fileExists(atPath: path) else {
        print("File not found: \(path)")
        exit(1)
    }

    let (_, err, status) = runCommand("/usr/bin/chflags", ["hidden", path])
    if status != 0 {
        print("Failed to hide \(path): \(err)")
        exit(1)
    }
    print("Hidden \(path)")
}

func handleUnhide(_ args: [String]) {
    guard let path = args.first else {
        print("unhide <path>")
        exit(1)
    }

    guard FileManager.default.fileExists(atPath: path) else {
        print("File not found: \(path)")
        exit(1)
    }

    let (_, err, status) = runCommand("/usr/bin/chflags", ["nohidden", path])
    if status != 0 {
        print("Failed to unhide \(path): \(err)")
        exit(1)
    }
    print("Unhidden \(path)")
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

func runCommand(_ executable: String, _ arguments: [String]) -> (stdout: String, stderr: String, status: Int32) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: executable)
    task.arguments = arguments
    let outPipe = Pipe()
    let errPipe = Pipe()
    task.standardOutput = outPipe
    task.standardError = errPipe
    do {
        try task.run()
    } catch {
        return ("", "Failed to launch \(executable): \(error.localizedDescription)", 1)
    }
    task.waitUntilExit()
    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
    let outStr = String(data: outData, encoding: .utf8) ?? ""
    let errStr = String(data: errData, encoding: .utf8) ?? ""
    return (outStr, errStr, task.terminationStatus)
}
