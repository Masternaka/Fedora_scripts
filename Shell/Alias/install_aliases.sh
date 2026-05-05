#!/usr/bin/env bash

# Script d'installation des alias Bash pour Fedora
# Copie bash_aliases.sh dans ~/.bash_aliases et configure ~/.bashrc pour le sourcer
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

# ── Chemins ───────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/bash_aliases.sh"

# Détecter l'utilisateur cible (supporte l'exécution via sudo ou directement)
if [[ -n "${SUDO_USER:-}" ]]; then
    TARGET_USER="$SUDO_USER"
    TARGET_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    TARGET_USER="$USER"
    TARGET_HOME="$HOME"
fi

ALIASES_FILE="$TARGET_HOME/.bash_aliases"
BASHRC="$TARGET_HOME/.bashrc"

# ── En-tête ───────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}=== Installation des alias Bash — Fedora ===${RESET}\n"

# ── 1. Vérification du fichier source ─────────────────────────────────────────
info "Fichier source : $SOURCE_FILE"
[[ -f "$SOURCE_FILE" ]] || error "Fichier introuvable : $SOURCE_FILE"
success "Fichier source trouvé."

# ── 2. Sauvegarde si ~/.bash_aliases existe déjà ─────────────────────────────
if [[ -f "$ALIASES_FILE" ]]; then
    BACKUP="${ALIASES_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
    warn "~/.bash_aliases existe déjà — sauvegarde : $BACKUP"
    cp "$ALIASES_FILE" "$BACKUP"
fi

# ── 3. Copie de bash_aliases.sh vers ~/.bash_aliases ─────────────────────────
info "Copie des alias vers $ALIASES_FILE..."
cp "$SOURCE_FILE" "$ALIASES_FILE"

# Ajuster le propriétaire si exécuté en root via sudo
if [[ $EUID -eq 0 ]]; then
    chown "$TARGET_USER:$TARGET_USER" "$ALIASES_FILE"
fi

success "Alias copiés dans $ALIASES_FILE."

# ── 4. Ajout du sourcing dans ~/.bashrc ───────────────────────────────────────
MARKER="# Source ~/.bash_aliases si le fichier existe"

if grep -qF "$MARKER" "$BASHRC" 2>/dev/null; then
    info "Le sourcing de ~/.bash_aliases est déjà présent dans $BASHRC."
else
    info "Ajout du sourcing de ~/.bash_aliases dans $BASHRC..."
    cat >> "$BASHRC" << 'BASHRC_BLOCK'

# Source ~/.bash_aliases si le fichier existe
if [[ -f ~/.bash_aliases ]]; then
    source ~/.bash_aliases
fi
BASHRC_BLOCK
    success "Sourcing ajouté dans $BASHRC."
fi

# ── 5. Résumé ─────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}=== Installation terminée ===${RESET}"
echo -e "  • Alias installés dans  : ${CYAN}$ALIASES_FILE${RESET}"
echo -e "  • Chargé automatiquement via : ${CYAN}$BASHRC${RESET}"
echo
echo -e "  ${YELLOW}➜  Appliquer immédiatement :${RESET} ${BOLD}source ~/.bashrc${RESET}"
echo -e "  ${YELLOW}➜  Modifier vos alias :${RESET}       ${BOLD}nano ~/.bash_aliases${RESET}"
echo
