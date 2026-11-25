#!/usr/bin/env bash
#
# install_copr.sh
# Activation des dépôts COPR et installation des paquets associés sur Fedora
#
# Dépôts et paquets gérés :
#   - lihaohong/yazi            -> yazi
#   - lilay/topgrade            -> topgrade
#
# Usage:
#   sudo ./09 - install_copr.sh [OPTIONS]
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

# Dépôts COPR et leurs paquets correspondants
declare -A COPR_MAP=(
    ["lihaohong/yazi"]="yazi"
    ["lilay/topgrade"]="topgrade"
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
    echo "  --dry-run, -n  Affiche les actions sans activer les dépôts ni installer les paquets."
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

is_copr_enabled() {
    local repo="$1"
    local owner="${repo%%/*}"
    local project="${repo##*/}"
    compgen -G "/etc/yum.repos.d/*copr*${owner}*${project}*.repo" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Activation des dépôts COPR et installation des paquets
# ---------------------------------------------------------------------------
process_coprs() {
    log_info "Configuration des dépôts COPR..."

    # DNF Core Plugins est requis pour la commande 'copr'
    if ! rpm -q dnf-plugins-core &>/dev/null; then
        log_info "Installation de dnf-plugins-core..."
        run dnf install -y dnf-plugins-core
    fi

    # Parcourir et configurer chaque dépôt COPR
    for repo in "${!COPR_MAP[@]}"; do
        local package="${COPR_MAP[$repo]}"

        # 1. Activation du dépôt
        if is_copr_enabled "$repo"; then
            log_ok "Dépôt COPR '${repo}' déjà activé."
        else
            log_info "Activation du dépôt COPR '${repo}'..."
            run dnf copr enable -y "$repo"
            log_ok "Dépôt COPR '${repo}' activé."
        fi

        # 2. Installation du paquet associé s'il est spécifié
        if [[ -n "$package" ]]; then
            if rpm -q "$package" &>/dev/null; then
                log_ok "Paquet '${package}' déjà installé."
            else
                log_info "Installation du paquet '${package}' depuis le dépôt COPR..."
                run dnf install -y "$package"
                log_ok "Paquet '${package}' installé avec succès."
            fi
        fi
    done
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
    process_coprs
    log_ok "Configuration COPR et installation des paquets terminées."
}

main "$@"