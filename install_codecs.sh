#!/usr/bin/env bash

# Script d'installation des codecs multimédia pour Fedora
# Carte graphique : Intel
# Source          : RPM Fusion (free + nonfree)
# Date            : 2026-05-05

set -euo pipefail

# ── Couleurs ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }

# ── Vérification root ─────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Ce script doit être exécuté en root (sudo)."

echo -e "\n${BOLD}=== Installation des codecs multimédia — Fedora (Intel) ===${RESET}\n"

# ── 1. Dépôts RPM Fusion ──────────────────────────────────────────────────────
info "Vérification des dépôts RPM Fusion..."

FEDORA_VERSION=$(rpm -E %fedora)

if ! rpm -q rpmfusion-free-release &>/dev/null; then
    info "Ajout de RPM Fusion Free..."
    dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm"
    success "RPM Fusion Free ajouté."
else
    success "RPM Fusion Free déjà présent."
fi

if ! rpm -q rpmfusion-nonfree-release &>/dev/null; then
    info "Ajout de RPM Fusion NonFree..."
    dnf install -y \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"
    success "RPM Fusion NonFree ajouté."
else
    success "RPM Fusion NonFree déjà présent."
fi

# ── 2. Mise à jour des métadonnées ────────────────────────────────────────────
info "Mise à jour des métadonnées DNF..."
dnf makecache --refresh -q
success "Métadonnées à jour."

# ── 3. Codecs multimédia de base (GStreamer) ──────────────────────────────────
info "Installation des plugins GStreamer..."
dnf install -y \
    gstreamer1-plugins-base \
    gstreamer1-plugins-good \
    gstreamer1-plugins-good-extras \
    gstreamer1-plugins-ugly \
    gstreamer1-plugins-ugly-free \
    gstreamer1-plugins-bad-free \
    gstreamer1-plugins-bad-free-extras \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugin-openh264 \
    gstreamer1-libav
success "Plugins GStreamer installés."

# ── 4. FFmpeg ─────────────────────────────────────────────────────────────────
info "Installation de FFmpeg (RPM Fusion)..."
# Remplacer ffmpeg-free (Fedora officiel) par ffmpeg complet de RPM Fusion
dnf swap -y ffmpeg-free ffmpeg --allowerasing 2>/dev/null || \
    dnf install -y ffmpeg --allowerasing
success "FFmpeg installé."

# ── 5. Codecs additionnels (formats propriétaires) ────────────────────────────
info "Installation des codecs additionnels..."
dnf install -y \
    faad2 \
    flac \
    lame \
    libdvdread \
    libdvdnav \
    libaacs \
    x264 \
    x265 \
    xvid \
    libmp4v2 \
    libvpx \
    opus \
    speex \
    mpg123 \
    a52dec \
    libmad
success "Codecs additionnels installés."

# ── 6. Lecture de DVD chiffrés (CSS) ─────────────────────────────────────────
info "Installation du support DVD chiffré (libdvdcss)..."

if ! rpm -q libdvdcss &>/dev/null; then
    dnf install -y libdvdcss
    success "libdvdcss installé."
else
    success "libdvdcss déjà présent."
fi

# ── 7. Accélération matérielle Intel (VA-API) ─────────────────────────────────
info "Installation du support VA-API pour Intel..."
dnf install -y \
    intel-media-driver \
    libva \
    libva-utils \
    libva-intel-driver \
    mesa-va-drivers \
    mesa-vdpau-drivers
success "Accélération matérielle Intel (VA-API) installée."

# ── 8. Lecteurs multimédia ────────────────────────────────────────────────────
echo
info "Voulez-vous installer les lecteurs multimédia recommandés ? (o/n)"
read -r INSTALL_PLAYERS

if [[ "$INSTALL_PLAYERS" == "o" || "$INSTALL_PLAYERS" == "O" ]]; then
    info "Installation de VLC et mpv..."
    dnf install -y vlc mpv
    success "VLC et mpv installés."
else
    info "Installation des lecteurs ignorée."
fi

# ── 9. Vérification VA-API ────────────────────────────────────────────────────
echo
info "Vérification de l'accélération matérielle (vainfo)..."
if command -v vainfo &>/dev/null; then
    vainfo 2>/dev/null | grep -E "VA-API|vainfo|iHD|i965" || \
        warn "vainfo a retourné une sortie inattendue — vérifiez manuellement."
    success "vainfo exécuté."
else
    warn "vainfo non disponible. Installez libva-utils pour vérifier VA-API."
fi

# ── Résumé ────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}=== Installation terminée ===${RESET}"
echo -e "  • Plugins GStreamer      : ${GREEN}installés${RESET}"
echo -e "  • FFmpeg                 : ${GREEN}installé${RESET}"
echo -e "  • libdvdcss (DVD CSS)    : ${GREEN}installé${RESET}"
echo -e "  • VA-API Intel           : ${GREEN}installé${RESET}"
echo -e ""
echo -e "  ${CYAN}Vérifier VA-API         :${RESET} vainfo"
echo -e "  ${CYAN}Tester la lecture DVD   :${RESET} vlc dvd:// (ou mpv dvd://)"
echo -e "  ${CYAN}Tester un fichier vidéo :${RESET} mpv <fichier>"
echo
