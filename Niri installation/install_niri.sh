#!/usr/bin/env bash
#
# install-niri-noctalia-fedora44.sh
#
# Installation de niri + Noctalia Shell v5 sur Fedora Everything 44
# - RPM Fusion (free + nonfree)
# - Dépôt Terra
# - COPR lionheartp/Hyprland (nécessaire pour noctalia-git v5)
# - Paquets essentiels pour une utilisation "desktop normale"
#   (audio, bluetooth, portails XDG, polices, Xwayland, capture d'écran...)
# - SDDM comme gestionnaire de connexion
# - kitty comme terminal par défaut de niri
#
# Cible : Fedora Everything 44, GPU Intel
#
# Usage:
#   ./install-niri-noctalia-fedora44.sh            # exécution normale
#   ./install-niri-noctalia-fedora44.sh --dry-run   # affiche les commandes sans les exécuter
#   ./install-niri-noctalia-fedora44.sh --skip-upgrade  # saute le dnf upgrade complet

set -euo pipefail

# ────────────────────────────────────────────────────────────────
# Configuration / couleurs
# ────────────────────────────────────────────────────────────────

readonly C_RESET='\033[0m'
readonly C_BLUE='\033[0;34m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_RED='\033[0;31m'
readonly C_BOLD='\033[1m'

DRY_RUN=0
SKIP_UPGRADE=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --skip-upgrade) SKIP_UPGRADE=1 ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--skip-upgrade]"
            exit 0
            ;;
        *)
            echo "Argument inconnu : $arg" >&2
            exit 1
            ;;
    esac
done

log_info()    { printf "${C_BLUE}[INFO]${C_RESET}  %s\n" "$1"; }
log_ok()      { printf "${C_GREEN}[ OK ]${C_RESET}  %s\n" "$1"; }
log_warn()    { printf "${C_YELLOW}[WARN]${C_RESET}  %s\n" "$1"; }
log_error()   { printf "${C_RED}[ERR ]${C_RESET}  %s\n" "$1"; }
log_step()    { printf "\n${C_BOLD}==> %s${C_RESET}\n" "$1"; }

# Exécute une commande, ou l'affiche seulement en mode dry-run
run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf "  ${C_YELLOW}[DRY-RUN]${C_RESET} %s\n" "$*"
    else
        eval "$@"
    fi
}

# ────────────────────────────────────────────────────────────────
# Vérifications préalables
# ────────────────────────────────────────────────────────────────

check_not_root() {
    if [[ "$EUID" -eq 0 ]]; then
        log_error "Ne pas exécuter ce script en root. Lance-le en tant qu'utilisateur normal (sudo sera demandé au besoin)."
        exit 1
    fi
}

check_fedora_version() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "/etc/os-release introuvable, impossible de vérifier la distribution."
        exit 1
    fi
    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "${ID:-}" != "fedora" ]]; then
        log_error "Ce script est conçu pour Fedora uniquement (détecté: ${ID:-inconnu})."
        exit 1
    fi
    if [[ "${VERSION_ID:-}" != "44" ]]; then
        log_warn "Ce script est prévu pour Fedora 44 (détecté: ${VERSION_ID:-inconnu}). On continue quand même."
    else
        log_ok "Fedora 44 détecté."
    fi
}

check_sudo() {
    log_info "Vérification des privilèges sudo (mot de passe demandé si nécessaire)..."
    if [[ "$DRY_RUN" -eq 0 ]]; then
        sudo -v
    fi
}

# ────────────────────────────────────────────────────────────────
# Dépôts
# ────────────────────────────────────────────────────────────────

enable_rpmfusion() {
    log_step "Activation de RPM Fusion (free + nonfree)"
    if rpm -q rpmfusion-free-release &>/dev/null && rpm -q rpmfusion-nonfree-release &>/dev/null; then
        log_ok "RPM Fusion déjà activé, on passe."
        return
    fi
    run "sudo dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-\$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-\$(rpm -E %fedora).noarch.rpm"
    log_ok "RPM Fusion activé."
}

enable_terra() {
    log_step "Activation du dépôt Terra"
    if rpm -q terra-release &>/dev/null; then
        log_ok "Terra déjà activé, on passe."
        return
    fi
    run "sudo dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra\$releasever' terra-release"
    log_ok "Terra activé."
    log_warn "Note: Terra héberge noctalia-shell (v4/Quickshell), pas la v5. La v5 sera installée via le COPR lionheartp/Hyprland plus bas."
}

enable_noctalia_copr() {
    log_step "Activation du COPR lionheartp/Hyprland (héberge noctalia-git v5)"
    if dnf copr list 2>/dev/null | grep -qi "lionheartp/Hyprland"; then
        log_ok "COPR lionheartp/Hyprland déjà activé, on passe."
        return
    fi
    run "sudo dnf copr enable -y lionheartp/Hyprland"
    log_ok "COPR lionheartp/Hyprland activé."
}

# ────────────────────────────────────────────────────────────────
# Mise à jour système
# ────────────────────────────────────────────────────────────────

system_upgrade() {
    if [[ "$SKIP_UPGRADE" -eq 1 ]]; then
        log_warn "Mise à jour système sautée (--skip-upgrade)."
        return
    fi
    log_step "Mise à jour complète du système"
    run "sudo dnf upgrade --refresh -y"
    log_ok "Système à jour."
}

# ────────────────────────────────────────────────────────────────
# Paquets essentiels pour une utilisation desktop normale
# ────────────────────────────────────────────────────────────────

install_pkgs() {
    local desc="$1"
    shift
    local pkgs=("$@")
    local missing=()

    for p in "${pkgs[@]}"; do
        if ! rpm -q "$p" &>/dev/null; then
            missing+=("$p")
        fi
    done

    if [[ "${#missing[@]}" -eq 0 ]]; then
        log_ok "$desc : déjà tout installé."
        return
    fi

    log_info "$desc : installation de ${missing[*]}"
    run "sudo dnf install -y ${missing[*]}"
}

install_core_base() {
    log_step "Paquets de base (firmware, réseau)"
    install_pkgs "Base système" \
        linux-firmware \
        NetworkManager \
        NetworkManager-wifi \
        xdg-user-dirs
}

install_graphics_intel() {
    log_step "Pilotes graphiques Intel"
    install_pkgs "Pilotes Intel" \
        mesa-dri-drivers \
        mesa-vulkan-drivers \
        intel-media-driver \
        libva-utils
}

install_audio() {
    log_step "Audio (PipeWire)"
    install_pkgs "Audio" \
        pipewire \
        pipewire-alsa \
        pipewire-pulseaudio \
        pipewire-jack-audio-connection-kit \
        wireplumber
}

install_bluetooth() {
    log_step "Bluetooth"
    install_pkgs "Bluetooth" \
        bluez \
        bluez-tools
    log_info "Activation du service bluetooth..."
    run "sudo systemctl enable --now bluetooth.service"
}

install_niri_stack() {
    log_step "niri et son écosystème"
    install_pkgs "niri + dépendances" \
        niri \
        xwayland-satellite \
        xdg-desktop-portal \
        xdg-desktop-portal-gtk \
        xdg-desktop-portal-gnome \
        polkit \
        polkit-kde-agent-1 \
        wl-clipboard \
        grim \
        slurp \
        swappy
}

install_fonts() {
    log_step "Polices"
    install_pkgs "Polices" \
        jetbrains-mono-fonts-all \
        google-noto-fonts-all \
        google-noto-emoji-fonts
}

install_apps() {
    log_step "Applications de base"
    install_pkgs "Applications" \
        kitty \
        nautilus \
        loupe
}

install_sddm() {
    log_step "SDDM (gestionnaire de connexion)"
    install_pkgs "SDDM" sddm
    log_info "Activation de SDDM comme display manager..."
    run "sudo systemctl enable sddm.service"
}

install_noctalia() {
    log_step "Noctalia Shell v5"
    if rpm -q noctalia-git &>/dev/null; then
        log_ok "noctalia-git déjà installé."
        return
    fi
    run "sudo dnf install -y noctalia-git"
    log_ok "Noctalia v5 installé."
}

# ────────────────────────────────────────────────────────────────
# Configuration niri : kitty comme terminal par défaut
# ────────────────────────────────────────────────────────────────

configure_niri_default_terminal() {
    log_step "Configuration de niri (terminal par défaut = kitty)"

    local config_dir="$HOME/.config/niri"
    local config_file="$config_dir/config.kdl"
    local default_config="/etc/niri/config.kdl"

    if [[ ! -f "$config_file" ]]; then
        if [[ -f "$default_config" ]]; then
            log_info "Copie de la config niri par défaut vers $config_file"
            run "mkdir -p '$config_dir'"
            run "cp '$default_config' '$config_file'"
        else
            log_warn "Aucune config niri par défaut trouvée, section ignorée."
            return
        fi
    fi

    if grep -q 'spawn-at-startup "alacritty"' "$config_file" 2>/dev/null; then
        log_info "Remplacement d'alacritty par kitty dans $config_file"
        run "sed -i 's/spawn-at-startup \"alacritty\"/spawn-at-startup \"kitty\"/' '$config_file'"
    fi

    if grep -qE 'bind Mod\+T.*alacritty' "$config_file" 2>/dev/null; then
        log_info "Remplacement du raccourci Super+T (alacritty -> kitty)"
        run "sed -i 's/alacritty/kitty/g' '$config_file'"
    fi

    log_ok "Configuration niri mise à jour (vérifie $config_file au besoin)."
}

# ────────────────────────────────────────────────────────────────
# Résumé
# ────────────────────────────────────────────────────────────────

print_summary() {
    log_step "Résumé"
    cat <<EOF

  Dépôts activés   : RPM Fusion (free/nonfree), Terra, COPR lionheartp/Hyprland
  Compositeur      : niri (dépôt officiel Fedora 44)
  Shell            : Noctalia v5 (noctalia-git, via COPR lionheartp/Hyprland)
  Terminal         : kitty (Super+T)
  Display manager  : SDDM (activé, pas encore démarré)
  GPU              : pilotes Intel (mesa + intel-media-driver)

  Prochaines étapes suggérées :
    1. Redémarrer la machine.
    2. Sur l'écran SDDM, sélectionner la session "niri".
    3. Lancer Noctalia manuellement une première fois pour générer sa config :
         noctalia --daemon
       (ou l'ajouter dans ~/.config/niri/config.kdl via spawn-at-startup)
    4. Configurer Noctalia via son application Settings.

  Note : le dépôt Terra est activé mais n'est pas utilisé pour Noctalia v5
  (il ne fournit que la v4/Quickshell). Il reste disponible pour d'autres
  paquets si tu en as besoin plus tard.

EOF
}

# ────────────────────────────────────────────────────────────────
# Exécution principale
# ────────────────────────────────────────────────────────────────

main() {
    log_step "Installation niri + Noctalia v5 — Fedora Everything 44"
    [[ "$DRY_RUN" -eq 1 ]] && log_warn "Mode DRY-RUN activé : aucune commande ne sera exécutée."

    check_not_root
    check_fedora_version
    check_sudo

    enable_rpmfusion
    enable_terra
    enable_noctalia_copr

    system_upgrade

    install_core_base
    install_graphics_intel
    install_audio
    install_bluetooth
    install_niri_stack
    install_fonts
    install_apps
    install_sddm
    install_noctalia

    configure_niri_default_terminal

    print_summary

    log_ok "Terminé."
}

main "$@"