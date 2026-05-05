#!/usr/bin/env bash

# Script d'installation et de configuration des outils CLI modernes pour Bash — Fedora
# Outils : zoxide, fzf, bat, ripgrep, eza, fd, starship
# Date: 2026-05-05

set -euo pipefail

# ── Couleurs ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Fonctions de journalisation ───────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }

# ── Vérification des droits ───────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Ce script doit être exécuté en root (sudo)."

# Récupérer l'utilisateur réel (celui qui a lancé sudo)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
BASHRC="$REAL_HOME/.bashrc"

echo -e "\n${BOLD}=== Configuration des outils CLI modernes pour Bash — Fedora ===${RESET}\n"

# ── 1. Installation des paquets ───────────────────────────────────────────────
PACKAGES=(
    zoxide       # Navigation intelligente dans les répertoires
    fzf          # Recherche floue interactive
    bat          # Remplacement amélioré de cat (syntaxe, git, pager)
    ripgrep      # Recherche ultra-rapide dans les fichiers (rg)
    eza          # Remplacement moderne de ls
    fd-find      # Remplacement simple et rapide de find
    starship     # Prompt cross-shell ultra-personnalisable
)

info "Installation des paquets via dnf..."
dnf install -y "${PACKAGES[@]}"
success "Tous les paquets ont été installés."

# ── 2. Vérification des binaires installés ────────────────────────────────────
echo
info "Vérification des binaires..."

declare -A TOOL_CMDS=(
    [zoxide]="zoxide"
    [fzf]="fzf"
    [bat]="bat"
    [ripgrep]="rg"
    [eza]="eza"
    [fd-find]="fd"
    [starship]="starship"
)

ALL_OK=true
for pkg in "${!TOOL_CMDS[@]}"; do
    cmd="${TOOL_CMDS[$pkg]}"
    if command -v "$cmd" &>/dev/null; then
        success "$pkg  →  $(command -v "$cmd")"
    else
        warn "$pkg installé mais '$cmd' introuvable dans le PATH."
        ALL_OK=false
    fi
done

$ALL_OK || warn "Certains binaires sont manquants — vérifiez votre PATH après redémarrage du shell."

# ── 3. Configuration de ~/.bashrc ─────────────────────────────────────────────
echo
info "Ajout de la configuration dans $BASHRC..."

# Marqueurs pour éviter les doublons
MARKER_START="# >>> cli-tools-setup — début (généré automatiquement) <<<"
MARKER_END="# >>> cli-tools-setup — fin <<<"

if grep -qF "$MARKER_START" "$BASHRC" 2>/dev/null; then
    warn "Un bloc de configuration existe déjà dans $BASHRC — mise à jour..."
    # Supprimer l'ancien bloc avant de réécrire
    sed -i "/$MARKER_START/,/$MARKER_END/d" "$BASHRC"
fi

# Écriture du bloc de configuration
cat >> "$BASHRC" << 'BASHRC_BLOCK'

# >>> cli-tools-setup — début (généré automatiquement) <<<
# ─────────────────────────────────────────────────────────────────────────────
# Configuration des outils CLI modernes pour Bash
# ─────────────────────────────────────────────────────────────────────────────

# ── fzf ──────────────────────────────────────────────────────────────────────
# Activation des raccourcis clavier et de la complétion automatique
if command -v fzf &>/dev/null; then
    # Chargement des bindings et de la complétion selon la version de fzf
    FZF_SHELL_DIR=""
    for dir in \
        "/usr/share/fzf" \
        "/usr/share/doc/fzf/examples" \
        "$HOME/.fzf"; do
        if [[ -d "$dir" ]]; then
            FZF_SHELL_DIR="$dir"
            break
        fi
    done

    if [[ -n "$FZF_SHELL_DIR" ]]; then
        [[ -f "$FZF_SHELL_DIR/key-bindings.bash"  ]] && source "$FZF_SHELL_DIR/key-bindings.bash"
        [[ -f "$FZF_SHELL_DIR/completion.bash"     ]] && source "$FZF_SHELL_DIR/completion.bash"
    fi

    # Options par défaut : prévisualisation avec bat si disponible
    if command -v bat &>/dev/null; then
        export FZF_DEFAULT_OPTS="--height=50% --layout=reverse --border \
--preview 'bat --color=always --style=numbers --line-range=:200 {}' \
--preview-window=right:55%:wrap"
    else
        export FZF_DEFAULT_OPTS="--height=50% --layout=reverse --border"
    fi

    # Utiliser ripgrep comme source si disponible (plus rapide, respecte .gitignore)
    if command -v rg &>/dev/null; then
        export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    fi
fi

# ── bat ──────────────────────────────────────────────────────────────────────
if command -v bat &>/dev/null; then
    # Utiliser bat comme pager par défaut pour man
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    export MANROFFOPT="-c"
    # Alias cat → bat (avec fallback si fichier binaire)
    alias cat='bat --paging=never'
fi

# ── ripgrep (rg) ─────────────────────────────────────────────────────────────
if command -v rg &>/dev/null; then
    # Fichier de configuration ripgrep
    export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"
fi

# ── eza ───────────────────────────────────────────────────────────────────────
if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza --icons --group-directories-first -lh --git'
    alias la='eza --icons --group-directories-first -lha --git'
    alias lt='eza --icons --tree --level=2'
    alias lta='eza --icons --tree --level=2 -a'
fi

# ── fd ────────────────────────────────────────────────────────────────────────
# fd est installé en tant que 'fd' sur Fedora (paquet fd-find)
if command -v fd &>/dev/null; then
    # Utiliser fd pour la complétion de chemin dans fzf
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

# ── zoxide ────────────────────────────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
    # Remplace 'cd' par la commande 'z' et active l'intégration complète
    eval "$(zoxide init bash)"
    # Alias pratiques
    alias cd='z'
fi

# ── starship ──────────────────────────────────────────────────────────────────
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi

# >>> cli-tools-setup — fin <<<
BASHRC_BLOCK

success "Bloc de configuration ajouté dans $BASHRC."

# ── 4. Configuration de ripgrep ───────────────────────────────────────────────
echo
info "Création du fichier de configuration ripgrep..."

RG_CONFIG_DIR="$REAL_HOME/.config/ripgrep"
RG_CONFIG_FILE="$RG_CONFIG_DIR/config"

mkdir -p "$RG_CONFIG_DIR"
chown "$REAL_USER:$REAL_USER" "$RG_CONFIG_DIR"

if [[ ! -f "$RG_CONFIG_FILE" ]]; then
    cat > "$RG_CONFIG_FILE" << 'EOF'
# Configuration ripgrep (~/.config/ripgrep/config)
# Inclure les fichiers cachés dans les recherches
--hidden
# Exclure le répertoire .git
--glob=!.git/*
# Afficher les numéros de ligne
--line-number
# Activer les couleurs
--color=auto
# Utiliser le type smart-case (insensible si tout en minuscules)
--smart-case
EOF
    chown "$REAL_USER:$REAL_USER" "$RG_CONFIG_FILE"
    success "Fichier de configuration ripgrep créé : $RG_CONFIG_FILE"
else
    warn "Fichier de configuration ripgrep déjà existant : $RG_CONFIG_FILE (non modifié)."
fi

# ── 5. Résumé ─────────────────────────────────────────────────────────────────

echo
echo -e "${BOLD}=== Configuration terminée ===${RESET}"
echo -e "  ${BOLD}Outils installés :${RESET}"
echo -e "    • ${CYAN}zoxide${RESET}   — navigation intelligente  →  ${BOLD}z <répertoire>${RESET}"
echo -e "    • ${CYAN}fzf${RESET}      — recherche floue          →  ${BOLD}Ctrl+T${RESET} (fichiers), ${BOLD}Ctrl+R${RESET} (historique), ${BOLD}Alt+C${RESET} (répertoires)"
echo -e "    • ${CYAN}bat${RESET}      — affichage fichiers       →  ${BOLD}cat${RESET} (alias), ${BOLD}bat <fichier>${RESET}"
echo -e "    • ${CYAN}ripgrep${RESET}  — recherche dans fichiers  →  ${BOLD}rg <motif>${RESET}"
echo -e "    • ${CYAN}eza${RESET}      — listage de fichiers      →  ${BOLD}ls / ll / la / lt${RESET}"
echo -e "    • ${CYAN}fd${RESET}       — recherche de fichiers    →  ${BOLD}fd <motif>${RESET}"
echo -e "    • ${CYAN}starship${RESET} — prompt personnalisé      →  actif automatiquement"
echo
echo -e "  ${BOLD}Fichier de configuration :${RESET}"
echo -e "    • ${CYAN}$BASHRC${RESET}"
echo -e "    • ${CYAN}$RG_CONFIG_FILE${RESET}"
echo
echo -e "  ${YELLOW}➜  Relancez votre terminal ou exécutez :${RESET} ${BOLD}source ~/.bashrc${RESET}"
echo
