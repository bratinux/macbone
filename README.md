<p align="center">
  <img src="https://img.shields.io/badge/macOS-15%20%7C%2026%20%7C%2027-000000?logo=apple&style=for-the-badge" alt="macOS versions">
  <img src="https://img.shields.io/badge/Swift-6.3-F05138?logo=swift&style=for-the-badge" alt="Swift 6.3">
  <img src="https://img.shields.io/github/license/bratinux/macbone?style=for-the-badge" alt="License">
</p>

<h1 align="center">🦴 macbone</h1>
<p align="center"><em>The lightweight, all-in-one CLI that puts macOS power at your fingertips.</em></p>

---

## 🧠 What is macbone?

`macbone` is a **single binary**, **zero‑dependency** command‑line tool for macOS power users. It wraps the most useful system controls into one consistent, intuitive interface. No more `defaults` incantations or manual `pmset` parsing... it's just `macbone`.

---

## ✨ Features (v0.1.0)

- **Dark Mode** – toggle, query, or set directly from your terminal
- **Battery** – charge level and charging state
- **Audio** – list output devices, switch output, set volume, toggle mute
- **Sleep & Lock** – instant sleep or lock screen
- **Trash** – empty your Trash in one command
- **Finder** – show/hide hidden files
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
| `audio out list` | Show output devices | `macbone audio out list` |
| `audio out set` | Switch output device | `macbone audio out set "MacBook Air Speakers"` |
| `audio volume` | Set volume (0‑100) | `macbone audio volume 50` |
| `audio mute` | Mute / unmute / toggle | `macbone audio mute toggle` |
| `sleep` | Put Mac to sleep | `macbone sleep` |
| `lock` | Lock screen | `macbone lock` |
| `trash empty` | Empty Trash | `macbone trash empty` |
| `finder showhidden` | Show/hide hidden files | `macbone finder showhidden toggle` |
| `info` | System overview | `macbone info` |
| `--version` / `version` | Print version | `macbone --version` |

*Help is always available with `macbone help` or `macbone --help`.*

---

## 🛠 Roadmap

- **v0.2.0** – Focus / DnD, display brightness control, wallpaper setting
- **v0.3.0** – Bluetooth management, battery health & cycles, CPU / memory stats
- **v0.4.0** – Proxy status, thermal state, process management
- **v1.0.0** – Full maintenance suite, stable API, Homebrew core submission

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-command`)
3. Commit your changes (`git commit -m 'Add amazing command'`)
4. Push to the branch (`git push origin feature/amazing-command`)
5. Open a Pull Request

All code must compile with **zero warnings** on Swift 6.3+, macOS 15+.

---

## 📄 License

MIT © bratinux

---

<p align="center">Made with ❤️ for the Mac community</p>
