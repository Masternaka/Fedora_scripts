#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

DRY_RUN=false
LOG_FILE="/var/log/installation_logiciels.log"
DNF_CACHE_REFRESHED=false

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; log_message "INFO" "$*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; log_message "OK" "$*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; log_message "WARN" "$*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; log_message "ERROR" "$*"; exit 1; }

log_message() {
    local level="$1"
    shift

    if [[ $EUID -eq 0 ]]; then
        printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

ARGS=()
for arg in "$@"; do
    case "$arg" in
        --dry-run|--simulation|-n)
            DRY_RUN=true
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done
set -- "${ARGS[@]}"

[[ $EUID -ne 0 ]] && error "Ce script doit être exécuté en root (sudo)."

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
else
    error "Impossible de lire /etc/os-release."
fi

[[ "${ID:-}" != "fedora" ]] && error "Ce script est prévu pour Fedora. Système détecté : ${PRETTY_NAME:-inconnu}"

if [[ "${VERSION_ID:-}" != "44" ]]; then
    warn "Fedora ${VERSION_ID:-inconnue} détecté. Le script est prévu pour Fedora 44, mais peut fonctionner sur une version proche."
fi

DNF_CMD="dnf"
command -v "$DNF_CMD" &>/dev/null || error "dnf est introuvable."

echo -e "\n${BOLD}=== Installation / désinstallation de logiciels - Fedora 44 ===${RESET}\n"

if [[ "$DRY_RUN" == true ]]; then
    warn "Mode simulation actif : aucune modification ne sera appliquée."
fi

# Adaptez ces listes selon vos besoins.
COPR_REPOS_ENABLE=(
    # Exemple :
    # atim/starship
)

DNF_PACKAGES_INSTALL=(
    curl
    wget
    git
    vim
    nano
    htop
    fastfetch
    unzip
    p7zip
    p7zip-plugins
    gnome-tweaks
)

# Ces paquets demandent généralement RPM Fusion.
RPMFUSION_DNF_PACKAGES_INSTALL=(
    vlc
    steam
)

DNF_PACKAGES_REMOVE=(
    gnome-tour
    rhythmbox
)

FLATPAK_APPS_INSTALL=(
    com.discordapp.Discord
    com.spotify.Client
    org.mozilla.Thunderbird
    org.gimp.GIMP
    org.videolan.VLC
)

FLATPAK_APPS_REMOVE=(
)

confirm() {
    local prompt="${1:-Continuer ?}"
    local response

    read -r -p "$(echo -e "${YELLOW}?${RESET} ${prompt} [o/N] ")" response
    [[ "$response" =~ ^[oOyY]$ ]]
}

pause() {
    echo
    read -r -p "Appuyez sur Entrée pour revenir au menu..."
}

run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        printf '[SIMULATION] '
        printf '%q ' "$@"
        printf '\n'
        log_message "DRY-RUN" "$*"
        return 0
    fi

    "$@"
}

refresh_dnf_cache_once() {
    if [[ "$DNF_CACHE_REFRESHED" == true ]]; then
        return
    fi

    info "Mise à jour des métadonnées DNF..."
    run_cmd "$DNF_CMD" makecache --refresh
    DNF_CACHE_REFRESHED=true
}

print_items() {
    local title="$1"
    shift
    local items=("$@")

    echo -e "\n${BOLD}${title}${RESET}"

    if ((${#items[@]} == 0)); then
        echo "  aucun"
        return
    fi

    local i
    for i in "${!items[@]}"; do
        printf '  %2d) %s\n' "$((i + 1))" "${items[$i]}"
    done
}

show_action_summary() {
    local title="$1"
    shift

    echo -e "\n${BOLD}${title}${RESET}"
    echo "Mode : $([[ "$DRY_RUN" == true ]] && echo "simulation" || echo "exécution réelle")"
    echo "Journal : $LOG_FILE"

    while (($# > 0)); do
        local section="$1"
        shift
        local count="$1"
        shift
        local items=("${@:1:count}")
        shift "$count"

        print_items "$section" "${items[@]}"
    done

    echo
}

warn_known_duplicates() {
    if [[ " ${RPMFUSION_DNF_PACKAGES_INSTALL[*]} " == *" vlc "* ]] &&
       [[ " ${FLATPAK_APPS_INSTALL[*]} " == *" org.videolan.VLC "* ]]; then
        warn "VLC est configuré à la fois en paquet DNF RPM Fusion et en Flatpak."
        warn "Vous pouvez garder les deux, mais cela installe deux versions différentes."
    fi
}

enable_copr_repos() {
    local repos=("$@")

    if ((${#repos[@]} == 0)); then
        warn "Aucun dépôt COPR à activer."
        return
    fi

    info "Installation du support COPR pour DNF..."
    run_cmd "$DNF_CMD" install -y dnf-plugins-core

    info "Activation des dépôts COPR..."
    printf '  - %s\n' "${repos[@]}"

    for repo in "${repos[@]}"; do
        run_cmd "$DNF_CMD" copr enable -y "$repo"
    done

    success "Dépôts COPR activés."
}

install_flatpak_support() {
    if ! command -v flatpak &>/dev/null; then
        info "Installation de Flatpak..."
        run_cmd "$DNF_CMD" install -y flatpak

        if [[ "$DRY_RUN" == true ]]; then
            info "Simulation : vérification Flathub ignorée tant que Flatpak n'est pas réellement installé."
            return
        fi
    fi

    if ! flatpak remotes --system --columns=name | grep -qx "flathub"; then
        info "Ajout du dépôt Flathub..."
        run_cmd flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
}

install_rpmfusion() {
    info "Vérification des dépôts RPM Fusion..."

    if "$DNF_CMD" repolist --enabled | grep -qE '^rpmfusion-free\b'; then
        success "RPM Fusion free est déjà activé."
    else
        info "Activation de RPM Fusion free..."
        run_cmd "$DNF_CMD" install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${VERSION_ID}.noarch.rpm"
    fi

    if "$DNF_CMD" repolist --enabled | grep -qE '^rpmfusion-nonfree\b'; then
        success "RPM Fusion nonfree est déjà activé."
    else
        info "Activation de RPM Fusion nonfree..."
        run_cmd "$DNF_CMD" install -y \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${VERSION_ID}.noarch.rpm"
    fi
}

install_dnf_packages() {
    local packages=("$@")

    if ((${#packages[@]} == 0)); then
        warn "Aucun paquet DNF à installer."
        return
    fi

    refresh_dnf_cache_once

    info "Installation des paquets DNF..."
    printf '  - %s\n' "${packages[@]}"
    run_cmd "$DNF_CMD" install -y "${packages[@]}"
    success "Installation DNF terminée."
}

remove_dnf_packages() {
    local packages=("$@")

    if ((${#packages[@]} == 0)); then
        warn "Aucun paquet DNF à désinstaller."
        return
    fi

    info "Désinstallation des paquets DNF..."
    printf '  - %s\n' "${packages[@]}"
    run_cmd "$DNF_CMD" remove -y "${packages[@]}"
    success "Désinstallation DNF terminée."
}

install_flatpak_apps() {
    local apps=("$@")

    if ((${#apps[@]} == 0)); then
        warn "Aucune application Flatpak à installer."
        return
    fi

    install_flatpak_support

    info "Installation des applications Flatpak..."
    printf '  - %s\n' "${apps[@]}"
    run_cmd flatpak install --system -y flathub "${apps[@]}"
    success "Installation Flatpak terminée."
}

remove_flatpak_apps() {
    local apps=("$@")

    if ((${#apps[@]} == 0)); then
        warn "Aucune application Flatpak à désinstaller."
        return
    fi

    if ! command -v flatpak &>/dev/null; then
        warn "Flatpak n'est pas installé."
        return
    fi

    info "Désinstallation des applications Flatpak..."
    printf '  - %s\n' "${apps[@]}"
    run_cmd flatpak uninstall --system -y "${apps[@]}"
    success "Désinstallation Flatpak terminée."
}

cleanup_system() {
    info "Nettoyage des paquets inutiles..."
    run_cmd "$DNF_CMD" autoremove -y

    if command -v flatpak &>/dev/null; then
        info "Nettoyage des runtimes Flatpak inutilisés..."
        run_cmd flatpak uninstall --system --unused -y || true
    fi

    success "Nettoyage terminé."
}

install_all() {
    warn_known_duplicates
    show_action_summary \
        "Résumé de l'installation complète" \
        "Dépôts COPR configurés" "${#COPR_REPOS_ENABLE[@]}" "${COPR_REPOS_ENABLE[@]}" \
        "Paquets DNF configurés" "${#DNF_PACKAGES_INSTALL[@]}" "${DNF_PACKAGES_INSTALL[@]}" \
        "Paquets DNF RPM Fusion configurés" "${#RPMFUSION_DNF_PACKAGES_INSTALL[@]}" "${RPMFUSION_DNF_PACKAGES_INSTALL[@]}" \
        "Applications Flatpak configurées" "${#FLATPAK_APPS_INSTALL[@]}" "${FLATPAK_APPS_INSTALL[@]}"

    if ! confirm "Continuer avec cette installation complète ?"; then
        warn "Installation annulée."
        return
    fi

    if confirm "Activer les dépôts COPR configurés ?"; then
        enable_copr_repos "${COPR_REPOS_ENABLE[@]}"
    fi

    if confirm "Activer RPM Fusion ? Recommandé pour VLC, Steam et certains codecs."; then
        install_rpmfusion
        install_dnf_packages "${DNF_PACKAGES_INSTALL[@]}" "${RPMFUSION_DNF_PACKAGES_INSTALL[@]}"
    else
        install_dnf_packages "${DNF_PACKAGES_INSTALL[@]}"
    fi

    if confirm "Installer aussi les applications Flatpak configurées ?"; then
        install_flatpak_apps "${FLATPAK_APPS_INSTALL[@]}"
    fi
}

remove_all() {
    show_action_summary \
        "Résumé de la désinstallation complète" \
        "Paquets DNF à désinstaller" "${#DNF_PACKAGES_REMOVE[@]}" "${DNF_PACKAGES_REMOVE[@]}" \
        "Applications Flatpak à désinstaller" "${#FLATPAK_APPS_REMOVE[@]}" "${FLATPAK_APPS_REMOVE[@]}"

    if confirm "Confirmer la désinstallation ?"; then
        remove_dnf_packages "${DNF_PACKAGES_REMOVE[@]}"
        remove_flatpak_apps "${FLATPAK_APPS_REMOVE[@]}"
        cleanup_system
    else
        warn "Désinstallation annulée."
    fi
}

show_lists() {
    print_items "Dépôts COPR à activer" "${COPR_REPOS_ENABLE[@]}"
    print_items "Paquets DNF à installer" "${DNF_PACKAGES_INSTALL[@]}"
    print_items "Paquets DNF à installer avec RPM Fusion" "${RPMFUSION_DNF_PACKAGES_INSTALL[@]}"
    print_items "Paquets DNF à désinstaller" "${DNF_PACKAGES_REMOVE[@]}"
    print_items "Applications Flatpak à installer" "${FLATPAK_APPS_INSTALL[@]}"
    print_items "Applications Flatpak à désinstaller" "${FLATPAK_APPS_REMOVE[@]}"
    echo
}

main_menu() {
    while true; do
        clear 2>/dev/null || true
        echo -e "${BOLD}=== Installation / désinstallation de logiciels - Fedora 44 ===${RESET}"
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${YELLOW}Mode simulation : aucune modification ne sera appliquée.${RESET}"
            echo
        fi
        echo "1) Installer tous les logiciels configurés"
        echo "2) Installer les paquets DNF configurés"
        echo "3) Activer RPM Fusion"
        echo "4) Installer les paquets DNF RPM Fusion configurés"
        echo "5) Activer les dépôts COPR configurés"
        echo "6) Installer les applications Flatpak configurées"
        echo "7) Désinstaller tous les logiciels configurés"
        echo "8) Désinstaller les paquets DNF configurés"
        echo "9) Désinstaller les applications Flatpak configurées"
        echo "10) Afficher les listes configurées"
        echo "11) Nettoyer le système"
        echo "12) Quitter"
        echo
        read -r -p "Choix : " choice

        case "$choice" in
            1) install_all; pause ;;
            2)
                show_action_summary "Résumé - installation DNF" \
                    "Paquets DNF configurés" "${#DNF_PACKAGES_INSTALL[@]}" "${DNF_PACKAGES_INSTALL[@]}"
                if confirm "Installer ces paquets DNF ?"; then
                    install_dnf_packages "${DNF_PACKAGES_INSTALL[@]}"
                else
                    warn "Installation DNF annulée."
                fi
                pause
                ;;
            3) install_rpmfusion; pause ;;
            4)
                install_rpmfusion
                show_action_summary "Résumé - installation DNF RPM Fusion" \
                    "Paquets DNF RPM Fusion configurés" "${#RPMFUSION_DNF_PACKAGES_INSTALL[@]}" "${RPMFUSION_DNF_PACKAGES_INSTALL[@]}"
                if confirm "Installer ces paquets RPM Fusion ?"; then
                    install_dnf_packages "${RPMFUSION_DNF_PACKAGES_INSTALL[@]}"
                else
                    warn "Installation RPM Fusion annulée."
                fi
                pause
                ;;
            5)
                show_action_summary "Résumé - activation COPR" \
                    "Dépôts COPR configurés" "${#COPR_REPOS_ENABLE[@]}" "${COPR_REPOS_ENABLE[@]}"
                if confirm "Activer ces dépôts COPR ?"; then
                    enable_copr_repos "${COPR_REPOS_ENABLE[@]}"
                else
                    warn "Activation COPR annulée."
                fi
                pause
                ;;
            6)
                show_action_summary "Résumé - installation Flatpak" \
                    "Applications Flatpak configurées" "${#FLATPAK_APPS_INSTALL[@]}" "${FLATPAK_APPS_INSTALL[@]}"
                if confirm "Installer ces applications Flatpak ?"; then
                    install_flatpak_apps "${FLATPAK_APPS_INSTALL[@]}"
                else
                    warn "Installation Flatpak annulée."
                fi
                pause
                ;;
            7) remove_all; pause ;;
            8)
                show_action_summary "Résumé - désinstallation DNF" \
                    "Paquets DNF à désinstaller" "${#DNF_PACKAGES_REMOVE[@]}" "${DNF_PACKAGES_REMOVE[@]}"
                if confirm "Confirmer la désinstallation des paquets DNF configurés ?"; then
                    remove_dnf_packages "${DNF_PACKAGES_REMOVE[@]}"
                else
                    warn "Désinstallation DNF annulée."
                fi
                pause
                ;;
            9)
                show_action_summary "Résumé - désinstallation Flatpak" \
                    "Applications Flatpak à désinstaller" "${#FLATPAK_APPS_REMOVE[@]}" "${FLATPAK_APPS_REMOVE[@]}"
                if confirm "Confirmer la désinstallation des applications Flatpak configurées ?"; then
                    remove_flatpak_apps "${FLATPAK_APPS_REMOVE[@]}"
                else
                    warn "Désinstallation Flatpak annulée."
                fi
                pause
                ;;
            10) show_lists; pause ;;
            11) cleanup_system; pause ;;
            12) exit 0 ;;
            *) warn "Choix invalide."; pause ;;
        esac
    done
}

case "${1:-}" in
    install) install_all ;;
    remove|uninstall|desinstaller|désinstaller) remove_all ;;
    list|liste) show_lists ;;
    clean|nettoyer) cleanup_system ;;
    ""|menu) main_menu ;;
    *)
        cat <<EOF
Usage:
  sudo $0                 Affiche le menu
  sudo $0 --dry-run       Affiche le menu en mode simulation
  sudo $0 install         Installe les logiciels configurés
  sudo $0 --dry-run install
  sudo $0 install --dry-run
  sudo $0 remove          Désinstalle les logiciels configurés
  sudo $0 list            Affiche les listes
  sudo $0 clean           Nettoie les paquets/runtimes inutilisés

Options:
  --dry-run, --simulation, -n
                         N'exécute aucune modification, affiche seulement les commandes.

Modifiez les tableaux au début du script pour changer les logiciels.
EOF
        exit 1
        ;;
esac

echo -e "\n${BOLD}=== Opération terminée ===${RESET}"
