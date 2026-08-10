import AppKit
import Foundation
import CoreAudio
import AudioToolbox

let version = "0.1.0"

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
        case "battery":        handleBattery()
        case "audio":          handleAudio(subArgs)
        case "sleep":          handleSleep()
        case "lock":           handleLock()
        case "trash":          handleTrash(subArgs)
        case "finder":         handleFinder(subArgs)
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
          audio out     list | set <device>
          audio volume  0-100
          audio mute    on | off | toggle
          sleep         Put the Mac to sleep immediately
          lock          Lock the screen
          trash empty   Empty the Trash
          finder showhidden  on | off | toggle
          info          Show system information
          version       Print version
        """
        print(usage)
    }
}

func handleDark(_ args: [String]) {
    let mode = args.first ?? "status"
    let script: String
    switch mode {
    case "on":
        script = "tell application \"System Events\" to tell appearance preferences to set dark mode to true"
    case "off":
        script = "tell application \"System Events\" to tell appearance preferences to set dark mode to false"
    case "toggle":
        script = "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
    case "status":
        script = "tell application \"System Events\" to tell appearance preferences to return dark mode"
    default:
        print("Unknown dark mode option: \(mode)")
        exit(1)
    }

    guard let appleScript = NSAppleScript(source: script) else {
        print("Failed to create AppleScript")
        exit(1)
    }
    var error: NSDictionary?
    let result = appleScript.executeAndReturnError(&error)
    if let error = error {
        print("Error: \(error)")
        exit(1)
    }
    if mode == "status" {
        let isDark = result.booleanValue
        print(isDark ? "on" : "off")
    } else {
        print("Dark mode set to \(mode)")
    }
}

func handleBattery() {
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
                let remainder = semicolons[2]
                if remainder.contains("remaining") {
                    timeRemaining = remainder.replacingOccurrences(of: " remaining", with: "")
                } else {
                    timeRemaining = remainder
                }
            }

            if state.contains("charging") {
                statusText = "charging"
            } else if state.contains("discharging") {
                statusText = "discharging"
                if !timeRemaining.isEmpty {
                    statusText += " (\(timeRemaining) remaining)"
                }
            } else {
                statusText = state
            }

            print("Battery")
            print("  Charge: \(percent)%")
            print("  Status: \(statusText)")
        }
    }

    if !foundBattery {
        print("No internal battery found")
        exit(1)
    }
}

func handleAudio(_ args: [String]) {
    guard let sub = args.first else {
        print("audio requires a subcommand: out, volume, mute")
        exit(1)
    }
    switch sub {
    case "out":     handleAudioOut(Array(args.dropFirst()))
    case "volume":  handleVolume(Array(args.dropFirst()))
    case "mute":    handleMute(Array(args.dropFirst()))
    default:
        print("Unknown audio subcommand: \(sub)")
        exit(1)
    }
}

func handleAudioOut(_ args: [String]) {
    guard let action = args.first else {
        print("audio out requires: list | set <device>")
        exit(1)
    }
    if action == "list" {
        listAudioDevices()
    } else if action == "set" {
        guard args.count >= 2 else {
            print("audio out set requires a device name")
            exit(1)
        }
        setAudioDevice(name: args[1])
    } else {
        print("Unknown audio out action: \(action)")
        exit(1)
    }
}

func listAudioDevices() {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var dataSize: UInt32 = 0
    AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
    let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &devices)

    for device in devices {
        var name: CFString?
        var nameSize = UInt32(MemoryLayout<CFString?>.size)
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        withUnsafeMutablePointer(to: &name) { namePtr in
            _ = AudioObjectGetPropertyData(device, &nameAddress, 0, nil, &nameSize, namePtr)
        }
        if let deviceName = name {
            print(deviceName as String)
        }
    }
}

func setAudioDevice(name: String) {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var dataSize: UInt32 = 0
    AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
    let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &devices)

    for device in devices {
        var deviceName: CFString?
        var nameSize = UInt32(MemoryLayout<CFString?>.size)
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        withUnsafeMutablePointer(to: &deviceName) { namePtr in
            _ = AudioObjectGetPropertyData(device, &nameAddress, 0, nil, &nameSize, namePtr)
        }
        if let dName = deviceName, dName as String == name {
            var defaultAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var mutableDevice = device
            let setStatus = AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &defaultAddress,
                0,
                nil,
                UInt32(MemoryLayout<AudioDeviceID>.size),
                &mutableDevice
            )
            if setStatus == noErr {
                print("Audio output set to \(name)")
            } else {
                print("Failed to set audio device (error \(setStatus)). You may need to grant accessibility permissions.")
                exit(1)
            }
            return
        }
    }
    print("Device not found: \(name)")
    exit(1)
}

func handleVolume(_ args: [String]) {
    guard let volStr = args.first, let vol = Int(volStr), (0...100).contains(vol) else {
        print("Volume must be 0-100")
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
        print("mute requires on | off | toggle")
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
    print(newMute == 1 ? "Muted" : "Unmuted")
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
        print("Failed to empty trash: \(error)")
        exit(1)
    }
    print("Trash emptied")
}

func handleFinder(_ args: [String]) {
    guard args.count >= 2, args[0] == "showhidden" else {
        print("finder showhidden on | off | toggle")
        exit(1)
    }
    let action = args[1]
    let cmd: String
    switch action {
    case "on":
        cmd = "defaults write com.apple.finder AppleShowAllFiles -bool YES && killall Finder"
    case "off":
        cmd = "defaults write com.apple.finder AppleShowAllFiles -bool NO && killall Finder"
    case "toggle":
        cmd = "defaults read com.apple.finder AppleShowAllFiles | grep -q 1 && defaults write com.apple.finder AppleShowAllFiles -bool NO || defaults write com.apple.finder AppleShowAllFiles -bool YES; killall Finder"
    default:
        print("Invalid option: \(action)")
        exit(1)
    }
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    task.arguments = ["-c", cmd]
    task.launch()
    task.waitUntilExit()
    print("Finder show hidden files: \(action)")
}

func handleInfo() {
    let processInfo = ProcessInfo.processInfo
    let osVersion = processInfo.operatingSystemVersionString
    let hostName = processInfo.hostName
    let uptime = processInfo.systemUptime

    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var model = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &model, &size, nil, 0)
    let modelData = Data(bytes: model, count: size)
    let modelStr = String(data: modelData, encoding: .utf8) ?? "Unknown"

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
