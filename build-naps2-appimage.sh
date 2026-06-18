#!/bin/bash
# ============================================================
#  build-naps2-appimage.sh
#  Erstellt ein AppImage für NAPS2 (Not Another PDF Scanner 2)
#  Basis: offizielles Linux-x64 .deb-Paket von GitHub Releases
#
#  Voraussetzungen im gleichen Verzeichnis:
#    - naps2-<VERSION>-linux-x64.deb   (von GitHub Releases)
#    - appimagetool-x86_64.AppImage
#
#  Verwendung:
#    ./build-naps2-appimage.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Farben
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()  { echo -e "\n${CYAN}=== $* ===${NC}"; }

# ---- Schritt 0: Voraussetzungen prüfen ----------------------

step "Schritt 0: Voraussetzungen"

APPIMAGETOOL="${SCRIPT_DIR}/appimagetool-x86_64.AppImage"
[ -x "$APPIMAGETOOL" ] || error "appimagetool-x86_64.AppImage nicht gefunden oder nicht ausführbar."

# .deb suchen
DEB_FILE=$(find "$SCRIPT_DIR" -maxdepth 1 -name "naps2-*-linux-x64.deb" | sort -V | tail -1)
[ -n "$DEB_FILE" ] || error "Kein naps2-*-linux-x64.deb in $SCRIPT_DIR gefunden."

# Version aus Dateiname extrahieren
DEB_BASE=$(basename "$DEB_FILE")
VERSION=$(echo "$DEB_BASE" | grep -oP 'naps2-\K[0-9]+\.[0-9]+\.[0-9]+')
[ -n "$VERSION" ] || error "Version konnte nicht aus '$DEB_BASE' extrahiert werden."

info "NAPS2 Version: $VERSION"
info ".deb: $DEB_FILE"
info "appimagetool: $APPIMAGETOOL"

# Hilfsprogramme prüfen
for cmd in ar tar file readelf; do
    command -v "$cmd" &>/dev/null || error "$cmd fehlt – bitte installieren."
done

# ---- Schritt 1: Arbeitsverzeichnis vorbereiten --------------

step "Schritt 1: Arbeitsverzeichnis"

WORK_DIR=$(mktemp -d /tmp/naps2-appimage-XXXXXX)
DEB_DIR="${WORK_DIR}/deb"
APPDIR="${WORK_DIR}/NAPS2.AppDir"

mkdir -p "$DEB_DIR" "$APPDIR"
info "Arbeitsverzeichnis: $WORK_DIR"
info "AppDir: $APPDIR"

trap 'info "Räume auf: $WORK_DIR"; rm -rf "$WORK_DIR"' EXIT

# ---- Schritt 2: .deb extrahieren ----------------------------

step "Schritt 2: .deb extrahieren"

cd "$DEB_DIR"
ar x "$DEB_FILE"
info ".deb als ar-Archiv entpackt"

# data.tar.xz (oder .gz) auspacken
DATA_TAR=$(find "$DEB_DIR" -name "data.tar.*" | head -1)
[ -n "$DATA_TAR" ] || error "data.tar.* nicht im .deb gefunden."

tar xf "$DATA_TAR" -C "$DEB_DIR"
info "data.tar extrahiert: $(basename "$DATA_TAR")"

DEB_ROOT="${DEB_DIR}/usr"
[ -d "$DEB_ROOT" ] || error "Erwartetes Verzeichnis $DEB_ROOT fehlt nach Extraktion."

NAPS2_LIB="${DEB_ROOT}/lib/naps2"
[ -d "$NAPS2_LIB" ] || error "$NAPS2_LIB fehlt – .deb-Struktur unerwartet."

info "NAPS2-Binaries: $NAPS2_LIB"

# ---- Schritt 3: AppDir-Struktur aufbauen --------------------

step "Schritt 3: AppDir-Struktur"

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

# Inhalt prüfen
info "AppDir/usr/lib/naps2/:"
ls "${APPDIR_NAPS2}/"

# ---- Schritt 4: Ausführbarkeit der Binaries -----------------

step "Schritt 4: Ausführbarkeit"

chmod +x "${APPDIR_NAPS2}/naps2"
[ -f "${APPDIR_NAPS2}/apphost" ] && chmod +x "${APPDIR_NAPS2}/apphost"
[ -f "${APPDIR_NAPS2}/_linux/tesseract" ] && chmod +x "${APPDIR_NAPS2}/_linux/tesseract"
info "naps2 + apphost + tesseract ausführbar"

# ---- Schritt 5: SONAME-Symlinks für gebündelte .so ----------

step "Schritt 5: SONAME-Symlinks"

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

# libpdfium (kein SONAME nötig, via dlopen mit exaktem Namen geladen)
if [ -f "${APPDIR_NAPS2}/_linux/libpdfium.so" ]; then
    info "  libpdfium.so vorhanden (kein SONAME, dlopen exakter Name)"
fi

# ---- Schritt 6: Desktop-Datei erstellen ---------------------

step "Schritt 6: Desktop-Datei"

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

info "Desktop-Datei erstellt: com.naps2.Naps2.desktop"

# ---- Schritt 7: AppRun erstellen ----------------------------

step "Schritt 7: AppRun"

cat > "${APPDIR}/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE="${SELF%/*}"
NAPS2_DIR="${HERE}/usr/lib/naps2"

# .NET Single-File entpackt Assemblies nach ~/.net/<app>/ (Standard)
# Bei noexec-Home: alternatives Verzeichnis setzen
if [ -n "$HOME" ] && [ -w "$HOME" ]; then
    export DOTNET_BUNDLE_EXTRACT_BASE_DIR="${DOTNET_BUNDLE_EXTRACT_BASE_DIR:-${HOME}/.cache/naps2}"
else
    export DOTNET_BUNDLE_EXTRACT_BASE_DIR="/tmp/.naps2-${USER:-user}"
fi

exec "${NAPS2_DIR}/naps2" "$@"
EOF

chmod +x "${APPDIR}/AppRun"
info "AppRun erstellt"

# ---- Schritt 8: .DirIcon Symlink ----------------------------

step "Schritt 8: .DirIcon"

ln -sf "com.naps2.Naps2.png" "${APPDIR}/.DirIcon"
info ".DirIcon → com.naps2.Naps2.png"

# ---- Schritt 9: Validierung ---------------------------------

step "Schritt 9: Validierung"

# Pflichtdateien
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

# .NET native helper .so prüfen
SO_COUNT=$(find "${APPDIR_NAPS2}" -maxdepth 1 -name "System.*.so" | wc -l)
info "  .NET System.*.so Dateien: $SO_COUNT"
[ "$SO_COUNT" -ge 5 ] || warn "Weniger als 5 System.*.so – .deb möglicherweise unvollständig"

# Größe
APPDIR_MB=$(du -sm "${APPDIR}" | cut -f1)
info "  AppDir-Größe: ${APPDIR_MB} MB"

# ---- Schritt 10: AppImage bauen -----------------------------

step "Schritt 10: AppImage bauen"

OUTPUT="${SCRIPT_DIR}/NAPS2-${VERSION}-x86_64.AppImage"

ARCH=x86_64 "$APPIMAGETOOL" "${APPDIR}" "${OUTPUT}" 2>&1

if [ -f "$OUTPUT" ]; then
    SIZE=$(du -sh "$OUTPUT" | cut -f1)
    info ""
    info "✅ AppImage erfolgreich erstellt!"
    info "   Datei:  $OUTPUT"
    info "   Größe:  $SIZE"
else
    error "AppImage wurde nicht erstellt."
fi
