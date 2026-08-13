#!/usr/bin/env bash

set -euo pipefail

# Couleurs
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[34m"
RESET="\e[0m"

# Options
DRY_RUN=false
SHOW_HELP=false
SHOW_LIST=false

# ─── Vérification anticipée de SUDO_USER (avant tout usage) ──────────────────
if [ -z "${SUDO_USER:-}" ]; then
    echo -e "${RED}SUDO_USER n'est pas défini. Veuillez exécuter avec sudo.${RESET}"
    exit 1
fi

# Récupération du home utilisateur réel (après vérification de SUDO_USER)
USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
if [ -z "$USER_HOME" ]; then
    echo -e "${RED}Impossible de déterminer le dossier personnel de $SUDO_USER.${RESET}"
    exit 1
fi

# Alias pour exécuter flatpak en tant qu'utilisateur réel (pas root) en mode --user
flatpak_user() {
    sudo -u "$SUDO_USER" flatpak --user "$@"
}

# ─── Liste des applications Flatpak à installer ───────────────────────────────
# Format : "app.id.flatpak:Description"
applications=(

    # Appstore pour Flatpak
    "io.github.kolunmi.Bazaar:Bazaar"
    #"org.dupot.easyflatpak:Easy Flatpak"

    # Logiciels pour gestion des flatpaks
    "io.github.flattool.Warehouse:Warehouse"
    "com.github.tchx84.Flatseal:Flatseal"
    "io.github.giantpinkrobots.flatsweep:Flatsweep"

    # Logiciels pour installation de logiciels windows et distrobox
    "com.usebottles.bottles:Bottles"
    "io.github.dvlv.boxbuddyrs:BoxBuddy"

    # Utilitaires pour service systemd
    "io.github.plrigaux.sysd-manager:Sysd Manager"

    # Utilitaire pour la gestion du son
    "com.github.wwmm.easyeffects:EasyEffects"

    # Utilitaire pour gestion des polices
    "io.github.getnf.embellish:Embellish"

    # Utilitaire pour git
    "com.github.Murmele.Gittyup:Gittyup"

    # Utilitaire de transfert de fichiers
    "org.localsend.localsend_app:LocalSend"

    # Utilitaire de monitoring et de gestion de système
    "io.missioncenter.MissionCenter:Mission Center"

    # Utilitaire de sauvegarde
    "org.gnome.World.PikaBackup:Pika Backup"

    # Utilitaire de communication
    "dev.vencord.Vesktop:Vesktop"
)

# ─── Fonctions utilitaires ────────────────────────────────────────────────────

show_help() {
    echo -e "${GREEN}=== Aide du script d'installation Flatpak ===${RESET}"
    echo ""
    echo "Ce script permet d'installer automatiquement des applications Flatpak."
    echo ""
    echo "UTILISATION:"
    echo "  sudo ./03\ -\ flatpak_install.sh [options]"
    echo ""
    echo "OPTIONS:"
    echo "  --help      Affiche cette aide"
    echo "  --dry-run   Simule les installations sans effectuer de modifications"
    echo "  --list      Affiche la liste des applications qui seraient installées"
    echo ""
    echo "APPLICATIONS INSTALLÉES:"
    for app_info in "${applications[@]}"; do
        local app_id="${app_info%%:*}"
        local app_desc="${app_info##*:}"
        echo "  - ${app_desc} (${app_id})"
    done
}

cleanup_on_exit() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}Installation interrompue (code: $exit_code).${RESET}"
    fi
}

# Confirmation interactive — ignorée si stdin n'est pas un terminal (ex: appelé depuis super_script.sh)
confirm_installation() {
    if [ "$DRY_RUN" = false ]; then
        if [ -t 0 ]; then
            echo -e "${YELLOW}Continuer avec l'installation des applications Flatpak ? (y/N)${RESET}"
            read -r -s -n 1 -p "> " response
            echo
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}Installation annulée.${RESET}"
                exit 0
            fi
        else
            echo -e "${YELLOW}[INFO] stdin non interactif — confirmation automatique.${RESET}"
        fi
    fi
}

# ─── Vérifications préliminaires ──────────────────────────────────────────────

ensure_flatpak_installed() {
    if command -v flatpak &> /dev/null; then
        echo -e "${GREEN}✓ Flatpak est installé : $(flatpak --version)${RESET}"
        return
    fi

    echo -e "${BLUE}Installation de Flatpak...${RESET}"
    if [ "$DRY_RUN" = false ]; then
        dnf install -y flatpak
        echo -e "${GREEN}✓ Flatpak installé : $(flatpak --version)${RESET}"
    else
        echo "DRY-RUN: dnf install -y flatpak"
    fi
}

# Vérifie et ajoute le remote Flathub pour l'utilisateur réel
setup_flathub_remote() {
    echo -e "${BLUE}Vérification du remote Flathub...${RESET}"
    if flatpak_user remotes --columns=name 2>/dev/null | grep -q "^flathub$"; then
        echo -e "${GREEN}✓ Remote Flathub déjà configuré pour $SUDO_USER${RESET}"
    else
        echo -e "${BLUE}➕ Ajout du remote Flathub pour $SUDO_USER...${RESET}"
        if [ "$DRY_RUN" = false ]; then
            flatpak_user remote-add --if-not-exists flathub \
                https://flathub.org/repo/flathub.flatpakrepo
            echo -e "${GREEN}✓ Remote Flathub ajouté${RESET}"
        else
            echo "DRY-RUN: flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
        fi
    fi
}

# ─── Affichage de la liste ────────────────────────────────────────────────────

show_applications_list() {
    echo -e "${GREEN}=== Applications Flatpak qui seront installées ===${RESET}"
    echo ""
    for app_info in "${applications[@]}"; do
        local app_id="${app_info%%:*}"
        local app_desc="${app_info##*:}"
        echo -e "${BLUE}•${RESET} $app_desc"
        echo -e "  ${YELLOW}ID:${RESET} $app_id"
        echo ""
    done
}

# ─── Installation avec retry ──────────────────────────────────────────────────

install_flatpak_with_retry() {
    local app="$1"
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if [ "$DRY_RUN" = false ]; then
            # Installation en tant qu'utilisateur réel (pas root)
            if flatpak_user install -y flathub "$app"; then
                return 0
            else
                attempt=$((attempt + 1))
                if [ $attempt -le $max_attempts ]; then
                    echo -e "${YELLOW}Nouvelle tentative dans 5 secondes... (tentative $attempt/$max_attempts)${RESET}"
                    sleep 5
                fi
            fi
        else
            echo "DRY-RUN: flatpak install -y flathub $app (en tant que $SUDO_USER)"
            return 0
        fi
    done

    return 1
}

# ─── Installation de toutes les applications ──────────────────────────────────

install_applications() {
    local total_apps=${#applications[@]}
    local current_app=0
    local failed_apps=()
    local success_count=0

    echo -e "${GREEN}=== Installation des applications Flatpak ===${RESET}"
    echo ""

    for app_info in "${applications[@]}"; do
        current_app=$((current_app + 1))
        local app_id="${app_info%%:*}"
        local app_desc="${app_info##*:}"

        echo -e "${BLUE}[$current_app/$total_apps] $app_desc${RESET} ($app_id)"

        # Vérifier si l'application est déjà installée (via l'utilisateur réel)
        # --columns=application donne uniquement l'App ID, sans ambiguïté
        if flatpak_user list --app --columns=application 2>/dev/null | grep -qx "$app_id"; then
            echo -e "${YELLOW}  ↳ Déjà installé, ignoré.${RESET}"
            success_count=$((success_count + 1))
        else
            if install_flatpak_with_retry "$app_id"; then
                echo -e "${GREEN}  ✓ Installé avec succès${RESET}"
                success_count=$((success_count + 1))
            else
                failed_apps+=("$app_id")
                echo -e "${RED}  ✗ Échec de l'installation${RESET}"
            fi
        fi
        echo ""
    done

    # ─── Rapport final ────────────────────────────────────────────────────────
    echo -e "${GREEN}=== Résumé ===${RESET}"
    echo -e "Applications réussies : $success_count / $total_apps"

    if [ ${#failed_apps[@]} -gt 0 ]; then
        echo -e "${RED}Applications non installées :${RESET}"
        for app in "${failed_apps[@]}"; do
            echo -e "  ${RED}✗ $app${RESET}"
        done
    fi

    if [ "$DRY_RUN" = false ]; then
        echo -e "${GREEN}✅ Installation terminée.${RESET}"
    else
        echo -e "${YELLOW}🔍 Mode simulation terminé.${RESET}"
    fi
}

# ─── Nettoyage final ──────────────────────────────────────────────────────────

cleanup() {
    if [ "$DRY_RUN" = false ]; then
        echo -e "${BLUE}🧹 Suppression des runtimes Flatpak inutilisés...${RESET}"
        # Nettoyage côté utilisateur réel
        if flatpak_user uninstall --unused -y 2>/dev/null; then
            echo -e "${GREEN}✓ Nettoyage terminé${RESET}"
        else
            echo -e "${YELLOW}⚠ Aucun paquet inutilisé à supprimer${RESET}"
        fi
    else
        echo "DRY-RUN: Nettoyage des runtimes inutilisés"
    fi
}

# ─── Gestion des arguments ────────────────────────────────────────────────────

for arg in "$@"; do
    case $arg in
        --help)
            show_help
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --list)
            SHOW_LIST=true
            ;;
        *)
            echo -e "${RED}Option inconnue: $arg${RESET}"
            echo "Utilisez --help pour voir les options disponibles."
            exit 1
            ;;
    esac
done

# ─── Vérification du mode superutilisateur ────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Veuillez exécuter ce script avec sudo.${RESET}"
    exit 1
fi

# ─── Gestion des signaux d'interruption ──────────────────────────────────────
trap 'cleanup_on_exit; exit 130' INT TERM
trap 'cleanup_on_exit' EXIT

# ─── Fonction principale ──────────────────────────────────────────────────────
main() {
    echo -e "${GREEN}=== Script d'installation des applications Flatpak ===${RESET}"
    echo -e "Utilisateur : $SUDO_USER (home: $USER_HOME)"
    echo -e "Date        : $(date)"
    echo -e "Mode dry-run: $DRY_RUN"
    echo ""

    # Afficher la liste si demandé
    if [ "$SHOW_LIST" = true ]; then
        show_applications_list
        exit 0
    fi

    # Vérifications préliminaires
    ensure_flatpak_installed
    setup_flathub_remote

    # Confirmation
    confirm_installation

    # Installation
    install_applications

    # Nettoyage
    cleanup
}

main
