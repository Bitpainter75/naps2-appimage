# NAPS2 — AppImage

Unofficial AppImage build of [NAPS2](https://www.naps2.com) (Not Another PDF Scanner 2) 8.2.1, a document scanning application that lets you scan to PDF and a wide variety of image formats.

> All application code belongs to the [original project](https://github.com/cyanfish/naps2) (GPL-2.0).

---

## Download

Grab the latest AppImage from the [Releases](../../releases/latest) page.

```bash
chmod +x NAPS2-8.2.1-x86_64.AppImage
./NAPS2-8.2.1-x86_64.AppImage
```

> **First launch**: .NET extracts its runtime assemblies to `~/.cache/naps2/` on first start — this takes 3–5 seconds and only happens once.

---

## Requirements

NAPS2 is a self-contained .NET application. No .NET runtime needs to be installed on the target system.

For **USB and network scanner support**, install SANE:

### Fedora / Bazzite / Aurora

```bash
sudo dnf install sane-backends sane-backends-libs sane-airscan
```

### Ubuntu / Debian

```bash
sudo apt install sane-utils libsane1 sane-airscan
```

### Arch / CachyOS / Manjaro

```bash
sudo pacman -S sane sane-airscan
```

> Without SANE, NAPS2 still works for importing images and editing existing PDFs — just without scanner access.

---

## What's bundled

| Component | Notes |
|---|---|
| .NET runtime | Fully self-contained inside the `naps2` binary (single-file publish) |
| libpdfium | PDF rendering — statically linked, no external dependencies |
| tesseract | OCR engine binary — OCR language data is downloaded on first use |
| .NET native helpers | `System.Native.so`, `System.IO.Compression.Native.so`, etc. |

**Not bundled — libsane must come from the system:**

SANE (Scanner Access Now Easy) needs access to system scanner configuration in `/etc/sane.d/` and hardware-specific backend drivers in `/usr/lib/sane/`. Bundling libsane would prevent it from finding any connected scanners.

---

## Features

- Scan from USB scanners (SANE) and network scanners (airscan/WSD/ESCL)
- Save to PDF, TIFF, JPEG, PNG, and more
- OCR in 100+ languages (powered by Tesseract, language packs downloaded on demand)
- Rotate, crop, reorder, and apply corrections to scanned pages
- Batch scanning and automation via CLI (`naps2 --help`)
- Profiles for different scanner configurations

---

## Compatibility

| Distribution / Target System | Status | Note |
|---|---|---|
| Bazzite / Aurora (Fedora 44) | ✅ tested | Smooth hardware access via system SANE layers |
| Fedora 40+ | ✅ expected | Full compatibility across all spin-offs |
| Arch / CachyOS / Manjaro | ✅ tested | Out-of-the-box compatibility |
| Ubuntu 24.04+ / Debian 13+ | ✅ expected | Built on modern Ubuntu 24.04 glibc base |
| Older distros (glibc < 2.39) | ❌ not supported | Requires Ubuntu 24.04+ baseline (e.g. Ubuntu 22.04 not supported) |

---

## Usage

```bash
# Open the GUI
./NAPS2-8.2.1-x86_64.AppImage

# CLI usage (scan to PDF)
./NAPS2-8.2.1-x86_64.AppImage --output ~/scan.pdf

# Show CLI help
./NAPS2-8.2.1-x86_64.AppImage --help

# Without FUSE (containers, older kernels)
APPIMAGE_EXTRACT_AND_RUN=1 ./NAPS2-8.2.1-x86_64.AppImage
```

### Desktop Integration (optional)

The easiest and most modern way to manage this AppImage is using **[Gear Lever](https://github.com)** (available as a Flatpak on Flathub). It provides full desktop integration, automatic icon generation, and application menu mapping without altering your core system files. It is highly recommended for atomic/immutable distributions like Bazzite and Aurora.

---

## First-Run Extraction Cache

On the first launch, .NET extracts its embedded runtime assemblies to:

~/.cache/naps2/

This directory can safely be deleted — it will be recreated on the next launch. Total size is approximately 150 MB.

If your home directory is on a `noexec` filesystem (some network shares), the cache is placed in `/tmp/.naps2-<username>/` instead.

---

## Build it yourself

### Prerequisites

For maximum target compatibility, it is recommended to run the build script inside an **Ubuntu 24.04 Distrobox** environment. 

The script automatically detects, updates, and installs missing build-essential packages inside the container.

Ensure that your downloaded **`naps2-8.2.1-linux-x64.deb`** package is placed in the **same directory** as the script before running it. If no file is present, the script will attempt to download the latest available version from GitHub automatically. (`appimagetool` will also be downloaded automatically if missing).

### Build

```bash
# Clone this repository
git clone https://github.com
cd naps2-appimage

# Ensure the .deb file is in this directory, then execute the build:
chmod +x build-naps2-appimage.sh
./build-naps2-appimage.sh
```

Produces a standalone, self-contained `NAPS2-8.2.1-x86_64.AppImage` (~22 MB) directly in your current working directory.

### What the script does

1. Validates build-essential tools and provisions dependencies dynamically via `apt`.
2. Locates the `naps2-*.tar.gz` archive in the local directory and unpacks it into a temporary sandbox.
3. Automatically maps internal binaries and extracts the embedded system execution profiles.
4. Generates a custom desktop entry structure with precise multi-format MIME-type associations.
5. Injects automated `SONAME` symlink routines to resolve .NET runtime native library calls.
6. Writes a portable `AppRun` environment handler to isolate cache directories (`DOTNET_BUNDLE_EXTRACT_BASE_DIR`).
7. Compresses and packages the environment directory tree into a ready-to-use AppImage bundle.

---

## Links

- [NAPS2 website](https://www.naps2.com)
- [NAPS2 on GitHub](https://github.com/cyanfish/naps2)
- [NAPS2 documentation](https://www.naps2.com/doc)
- [SANE — Scanner Access Now Easy](http://www.sane-project.org)
- [sane-airscan (network scanners)](https://github.com/alexpevzner/sane-airscan)
