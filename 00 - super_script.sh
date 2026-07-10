#!/usr/bin/env bash

set -euo pipefail

# -------------------- CONFIGURATION --------------------
# Dossier contenant tous les scripts secondaires
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="/var/log/fedora-custom-$(date +%Y%m%d-%H%M%S).log"

# Scripts à exécuter avec sudo (root requis)
# Format : "nom_du_fichier.sh"
SCRIPTS_SUDO=(
    "01 - systemd_services.sh"
    "02 - zram_settings.sh"
    "04 - bash_tools.sh"
    "06 - install_samba.sh"
    "07 - install_rpmfusion.sh"
    "08 - install_terrarepo.sh"
    "09 - install_copr.sh"
    "10 - install_dnf.sh"
    "11 - install_thirdparty.sh"
    "12 - flatpak_install.sh"
    "13 - install_niridms.sh"
)

# Scripts à exécuter sans sudo
SCRIPTS_USER=(
    "03 - install_nerd_fonts.sh"
    "05 - install_alias.sh"
)
# ------------------------------------------------------

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

DRY_RUN=0

show_help() {
    echo "Usage: sudo $0 [--dry-run]"
    echo "  --dry-run  Affiche les actions des scripts sans appliquer de modification."
}

for arg in "$@"; do
    case "$arg" in
        --dry-run|-n)
            DRY_RUN=1
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}ERREUR : Argument inconnu : $arg${NC}" >&2
            show_help >&2
            exit 1
            ;;
    esac
done

if [[ "$DRY_RUN" -eq 1 ]]; then
    LOGFILE="/tmp/fedora-custom-dry-run-$(date +%Y%m%d-%H%M%S).log"
fi

# -------------------- SUIVI DES RÉSULTATS --------------------
declare -A SCRIPT_RESULTS
for script in "${SCRIPTS_SUDO[@]}" "${SCRIPTS_USER[@]}"; do
    SCRIPT_RESULTS["$script"]="En attente"
done

refresh_sudo() {
    while true; do
        sudo -v
        sleep 60
    done
}

show_summary() {
    if [[ -n "${SUDO_REFRESH_PID:-}" ]]; then
        kill "$SUDO_REFRESH_PID" 2>/dev/null || true
    fi

    echo -e "\n${YELLOW}==================================================${NC}"
    echo -e "${YELLOW}               RÉSUMÉ DE L'INSTALLATION            ${NC}"
    echo -e "${YELLOW}==================================================${NC}"

    for script in "${SCRIPTS_SUDO[@]}" "${SCRIPTS_USER[@]}"; do
        local status="${SCRIPT_RESULTS["$script"]}"
        case "$status" in
            "Succès")
                echo -e "  [${GREEN}✔${NC}] $script : ${GREEN}Succès${NC}"
                ;;
            "Échoué"*)
                echo -e "  [${RED}✘${NC}] $script : ${RED}$status${NC}"
                ;;
            "En cours")
                echo -e "  [${RED}✘${NC}] $script : ${RED}Interrompu en cours de route${NC}"
                ;;
            "En attente")
                echo -e "  [${YELLOW}-${NC}] $script : ${YELLOW}Ignoré (erreur précédente)${NC}"
                ;;
            *)
                echo -e "  [${RED}!${NC}] $script : ${RED}$status${NC}"
                ;;
        esac
done
    echo -e "${YELLOW}==================================================${NC}"
}

trap show_summary EXIT

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}ERREUR : Ce script doit être exécuté en tant que root (utilisez: sudo $0)${NC}" >&2
    exit 1
fi

if [[ -z "${SUDO_USER:-}" ]]; then
    echo -e "${RED}ERREUR : La variable SUDO_USER n'est pas définie.${NC}" >&2
    echo -e "${RED}Ce script doit être lancé via 'sudo' depuis un compte utilisateur standard.${NC}" >&2
    exit 1
fi

export FEDORA_CUSTOM_LOGFILE="$LOGFILE"

exec > >(tee -a "$LOGFILE") 2>&1

echo -e "${YELLOW}### Début de la personnalisation - $(date) ###${NC}"
echo "Dossier des scripts : $SCRIPT_DIR"
echo "Log : $LOGFILE"
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "Mode : dry-run"
fi
echo ""

sudo -v
refresh_sudo &
SUDO_REFRESH_PID=$!

run_script() {
    local script_name="$1"
    local script_path="${SCRIPT_DIR}/${script_name}"
    local use_sudo="$2"

    echo -e "${GREEN}--- $script_name ---${NC}"
    if [[ ! -f "$script_path" ]]; then
        echo -e "${RED}ERREUR : Fichier introuvable : $script_path${NC}" >&2
        SCRIPT_RESULTS["$script_name"]="Introuvable"
        exit 1
    fi

    SCRIPT_RESULTS["$script_name"]="En cours"
    local exit_code=0
    local args=()
    if [[ "$DRY_RUN" -eq 1 ]]; then
        args+=(--dry-run)
    fi

    if [[ "$use_sudo" == "yes" ]]; then
        sudo bash "$script_path" "${args[@]}" || exit_code=$?
    else
        sudo -u "$SUDO_USER" bash "$script_path" "${args[@]}" || exit_code=$?
    fi

    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}ERREUR : $script_path a échoué (code $exit_code).${NC}" >&2
        SCRIPT_RESULTS["$script_name"]="Échoué (code $exit_code)"
        exit $exit_code
    fi

    SCRIPT_RESULTS["$script_name"]="Succès"
    echo -e "${GREEN}--- Ok ---${NC}"
    echo ""
}

echo -e "${YELLOW}== Scripts administrateur (sudo) ==${NC}"
for script in "${SCRIPTS_SUDO[@]}"; do
    run_script "${script}" "yes"
done

echo -e "${YELLOW}== Scripts utilisateur (sans sudo) ==${NC}"
for script in "${SCRIPTS_USER[@]}"; do
    run_script "${script}" "no"
done

echo -e "${YELLOW}### Terminé - $(date) ###${NC}"
