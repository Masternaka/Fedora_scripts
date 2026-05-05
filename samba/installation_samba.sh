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
info "Installation de samba, samba-common et samba-client..."
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
#    create mask = 0664
#    directory mask = 0775
#    force group = samba
EOF
success "smb.conf configuré : $SMB_CONF"

# ── 3. Validation de la configuration ─────────────────────────────────────────
info "Validation de la configuration avec testparm..."
if testparm -s &>/dev/null; then
    success "Configuration smb.conf valide (testparm OK)."
else
    warn "testparm a détecté des avertissements dans $SMB_CONF — vérifiez manuellement."
fi

# ── 4. SELinux ────────────────────────────────────────────────────────────────
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

# ── 5. Services ───────────────────────────────────────────────────────────────
info "Activation et démarrage des services smb et nmb..."
systemctl enable --now smb nmb
success "Services smb et nmb actifs."

# ── 6. Firewall (firewalld) ───────────────────────────────────────────────────
echo
info "Configuration du firewall..."

if command -v firewall-cmd &>/dev/null; then
    info "firewalld détecté."
    systemctl enable --now firewalld
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

# ── 7. Création d'un utilisateur Samba ───────────────────────────────────────
echo
echo -e "${BOLD}Voulez-vous créer un utilisateur Samba maintenant ? (o/n)${RESET}"
read -r CREATE_USER

if [[ "$CREATE_USER" == "o" || "$CREATE_USER" == "O" ]]; then
    echo -e "Nom d'utilisateur système à ajouter à Samba :"
    read -r SAMBA_USER

    if id "$SAMBA_USER" &>/dev/null; then
        info "Ajout de '$SAMBA_USER' à Samba (un mot de passe Samba va être demandé)..."
        smbpasswd -a "$SAMBA_USER"
        smbpasswd -e "$SAMBA_USER"
        success "Utilisateur '$SAMBA_USER' ajouté et activé dans Samba."
    else
        warn "L'utilisateur système '$SAMBA_USER' n'existe pas. Créez-le d'abord avec : useradd $SAMBA_USER"
    fi
else
    info "Création d'utilisateur ignorée. Utilisez 'sudo smbpasswd -a <utilisateur>' plus tard."
fi

# ── 8. Résumé ─────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}=== Installation terminée ===${RESET}"
echo -e "  • Fichier de config   : ${CYAN}$SMB_CONF${RESET}"
echo -e "  • Ajouter un user     : ${CYAN}smbpasswd -a <utilisateur>${RESET}"
echo -e "  • Vérifier la config  : ${CYAN}testparm${RESET}"
echo -e "  • Statut des services : ${CYAN}systemctl status smb nmb${RESET}"
echo -e "  • Voir les partages   : ${CYAN}smbclient -L localhost -U <utilisateur>${RESET}"
echo