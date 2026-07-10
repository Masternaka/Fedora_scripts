#!/usr/bin/env bash
#
# install_thirdparty.sh
# Installation de logiciels tiers non disponibles dans les dépôts Fedora officiels
#
# Logiciels gérés :
#   - Brave Browser (Dépôt RPM officiel)
#   - Vivaldi Browser (Dépôt RPM officiel)
#   - Visual Studio Code (Dépôt RPM officiel)
#   - OpenRGB (COPR ianhattendorf/openrgb)
#   - Warp Terminal (Localinstall RPM officiel)
#   - Discord (Direct tar.gz dans /opt/)
#   - Zed Editor (Script officiel exécuté sous l'utilisateur réel)
#   - GitKraken (Localinstall RPM officiel)
#   - GitHub Desktop (Dépôt miroir shiftkey)
#   - Angry IP Scanner (Localinstall du dernier RPM depuis GitHub releases)
#
# Usage:
#   sudo ./11 - install_thirdparty.sh [OPTIONS]
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
    echo "  --dry-run, -n  Affiche les actions sans effectuer d'installations."
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
# Détermination du profil de l'utilisateur réel
# ---------------------------------------------------------------------------
if [[ -z "${SUDO_USER:-}" ]]; then
    log_err "La variable SUDO_USER n'est pas définie."
    log_err "Ce script doit être lancé via 'sudo' depuis un compte utilisateur standard."
    exit 1
fi

readonly USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
readonly USER_GROUP=$(id -gn "$SUDO_USER")

if [[ -z "$USER_HOME" || -z "$USER_GROUP" ]]; then
    log_err "Impossible de déterminer le répertoire ou le groupe de $SUDO_USER."
    exit 1
fi

# ---------------------------------------------------------------------------
# Fonctions d'installation individuelle
# ---------------------------------------------------------------------------

install_brave() {
    if rpm -q brave-browser &>/dev/null; then
        log_ok "Brave Browser déjà installé."
        return
    fi
    log_info "Configuration du dépôt Brave Browser..."
    run dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
    run rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
    log_info "Installation de Brave Browser..."
    run dnf install -y brave-browser
    log_ok "Brave Browser installé avec succès."
}

install_vivaldi() {
    if rpm -q vivaldi-stable &>/dev/null; then
        log_ok "Vivaldi Browser déjà installé."
        return
    fi
    log_info "Configuration du dépôt Vivaldi..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  (dry-run) création de /etc/yum.repos.d/vivaldi.repo"
    else
        printf '[vivaldi]\nname=Vivaldi packages for Linux\nbaseurl=https://repo.vivaldi.com/archive/rpm/x86_64\nenabled=1\ngpgcheck=1\ngpgkey=https://repo.vivaldi.com/archive/linux_signing_key.pub\n' > /etc/yum.repos.d/vivaldi.repo
    fi
    log_info "Installation de Vivaldi Browser..."
    run dnf install -y vivaldi-stable
    log_ok "Vivaldi Browser installé avec succès."
}

install_vscode() {
    if rpm -q code &>/dev/null; then
        log_ok "VS Code déjà installé."
        return
    fi
    log_info "Configuration du dépôt VS Code..."
    run rpm --import https://packages.microsoft.com/keys/microsoft.asc
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  (dry-run) création de /etc/yum.repos.d/vscode.repo"
    else
        printf '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' > /etc/yum.repos.d/vscode.repo
    fi
    log_info "Installation de VS Code..."
    run dnf install -y code
    log_ok "VS Code installé avec succès."
}

install_openrgb() {
    if rpm -q openrgb &>/dev/null; then
        log_ok "OpenRGB déjà installé."
        return
    fi
    log_info "Activation du dépôt COPR OpenRGB (ianhattendorf/openrgb)..."
    run dnf copr enable -y ianhattendorf/openrgb
    log_info "Installation de OpenRGB..."
    run dnf install -y openrgb
    log_ok "OpenRGB installé avec succès."
}

install_warp() {
    if rpm -q warp-terminal &>/dev/null; then
        log_ok "Warp Terminal déjà installé."
        return
    fi
    log_info "Téléchargement et installation de Warp Terminal..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  (dry-run) téléchargement de warp-terminal-latest.rpm vers /tmp et dnf localinstall"
    else
        curl -fsSL https://releases.warp.dev/stable/latest/linux/warp-terminal-latest.rpm -o /tmp/warp-terminal.rpm
        dnf localinstall -y /tmp/warp-terminal.rpm
        rm -f /tmp/warp-terminal.rpm
    fi
    log_ok "Warp Terminal installé avec succès."
}

install_discord() {
    if [[ -d "/opt/Discord" ]]; then
        log_ok "Discord déjà installé dans /opt/Discord."
        return
    fi
    log_info "Téléchargement et installation de Discord..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  (dry-run) téléchargement et extraction de Discord tar.gz dans /opt/ et liaison dans /usr/local/bin/"
    else
        wget "https://discord.com/api/download?platform=linux&format=tar.gz" -O /tmp/discord.tar.gz
        tar -xzf /tmp/discord.tar.gz -C /tmp
        mv /tmp/Discord /opt/
        ln -sf /opt/Discord/Discord /usr/local/bin/discord
        rm -f /tmp/discord.tar.gz
    fi
    log_ok "Discord installé avec succès."
}

install_zed() {
    if sudo -u "$SUDO_USER" command -v zed &>/dev/null || [[ -f "$USER_HOME/.local/bin/zed" ]]; then
        log_ok "Zed Editor déjà installé."
        return
    fi
    log_info "Installation de Zed Editor pour l'utilisateur ${SUDO_USER}..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  (dry-run) curl -f https://zed.dev/install.sh | sudo -u $SUDO_USER sh"
    else
        curl -fsSL https://zed.dev/install.sh | sudo -u "$SUDO_USER" sh
    fi
    log_ok "Zed Editor installé avec succès."
}

install_gitkraken() {
    if rpm -q gitkraken &>/dev/null; then
        log_ok "GitKraken déjà installé."
        return
    fi
    log_info "Téléchargement et installation de GitKraken..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  (dry-run) téléchargement de gitkraken-amd64.rpm vers /tmp et dnf localinstall"
    else
        curl -fsSL "https://release.gitkraken.com/linux/gitkraken-amd64.rpm" -o /tmp/gitkraken.rpm
        dnf localinstall -y /tmp/gitkraken.rpm
        rm -f /tmp/gitkraken.rpm
    fi
    log_ok "GitKraken installé avec succès."
}

install_github_desktop() {
    if rpm -q github-desktop &>/dev/null; then
        log_ok "GitHub Desktop déjà installé."
        return
    fi
    log_info "Configuration du dépôt miroir pour GitHub Desktop..."
    run rpm --import https://mirror.mwt.me/ghd/gpgkey
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  (dry-run) création de /etc/yum.repos.d/shiftkey-desktop.repo"
    else
        printf '[shiftkey]\nname=GitHub Desktop\nbaseurl=https://mirror.mwt.me/ghd/rpm\nenabled=1\ngpgcheck=0\nrepo_gpgcheck=1\ngpgkey=https://mirror.mwt.me/ghd/gpgkey\n' > /etc/yum.repos.d/shiftkey-desktop.repo
    fi
    log_info "Installation de GitHub Desktop..."
    run dnf install -y github-desktop
    log_ok "GitHub Desktop installé avec succès."
}

install_angry_ip_scanner() {
    if rpm -q ipscan &>/dev/null; then
        log_ok "Angry IP Scanner déjà installé."
        return
    fi
    log_info "Récupération de la dernière version d'Angry IP Scanner depuis GitHub..."
    
    local latest_tag="3.9.1"
    if [[ "$DRY_RUN" -eq 0 ]]; then
        latest_tag=$(curl -s "https://api.github.com/repos/angryip/ipscan/releases/latest" | grep -Po '"tag_name": "\K[^"]*' || echo "3.9.1")
    fi
    
    log_info "Téléchargement et installation de la version ${latest_tag}..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  (dry-run) téléchargement du RPM pour la version ${latest_tag} et dnf localinstall"
    else
        curl -fsSL "https://github.com/angryip/ipscan/releases/download/${latest_tag}/ipscan-${latest_tag}-1.x86_64.rpm" -o /tmp/ipscan.rpm
        dnf localinstall -y /tmp/ipscan.rpm
        rm -f /tmp/ipscan.rpm
    fi
    log_ok "Angry IP Scanner installé avec succès."
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

    log_info "=== Début de l'installation des logiciels tiers ==="
    
    # DNF plugins core est recommandé pour config-manager et copr
    if ! rpm -q dnf-plugins-core &>/dev/null; then
        log_info "Installation de dnf-plugins-core..."
        run dnf install -y dnf-plugins-core
    fi

    install_brave
    install_vivaldi
    install_vscode
    install_openrgb
    install_warp
    install_discord
    install_zed
    install_gitkraken
    install_github_desktop
    install_angry_ip_scanner

    log_ok "=== Installation des logiciels tiers terminée ==="
}

main "$@"
