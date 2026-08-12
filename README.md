<p align="center">
  <img src="https://img.shields.io/badge/macOS-26%20%7C%2027-000000?logo=apple&style=for-the-badge" alt="macOS versions">
  <img src="https://img.shields.io/badge/Swift-6.3-F05138?logo=swift&style=for-the-badge" alt="Swift 6.3">
  <img src="https://img.shields.io/badge/version-0.3.0-blue?style=for-the-badge" alt="version">
  <img src="https://img.shields.io/github/license/bratinux/macbone?style=for-the-badge" alt="License">
</p>

<h1 align="center">🦴 macbone</h1>
<p align="center"><em>The lightweight, all-in-one CLI that puts macOS power at your fingertips.</em></p>

---

## 🧠 What is macbone?

`macbone` is a **single binary**, **zero‑dependency** command‑line tool for macOS power users. It wraps the most useful system controls and health checks into one consistent, intuitive interface. No more `defaults` incantations or manual `pmset` parsing – just `macbone`.

---

## ✨ Features (v0.3.0)

- **Dark Mode** – toggle, query, or set directly from your terminal
- **Battery** – charge level & status; health & cycle count
- **Audio** – volume control (absolute, up/down, and status); mute toggle
- **Wallpaper** – set the desktop background for all displays
- **Sleep & Lock** – instant sleep or lock screen
- **Trash** – empty your Trash in one command
- **Finder** – show/hide hidden files
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
| `cpu` | CPU info and load | `macbone cpu` |
| `memory` | Memory usage and pressure | `macbone memory` |
| `thermal` | Thermal state | `macbone thermal` |
| `info` | System overview | `macbone info` |
| `--version` / `version` | Print version | `macbone --version` |

*Help is always available with `macbone help` or `macbone --help`.*

---

## 🛠 Roadmap

- **v0.4.0** – Focus / Do Not Disturb, display brightness control
- **v0.5.0** – Bluetooth management, process list/kill
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
