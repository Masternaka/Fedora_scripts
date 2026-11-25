#!/usr/bin/env bash

set -euo pipefail

readonly C_RESET='\033[0m'
readonly C_INFO='\033[1;34m'
readonly C_OK='\033[1;32m'
readonly C_WARN='\033[1;33m'
readonly C_ERR='\033[0;31m'

log_info()  { echo -e "${C_INFO}[INFO]${C_RESET} $*"; }
log_ok()    { echo -e "${C_OK}[ OK ]${C_RESET} $*"; }
log_warn()  { echo -e "${C_WARN}[WARN]${C_RESET} $*"; }
log_err()   { echo -e "${C_ERR}[ERR ]${C_RESET} $*" >&2; }

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

ensure_package_installed() {
    local pkg="$1"
    if rpm -q "$pkg" &>/dev/null; then
        log_ok "Paquet ${pkg} déjà installé."
        return
    fi
    log_info "Installation du paquet ${pkg}..."
    run dnf install -y "$pkg"
    log_ok "Paquet ${pkg} installé."
}

ensure_service_enabled() {
    local unit="$1"
    if [[ "$DRY_RUN" -eq 0 ]] \
        && systemctl is-enabled --quiet "$unit" 2>/dev/null \
        && systemctl is-active --quiet "$unit" 2>/dev/null; then
        log_ok "${unit} déjà activé et actif."
        return
    fi
    log_info "Activation de ${unit}..."
    run systemctl enable --now "$unit"
    log_ok "${unit} activé."
}

setup_fstrim() {
    log_info "=== fstrim ==="
    ensure_package_installed util-linux

    if command -v lsblk &>/dev/null; then
        local rota_count
        rota_count=$(lsblk -dn -o ROTA 2>/dev/null | grep -c '^1' || true)
        if [[ "$rota_count" -gt 0 ]]; then
            log_warn "Au moins un disque rotationnel (HDD) détecté ; fstrim ne profite qu'aux SSD/NVMe."
        else
            log_ok "Aucun disque rotationnel détecté, fstrim est pertinent."
        fi
    fi

    ensure_service_enabled fstrim.timer
}

setup_bluetooth() {
    log_info "=== bluetooth ==="
    ensure_package_installed bluez

    if [[ -d /sys/class/bluetooth ]] && [[ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ]]; then
        log_ok "Adaptateur Bluetooth détecté."
    else
        log_warn "Aucun adaptateur Bluetooth détecté sur ce système (le service sera activé quand même)."
    fi

    ensure_service_enabled bluetooth.service
}

setup_firewalld() {
    log_info "=== firewalld ==="

    if rpm -q ufw &>/dev/null && systemctl is-active --quiet ufw 2>/dev/null; then
        log_warn "ufw est actif et peut entrer en conflit avec firewalld."
        log_warn "Pense à le désactiver : systemctl disable --now ufw"
    fi

    ensure_package_installed firewalld
    ensure_service_enabled firewalld.service
}

verify_all() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "Dry-run terminé, aucune vérification réelle effectuée."
        return
    fi

    echo
    log_info "Résumé des services :"
    printf "%-22s %-10s %-10s\n" "UNITÉ" "ENABLED" "ACTIVE"
    for unit in fstrim.timer bluetooth.service firewalld.service; do
        local enabled active
        enabled=$(systemctl is-enabled "$unit" 2>/dev/null || echo "?")
        active=$(systemctl is-active "$unit" 2>/dev/null || echo "?")
        printf "%-22s %-10s %-10s\n" "$unit" "$enabled" "$active"
    done
}

main() {
    check_root
    check_fedora
    setup_fstrim
    setup_bluetooth
    setup_firewalld
    verify_all
    log_ok "Vérification et activation des services terminées."
}

main "$@"
