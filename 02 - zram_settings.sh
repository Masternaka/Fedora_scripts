#!/usr/bin/env bash

set -euo pipefail

# --- Couleurs -----------------------------------------------------------
readonly C_RESET='\033[0m'
readonly C_INFO='\033[1;34m'
readonly C_OK='\033[1;32m'
readonly C_WARN='\033[1;33m'
readonly C_ERR='\033[1;31m'

log_info()  { echo -e "${C_INFO}[INFO]${C_RESET} $*"; }
log_ok()    { echo -e "${C_OK}[ OK ]${C_RESET} $*"; }
log_warn()  { echo -e "${C_WARN}[WARN]${C_RESET} $*"; }
log_err()   { echo -e "${C_ERR}[ERR ]${C_RESET} $*" >&2; }

# --- Paramètres -----------------------------------------------------------
readonly ZRAM_SIZE="ram / 2"
readonly ZRAM_ALGO="zstd"
readonly ZRAM_FSTYPE="swap"
readonly ZRAM_PRIORITY=100
readonly CONFIG_FILE="/etc/systemd/zram-generator.conf"
readonly PACKAGE="systemd-zram-generator"
readonly ZRAM_UNIT="systemd-zram-setup@zram0.service"

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
    log_warn "Mode dry-run activé : aucune modification ne sera appliquée."
fi

run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '  (dry-run)'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

# --- Vérifications préalables ---------------------------------------------
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log_err "Ce script doit être exécuté en root (sudo)."
        exit 1
    fi
}

check_fedora() {
    if ! grep -qiE 'fedora|rhel|centos' /etc/os-release 2>/dev/null; then
        log_warn "Distribution non détectée comme Fedora/RHEL. Poursuite quand même."
    fi
}

check_existing_zram() {
    if swapon --show=NAME --noheadings 2>/dev/null | grep -q "zram0"; then
        log_warn "Un device zram0 est déjà actif comme swap."
    fi
}

# --- Installation du paquet -------------------------------------------------
install_package() {
    if rpm -q "$PACKAGE" &>/dev/null; then
        log_ok "Le paquet ${PACKAGE} est déjà installé."
        return
    fi

    log_info "Installation du paquet ${PACKAGE}..."
    run dnf install -y "$PACKAGE"
    log_ok "Paquet ${PACKAGE} installé."
}

# --- Écriture de la configuration -------------------------------------------
write_config() {
    local new_content
    new_content=$(cat <<EOF
[zram0]
zram-size = ${ZRAM_SIZE}
compression-algorithm = ${ZRAM_ALGO}
fs-type = ${ZRAM_FSTYPE}
swap-priority = ${ZRAM_PRIORITY}
EOF
)

    if [[ -f "$CONFIG_FILE" ]] && diff -q <(echo "$new_content") "$CONFIG_FILE" &>/dev/null; then
        log_ok "La configuration ${CONFIG_FILE} est déjà à jour."
        return
    fi

    if [[ -f "$CONFIG_FILE" ]]; then
        local backup="${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
        log_warn "Une configuration existante a été trouvée, sauvegarde vers ${backup}."
        run cp "$CONFIG_FILE" "$backup"
    fi

    log_info "Écriture de ${CONFIG_FILE}..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  (dry-run) contenu prévu :"
        echo "$new_content" | sed 's/^/    /'
    else
        echo "$new_content" > "$CONFIG_FILE"
    fi
    log_ok "Configuration écrite."
}

# --- Activation du device zram ----------------------------------------------
activate_zram() {
    log_info "Rechargement de systemd et activation du device zram0..."
    run systemctl daemon-reload

    # Si zram0 est déjà actif avec l'ancienne config, on le redémarre proprement
    if [[ "$DRY_RUN" -eq 0 ]] && swapon --show=NAME --noheadings 2>/dev/null | grep -q "zram0"; then
        log_warn "Redémarrage du device zram0 pour appliquer la nouvelle configuration."
        systemctl stop "$ZRAM_UNIT" || true
        swapoff /dev/zram0 || true
    fi

    run systemctl start "$ZRAM_UNIT"
    log_ok "Device zram0 activé."
}

# --- Vérification finale -----------------------------------------------------
verify() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "Dry-run terminé, aucune vérification réelle effectuée."
        return
    fi

    log_info "Vérification du swap zram :"
    swapon --show
    echo
    log_info "Détails du device :"
    zramctl
}

main() {
    check_root
    check_fedora
    check_existing_zram
    install_package
    write_config
    activate_zram
    verify
    log_ok "Configuration de zram terminée."
}

main "$@"
