<p align="center">
  <img src="assets/icons/arabellity.svg" width="128" height="128" alt="Arabellity Icon" />
</p>

<h1 align="center">Arabellity</h1>

<p align="center">
  <b>Fast, lightweight, standalone Wayland terminal emulator written in pure x86-64 NASM assembly.</b>
</p>

<p align="center">
  <a href="README.md">English</a> •
  <a href="README.ru.md">Русский</a>
</p>

---

## Overview

**Arabellity** is a modern terminal emulator built from the ground up for Wayland compositors without relying on any external C runtime libraries or toolkits.

- **100% Static & Standalone**: Pure Linux kernel system calls (`syscall`). Zero dependency on `libc`, `libwayland`, `libxkbcommon`, `cairo`, or any runtime shared libraries.
- **Wayland Native**: Direct UNIX domain socket communication implementing core Wayland protocols (`wl_compositor`, `wl_shm`, `xdg_wm_base`, `wl_seat`, `wl_data_device`).
- **Kitty Graphics Protocol**: Full inline graphics support (PNG and direct RGBA) for tools like `fastfetch`, `yazi`, `chafa`, and `ranger`.
- **Programming Font Ligatures**: JetBrains Mono atlas with automatic ligatures (`===`, `==`, `=>`, `->`, `!=`, `!==`, `<=`, `>=`, `:=`, `::`, `<-`).
- **Rich Colors & Themes**: TrueColor (24-bit RGB), 256-color ANSI cube, OSC 4/10/11/12 palette sequences, and auto-loading Kitty color themes (`include themes/...`).
- **Zero Runtime Bloat**: Instant startup, minimal memory footprint, and sub-millisecond latency.

---

## Installation

### Universal Installer (Any Linux Distribution)

The installer automatically compiles the static binary (if not already built) and installs the executable, desktop entry, application icons, and default configuration:

```sh
# Install for current user into ~/.local (no root/sudo required):
./install.sh --user

# Or install system-wide into /usr/local:
sudo ./install.sh
```

To uninstall:

```sh
# If installed with --user:
./uninstall.sh --user

# If installed system-wide:
sudo ./uninstall.sh
```

### Arch Linux (makepkg / pacman)

Build and install via Arch package manager:

```sh
# Build and install package:
cd packaging/arch
makepkg -si

# Remove cleanly via pacman:
sudo pacman -R arabellity
```

---

## Building from Source

### Prerequisites

All you need is NASM and GNU Binutils (`ld`):

- **Arch / Manjaro**: `sudo pacman -S nasm binutils`
- **Debian / Ubuntu**: `sudo apt install nasm binutils`
- **Fedora**: `sudo dnf install nasm binutils`

### Build Targets

```sh
make         # Build optimized static binary -> build/arabellity
make test    # Run automated test suite (verifies zero dynamic dependencies & syscall purity)
make dist    # Package release tarball arabellity-*-linux-x86_64.tar.gz
make run     # Build and immediately launch Arabellity
make clean   # Clean build artifacts
```

---

## Configuration

Arabellity reads its configuration from `~/.config/arabellity/arabellity.conf`. If it does not exist, a default config will be created on first launch or installation.

Supports:

- Window dimensions (`width`, `height`)
- Padding (`padding_x`, `padding_y`)
- Opacity (`opacity 0.0` - `1.0`)
- Font rendering options
- Kitty theme integration (`include themes/Everforest_Dark_Hard.conf`)

---

## Project Structure

```
arabellity/
├── assets/
│   ├── arabellity.desktop        # Desktop launcher entry
│   ├── fonts/
│   │   └── nerd_font.bin         # Pre-rendered JetBrains Mono binary glyph atlas
│   └── icons/                    # Vector SVG and multi-resolution PNG icons
├── packaging/
│   └── arch/                     # PKGBUILD for Arch Linux / AUR
├── scripts/
│   └── gen_font.rs               # Rust/FreeType font atlas & ligature generator
├── src/                          # Pure x86-64 NASM source code
│   ├── main.asm                  # _start entrypoint, epoll event loop, signals
│   ├── wl.asm, wl.inc            # Wayland protocol client & UNIX socket serialization
│   ├── window.asm                # wl_shm pixel buffers and frame dispatching
│   ├── term_screen.asm           # VT100/XTerm parser, grid layout, ligature scanner
│   ├── kitty_gfx.asm             # Kitty Graphics Protocol handler
│   ├── png_decode.asm            # Standalone PNG decoder
│   ├── tinflate.asm              # Deflate/zlib decompressor
│   ├── pty.asm                   # Pseudo-terminal allocation and shell spawn
│   ├── kbd.asm                   # Wayland keymap & XKB translation
│   ├── config.asm                # Configuration file parser
│   └── font.asm                  # Subpixel-aware glyph blitter
├── arabellity.conf               # Default configuration
├── install.sh                    # Universal installation script
├── uninstall.sh                  # Universal uninstallation script
└── Makefile                      # Build automation
```

---

## License

[MIT](LICENSE)
