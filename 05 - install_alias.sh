#!/usr/bin/env bash

set -euo pipefail

DRY_RUN=0
ALIASES_FILE=""

show_help() {
    echo "Usage: $0 [--dry-run] [--file CHEMIN]"
    echo "  --dry-run      Affiche les actions sans modifier .bashrc."
    echo "  --file CHEMIN  Chemin du fichier d'alias à charger."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run|-n)
            DRY_RUN=1
            shift
            ;;
        --file)
            if [[ -z "${2:-}" ]]; then
                echo "ERREUR : --file nécessite un chemin." >&2
                exit 1
            fi
            ALIASES_FILE="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "ERREUR : Argument inconnu : $1" >&2
            show_help >&2
            exit 1
            ;;
    esac
done

# Déterminer le répertoire personnel de l'utilisateur (même si exécuté avec sudo)
USER_HOME="$HOME"
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
fi
if [[ -z "$USER_HOME" ]]; then
    echo "ERREUR : Impossible de déterminer le dossier personnel." >&2
    exit 1
fi

# Chemin fixe du fichier d'alias
if [[ -z "$ALIASES_FILE" ]]; then
    ALIASES_FILE="$USER_HOME/.bash_aliases"
fi
BASHRC="$USER_HOME/.bashrc"

# Marqueur et bloc de chargement
MARKER="# >>> bash_aliases activé par enable-bash-aliases.sh"
SOURCE_BLOCK="if [ -f \"$ALIASES_FILE\" ]; then source \"$ALIASES_FILE\"; fi"

echo "=== Activation du fichier d'alias : $ALIASES_FILE ==="

# ---- Vérifications d'existence ----
if [ ! -f "$ALIASES_FILE" ]; then
    echo "ERREUR : le fichier '$ALIASES_FILE' n'existe pas." >&2
    echo "Veuillez le créer avant d'exécuter ce script." >&2
    exit 1
fi

if [ ! -f "$BASHRC" ]; then
    echo "ERREUR : $BASHRC n'existe pas. Impossible de le modifier." >&2
    exit 1
fi

# ---- Ajout du chargement dans .bashrc si absent ----
if grep -qF "$MARKER" "$BASHRC"; then
    echo "Le chargement est déjà présent dans $BASHRC."
else
    # Sauvegarde
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "DRY-RUN: cp -p '$BASHRC' '$BASHRC.backup.$(date +%Y%m%d_%H%M%S)'"
        echo "DRY-RUN: ajout du bloc de chargement dans $BASHRC"
    else
        cp -p "$BASHRC" "$BASHRC.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "\n$MARKER" >> "$BASHRC"
        echo "$SOURCE_BLOCK" >> "$BASHRC"
        if [[ -n "${SUDO_USER:-}" ]]; then
            chown "$SUDO_USER:$(id -gn "$SUDO_USER")" "$BASHRC"
        fi
        echo "✓ Ajout effectué dans $BASHRC (sauvegarde créée)."
    fi
fi

echo ""
echo "=== Terminé ==="
echo "Le fichier $ALIASES_FILE sera chargé automatiquement."
echo "Pour appliquer : source ~/.bashrc"
