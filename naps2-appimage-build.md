# NAPS2 AppImage – Build-Dokumentation

## Überblick

NAPS2 (Not Another PDF Scanner 2) ist ein Document-Scanning-Programm für Linux, Windows und macOS.
Dieses AppImage basiert auf dem offiziellen `.deb`-Paket, das auf GitHub Releases veröffentlicht wird.

### Besonderheiten

- **NAPS2 ist eine .NET 8 Single-File Executable** — der komplette .NET-Laufzeitumgebung und alle C#-Assemblies sind in den `naps2`-Binary eingebettet (43 MB).  
  Beim ersten Start werden diese nach `~/.cache/naps2/` entpackt (einmalig, ca. 3–5 Sekunden).
- **Kein .NET auf dem Zielsystem erforderlich** — die Runtime ist self-contained.
- **`libsane` ist NICHT gebündelt** — SANE (Scanner Access Now Easy) benötigt Systemkonfiguration in `/etc/sane.d/` und backend-spezifische Treiber. Eine gebündelte Version würde Netzwerk- und USB-Scanner nicht finden.

---

## Bundled Components

| Datei | Typ | Zweck |
|---|---|---|
| `naps2` | .NET 8 Single-File Host | Hauptprogramm + eingebetteter Runtime |
| `apphost` | .NET AppHost | Starthelfer (wird intern genutzt) |
| `appsettings.xml` | Konfiguration | Standardeinstellungen |
| `System.Globalization.Native.so` | .NET native | ICU/Locales |
| `System.IO.Compression.Native.so` | .NET native | zlib/brotli |
| `System.Native.so` | .NET native | Unix-Syscalls |
| `System.Net.Http.Native.so` | .NET native | TLS/HTTP |
| `System.Net.Security.Native.so` | .NET native | SSL |
| `System.Security.Cryptography.Native.OpenSsl.so` | .NET native | OpenSSL-Kryptographie |
| `libdbgshim.so` | .NET Debugger | Diagnose (runtime-intern) |
| `libsos.so` | .NET Debugger | SOS Debug Extension |
| `libsosplugin.so` | .NET Debugger | SOS GDB Plugin |
| `_linux/libpdfium.so` | nativer Code | PDF-Rendering (statisch gelinkt) |
| `_linux/tesseract` | nativer Binary | OCR-Engine |

---

## Systemvoraussetzungen auf dem Zielsystem

| Paket | Fedora/Bazzite/Aurora | Ubuntu/Debian | Arch |
|---|---|---|---|
| `libsane` (Scanner-Support) | `sane-backends-libs` | `libsane1` | `sane` |
| GTK3 (UI-Abhängigkeit) | vorinstalliert | vorinstalliert | `gtk3` |
| OpenSSL | `openssl-libs` | `libssl-dev` | `openssl` |

**`libsane`** ist nur erforderlich, wenn USB-Scanner verwendet werden sollen.  
Netzwerkscanner (airscan/WSD) benötigen zusätzlich `sane-airscan`.  
Ohne jedes SANE-Paket kann NAPS2 noch Bilder importieren und PDFs bearbeiten.

---

## AppDir-Struktur

```
NAPS2.AppDir/
├── AppRun                                ← Einstiegspunkt
├── com.naps2.Naps2.desktop               ← Desktop-Integration
├── com.naps2.Naps2.png                   ← App-Icon (128×128)
├── .DirIcon → com.naps2.Naps2.png
└── usr/
    ├── lib/
    │   └── naps2/
    │       ├── naps2                     ← Hauptbinary (43 MB Single-File)
    │       ├── apphost
    │       ├── appsettings.xml
    │       ├── System.*.so               ← .NET native helper (6 Dateien)
    │       ├── libdbgshim.so
    │       ├── libsos.so
    │       ├── libsosplugin.so
    │       └── _linux/
    │           ├── libpdfium.so          ← PDF-Rendering
    │           └── tesseract             ← OCR
    └── share/
        └── icons/hicolor/128x128/apps/
            └── com.naps2.Naps2.png
```

---

## AppRun

```bash
#!/bin/bash
SELF=$(readlink -f "$0")
HERE="${SELF%/*}"
NAPS2_DIR="${HERE}/usr/lib/naps2"

if [ -n "$HOME" ] && [ -w "$HOME" ]; then
    export DOTNET_BUNDLE_EXTRACT_BASE_DIR="${DOTNET_BUNDLE_EXTRACT_BASE_DIR:-${HOME}/.cache/naps2}"
else
    export DOTNET_BUNDLE_EXTRACT_BASE_DIR="/tmp/.naps2-${USER:-user}"
fi

exec "${NAPS2_DIR}/naps2" "$@"
```

**`DOTNET_BUNDLE_EXTRACT_BASE_DIR`**: Steuert, wohin die eingebetteten Assemblies beim ersten Start entpackt werden. Standard ist `$HOME/.cache/naps2/`. Auf Systemen mit `noexec`-Home wird `/tmp/.naps2-<user>/` als Fallback verwendet.

---

## Build-Prozess

```
naps2-X.Y.Z-linux-x64.deb
         │
         ▼
    ar x + tar xf          ← .deb als ar-Archiv + data.tar.xz
         │
         ▼
    AppDir aufbauen
         ├── cp usr/lib/naps2/ → AppDir/usr/lib/naps2/
         ├── desktop file erstellen
         ├── icon kopieren
         └── AppRun schreiben
         │
         ▼
    appimagetool            ← squashfs + ELF-Header
         │
         ▼
    NAPS2-X.Y.Z-x86_64.AppImage (~22 MB)
```

---

## Warum ist das AppImage nur ~22 MB?

Der `.deb` ist ~17 MB, das AppImage ist ~22 MB (wegen AppImage-Runtime-Header ~1 MB + zstd-Kompression).

Der Hauptfaktor: Das .NET 8 Single-File-Bundle komprimiert alle Assemblies intern bereits.  
Der entpackte AppDir ist ~60 MB unkomprimiert, squashfs komprimiert das auf ~21 MB.

---

## Bekannte Einschränkungen

1. **Erster Start langsam**: .NET entpackt ~150 MB Assemblies nach `~/.cache/naps2/`. Nach dem ersten Start dauert der Start nur 1–2 Sekunden.
2. **OCR-Sprachpakete**: `tesseract` ist gebündelt, aber Sprachdaten (`*.traineddata`) werden zur Laufzeit aus dem Internet geladen und in `~/.local/share/naps2/` gespeichert.
3. **libsane nicht gebündelt**: Scanner funktionieren nur, wenn `libsane` auf dem Zielsystem installiert ist.
4. **TWAIN nicht verfügbar**: TWAIN-Scanner werden unter Linux generell nicht unterstützt (nur unter Windows).
