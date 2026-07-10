#!/usr/bin/env bash
#
# install_terrarepo.sh
# Installation du dépôt Terra (Fyra Labs) et des paquets associés sur Fedora
#
# Usage:
#   sudo ./08 - install_terrarepo.sh [OPTIONS]
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

# Paquets à installer depuis le dépôt Terra
readonly PACKAGES=(
    
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
    echo "  --dry-run, -n  Affiche les actions sans installer le dépôt ni les paquets."
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
# Installation du dépôt Terra
# ---------------------------------------------------------------------------
install_terra() {
    if rpm -q terra-release &>/dev/null; then
        log_ok "Dépôt Terra déjà installé (terra-release est présent)."
        return
    fi

    log_info "Installation de terra-release depuis le dépôt distant de Fyra Labs..."
    run dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
    log_ok "Dépôt Terra installé avec succès."
}

refresh_cache() {
    log_info "Rafraîchissement du cache DNF..."
    run dnf makecache --refresh
    log_ok "Cache DNF mis à jour."
}

install_packages() {
    if [[ ${#PACKAGES[@]} -eq 0 ]]; then
        log_info "Aucun paquet à installer depuis le dépôt Terra."
        return
    fi

    log_info "Installation des paquets Terra : ${PACKAGES[*]}"
    run dnf install -y "${PACKAGES[@]}"
    log_ok "Paquets Terra installés avec succès."
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
    install_terra
    refresh_cache
    install_packages
    log_ok "Configuration de Terra et installation des paquets terminées."
}

main "$@"