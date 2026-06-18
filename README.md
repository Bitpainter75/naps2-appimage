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

NAPS2 is a self-contained .NET 8 application. No .NET runtime needs to be installed on the target system.

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
| .NET 8 runtime | Fully self-contained inside the `naps2` binary (single-file publish) |
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

| Distribution | Status |
|---|---|
| Bazzite / Aurora (Fedora 44) | ✅ tested |
| Fedora 40+ | ✅ expected |
| Arch / CachyOS / Manjaro | ✅ tested (build system) |
| Ubuntu 22.04+ | ✅ expected |
| Any x86_64 Linux with glibc ≥ 2.17 | ✅ |

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

With [AppImageLauncher](https://github.com/TheAssassin/AppImageLauncher) or [appimaged](https://github.com/probonopd/go-appimage), the AppImage is automatically integrated into your application menu with PDF and image MIME-type associations.

---

## First-Run Extraction Cache

On the first launch, .NET extracts its embedded runtime assemblies to:

```
~/.cache/naps2/
```

This directory can safely be deleted — it will be recreated on the next launch. Total size is approximately 150 MB.

If your home directory is on a `noexec` filesystem (some network shares), the cache is placed in `/tmp/.naps2-<username>/` instead.

---

## Build it yourself

### Prerequisites

```bash
# Any distribution
# appimagetool-x86_64.AppImage and naps2-X.Y.Z-linux-x64.deb must be in the same directory
```

Download the `.deb` from [NAPS2 Releases on GitHub](https://github.com/cyanfish/naps2/releases) and `appimagetool` from [AppImage Releases](https://github.com/AppImage/appimagetool/releases).

### Build

```bash
chmod +x build-naps2-appimage.sh
./build-naps2-appimage.sh
```

Produces `NAPS2-8.2.1-x86_64.AppImage` (~22 MB) in the current directory.

### What the script does

1. Locates the `naps2-*-linux-x64.deb` file in the current directory
2. Extracts it using `ar` + `tar` (no `dpkg` required)
3. Copies all files from `usr/lib/naps2/` into the AppDir
4. Creates a minimal desktop file with correct MIME-type associations
5. Writes an `AppRun` that sets `DOTNET_BUNDLE_EXTRACT_BASE_DIR`
6. Packs everything with `appimagetool` using zstd compression

---

## Links

- [NAPS2 website](https://www.naps2.com)
- [NAPS2 on GitHub](https://github.com/cyanfish/naps2)
- [NAPS2 documentation](https://www.naps2.com/doc)
- [SANE — Scanner Access Now Easy](http://www.sane-project.org)
- [sane-airscan (network scanners)](https://github.com/alexpevzner/sane-airscan)
