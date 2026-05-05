#!/bin/bash

# Script d'installation modulaire pour Fedora 44
# Date: 2026-05-05

set -euo pipefail  # Arrêter en cas d'erreur, variable non définie, ou erreur dans un pipe

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
LOG_FILE="$SCRIPT_DIR/install.log"

# Fonctions de journalisation
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERREUR:${NC} $1" | tee -a "$LOG_FILE" >&2
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCÈS:${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] AVERTISSEMENT:${NC} $1" | tee -a "$LOG_FILE"
}

# Vérification des droits administrateur
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté avec les droits administrateur (sudo)"
        exit 1
    fi
    log "Vérification des droits administrateur: OK"
}

# Chargement d'un module de configuration
load_module() {
    local module_file="$1"
    local module_name
    module_name=$(basename "$module_file" .conf)

    log "Chargement du module: $module_name"

    if [[ ! -f "$module_file" ]]; then
        log_error "Fichier de module introuvable: $module_file"
        return 1
    fi

    # shellcheck source=/dev/null
    source "$module_file"

    if [[ -z "${MODULE_NAME:-}" ]]; then
        log_error "MODULE_NAME non défini dans $module_file"
        return 1
    fi

    if [[ -z "${INSTALL_CMD:-}" ]]; then
        log_error "INSTALL_CMD non défini dans $module_file"
        return 1
    fi

    log "Module '$MODULE_NAME' chargé avec succès"
    return 0
}

# Exécution d'un module
execute_module() {
    local module_file="$1"
    local module_name
    module_name=$(basename "$module_file" .conf)

    log "=== DÉBUT DU MODULE: $module_name ==="

    if ! load_module "$module_file"; then
        log_error "Échec du chargement du module $module_name"
        return 1
    fi

    # Installer les prérequis si définis
    # Utilisation de "while read" pour traiter ligne par ligne (évite le bug de parsing des commentaires)
    if [[ -n "${PREREQS:-}" ]]; then
        log "Installation des prérequis pour $MODULE_NAME"
        while IFS= read -r prereq; do
            [[ -z "$prereq" || "$prereq" =~ ^[[:space:]]*# ]] && continue
            if ! $INSTALL_CMD "$prereq" 2>&1 | tee -a "$LOG_FILE"; then
                log_error "Échec de l'installation du prérequis: $prereq"
                return 1
            fi
        done <<< "$PREREQS"
        log "Prérequis installés avec succès"
    fi

    # Installer les paquets
    if [[ -n "${PACKAGES:-}" ]]; then
        log "Installation des paquets pour $MODULE_NAME"
        while IFS= read -r package; do
            # Ignorer les lignes vides et les commentaires
            [[ -z "$package" || "$package" =~ ^[[:space:]]*# ]] && continue

            # Commande personnalisée (format: NOM|COMMANDE)
            if [[ "$package" == *"|"* ]]; then
                local package_name
                local custom_cmd
                package_name=$(echo "$package" | cut -d'|' -f1)
                custom_cmd=$(echo "$package" | cut -d'|' -f2-)
                log "Installation personnalisée: $package_name"
                if ! eval "$custom_cmd" 2>&1 | tee -a "$LOG_FILE"; then
                    log_error "Échec de l'installation personnalisée: $package_name"
                    return 1
                fi
                log_success "Installation personnalisée réussie: $package_name"
            else
                log "Installation du paquet: $package"
                if ! $INSTALL_CMD "$package" 2>&1 | tee -a "$LOG_FILE"; then
                    log_error "Échec de l'installation du paquet: $package"
                    return 1
                fi
                log_success "Paquet installé: $package"
            fi
        done <<< "$PACKAGES"
        log_success "Tous les paquets de $MODULE_NAME ont été installés"
    else
        log "Aucun paquet à installer pour $MODULE_NAME"
    fi

    unset MODULE_NAME INSTALL_CMD PACKAGES PREREQS

    log "=== FIN DU MODULE: $module_name ==="
    return 0
}

# Sélection interactive des modules
select_modules() {
    local modules=("$MODULES_DIR"/*.conf)
    local selected_modules=()

    if [[ ${#modules[@]} -eq 0 || ! -f "${modules[0]}" ]]; then
        log_error "Aucun fichier de configuration (.conf) trouvé dans $MODULES_DIR"
        exit 1
    fi

    echo ""
    echo -e "${BOLD}=== SÉLECTION DES MODULES À EXÉCUTER ===${NC}"
    echo "Modules disponibles:"

    for i in "${!modules[@]}"; do
        local module_name
        module_name=$(basename "${modules[$i]}" .conf)
        echo "  $((i+1)). $module_name"
    done

    echo ""
    echo "Entrez les numéros des modules (séparés par des espaces) ou 'all' pour tous:"

    local user_input
    while true; do
        read -r user_input

        if [[ "$user_input" == "all" ]]; then
            selected_modules=("${modules[@]}")
            break
        fi

        local valid=true
        local temp_selected=()
        for num in $user_input; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#modules[@]} ]]; then
                temp_selected+=("${modules[$((num-1))]}")
            else
                log_warn "Numéro invalide: $num. Veuillez réessayer."
                valid=false
                break
            fi
        done

        if $valid && [[ ${#temp_selected[@]} -gt 0 ]]; then
            selected_modules=("${temp_selected[@]}")
            break
        elif $valid; then
            log_warn "Aucun module sélectionné. Entrez au moins un numéro."
        fi
    done

    echo ""
    echo -e "${BOLD}Modules sélectionnés: ${#selected_modules[@]}${NC}"
    for module_file in "${selected_modules[@]}"; do
        echo "  - $(basename "$module_file" .conf)"
    done

    echo ""
    echo "Confirmer l'exécution? (o/n)"
    read -r confirm

    if [[ "$confirm" != "o" && "$confirm" != "O" ]]; then
        log "Opération annulée par l'utilisateur"
        exit 0
    fi

    printf '%s\n' "${selected_modules[@]}"
}

# Fonction principale
main() {
    log "=== DÉBUT DE L'INSTALLATION MODULAIRE FEDORA 44 ==="

    check_sudo

    log "Mise à jour du système"
    if ! dnf upgrade -y 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Échec de la mise à jour du système"
        exit 1
    fi
    log_success "Système mis à jour avec succès"

    if [[ ! -d "$MODULES_DIR" ]]; then
        log_error "Dossier des modules introuvable: $MODULES_DIR"
        exit 1
    fi

    local selected_modules
    readarray -t selected_modules < <(select_modules)

    for module_file in "${selected_modules[@]}"; do
        if ! execute_module "$module_file"; then
            log_error "Échec de l'exécution du module: $(basename "$module_file")"
            exit 1
        fi
    done

    log_success "=== INSTALLATION TERMINÉE AVEC SUCCÈS ==="
}

main "$@"
