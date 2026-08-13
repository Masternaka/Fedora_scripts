#!/usr/bin/env bash
#
# install_rpmfusion.sh
# Installation des dépôts RPM Fusion (Free et Nonfree) et des codecs audio/vidéo sur Fedora
#
# Usage:
#   sudo ./07 - install_rpmfusion.sh [OPTIONS]
#
# Options:
#   -n, --dry-run        Affiche les actions sans les exécuter
#   -h, --help           Affiche cette aide
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Constantes et couleurs
# ---------------------------------------------------------------------------
readonly C_RESET='\033[0m'
readonly C_INFO='\033[1;34m'
readonly C_OK='\033[1;32m'
readonly C_WARN='\033[1;33m'
readonly C_ERR='\033[0;31m'

# Liste des codecs et plugins multimédias à installer
readonly PACKAGES=(
    gstreamer1-plugins-base
    gstreamer1-plugins-good
    gstreamer1-plugins-good-extras
    gstreamer1-plugins-bad-free
    gstreamer1-plugins-bad-free-extras
    gstreamer1-plugins-ugly
    gstreamer1-plugins-ugly-free
    gstreamer1-plugin-openh264
    gstreamer1-plugin-libav
    libdvdcss
    gstreamer1-plugins-bad-freeworld
)

DRY_RUN=0

# ---------------------------------------------------------------------------
# Fonctions utilitaires
# ---------------------------------------------------------------------------
log_info()  { echo -e "${C_INFO}[INFO]${C_RESET} $*"; }
log_ok()    { echo -e "${C_OK}[ OK ]${C_RESET} $*"; }
log_warn()  { echo -e "${C_WARN}[WARN]${C_RESET} $*"; }
log_err()   { echo -e "${C_ERR}[ERR ]${C_RESET} $*" >&2; }

run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '  (dry-run)'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

show_help() {
    echo "Usage: sudo $0 [OPTIONS]"
    echo "  --dry-run, -n  Affiche les actions sans installer le dépôt ni les codecs."
    echo "  --help, -h     Affiche cette aide."
}

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log_err "Ce script doit être exécuté en root (sudo)."
        exit 1
    fi
}

check_fedora() {
    if ! grep -qiE 'fedora|rhel|centos' /etc/os-release 2>/dev/null; then
        log_warn "Distribution non détectée comme Fedora/RHEL. Poursuite quand même."
    fi
}

# ---------------------------------------------------------------------------
# Installation des dépôts RPM Fusion
# ---------------------------------------------------------------------------
install_rpmfusion() {
    local fedora_version
    fedora_version=$(rpm -E %fedora)

    log_info "Version Fedora détectée : ${fedora_version}"

    # Vérification et installation de RPM Fusion Free
    if rpm -q rpmfusion-free-release &>/dev/null; then
        log_ok "Dépôt RPM Fusion Free déjà installé."
    else
        log_info "Installation de RPM Fusion Free..."
        run dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm"
        log_ok "Dépôt RPM Fusion Free installé."
    fi

    # Vérification et installation de RPM Fusion Nonfree
    if rpm -q rpmfusion-nonfree-release &>/dev/null; then
        log_ok "Dépôt RPM Fusion Nonfree déjà installé."
    else
        log_info "Installation de RPM Fusion Nonfree..."
        run dnf install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm"
        log_ok "Dépôt RPM Fusion Nonfree installé."
    fi
}

update_appstream() {
    log_info "Mise à jour des métadonnées d'AppStream..."
    run dnf groupupdate -y core
    log_ok "Métadonnées AppStream mises à jour."
}

# ---------------------------------------------------------------------------
# Installation de FFmpeg complet et des codecs multimédias
# ---------------------------------------------------------------------------
install_codecs() {
    log_info "Remplacement de ffmpeg-free (Fedora par défaut) par ffmpeg complet (RPM Fusion)..."
    run dnf swap -y ffmpeg-free ffmpeg --allowerasing

    log_info "Installation des codecs audio, vidéo et plugins GStreamer..."
    run dnf install -y "${PACKAGES[@]}"
    log_ok "Codecs multimédias et plugins GStreamer installés avec succès."
}

# ---------------------------------------------------------------------------
# Analyse des arguments
# ---------------------------------------------------------------------------
parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --dry-run|-n)
                DRY_RUN=1
                log_warn "Mode dry-run activé : aucune modification ne sera appliquée."
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_err "Argument inconnu : $arg"
                show_help
                exit 1
                ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Point d'entrée principal
# ---------------------------------------------------------------------------
main() {
    parse_args "$@"
    check_root
    check_fedora
    install_rpmfusion
    update_appstream
    install_codecs
    log_ok "Configuration de RPM Fusion et installation des codecs terminées avec succès."
}

main "$@"