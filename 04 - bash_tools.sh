#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

DRY_RUN=0

show_help() {
    echo "Usage: sudo $0 [--dry-run]"
    echo "  --dry-run  Affiche les actions sans installer ni modifier .bashrc."
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

run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf 'DRY-RUN:'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}ERREUR : Ce script doit être exécuté en root (sudo).${NC}" >&2
    exit 1
fi

if [[ -z "${SUDO_USER:-}" ]]; then
    echo -e "${RED}ERREUR : SUDO_USER n'est pas défini.${NC}" >&2
    echo -e "${RED}Lancez ce script avec sudo depuis un compte utilisateur standard.${NC}" >&2
    exit 1
fi

USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
USER_GROUP=$(id -gn "$SUDO_USER")
if [[ -z "$USER_HOME" || -z "$USER_GROUP" ]]; then
    echo -e "${RED}ERREUR : Impossible de déterminer le home ou le groupe de $SUDO_USER.${NC}" >&2
    exit 1
fi

# ---- Liste des outils (dépôts officiels Fedora) ----
# Note : starship est géré séparément, il peut être installé plus tard.
PACKAGES=(
    bat             # cat avec coloration syntaxique
    eza             # ls moderne (fork actif de exa)
    ripgrep         # grep ultra-rapide (rg)
    fd              # find simplifié
    fzf             # fuzzy finder
    zoxide          # cd intelligent
    duf             # df moderne
)

# ---- Installation des paquets ----
echo -e "${CYAN}>>> Mise à jour du cache DNF...${NC}"
run dnf makecache --refresh

echo -e "${CYAN}>>> Installation des outils depuis les dépôts officiels...${NC}"
run dnf install -y "${PACKAGES[@]}"

# ---- Sauvegarde du .bashrc ----
BASHRC="$USER_HOME/.bashrc"
if [ -f "$BASHRC" ]; then
    run cp -p "$BASHRC" "$BASHRC.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}Sauvegarde de .bashrc effectuée.${NC}"
else
    run touch "$BASHRC"
    run chown "$SUDO_USER:$USER_GROUP" "$BASHRC"
    echo -e "${YELLOW}.bashrc absent, création de ${BASHRC}.${NC}"
fi

# ---- Vérification optionnelle pour starship ----
STARSHIP_INSTALLED=true
if ! command -v starship &> /dev/null; then
    echo -e "${YELLOW}⚠️  starship n'est pas installé. Il peut être installé avec dnf ou via le script officiel.${NC}"
    echo -e "   Pour l'installer : sudo dnf install -y starship"
    echo -e "   Ou via le script officiel : curl -sS https://starship.rs/install.sh | sh"
    echo -e "   La configuration de starship sera ignorée pour le moment."
    STARSHIP_INSTALLED=false
fi

STARSHIP_LINE="# Starship non installé, ligne ignorée"
if [ "$STARSHIP_INSTALLED" = true ]; then
    STARSHIP_LINE='eval "$(starship init bash)"'
fi

# ---- Configuration à ajouter ----
MODERN_CONF=$(cat <<EOF
# ============================================================
#  Configuration moderne du shell (ajoutée par le script)
# ============================================================

# ---- Alias modernes ----
alias ls='eza --icons --color=auto --group-directories-first'
alias ll='eza -la --icons --color=auto --group-directories-first'
alias la='eza -a --icons --color=auto'
alias tree='eza --tree --icons'
alias bat='bat'
alias cat='bat --paging=never --style=plain'
alias grep='rg --color=auto'
alias df='duf'

# ---- Initialisation des outils ----
# Zoxide (remplacez '--cmd cd' par '--cmd z' si vous préférez utiliser 'z' sans écraser cd)
eval \"\$(zoxide init bash --cmd cd)\"

# FZF : configuration par défaut
[ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash
[ -f /usr/share/fzf/completion.bash ] && source /usr/share/fzf/completion.bash

# ---- Starship (si installé) ----
${STARSHIP_LINE}

# ---- Options utiles ----
# Meilleur historique
shopt -s histappend
export HISTSIZE=100000
export HISTFILESIZE=100000
export HISTCONTROL=ignoreboth:erasedups

# Autocomplétion améliorée
bind 'set show-all-if-ambiguous on'
bind 'set completion-ignore-case on'
EOF
)

# ---- Ajout de la configuration (sans duplication) ----
if ! grep -q "Configuration moderne du shell" "$BASHRC" 2>/dev/null; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "DRY-RUN: ajout du bloc de configuration moderne dans $BASHRC"
    else
        printf '\n%s\n' "$MODERN_CONF" >> "$BASHRC"
        chown "$SUDO_USER:$USER_GROUP" "$BASHRC"
        echo -e "${GREEN}Configuration ajoutée à ${BASHRC}.${NC}"
    fi
else
    echo -e "${YELLOW}La configuration moderne est déjà présente dans ${BASHRC}.${NC}"
fi

# ---- Résumé final ----
echo -e "\n${GREEN}=== Installation terminée ===${NC}"
echo -e "Pour appliquer les changements, ouvrez un nouveau terminal ou lancez :"
echo -e "  ${CYAN}source ~/.bashrc${NC}"
echo -e "\nQuelques commandes à essayer :"
echo -e "  ${YELLOW}ls${NC}   -> eza avec icônes"
echo -e "  ${YELLOW}cat${NC}  -> bat (coloration)"
echo -e "  ${YELLOW}cd${NC}   -> zoxide (apprentissage automatique de vos dossiers)"
echo -e "  ${YELLOW}Ctrl+R${NC} -> historique interactif via fzf"
echo -e "  ${YELLOW}Ctrl+T${NC} -> recherche de fichiers via fzf"
echo -e "  ${YELLOW}df${NC}   -> duf (affichage moderne de l'espace disque)"
if [ "$STARSHIP_INSTALLED" = false ]; then
    echo -e "\n${YELLOW}Pour profiter du prompt starship, installez-le avec :${NC}"
    echo -e "  ${CYAN}curl -sS https://starship.rs/install.sh | sh${NC}"
fi
