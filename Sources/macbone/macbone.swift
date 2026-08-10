import AppKit
import Foundation
import CoreAudio
import AudioToolbox

let version = "0.1.1"

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
          audio volume  0-100
          audio mute    on | off | toggle | status
          sleep         Put the Mac to sleep immediately
          lock          Lock the screen
          trash empty   Empty the Trash
          finder showhidden  on | off | toggle | status
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
                statusText = "on battery"
                if !timeRemaining.isEmpty {
                    statusText += " (\(timeRemaining) remaining)"
                }
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
    guard let volStr = args.first, let vol = Int(volStr), (0...100).contains(vol) else {
        print("Volume must be between 0 and 100")
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
