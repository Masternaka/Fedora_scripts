#!/usr/bin/env bash
#
# install_dnf.sh
# Installation des paquets depuis les dépôts officiels Fedora via DNF
#
# Usage:
#   sudo ./10 - install_dnf.sh [OPTIONS]
#
# Options:
#   -n, --dry-run        Affiche les commandes DNF sans les exécuter
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

# Paquets à installer depuis les dépôts Fedora officiels
readonly PACKAGES=(

# Outils de base et système
git
curl
wget
firewall-config

# Outils DNF
dnf-utils

# Utilitaires
gnome-disk-utility
gparted
timeshift
stow
flameshot
7zip
unzip
stow
ranger
yazi

# Développement
micro
meld
ShellCheck
hx
neovim

# Virtualisation
distrobox
podman
podman-tui
podman-compose
toolbox
toolbox-extra-tools

# Terminal
#kitty
ptyxis
guake
starship
foot

# Monitoring & système
btop
fastfetch
lm_sensors
lshw
fwupd
inxi

# Administration système
cockpit
cockpit-bridge
cockpit-networkmanager
cockpit-selinux
cockpit-storaged
cockpit-system
cockpit-ws
cockpit-podman
cockpit-machines
#yumex

# Sécurité
keepassxc

# Navigateur web, email et internet
thunderbird
qbittorrent
transmission-gtk

# Multimédia
vlc
mpv
strawberry
deadbeef

# Office et notes
libreoffice
obsidian
helix-notes

# Langues
libreoffice-l10n-fr
firefox-l10n-fr
thunderbird-l10n-fr 

# Spécifiques à KDE
#io-admin
#io-extras
#olphin-plugins
#rusader
#akuake
#olphin-plugins

# Spécifiques à Gnome
gnome-tweaks
file-roller
dconf-editor

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
    echo "  --dry-run, -n  Affiche les commandes DNF sans les exécuter."
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
# Point d'entrée principal
# ---------------------------------------------------------------------------
main() {
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

    check_root
    check_fedora

    # Rafraîchir le cache DNF
    log_info "Mise à jour du cache DNF..."
    run dnf makecache --refresh
    log_ok "Cache DNF mis à jour."

    # Installation des paquets officiels
    if [[ ${#PACKAGES[@]} -gt 0 ]]; then
        log_info "Installation des paquets officiels Fedora : ${PACKAGES[*]}"
        run dnf install -y "${PACKAGES[@]}"
        log_ok "Paquets officiels Fedora installés."
    else
        log_warn "Aucun paquet à installer."
    fi

    log_ok "Installation terminée avec succès."
}

main "$@"