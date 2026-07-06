#!/usr/bin/env bash
# ============================================================
#  build-naps2-appimage.sh
#  Erstellt ein hochgradig portables AppImage für NAPS2 aus einem .deb-Paket.
#  Optimiert für Ubuntu 24.04 (Distrobox) mit manuellem appimagetool-Handling.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"
BUILD_DIR="${TMPDIR:-/tmp}/naps2-appimage-$$"

# Farben
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()  { echo -e "\n${CYAN}=== $* ===${NC}"; }

# ---- Schritt 0: Voraussetzungen prüfen & installieren -------

step "Schritt 0: Voraussetzungen prüfen"

REQUIRED_PKGS=()
command -v curl &>/dev/null || REQUIRED_PKGS+=("curl")
command -v sed &>/dev/null || REQUIRED_PKGS+=("sed")
command -v dpkg-deb &>/dev/null || REQUIRED_PKGS+=("dpkg")
command -v ar &>/dev/null || REQUIRED_PKGS+=("binutils")
command -v file &>/dev/null || REQUIRED_PKGS+=("file")

SUDO_CMD=""
if [ "$EUID" -ne 0 ]; then
    if command -v sudo &>/dev/null; then SUDO_CMD="sudo"; else error "Sudo wird benötigt."; fi
fi

if [ ${#REQUIRED_PKGS[@]} -ne 0 ]; then
    info "Installiere fehlende Werkzeuge auf der Build-Maschine: ${REQUIRED_PKGS[*]}"
    $SUDO_CMD apt-get update -y
    $SUDO_CMD apt-get install -y "${REQUIRED_PKGS[@]}"
fi

# ---- Schritt 1: Downloads / Validierung der Medien ----------

step "Schritt 1: Quellmedien prüfen"

APPIMAGETOOL="${SCRIPT_DIR}/appimagetool-x86_64.AppImage"

# RADIKALER FIX: Wenn die Datei existiert, wird sie NIEMALS gelöscht oder neu geladen!
if [ -f "$APPIMAGETOOL" ]; then
    info "Nutze vorhandenes lokales appimagetool: $APPIMAGETOOL"
    chmod +x "$APPIMAGETOOL"
else
    info "appimagetool nicht im Ordner gefunden. Starte einmaligen Download..."
    curl -sL -f -o "$APPIMAGETOOL" "https://github.com" || \
    error "Download fehlgeschlagen. Bitte kopiere 'appimagetool-x86_64.AppImage' manuell in diesen Ordner!"
    chmod +x "$APPIMAGETOOL"
fi

# .deb suchen oder von GitHub laden
DEB_FILE=$(find "$SCRIPT_DIR" -maxdepth 1 -name "naps2-*-linux-x64.deb" | sort -V | tail -1 || true)
if [ -z "$DEB_FILE" ]; then
    info "Kein naps2 .deb im Ordner gefunden. Ermittle neueste Version von GitHub..."
    LATEST_URL=$(curl -s https://github.com | grep "browser_download_url.*linux-x64.deb" | cut -d '"' -f 4 | head -n 1)
    if [ -z "$LATEST_URL" ]; then error "Konnte Download-URL für NAPS2 nicht ermitteln."; fi

    DEB_NAME=$(basename "$LATEST_URL")
    info "Lade $DEB_NAME herunter..."
    curl -sL -o "$SCRIPT_DIR/$DEB_NAME" "$LATEST_URL"
    DEB_FILE="$SCRIPT_DIR/$DEB_NAME"
fi

# Version aus Dateiname extrahieren
DEB_BASE=$(basename "$DEB_FILE")
VERSION=$(echo "$DEB_BASE" | grep -oP 'naps2-\K[0-9]+\.[0-9]+\.[0-9]+')
[ -n "$VERSION" ] || error "Version konnte nicht aus '$DEB_BASE' extrahiert werden."

info "NAPS2 Version: $VERSION"
info ".deb-Quelle: $DEB_FILE"

# ---- Schritt 2: Arbeitsverzeichnis vorbereiten --------------

step "Schritt 2: Arbeitsverzeichnis"

mkdir -p "$BUILD_DIR"
DEB_DIR="${BUILD_DIR}/deb"
APPDIR="${BUILD_DIR}/NAPS2.AppDir"

mkdir -p "$DEB_DIR" "$APPDIR"
info "Sandbox vorbereitet: $BUILD_DIR"

trap 'info "Räume auf: $BUILD_DIR"; rm -rf "$BUILD_DIR"' EXIT

# ---- Schritt 3: .deb extrahieren ----------------------------

step "Schritt 3: .deb extrahieren"

cd "$DEB_DIR"
ar x "$DEB_FILE"

DATA_TAR=$(find "$DEB_DIR" -name "data.tar.*" | head -1)
[ -n "$DATA_TAR" ] || error "data.tar.* nicht im .deb gefunden."

tar xf "$DATA_TAR" -C "$DEB_DIR"
info "data.tar erfolgreich entpackt."

DEB_ROOT="${DEB_DIR}/usr"
[ -d "$DEB_ROOT" ] || error "Erwartetes Verzeichnis $DEB_ROOT fehlt nach Extraktion."

NAPS2_LIB="${DEB_ROOT}/lib/naps2"
[ -d "$NAPS2_LIB" ] || error "$NAPS2_LIB fehlt – .deb-Struktur unerwartet."

# ---- Schritt 4: AppDir-Struktur aufbauen --------------------

step "Schritt 4: AppDir-Struktur"

APPDIR_NAPS2="${APPDIR}/usr/lib/naps2"
mkdir -p "$APPDIR_NAPS2"
mkdir -p "${APPDIR}/usr/share/icons/hicolor/128x128/apps"

# Alle Dateien aus usr/lib/naps2/ kopieren
cp -r "${NAPS2_LIB}/." "${APPDIR_NAPS2}/"
info "usr/lib/naps2/ komplett kopiert"

# Icon kopieren
ICON_SRC="${DEB_ROOT}/share/icons/hicolor/128x128/apps/com.naps2.Naps2.png"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "${APPDIR}/usr/share/icons/hicolor/128x128/apps/"
    cp "$ICON_SRC" "${APPDIR}/com.naps2.Naps2.png"
    info "Icon kopiert: com.naps2.Naps2.png"
else
    warn "Icon nicht gefunden: $ICON_SRC"
fi

# ---- Schritt 5: Ausführbarkeit der Binaries -----------------

step "Schritt 5: Ausführbarkeit"

chmod +x "${APPDIR_NAPS2}/naps2"
[ -f "${APPDIR_NAPS2}/apphost" ] && chmod +x "${APPDIR_NAPS2}/apphost"
[ -f "${APPDIR_NAPS2}/_linux/tesseract" ] && chmod +x "${APPDIR_NAPS2}/_linux/tesseract"
info "Ausführungsrechte zugewiesen."

# ---- Schritt 6: SONAME-Symlinks für gebündelte .so ----------

step "Schritt 6: SONAME-Symlinks"

for lib in "${APPDIR_NAPS2}"/*.so; do
    [[ -f "$lib" ]] || continue
    soname=$(readelf -d "$lib" 2>/dev/null | grep SONAME | grep -o '\[.*\]' | tr -d '[]')
    [[ -z "$soname" ]] && continue
    fname=$(basename "$lib")
    if [[ "$soname" != "$fname" ]] && [[ ! -e "${APPDIR_NAPS2}/${soname}" ]]; then
        ln -sf "$fname" "${APPDIR_NAPS2}/${soname}"
        info "  Symlink: $soname → $fname"
    fi
done

# ---- Schritt 7: Desktop-Datei erstellen ---------------------

step "Schritt 7: Desktop-Datei"

DESK="${APPDIR}/com.naps2.Naps2.desktop"

cat > "$DESK" << 'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=NAPS2
Comment=Not Another PDF Scanner
Exec=naps2
Icon=com.naps2.Naps2
Categories=Graphics;Office;Scanning;OCR;
MimeType=application/pdf;image/jpeg;image/png;image/tiff;image/bmp;
Terminal=false
StartupNotify=true
EOF

info "Desktop-Datei generiert."

# ---- Schritt 8: AppRun erstellen ----------------------------

step "Schritt 8: AppRun"

cat > "${APPDIR}/AppRun" << 'EOF'
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
EOF

chmod +x "${APPDIR}/AppRun"
ln -sf "com.naps2.Naps2.png" "${APPDIR}/.DirIcon"
info "AppRun eingerichtet."

# ---- Schritt 9: Validierung ---------------------------------

step "Schritt 9: Validierung"

for f in \
    "${APPDIR}/AppRun" \
    "${APPDIR}/com.naps2.Naps2.desktop" \
    "${APPDIR}/com.naps2.Naps2.png" \
    "${APPDIR_NAPS2}/naps2" \
    "${APPDIR_NAPS2}/appsettings.xml" \
    "${APPDIR_NAPS2}/_linux/libpdfium.so" \
    "${APPDIR_NAPS2}/_linux/tesseract"; do
    if [ -e "$f" ]; then
        info "  ✅ $(basename "$f")"
    else
        warn "  ❌ FEHLT: $f"
    fi
done

SO_COUNT=$(find "${APPDIR_NAPS2}" -maxdepth 1 -name "System.*.so" | wc -l)
info "  .NET System.*.so Dateien: $SO_COUNT"

APPDIR_MB=$(du -sm "${APPDIR}" | cut -f1)
info "  AppDir-Gesamtgröße: ${APPDIR_MB} MB"

# ---- Schritt 10: AppImage bauen -----------------------------

step "Schritt 10: AppImage bauen"

OUTPUT="${OUTPUT_DIR}/NAPS2-${VERSION}-x86_64.AppImage"

# FUSE-freie Ausführung im Distrobox-Container erzwingen
export APPIMAGE_EXTRACT_AND_RUN=1
ARCH=x86_64 "$APPIMAGETOOL" "${APPDIR}" "${OUTPUT}" > /dev/null

if [ -f "$OUTPUT" ]; then
    SIZE=$(du -sh "$OUTPUT" | cut -f1)
    info ""
    info "✅ AppImage erfolgreich aus .deb erstellt!"
    info "   Datei:  $OUTPUT"
    info "   Größe:  $SIZE"
    exit 0
else
    error "AppImage-Erstellung fehlgeschlagen."
fi
