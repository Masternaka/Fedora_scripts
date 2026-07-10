#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }

FORCE=0
DRY_RUN=0

usage() {
    echo "Usage: sudo $0 [--force] [--dry-run]"
    echo "  --force    Remplace smb.conf sans demander de confirmation."
    echo "  --dry-run  Affiche les actions sans installer ni modifier le système."
}

for arg in "$@"; do
    case "$arg" in
        --force)
            FORCE=1
            ;;
        --dry-run|-n)
            DRY_RUN=1
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            error "Argument inconnu : $arg"
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

[[ $EUID -ne 0 ]] && error "Ce script doit être exécuté en root (sudo)."

echo -e "\n${BOLD}=== Installation de Samba — Fedora ===${RESET}\n"

# ── 1. Installation ───────────────────────────────────────────────────────────
info "Installation de samba et des composants de Samba..."
run dnf install -y samba samba-common samba-client

success "Samba installé."

# ── 2. Sauvegarde + configuration smb.conf ────────────────────────────────────
SMB_CONF="/etc/samba/smb.conf"

if [[ -f "$SMB_CONF" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
        warn "dry-run : $SMB_CONF serait sauvegardé puis remplacé par une configuration minimale."
    elif [[ "$FORCE" -ne 1 ]]; then
        if [[ -t 0 ]]; then
            warn "$SMB_CONF existe déjà et sera remplacé par une configuration minimale."
            read -r -p "Continuer ? [y/N] " response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                warn "Configuration Samba conservée. Installation annulée avant modification."
                exit 0
            fi
        else
            warn "stdin non interactif : remplacement automatique de $SMB_CONF après sauvegarde."
        fi
    fi

    BACKUP="${SMB_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
    info "Sauvegarde de l'ancienne config : $BACKUP"
    run cp "$SMB_CONF" "$BACKUP"
fi

info "Écriture d'un smb.conf minimal..."
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: écriture d'une configuration minimale dans $SMB_CONF"
else
    cat > "$SMB_CONF" <<'EOF'
[global]
   workgroup = WORKGROUP
   server string = Samba Server %v
   server role = standalone server
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   panic action = /usr/share/samba/panic-action %d
   server schannel = yes
   map to guest = bad user
   usershare allow guests = no

# ── Exemple de partage (décommenter et adapter) ──────────────────────────────
# [partage]
#    path = /srv/samba/partage
#    browsable = yes
#    writable = yes
#    guest ok = no
#    valid users = @samba
EOF
fi
success "smb.conf configuré : $SMB_CONF"

info "Validation de la configuration Samba..."
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: testparm -s '$SMB_CONF'"
else
    testparm -s "$SMB_CONF" >/dev/null
fi
success "Configuration Samba valide."

# ── 3. Services ───────────────────────────────────────────────────────────────
info "Activation et démarrage des services smb et nmb..."
run systemctl enable --now smb nmb
success "Services smb et nmb actifs."

# ── 4. Firewall (ufw) ─────────────────────────────────────────────────────────
echo
info "Configuration du firewall..."

if command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
    info "firewalld détecté et actif."
    run firewall-cmd --permanent --add-service=samba
    run firewall-cmd --reload
    success "Règles Samba ajoutées dans firewalld."

elif command -v ufw &>/dev/null && { systemctl is-active --quiet ufw 2>/dev/null || ! command -v firewall-cmd &>/dev/null; }; then
    UFW_STATUS=$(ufw status | head -1)
    info "ufw détecté — statut : $UFW_STATUS"
    run ufw allow Samba
    success "Règles Samba ajoutées dans ufw."
    # S'assurer que ufw est actif
    if echo "$UFW_STATUS" | grep -q "inactive"; then
        warn "ufw est inactif. Activation..."
        run ufw --force enable
        success "ufw activé."
    fi

elif command -v firewall-cmd &>/dev/null; then
    info "firewalld détecté (inactif). Activation et configuration..."
    run systemctl enable --now firewalld
    run firewall-cmd --permanent --add-service=samba
    run firewall-cmd --reload
    success "Règles Samba ajoutées dans firewalld."

else
    warn "Aucun firewall reconnu ou actif — configuration manuelle requise."
    warn "Ports à ouvrir : TCP 139, TCP 445, UDP 137, UDP 138"
fi

# ── 5. Résumé ─────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}=== Installation terminée ===${RESET}"
echo -e "  • Fichier de config : ${CYAN}$SMB_CONF${RESET}"
echo -e "  • Ajouter un utilisateur Samba : ${CYAN}smbpasswd -a <utilisateur>${RESET}"
echo -e "  • Vérifier la config : ${CYAN}testparm${RESET}"
echo -e "  • Statut des services : ${CYAN}systemctl status smb nmb${RESET}"
echo
