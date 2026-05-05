#!/bin/bash

# Script d'installation modulaire pour Fedora 44
# Auteur: Système automatisé
# Date: $(date +%Y-%m-%d)

set -e  # Arrêter le script en cas d'erreur

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
LOG_FILE="$SCRIPT_DIR/install.log"

# Fonctions de journalisation
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERREUR: $1" | tee -a "$LOG_FILE" >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCÈS: $1" | tee -a "$LOG_FILE"
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
    local module_name=$(basename "$module_file" .conf)
    
    log "Chargement du module: $module_name"
    
    if [[ ! -f "$module_file" ]]; then
        log_error "Fichier de module introuvable: $module_file"
        return 1
    fi
    
    # Charger les variables du module
    source "$module_file"
    
    # Vérifier les variables requises
    if [[ -z "$MODULE_NAME" ]]; then
        log_error "MODULE_NAME non défini dans $module_file"
        return 1
    fi
    
    if [[ -z "$INSTALL_CMD" ]]; then
        log_error "INSTALL_CMD non défini dans $module_file"
        return 1
    fi
    
    log "Module '$MODULE_NAME' chargé avec succès"
    return 0
}

# Exécution d'un module
execute_module() {
    local module_file="$1"
    local module_name=$(basename "$module_file" .conf)
    
    log "=== DÉBUT DU MODULE: $module_name ==="
    
    # Charger le module
    if ! load_module "$module_file"; then
        log_error "Échec du chargement du module $module_name"
        return 1
    fi
    
    # Installer les prérequis si définis
    if [[ -n "$PREREQS" ]]; then
        log "Installation des prérequis pour $MODULE_NAME"
        for prereq in $PREREQS; do
            if ! $INSTALL_CMD "$prereq" 2>&1 | tee -a "$LOG_FILE"; then
                log_error "Échec de l'installation du prérequis: $prereq"
                return 1
            fi
        done
        log "Prérequis installés avec succès"
    fi
    
    # Installer les paquets
    if [[ -n "$PACKAGES" ]]; then
        log "Installation des paquets pour $MODULE_NAME"
        for package in $PACKAGES; do
            # Ignorer les lignes vides et les commentaires
            if [[ -n "$package" && ! "$package" =~ ^[[:space:]]*# ]]; then
                # Vérifier si c'est une commande personnalisée (format: NOM|COMMANDE)
                if [[ "$package" == *"|"* ]]; then
                    local package_name=$(echo "$package" | cut -d'|' -f1)
                    local custom_cmd=$(echo "$package" | cut -d'|' -f2-)
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
            fi
        done
        log_success "Tous les paquets de $MODULE_NAME ont été installés"
    else
        log "Aucun paquet à installer pour $MODULE_NAME"
    fi
    
    # Nettoyer les variables du module
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
    echo "=== SÉLECTION DES MODULES À EXÉCUTER ==="
    echo "Modules disponibles:"
    
    for i in "${!modules[@]}"; do
        local module_file="${modules[$i]}"
        local module_name=$(basename "$module_file" .conf)
        echo "$((i+1)). $module_name"
    done
    
    echo ""
    echo "Entrez les numéros des modules à exécuter (séparés par des espaces) ou 'all' pour tous:"
    read -r user_input
    
    if [[ "$user_input" == "all" ]]; then
        selected_modules=("${modules[@]}")
    else
        for num in $user_input; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#modules[@]} ]]; then
                selected_modules+=("${modules[$((num-1))]}")
            else
                log_error "Numéro invalide: $num"
                exit 1
            fi
        done
    fi
    
    if [[ ${#selected_modules[@]} -eq 0 ]]; then
        log_error "Aucun module sélectionné"
        exit 1
    fi
    
    echo "Modules sélectionnés: ${#selected_modules[@]}"
    for module_file in "${selected_modules[@]}"; do
        echo "  - $(basename "$module_file" .conf)"
    done
    
    echo ""
    echo "Confirmer l'exécution de ces modules? (o/n)"
    read -r confirm
    
    if [[ "$confirm" != "o" && "$confirm" != "O" ]]; then
        log "Opération annulée par l'utilisateur"
        exit 0
    fi
    
    # Retourner les modules sélectionnés
    printf '%s\n' "${selected_modules[@]}"
}

# Fonction principale
main() {
    log "=== DÉBUT DE L'INSTALLATION MODULAIRE FEDORA 44 ==="
    
    # Vérification des droits
    check_sudo
    
    # Mettre à jour le système
    log "Mise à jour du système"
    if ! dnf update -y 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Échec de la mise à jour du système"
        exit 1
    fi
    log_success "Système mis à jour avec succès"
    
    # Vérifier que le dossier des modules existe
    if [[ ! -d "$MODULES_DIR" ]]; then
        log_error "Dossier des modules introuvable: $MODULES_DIR"
        exit 1
    fi
    
    # Sélection interactive des modules
    local selected_modules
    readarray -t selected_modules < <(select_modules)
    
    # Exécuter les modules sélectionnés
    for module_file in "${selected_modules[@]}"; do
        if ! execute_module "$module_file"; then
            log_error "Échec de l'exécution du module: $(basename "$module_file")"
            exit 1
        fi
    done
    
    log_success "=== INSTALLATION TERMINÉE AVEC SUCCÈS ==="
}

# Exécuter la fonction principale
main "$@"
