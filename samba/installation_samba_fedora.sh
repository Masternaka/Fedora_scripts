#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }

[[ $EUID -ne 0 ]] && error "Ce script doit être exécuté en root (sudo)."

echo -e "\n${BOLD}=== Installation de Samba — Fedora ===${RESET}\n"

# ── 1. Installation ───────────────────────────────────────────────────────────
info "Installation de samba et samba-common..."
dnf install -y samba samba-common samba-client

success "Samba installé."

# ── 2. Sauvegarde + configuration smb.conf ────────────────────────────────────
SMB_CONF="/etc/samba/smb.conf"

if [[ -f "$SMB_CONF" ]]; then
    BACKUP="${SMB_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
    info "Sauvegarde de l'ancienne config : $BACKUP"
    cp "$SMB_CONF" "$BACKUP"
fi

info "Écriture d'un smb.conf minimal..."
cat > "$SMB_CONF" <<'EOF'
[global]
   workgroup = WORKGROUP
   server string = Samba Server %v
   server role = standalone server
   log file = /var/log/samba/log.%m
   max log size = 50
   security = user
   passdb backend = tdbsam
   map to guest = bad user

# ── Exemple de partage (décommenter et adapter) ──────────────────────────────
# [partage]
#    path = /srv/samba/partage
#    browsable = yes
#    writable = yes
#    guest ok = no
#    valid users = @samba
EOF
success "smb.conf configuré : $SMB_CONF"

# ── 3. SELinux ────────────────────────────────────────────────────────────────
if command -v getenforce &>/dev/null; then
    SELINUX_STATUS=$(getenforce)
    info "SELinux détecté — mode : $SELINUX_STATUS"
    if [[ "$SELINUX_STATUS" != "Disabled" ]]; then
        info "Application des booléens SELinux pour Samba..."
        setsebool -P samba_enable_home_dirs on  2>/dev/null || true
        setsebool -P samba_export_all_rw on     2>/dev/null || true
        success "Booléens SELinux configurés."
        warn "Si vous partagez des dossiers custom, appliquez aussi :"
        warn "  chcon -t samba_share_t /votre/chemin  OU  semanage fcontext + restorecon"
    fi
fi

# ── 4. Services ───────────────────────────────────────────────────────────────
info "Activation et démarrage des services smb et nmb..."
systemctl enable --now smb nmb
success "Services smb et nmb actifs."

# ── 5. Firewall (firewalld) ───────────────────────────────────────────────────
echo
info "Configuration du firewall..."

if command -v firewall-cmd &>/dev/null; then
    info "firewalld détecté."
    systemctl enable --now firewalld
    # Zone active par défaut (public sur Fedora)
    ZONE=$(firewall-cmd --get-default-zone)
    info "Zone active : $ZONE"
    firewall-cmd --permanent --zone="$ZONE" --add-service=samba
    firewall-cmd --reload
    success "Règles Samba ajoutées dans firewalld (zone : $ZONE)."

elif command -v ufw &>/dev/null; then
    info "ufw détecté (inhabituel sur Fedora, mais supporté)."
    ufw allow Samba
    success "Règles Samba ajoutées dans ufw."

else
    warn "Aucun firewall reconnu — configuration manuelle requise."
    warn "Ports à ouvrir : TCP 139, TCP 445, UDP 137, UDP 138"
fi

# ── 6. Résumé ─────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}=== Installation terminée ===${RESET}"
echo -e "  • Fichier de config : ${CYAN}$SMB_CONF${RESET}"
echo -e "  • Ajouter un utilisateur Samba : ${CYAN}smbpasswd -a <utilisateur>${RESET}"
echo -e "  • Vérifier la config : ${CYAN}testparm${RESET}"
echo -e "  • Statut des services : ${CYAN}systemctl status smb nmb${RESET}"
echo