#!/usr/bin/env bash

set -euo pipefail  # Arrêter le script en cas d'erreur

# Couleurs pour l'affichage
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

DRY_RUN=0
SHOW_LIST=0

# Liste des fonts à télécharger (noms des assets .zip côté Nerd Fonts)
fonts=(
    "JetBrainsMono"
    "CascadiaMono"
    "FiraCode"
    "Hack"
    "Iosevka"
    "Meslo"
    "Noto" 
)

show_help() {
    echo "Usage: $0 [--dry-run] [--list]"
    echo "  --dry-run  Affiche les téléchargements et copies sans les exécuter."
    echo "  --list     Affiche la liste des polices prévues."
}

for arg in "$@"; do
    case "$arg" in
        --dry-run|-n)
            DRY_RUN=1
            ;;
        --list)
            SHOW_LIST=1
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

# Détection de l'OS
OS="$(uname -s)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Installation des Nerd Fonts${NC}"
echo -e "${BLUE}========================================${NC}\n"
echo -e "${BLUE}Système détecté: ${OS}${NC}\n"

if [[ "$SHOW_LIST" -eq 1 ]]; then
    printf '%s\n' "${fonts[@]}"
    exit 0
fi

if [[ "$OS" != "Linux" ]]; then
    echo -e "${RED}❌ Ce script est compatible Linux uniquement.${NC}"
    echo -e "${YELLOW}Veuillez l’exécuter sur une machine Linux.${NC}\n"
    exit 1
fi

require_cmd() {
    local cmd="$1"
    local hint="${2:-}"
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}❌ Commande requise introuvable: ${cmd}${NC}"
        if [[ -n "$hint" ]]; then
            echo -e "${YELLOW}${hint}${NC}"
        fi
        exit 1
    fi
}

echo -e "${BLUE}Installation des Nerd Fonts via GitHub (Linux)...${NC}\n"

if [[ "$DRY_RUN" -eq 0 ]]; then
    require_cmd "curl" "Installez-la par ex: sudo dnf install -y curl"
    require_cmd "unzip" "Installez-la par ex: sudo dnf install -y unzip"
    require_cmd "fc-cache" "Installez-la par ex: sudo dnf install -y fontconfig"
fi

# Répertoire d'installation des polices (utilisateur)
FONT_DIR="$HOME/.local/share/fonts/NerdFonts"
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: mkdir -p '$FONT_DIR'"
else
    mkdir -p "$FONT_DIR"
fi

# URL de base GitHub
BASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"

# Nettoyage en cas d'erreur ou d'interruption
TEMP_DIR=""
cleanup() {
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Télécharger et installer chaque font
for font in "${fonts[@]}"; do
    echo -e "${BLUE}Téléchargement de ${font}...${NC}"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "DRY-RUN: curl -fLo '${font}.zip' '${BASE_URL}/${font}.zip'"
        echo "DRY-RUN: unzip '${font}.zip' et copie des fichiers .ttf/.otf vers '$FONT_DIR'"
        echo -e "${GREEN}✓ ${font} simulé${NC}"
        continue
    fi

    TEMP_DIR="$(mktemp -d)"
    (
        cd "$TEMP_DIR"
        curl -fLo "${font}.zip" "${BASE_URL}/${font}.zip"

        echo -e "${BLUE}Extraction de ${font}...${NC}"
        unzip -q "${font}.zip" -d "${font}"

        find "${font}" \( -name "*.ttf" -o -name "*.otf" \) -type f -print0 | while IFS= read -r -d '' file; do
            cp "$file" "$FONT_DIR/"
        done
    )
    rm -rf "$TEMP_DIR"
    TEMP_DIR=""

    echo -e "${GREEN}✓ ${font} installé avec succès${NC}"
done

# Mettre à jour le cache des fonts
echo -e "\n${BLUE}Mise à jour du cache des polices...${NC}"
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: fc-cache -fv '$FONT_DIR'"
else
    fc-cache -fv "$FONT_DIR"
fi
echo -e "${GREEN}✓ Cache mis à jour${NC}"

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Installation terminée!${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "Les polices sont installées dans: ${FONT_DIR}"
echo -e "Vous devrez peut-être redémarrer vos applications ou votre session pour voir les nouvelles polices.\n"
