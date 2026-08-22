<p align="center">
  <img src="https://img.shields.io/badge/macOS-26%20%7C%2027-000000?logo=apple&style=for-the-badge" alt="macOS versions">
  <img src="https://img.shields.io/badge/Swift-6.3-F05138?logo=swift&style=for-the-badge" alt="Swift 6.3">
  <img src="https://img.shields.io/badge/version-0.7.0-blue?style=for-the-badge" alt="version">
  <img src="https://img.shields.io/github/license/bratinux/macbone?style=for-the-badge" alt="License">
</p>

<h1 align="center">🦴 macbone</h1>
<p align="center"><em>The lightweight, all-in-one CLI that puts macOS power at your fingertips.</em></p>

---

## 🧠 What is macbone?

`macbone` is a **single binary**, **zero‑dependency** command‑line tool for macOS power users. It wraps the most useful system controls, health checks, and maintenance tasks into one consistent, intuitive interface. No more `defaults` incantations or manual `pmset` parsing – just `macbone`.

---

## ✨ Features (v0.7.0)

- **Dark Mode** – toggle, query, or set directly from your terminal
- **Battery** – charge level & status; health & cycle count
- **Audio** – volume control (absolute, up/down, and status); mute toggle
- **Wallpaper** – set the desktop background for all displays
- **Sleep & Lock** – instant sleep or lock screen
- **Trash** – empty your Trash in one command
- **Finder** – show/hide hidden files
- **Disk** – system volume usage and full volume list
- **Process** – search by name or show top CPU/memory consumers
- **Notify** – post macOS notifications from the terminal
- **OpenWith** – open files with a specific application
- **Eject** – eject a single volume or all removable volumes
- **Network** – current service, SSID, IP, router, DNS
- **Updates** – list available macOS updates
- **Proxy** – show HTTP, HTTPS, SOCKS proxy settings
- **AirDrop** – enable, disable, or check status
- **Dock** – auto-hide and magnification toggles
- **Accent color** – set or check system accent color
- **Highlight color** – set or check system highlight color
- **Gatekeeper** – enable, disable, or check status
- **Power** – noidle, display sleep, boot time, shutdown, reboot, purge
- **Process control** – kill by name (graceful or forced)
- **Restart** – restart Finder, Dock, Control Center, or CoreAudio
- **File search** – search files and folders with Spotlight
- **Directory size** – show file or directory size
- **File info** – show file metadata
- **Hide/Unhide** – toggle file visibility
- **CPU** – brand, core architecture, and load percentage
- **Memory** – total, used, and pressure level
- **Thermal** – current thermal state
- **System Info** – hostname, macOS version, model, serial, uptime
- **Version** – `macbone --version` prints the version

All commands are **pipe‑friendly** and **script‑ready**.

---

## 📦 Installation

### Homebrew (recommended)

```bash
brew tap bratinux/macbone
brew install macbone
```

> This builds `macbone` from source with Swift. Make sure you have Xcode Command Line Tools installed (`xcode-select --install`).

### Manual build

```bash
git clone https://github.com/bratinux/macbone.git
cd macbone
swift build -c release
sudo cp .build/release/macbone /usr/local/bin/
```

---

## 🚀 Usage

```bash
macbone <command> [options]
```

| Command | Description | Example |
|---------|-------------|---------|
| `dark` | Dark mode control | `macbone dark on`<br>`macbone dark status` |
| `battery` | Battery charge & status | `macbone battery` |
| `battery health` | Battery health & cycle count | `macbone battery health` |
| `audio volume` | Set volume (0‑100), show current, or adjust | `macbone audio volume 50`<br>`macbone audio volume status`<br>`macbone audio volume up` |
| `audio mute` | Mute / unmute / toggle | `macbone audio mute toggle` |
| `wallpaper set` | Set desktop wallpaper | `macbone wallpaper set ~/image.jpg` |
| `sleep` | Put Mac to sleep | `macbone sleep` |
| `lock` | Lock screen | `macbone lock` |
| `trash empty` | Empty Trash | `macbone trash empty` |
| `finder showhidden` | Show/hide hidden files | `macbone finder showhidden toggle` |
| `disk` | System volume usage | `macbone disk` |
| `disk list` | All mounted volumes | `macbone disk list` |
| `process` | Search processes by name | `macbone process Safari` |
| `process top` | Top processes by CPU or memory | `macbone process top --cpu --count 5` |
| `notify` | Send a notification | `macbone notify "Build done" --title "CI"` |
| `openwith` | Open file with a specific app | `macbone openwith "Sublime Text" file.md` |
| `eject` | Eject a specific volume | `macbone eject /Volumes/Backup` |
| `ejectall` | Eject all removable volumes | `macbone ejectall` |
| `network` | Current network info | `macbone network` |
| `updates` | List available macOS updates | `macbone updates` |
| `proxy` | Show proxy settings | `macbone proxy` |
| `airdrop` | Enable, disable, or check AirDrop | `macbone airdrop status` |
| `dock autohide` | Auto-hide the Dock | `macbone dock autohide toggle` |
| `dock magnification` | Toggle Dock magnification | `macbone dock magnification toggle` |
| `accent` | Set or check accent color | `macbone accent purple` |
| `highlight` | Set or check highlight color | `macbone highlight green` |
| `gatekeeper` | Enable, disable, or check Gatekeeper | `macbone gatekeeper status` |
| `noidle` | Prevent sleep for N minutes | `macbone noidle 30` |
| `displaysleep` | Set display sleep timeout | `macbone displaysleep 10` |
| `boottime` | Show last boot time | `macbone boottime` |
| `shutdown` | Shut down the Mac | `macbone shutdown` |
| `reboot` | Reboot the Mac | `macbone reboot` |
| `purge` | Purge inactive memory | `macbone purge` |
| `restart` | Restart system component | `macbone restart finder`<br>`macbone restart dock`<br>`macbone restart audio` |
| `kill` | Terminate process by name | `macbone kill --yes Safari`<br>`macbone kill --force --yes Safari` |
| `search` | Search files using Spotlight | `macbone search "README.md"`<br>`macbone search --path ~/Documents --name "macbone*"` |
| `du` | Show file or directory size | `macbone du ~/Downloads`<br>`macbone du --top ~/Documents` |
| `fileinfo` | Show file metadata | `macbone fileinfo README.md` |
| `hide` | Hide a file or folder | `macbone hide ~/private.txt` |
| `unhide` | Unhide a file or folder | `macbone unhide ~/private.txt` |
| `cpu` | CPU info and load | `macbone cpu` |
| `memory` | Memory usage and pressure | `macbone memory` |
| `thermal` | Thermal state | `macbone thermal` |
| `info` | System overview | `macbone info` |
| `--version` / `version` | Print version | `macbone --version` |

*Help is always available with `macbone help` or `macbone --help`.*

---

## 🛠 Roadmap

- **v0.8.0** – Security & privacy tools
- **v0.9.0** – System management & final feature set
- **v1.0.0** – Stable API, Homebrew core submission

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-command`)
3. Commit your changes (`git commit -m 'Add amazing command'`)
4. Push to the branch (`git push origin feature/amazing-command`)
5. Open a Pull Request

All code must compile with **zero warnings** on Swift 6.3+, macOS 26+.

---

## 📄 License

MIT © bratinux

---

<p align="center">Made with ❤️ for the Mac community</p>
