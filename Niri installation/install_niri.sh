#!/usr/bin/env bash
# =============================================================================
#  install-niri-noctalia.sh
#  Installation automatisée : Fedora 44 Minimal → niri + Noctalia Shell
# =============================================================================
#  Usage : bash install-niri-noctalia.sh [--headless] [--no-flatpak] [--help]
#
#  Options :
#    --headless     Mode non-interactif (utilise les choix par défaut)
#    --no-flatpak   Ignore l'installation de Flatpak / Flathub
#    --no-bluetooth Ignore la configuration Bluetooth
#    --help         Affiche cette aide
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Flags et options
# ---------------------------------------------------------------------------
HEADLESS=false
SKIP_FLATPAK=false
SKIP_BLUETOOTH=false

for arg in "$@"; do
  case "$arg" in
    --headless)      HEADLESS=true ;;
    --no-flatpak)    SKIP_FLATPAK=true ;;
    --no-bluetooth)  SKIP_BLUETOOTH=true ;;
    --help)
      sed -n '/^# Usage/,/^# ====/p' "$0"
      exit 0
      ;;
    *) echo "Option inconnue : $arg — utilisez --help" >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Couleurs et helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
  echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${CYAN}  $1${NC}"
  echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════${NC}\n"
}

step() {
  echo -e "${BOLD}${GREEN}▶ $1${NC}"
}

info() {
  echo -e "${CYAN}  ℹ  $1${NC}"
}

warn() {
  echo -e "${YELLOW}  ⚠  $1${NC}"
}

die() {
  echo -e "${RED}  ✖  ERREUR : $1${NC}" >&2
  exit 1
}

ok() {
  echo -e "${GREEN}  ✔  $1${NC}"
}

ask_yn() {
  # ask_yn "Question ?" [default_y|default_n]
  local prompt="$1"
  local default="${2:-default_y}"
  if $HEADLESS; then
    [[ "$default" == "default_y" ]] && return 0 || return 1
  fi
  local yn_hint
  [[ "$default" == "default_y" ]] && yn_hint="[O/n]" || yn_hint="[o/N]"
  read -rp "$(echo -e "${YELLOW}  ?  ${prompt} ${yn_hint} : ${NC}")" ans
  ans="${ans,,}"
  case "$ans" in
    o|oui|y|yes) return 0 ;;
    n|non|no)    return 1 ;;
    *)
      [[ "$default" == "default_y" ]] && return 0 || return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Vérifications préalables
# ---------------------------------------------------------------------------
preflight_check() {
  banner "Vérifications préalables"

  # Fedora ?
  if ! grep -qi 'fedora' /etc/os-release 2>/dev/null; then
    die "Ce script est conçu pour Fedora. Distribution non reconnue."
  fi

  # Fedora 44 ?
  local ver
  ver=$(rpm -E '%fedora')
  if [[ "$ver" -lt 44 ]]; then
    warn "Ce script cible Fedora 44. Version détectée : $ver — continuez à vos risques."
    ask_yn "Continuer quand même ?" default_n || exit 0
  fi
  ok "Fedora $ver détecté."

  # Root ?
  [[ $EUID -ne 0 ]] && die "Ce script doit être exécuté en tant que root (ou avec sudo)."

  # Connexion internet
  if ! curl -s --max-time 5 https://fedoraproject.org > /dev/null; then
    die "Pas de connexion internet détectée. Branchez un câble Ethernet ou configurez le Wi-Fi d'abord."
  fi
  ok "Connexion internet : OK"

  # Conserver l'utilisateur courant (sudo) pour les configs ~
  if [[ -n "${SUDO_USER:-}" ]]; then
    TARGET_USER="$SUDO_USER"
  else
    # Script lancé directement en root — demander le nom d'utilisateur
    if $HEADLESS; then
      TARGET_USER="$(getent passwd 1000 | cut -d: -f1)" || die "Impossible de détecter l'utilisateur normal."
    else
      read -rp "$(echo -e "${YELLOW}  ?  Nom de l'utilisateur principal (sans root) : ${NC}")" TARGET_USER
    fi
  fi
  TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
  [[ -d "$TARGET_HOME" ]] || die "Répertoire home introuvable pour $TARGET_USER"
  ok "Utilisateur cible : ${BOLD}$TARGET_USER${NC} (home : $TARGET_HOME)"
}

# ---------------------------------------------------------------------------
# 1. Optimisation DNF
# ---------------------------------------------------------------------------
configure_dnf() {
  banner "1. Optimisation de DNF"

  step "Configuration de /etc/dnf/dnf.conf"
  if ! grep -q 'max_parallel_downloads' /etc/dnf/dnf.conf; then
    cat >> /etc/dnf/dnf.conf <<'EOF'
max_parallel_downloads=10
defaultyes=True
fastestmirror=True
EOF
    ok "Paramètres DNF ajoutés."
  else
    info "DNF déjà configuré — aucune modification."
  fi
}

# ---------------------------------------------------------------------------
# 2. Dépôts supplémentaires
# ---------------------------------------------------------------------------
setup_repos() {
  banner "2. Activation des dépôts"

  # RPM Fusion
  step "RPM Fusion Free + Non-Free"
  dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" \
    2>/dev/null || true
  ok "RPM Fusion configuré."

  # Terra (pour noctalia-shell)
  step "Terra (Fyra Labs) — requis pour noctalia-shell"
  if ! dnf repolist 2>/dev/null | grep -q 'terra'; then
    dnf install -y --nogpgcheck \
      --repofrompath "terra,https://repos.fyralabs.com/terra\$(rpm -E %fedora)" \
      terra-release 2>/dev/null || \
    dnf install -y --nogpgcheck \
      "https://repos.fyralabs.com/terra$(rpm -E %fedora)/terra-release-$(rpm -E %fedora).noarch.rpm"
    ok "Dépôt Terra ajouté."
  else
    info "Dépôt Terra déjà présent."
  fi

  # Mise à jour du système
  step "Mise à jour complète du système"
  dnf upgrade --refresh -y
  ok "Système à jour."
}

# ---------------------------------------------------------------------------
# 3. Paquets de base indispensables
# ---------------------------------------------------------------------------
install_base() {
  banner "3. Paquets de base"

  step "Installation des utilitaires système essentiels"
  dnf install -y \
    bash-completion \
    curl wget \
    git \
    htop \
    linux-firmware \
    pciutils usbutils \
    which \
    xdg-user-dirs \
    unzip tar \
    polkit \
    dbus-daemon \
    gnome-keyring libsecret

  # Dossiers XDG (Documents, Images, Téléchargements, etc.)
  step "Création des dossiers XDG pour $TARGET_USER"
  sudo -u "$TARGET_USER" xdg-user-dirs-update
  ok "Paquets de base installés."
}

# ---------------------------------------------------------------------------
# 4. Réseau
# ---------------------------------------------------------------------------
install_network() {
  banner "4. Réseau et connectivité"

  step "NetworkManager + Wi-Fi"
  dnf install -y \
    NetworkManager \
    NetworkManager-wifi \
    NetworkManager-tui \
    network-manager-applet

  systemctl enable --now NetworkManager
  ok "NetworkManager activé."
}

# ---------------------------------------------------------------------------
# 5. Audio (PipeWire)
# ---------------------------------------------------------------------------
install_audio() {
  banner "5. Audio — PipeWire"

  step "PipeWire + WirePlumber + PulseAudio compat"
  dnf install -y \
    pipewire \
    pipewire-alsa \
    pipewire-pulseaudio \
    wireplumber \
    alsa-sof-firmware \
    pavucontrol

  # Activer pour l'utilisateur cible
  step "Activation des services audio pour $TARGET_USER"
  sudo -u "$TARGET_USER" systemctl --user enable --now \
    pipewire pipewire-pulse wireplumber 2>/dev/null || true
  ok "PipeWire configuré."
}

# ---------------------------------------------------------------------------
# 6. Bluetooth (optionnel)
# ---------------------------------------------------------------------------
install_bluetooth() {
  banner "6. Bluetooth"

  step "Paquets Bluetooth"
  dnf install -y \
    bluez \
    bluez-tools \
    blueman

  systemctl enable --now bluetooth
  ok "Bluetooth configuré."
}

# ---------------------------------------------------------------------------
# 7. Niri — Compositeur Wayland
# ---------------------------------------------------------------------------
install_niri() {
  banner "7. Niri — Scrollable-tiling Wayland Compositor"

  step "Installation de niri et xwayland-satellite"
  # niri est dans les dépôts officiels Fedora depuis F40
  dnf install -y \
    niri \
    xwayland-satellite

  # Portails XDG (nécessaires pour partage d'écran, screenshots, sélecteur de fichiers, etc.)
  step "XDG Desktop Portals"
  dnf install -y \
    xdg-desktop-portal \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-wlr \
    xdg-utils

  # Configurer le portail pour niri
  step "Configuration du portail XDG pour niri"
  local portal_dir="$TARGET_HOME/.config/xdg-desktop-portal"
  sudo -u "$TARGET_USER" mkdir -p "$portal_dir"
  sudo -u "$TARGET_USER" tee "$portal_dir/portals.conf" > /dev/null <<'EOF'
[preferred]
default=gnome;gtk
org.freedesktop.impl.portal.Screenshot=wlr
org.freedesktop.impl.portal.ScreenCast=wlr
EOF

  ok "niri installé ($(niri --version 2>/dev/null || echo 'version inconnue'))."
}

# ---------------------------------------------------------------------------
# 8. Noctalia Shell — via Terra
# ---------------------------------------------------------------------------
install_noctalia() {
  banner "8. Noctalia Shell"

  step "Installation de noctalia-shell depuis Terra"
  # Installe automatiquement noctalia-qs (fork Quickshell) comme dépendance
  # Note : si quickshell est déjà installé, il faut le retirer d'abord
  if rpm -q quickshell &>/dev/null; then
    warn "Paquet 'quickshell' détecté — en conflit avec noctalia-qs. Suppression..."
    dnf remove -y quickshell
  fi

  dnf install -y noctalia-shell
  ok "noctalia-shell installé."

  # Dépendances optionnelles recommandées par noctalia
  step "Dépendances optionnelles de noctalia"
  dnf install -y \
    grim \
    slurp \
    wl-clipboard \
    cliphist \
    playerctl \
    brightnessctl \
    swaylock \
    swayidle \
    upower \
    libnotify
  ok "Dépendances noctalia installées."
}

# ---------------------------------------------------------------------------
# 9. Applications essentielles
# ---------------------------------------------------------------------------
install_apps() {
  banner "9. Applications essentielles"

  step "Terminal, lanceur d'applications, gestionnaire de fichiers"
  dnf install -y \
    kitty \
    fuzzel \
    nautilus \
    gvfs gvfs-mtp \
    file-roller

  step "Outils système Wayland"
  dnf install -y \
    wlr-randr \
    kanshi \
    mako \
    gammastep

  step "Utilitaires modernes (Rust-based)"
  dnf install -y \
    eza \
    bat \
    ripgrep \
    fd-find \
    fzf \
    zoxide \
    starship

  step "Polices de caractères"
  dnf install -y \
    jetbrains-mono-fonts-all \
    google-noto-fonts-all \
    google-noto-emoji-fonts \
    fontawesome-fonts \
    fontawesome-fonts-web

  # Installler JetBrainsMono Nerd Font si pas déjà présent
  local nf_dir="$TARGET_HOME/.local/share/fonts/NerdFonts"
  if [[ ! -d "$nf_dir" ]]; then
    step "Téléchargement de JetBrainsMono Nerd Font"
    sudo -u "$TARGET_USER" mkdir -p "$nf_dir"
    local tmp_nf
    tmp_nf=$(mktemp -d)
    curl -fLo "$tmp_nf/JetBrainsMono.zip" \
      "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" \
      && unzip -q "$tmp_nf/JetBrainsMono.zip" -d "$nf_dir" \
      && fc-cache -f "$TARGET_HOME/.local/share/fonts" \
      && ok "JetBrainsMono Nerd Font installée."
    rm -rf "$tmp_nf"
  else
    info "JetBrainsMono Nerd Font déjà présente."
  fi

  ok "Applications essentielles installées."
}

# ---------------------------------------------------------------------------
# 10. Gestionnaire de session / Greeter
# ---------------------------------------------------------------------------
install_greeter() {
  banner "10. Gestionnaire de session (Display Manager)"

  local dm_choice="greetd"

  if ! $HEADLESS; then
    echo -e "${CYAN}  Choisissez un gestionnaire de connexion :${NC}"
    echo -e "    ${BOLD}1)${NC} greetd + tuigreet ${YELLOW}(recommandé — léger, TUI)${NC}"
    echo -e "    ${BOLD}2)${NC} SDDM              ${CYAN}(graphique, plus traditionnel)${NC}"
    echo -e "    ${BOLD}3)${NC} GDM               ${CYAN}(GNOME Display Manager)${NC}"
    echo -e "    ${BOLD}4)${NC} Aucun             ${CYAN}(lancer niri-session manuellement depuis TTY)${NC}"
    read -rp "$(echo -e "${YELLOW}  Choix [1-4, défaut=1] : ${NC}")" dm_choice_num
    case "${dm_choice_num:-1}" in
      1) dm_choice="greetd" ;;
      2) dm_choice="sddm"   ;;
      3) dm_choice="gdm"    ;;
      4) dm_choice="none"   ;;
      *) dm_choice="greetd" ;;
    esac
  fi

  case "$dm_choice" in
    greetd)
      step "Installation de greetd + tuigreet"
      dnf install -y greetd greetd-tuigreet

      # Configuration greetd pour niri
      mkdir -p /etc/greetd
      cat > /etc/greetd/config.toml <<EOF
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd niri-session"
user = "greeter"
EOF
      systemctl enable greetd
      ok "greetd configuré pour niri-session."
      ;;

    sddm)
      step "Installation de SDDM"
      dnf install -y sddm sddm-wayland-plasma
      systemctl enable sddm
      ok "SDDM activé."
      ;;

    gdm)
      step "Installation de GDM"
      dnf install -y gdm
      systemctl enable gdm
      ok "GDM activé."
      ;;

    none)
      info "Aucun gestionnaire de session. Pour démarrer niri, lancez 'niri-session' depuis un TTY."
      ;;
  esac

  # S'assurer que la cible graphique est le défaut
  systemctl set-default graphical.target
  ok "Cible de démarrage : graphical.target"
}

# ---------------------------------------------------------------------------
# 11. Flatpak + Flathub
# ---------------------------------------------------------------------------
install_flatpak() {
  banner "11. Flatpak + Flathub"

  step "Installation de Flatpak"
  dnf install -y flatpak

  step "Ajout du dépôt Flathub"
  flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
  ok "Flatpak + Flathub prêts."
}

# ---------------------------------------------------------------------------
# 12. Configuration niri (config.kdl)
# ---------------------------------------------------------------------------
configure_niri() {
  banner "12. Configuration de niri"

  local niri_dir="$TARGET_HOME/.config/niri"
  sudo -u "$TARGET_USER" mkdir -p "$niri_dir"

  # N'écraser la config que si elle n'existe pas
  if [[ -f "$niri_dir/config.kdl" ]]; then
    if ! ask_yn "Un fichier config.kdl existe déjà. Écraser avec la configuration de base ?" default_n; then
      info "Configuration niri existante conservée."
      return
    fi
    cp "$niri_dir/config.kdl" "$niri_dir/config.kdl.backup.$(date +%Y%m%d-%H%M%S)"
    info "Sauvegarde créée."
  fi

  step "Écriture de ~/.config/niri/config.kdl"
  sudo -u "$TARGET_USER" tee "$niri_dir/config.kdl" > /dev/null <<'KDLEOF'
// ============================================================
//  niri config.kdl — Fedora 44 + Noctalia Shell
//  Généré automatiquement par install-niri-noctalia.sh
// ============================================================

// ---------- Comportement général ----------
prefer-no-csd

// ---------- Mise en page ----------
layout {
    gaps 8
    center-focused-column "never"

    preset-column-widths {
        proportion 0.333
        proportion 0.5
        proportion 0.667
    }

    default-column-width { proportion 0.5; }

    focus-ring {
        width 2
        active-color "#cba6f7"   // Mauve (Catppuccin Mocha)
        inactive-color "#313244"
    }

    border {
        off
    }
}

// ---------- Animations ----------
animations {
    slowdown 1.0
}

// ---------- Environnement Wayland ----------
environment {
    QT_QPA_PLATFORM "wayland"
    QT_WAYLAND_DISABLE_WINDOWDECORATION "1"
    GDK_BACKEND "wayland,x11"
    MOZ_ENABLE_WAYLAND "1"
    ELECTRON_OZONE_PLATFORM_HINT "auto"
    NIXOS_OZONE_WL "1"
    SDL_VIDEODRIVER "wayland"
    XCURSOR_SIZE "24"
    XCURSOR_THEME "Adwaita"
}

// ---------- Clavier ----------
input {
    keyboard {
        xkb {
            layout "ca"
            // variant "fr"
            options "caps:escape"
        }
        repeat-delay 200
        repeat-rate 35
    }

    touchpad {
        tap
        dwt
        natural-scroll
        scroll-method "two-finger"
        accel-speed 0.2
        accel-profile "adaptive"
    }

    mouse {
        accel-profile "flat"
    }
}

// ---------- Sorties vidéo ----------
// Décommentez et adaptez selon vos moniteurs
// Consultez : niri msg outputs
//
// output "eDP-1" {
//     scale 1.5
//     mode "1920x1080@60"
// }
//
// output "HDMI-A-1" {
//     position x=1920 y=0
//     mode "1920x1080@60"
// }

// ---------- Démarrage automatique ----------
spawn-at-startup "noctalia-shell"
// spawn-at-startup "mako"     // si vous n'utilisez pas les notifs de noctalia
spawn-at-startup "kanshi"
spawn-at-startup "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"

// ---------- Règles de fenêtres ----------
window-rule {
    match app-id="org.gnome.Nautilus"
    default-column-width { proportion 0.45; }
}

window-rule {
    match app-id="kitty"
    draw-border-with-background false
}

window-rule {
    match is-dialog=true
    default-column-width { proportion 0.4; }
    default-floating true
}

window-rule {
    match app-id=r#".*\.portal.*"#
    default-floating true
}

// ---------- Raccourcis clavier ----------
binds {
    // --- Applications ---
    Mod+T    { spawn "kitty"; }
    Mod+D    { spawn "fuzzel"; }
    Mod+E    { spawn "nautilus"; }
    Mod+B    { spawn "firefox"; }

    // --- Noctalia Shell ---
    Mod+Space      { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
    Mod+Shift+N    { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "control-center" "toggle"; }

    // --- Screenshots ---
    Print        { screenshot; }
    Ctrl+Print   { screenshot-screen; }
    Alt+Print    { screenshot-window; }

    // --- Verrou d'écran ---
    Mod+L        { spawn "swaylock" "-f" "-c" "1e1e2e"; }

    // --- Gestion des fenêtres ---
    Mod+Q        { close-window; }
    Mod+F        { maximize-column; }
    Mod+Shift+F  { fullscreen-window; }
    Mod+C        { center-column; }

    // --- Focus (clavier) ---
    Mod+H        { focus-column-left; }
    Mod+L        { focus-column-right; }
    Mod+J        { focus-window-down; }
    Mod+K        { focus-window-up; }
    Mod+Left     { focus-column-left; }
    Mod+Right    { focus-column-right; }
    Mod+Down     { focus-window-down; }
    Mod+Up       { focus-window-up; }

    // --- Déplacement de fenêtres ---
    Mod+Shift+H      { move-column-left; }
    Mod+Shift+L      { move-column-right; }
    Mod+Shift+J      { move-window-down; }
    Mod+Shift+K      { move-window-up; }
    Mod+Shift+Left   { move-column-left; }
    Mod+Shift+Right  { move-column-right; }
    Mod+Shift+Down   { move-window-down; }
    Mod+Shift+Up     { move-window-up; }

    // --- Largeur des colonnes ---
    Mod+Minus        { set-column-width "-10%"; }
    Mod+Equal        { set-column-width "+10%"; }
    Mod+Shift+Minus  { set-window-height "-10%"; }
    Mod+Shift+Equal  { set-window-height "+10%"; }
    Mod+R            { reset-window-height; }

    // --- Workspaces ---
    Mod+1            { focus-workspace 1; }
    Mod+2            { focus-workspace 2; }
    Mod+3            { focus-workspace 3; }
    Mod+4            { focus-workspace 4; }
    Mod+5            { focus-workspace 5; }
    Mod+6            { focus-workspace 6; }
    Mod+Ctrl+H       { focus-workspace-up; }
    Mod+Ctrl+L       { focus-workspace-down; }
    Mod+Ctrl+Up      { focus-workspace-up; }
    Mod+Ctrl+Down    { focus-workspace-down; }

    Mod+Shift+1      { move-window-to-workspace 1; }
    Mod+Shift+2      { move-window-to-workspace 2; }
    Mod+Shift+3      { move-window-to-workspace 3; }
    Mod+Shift+4      { move-window-to-workspace 4; }
    Mod+Shift+5      { move-window-to-workspace 5; }
    Mod+Shift+6      { move-window-to-workspace 6; }

    // --- Moniteurs ---
    Mod+Ctrl+Shift+H    { focus-monitor-left; }
    Mod+Ctrl+Shift+L    { focus-monitor-right; }
    Mod+Shift+Ctrl+Left  { move-window-to-monitor-left; }
    Mod+Shift+Ctrl+Right { move-window-to-monitor-right; }

    // --- Système ---
    Mod+Shift+E     { quit; }
    Mod+Shift+R     { reload-config; }
    Mod+Shift+Slash { show-hotkey-overlay; }

    // --- Volume (touches multimédia) ---
    XF86AudioRaiseVolume  allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
    XF86AudioLowerVolume  allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
    XF86AudioMute         allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
    XF86AudioMicMute      allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }

    // --- Luminosité ---
    XF86MonBrightnessUp   { spawn "brightnessctl" "set" "10%+"; }
    XF86MonBrightnessDown { spawn "brightnessctl" "set" "10%-"; }

    // --- Lecture multimédia ---
    XF86AudioPlay  { spawn "playerctl" "play-pause"; }
    XF86AudioStop  { spawn "playerctl" "stop"; }
    XF86AudioNext  { spawn "playerctl" "next"; }
    XF86AudioPrev  { spawn "playerctl" "previous"; }
}
KDLEOF

  chown "$TARGET_USER:$TARGET_USER" "$niri_dir/config.kdl"
  ok "~/.config/niri/config.kdl écrit."
}

# ---------------------------------------------------------------------------
# 13. Configuration de kitty
# ---------------------------------------------------------------------------
configure_kitty() {
  banner "13. Configuration de kitty"

  local kitty_dir="$TARGET_HOME/.config/kitty"
  sudo -u "$TARGET_USER" mkdir -p "$kitty_dir"

  if [[ -f "$kitty_dir/kitty.conf" ]]; then
    info "kitty.conf existant conservé."
    return
  fi

  step "Écriture de ~/.config/kitty/kitty.conf (Catppuccin Mocha)"
  sudo -u "$TARGET_USER" tee "$kitty_dir/kitty.conf" > /dev/null <<'EOF'
# ── Catppuccin Mocha ──────────────────────────────────────────────────────────
foreground              #CDD6F4
background              #1E1E2E
selection_foreground    #1E1E2E
selection_background    #F5E0DC

cursor                  #F5E0DC
cursor_text_color       #1E1E2E

url_color               #F5E0DC

active_border_color     #B4BEFE
inactive_border_color   #6C7086
bell_border_color       #F9E2AF

active_tab_foreground   #11111B
active_tab_background   #CBA6F7
inactive_tab_foreground #CDD6F4
inactive_tab_background #181825
tab_bar_background      #11111B

color0  #45475A
color1  #F38BA8
color2  #A6E3A1
color3  #F9E2AF
color4  #89B4FA
color5  #F5C2E7
color6  #94E2D5
color7  #BAC2DE
color8  #585B70
color9  #F38BA8
color10 #A6E3A1
color11 #F9E2AF
color12 #89B4FA
color13 #F5C2E7
color14 #94E2D5
color15 #A6ADC8

# ── Police ────────────────────────────────────────────────────────────────────
font_family      JetBrainsMono Nerd Font
bold_font        JetBrainsMono Nerd Font Bold
italic_font      JetBrainsMono Nerd Font Italic
bold_italic_font JetBrainsMono Nerd Font Bold Italic
font_size        12.0

# ── Comportement ──────────────────────────────────────────────────────────────
scrollback_lines        10000
copy_on_select          yes
strip_trailing_spaces   smart
url_prefixes            file ftp ftps git http https mailto ssh

# ── Apparence ─────────────────────────────────────────────────────────────────
window_padding_width    8
hide_window_decorations yes
background_opacity      0.95
dynamic_background_opacity yes

# ── Onglets ───────────────────────────────────────────────────────────────────
tab_bar_style           powerline
tab_powerline_style     slanted

# ── Wayland ───────────────────────────────────────────────────────────────────
linux_display_server    wayland
EOF

  chown -R "$TARGET_USER:$TARGET_USER" "$kitty_dir"
  ok "~/.config/kitty/kitty.conf écrit."
}

# ---------------------------------------------------------------------------
# 14. Configuration Noctalia (settings.json initial)
# ---------------------------------------------------------------------------
configure_noctalia() {
  banner "14. Configuration initiale de Noctalia Shell"

  local qs_dir="$TARGET_HOME/.config/quickshell/noctalia-shell"

  # Noctalia s'auto-configure au premier lancement, mais on peut pré-configurer
  # le settings.json pour un meilleur départ
  if [[ ! -d "$qs_dir" ]]; then
    warn "Noctalia n'a pas encore créé son répertoire de config (~/.config/quickshell/noctalia-shell)."
    warn "Il sera créé automatiquement au premier lancement de 'noctalia-shell'."
    return
  fi

  local settings_file="$qs_dir/settings.json"
  if [[ -f "$settings_file" ]]; then
    info "settings.json noctalia déjà présent — non modifié."
    return
  fi

  step "Pré-configuration de Noctalia (settings.json)"
  sudo -u "$TARGET_USER" tee "$settings_file" > /dev/null <<'EOF'
{
  "bar": {
    "position": "top",
    "widgets": {
      "left": [
        { "id": "SystemMonitor", "showCpuUsage": true, "showMemoryUsage": true },
        { "id": "ActiveWindow", "showIcon": true, "maxWidth": 200 },
        { "id": "MediaMini", "maxWidth": 150 }
      ],
      "center": [
        { "id": "Workspace", "labelMode": "name", "hideUnoccupied": false }
      ],
      "right": [
        { "id": "Tray" },
        { "id": "Battery" },
        { "id": "Volume" },
        { "id": "Network" },
        { "id": "Clock", "formatHorizontal": "HH:mm  ddd, MMM dd" },
        { "id": "ControlCenter" }
      ]
    }
  },
  "colorSchemes": {
    "darkMode": true,
    "predefinedScheme": "Catppuccin Mocha"
  },
  "ui": {
    "fontDefault": "JetBrainsMono Nerd Font Propo",
    "roundedCorners": true
  },
  "wallpaper": {
    "directory": "~/Images/Wallpapers",
    "enabled": false,
    "fillMode": "crop",
    "randomEnabled": false
  },
  "compositor": "niri"
}
EOF

  chown "$TARGET_USER:$TARGET_USER" "$settings_file"
  ok "settings.json Noctalia écrit."
}

# ---------------------------------------------------------------------------
# 15. polkit-gnome (authentification graphique)
# ---------------------------------------------------------------------------
install_polkit_agent() {
  banner "15. Agent d'authentification Polkit"
  step "polkit-gnome"
  dnf install -y polkit-gnome
  ok "polkit-gnome installé."
}

# ---------------------------------------------------------------------------
# 16. Thème GTK / icônes
# ---------------------------------------------------------------------------
install_themes() {
  banner "16. Thèmes GTK et icônes"

  step "Catppuccin GTK + icônes Papirus"
  dnf install -y papirus-icon-theme

  # Catppuccin GTK depuis GitHub (pas encore dans les repos)
  local gtk_dir="$TARGET_HOME/.local/share/themes"
  sudo -u "$TARGET_USER" mkdir -p "$gtk_dir"

  if [[ ! -d "$gtk_dir/Catppuccin-Mocha-Standard-Mauve-Dark" ]]; then
    step "Téléchargement du thème Catppuccin GTK Mocha"
    local tmp_gtk
    tmp_gtk=$(mktemp -d)
    curl -fLo "$tmp_gtk/catppuccin-gtk.zip" \
      "https://github.com/catppuccin/gtk/releases/latest/download/catppuccin-mocha-mauve-standard.zip" \
      && unzip -q "$tmp_gtk/catppuccin-gtk.zip" -d "$gtk_dir" \
      && ok "Thème Catppuccin GTK installé."
    rm -rf "$tmp_gtk"
  else
    info "Thème Catppuccin GTK déjà présent."
  fi

  # Application du thème GTK via gsettings (si dconf est disponible)
  if command -v gsettings &>/dev/null; then
    step "Application du thème GTK pour $TARGET_USER"
    sudo -u "$TARGET_USER" gsettings set org.gnome.desktop.interface \
      gtk-theme "Catppuccin-Mocha-Standard-Mauve-Dark" 2>/dev/null || true
    sudo -u "$TARGET_USER" gsettings set org.gnome.desktop.interface \
      icon-theme "Papirus-Dark" 2>/dev/null || true
    sudo -u "$TARGET_USER" gsettings set org.gnome.desktop.interface \
      cursor-theme "Adwaita" 2>/dev/null || true
    sudo -u "$TARGET_USER" gsettings set org.gnome.desktop.interface \
      cursor-size 24 2>/dev/null || true
    sudo -u "$TARGET_USER" gsettings set org.gnome.desktop.interface \
      font-name "Cantarell 11" 2>/dev/null || true
  fi

  ok "Thèmes configurés."
}

# ---------------------------------------------------------------------------
# 17. Récapitulatif final
# ---------------------------------------------------------------------------
print_summary() {
  banner "✅ Installation terminée !"

  echo -e "${GREEN}${BOLD}Ce qui a été installé et configuré :${NC}\n"
  echo -e "  ${CYAN}✔${NC} Fedora 44 Minimal → environnement graphique complet"
  echo -e "  ${CYAN}✔${NC} DNF optimisé (parallel downloads, fastestmirror)"
  echo -e "  ${CYAN}✔${NC} RPM Fusion + Terra (Fyra Labs)"
  echo -e "  ${CYAN}✔${NC} NetworkManager + Wi-Fi"
  echo -e "  ${CYAN}✔${NC} PipeWire / WirePlumber"
  echo -e "  ${CYAN}✔${NC} niri (compositeur Wayland scrollable-tiling)"
  echo -e "  ${CYAN}✔${NC} xwayland-satellite (support apps X11)"
  echo -e "  ${CYAN}✔${NC} XDG Desktop Portals (screenshots, partage d'écran)"
  echo -e "  ${CYAN}✔${NC} noctalia-shell (via Terra)"
  echo -e "  ${CYAN}✔${NC} kitty terminal (thème Catppuccin Mocha)"
  echo -e "  ${CYAN}✔${NC} JetBrainsMono Nerd Font"
  echo -e "  ${CYAN}✔${NC} fuzzel (lanceur d'applications)"
  echo -e "  ${CYAN}✔${NC} polkit-gnome, kanshi, mako, swaylock"
  echo -e "  ${CYAN}✔${NC} Thème Catppuccin GTK Mocha + Papirus icons"
  [[ "$SKIP_FLATPAK" == "false" ]] && echo -e "  ${CYAN}✔${NC} Flatpak + Flathub"
  [[ "$SKIP_BLUETOOTH" == "false" ]] && echo -e "  ${CYAN}✔${NC} Bluetooth (bluez + blueman)"
  echo ""

  echo -e "${BOLD}${YELLOW}Prochaines étapes :${NC}\n"
  echo -e "  1. ${BOLD}Redémarrez${NC} votre système"
  echo -e "     ${CYAN}sudo reboot${NC}\n"
  echo -e "  2. ${BOLD}Connectez-vous${NC} via le greeter → session niri démarrera automatiquement"
  echo -e "     ${CYAN}(ou tapez 'niri-session' sur un TTY si pas de DM)${NC}\n"
  echo -e "  3. ${BOLD}Noctalia Shell${NC} démarrera avec niri."
  echo -e "     Configurez-le via ${CYAN}~/.config/quickshell/noctalia-shell/settings.json${NC}\n"
  echo -e "  4. ${BOLD}Raccourcis clavier niri de base :${NC}"
  echo -e "     ${CYAN}Super+T${NC}           → kitty"
  echo -e "     ${CYAN}Super+D${NC}           → fuzzel (lanceur)"
  echo -e "     ${CYAN}Super+Space${NC}       → Noctalia App Launcher"
  echo -e "     ${CYAN}Super+Shift+N${NC}     → Noctalia Control Center"
  echo -e "     ${CYAN}Super+Shift+?${NC}     → Aide des raccourcis niri"
  echo -e "     ${CYAN}Super+Q${NC}           → Fermer fenêtre"
  echo -e "     ${CYAN}Super+L${NC}           → Verrouiller l'écran"
  echo -e "     ${CYAN}Super+Shift+E${NC}     → Quitter niri\n"
  echo -e "  5. ${BOLD}Documentation :${NC}"
  echo -e "     Niri     → ${CYAN}https://github.com/niri-wm/niri/wiki${NC}"
  echo -e "     Noctalia → ${CYAN}https://docs.noctalia.dev/v4${NC}\n"

  warn "N'oubliez pas d'adapter la section 'output' dans ~/.config/niri/config.kdl"
  warn "selon vos moniteurs (consultez 'niri msg outputs' après le premier démarrage)."
  warn ""
  warn "Le layout clavier est configuré en 'ca' (canadien). Modifiez la section"
  warn "'keyboard { xkb { layout } }' dans config.kdl si nécessaire."
}

# ---------------------------------------------------------------------------
# POINT D'ENTRÉE PRINCIPAL
# ---------------------------------------------------------------------------
main() {
  clear
  echo -e "${BOLD}${CYAN}"
  cat <<'ASCII'
  ███╗   ██╗██╗██████╗ ██╗    ███╗   ██╗ ██████╗  ██████╗████████╗ █████╗ ██╗     ██╗ █████╗
  ████╗  ██║██║██╔══██╗██║    ████╗  ██║██╔═══██╗██╔════╝╚══██╔══╝██╔══██╗██║     ██║██╔══██╗
  ██╔██╗ ██║██║██████╔╝██║    ██╔██╗ ██║██║   ██║██║        ██║   ███████║██║     ██║███████║
  ██║╚██╗██║██║██╔══██╗██║    ██║╚██╗██║██║   ██║██║        ██║   ██╔══██║██║     ██║██╔══██║
  ██║ ╚████║██║██║  ██║██║    ██║ ╚████║╚██████╔╝╚██████╗   ██║   ██║  ██║███████╗██║██║  ██║
  ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═╝    ╚═╝  ╚═══╝ ╚═════╝  ╚═════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝╚═╝  ╚═╝
ASCII
  echo -e "${NC}"
  echo -e "${BOLD}  Fedora 44 Minimal → niri + Noctalia Shell${NC}"
  echo -e "  ${CYAN}https://github.com/niri-wm/niri | https://docs.noctalia.dev${NC}\n"

  preflight_check

  echo ""
  if ! ask_yn "Démarrer l'installation complète ?" default_y; then
    echo "Installation annulée."
    exit 0
  fi

  configure_dnf
  setup_repos
  install_base
  install_network
  install_audio

  if ! $SKIP_BLUETOOTH; then
    if ask_yn "Installer le support Bluetooth ?" default_y; then
      install_bluetooth
    fi
  fi

  install_niri
  install_noctalia
  install_polkit_agent
  install_apps

  if ! $SKIP_FLATPAK; then
    install_flatpak
  fi

  install_greeter
  configure_niri
  configure_kitty
  configure_noctalia
  install_themes

  print_summary
}

main "$@"