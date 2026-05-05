#!/usr/bin/env bash

# Script d'installation de QEMU, virt-manager et configuration pour Fedora 44

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
print_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ── 1. Vérifications préliminaires ────────────────────────────────────────────

# Le script doit être exécuté en utilisateur normal (pas root)
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Ce script ne doit pas être exécuté en tant que root."
        print_info "Exécutez-le avec votre utilisateur normal (sudo sera utilisé quand nécessaire)."
        exit 1
    fi
}

# Vérification du support KVM matériel
check_kvm_support() {
    print_info "Vérification du support de la virtualisation matérielle..."
    if ! grep -qE '(vmx|svm)' /proc/cpuinfo; then
        print_error "Votre processeur ne supporte pas la virtualisation matérielle (KVM)."
        print_info "Vérifiez que la virtualisation (VT-x/AMD-V) est activée dans le BIOS/UEFI."
        exit 1
    fi
    local cpu_flag
    cpu_flag=$(grep -oE 'vmx|svm' /proc/cpuinfo | head -1 | tr '[:lower:]' '[:upper:]')
    print_success "Virtualisation matérielle supportée ($cpu_flag)."
}

# Vérification de la distribution Fedora
check_fedora() {
    if [[ ! -f /etc/fedora-release ]]; then
        print_error "Ce script est conçu pour Fedora uniquement."
        exit 1
    fi

    local fedora_version
    fedora_version=$(grep -oE '[0-9]+' /etc/fedora-release | head -1)

    if [[ "$fedora_version" != "44" ]]; then
        print_warning "Ce script est optimisé pour Fedora 44, vous utilisez Fedora $fedora_version."
        read -r -p "Voulez-vous continuer? (o/N): " confirm
        echo
        if [[ ! "$confirm" =~ ^[Oo]$ ]]; then
            exit 1
        fi
    fi
    print_success "Fedora $fedora_version détectée."
}

# ── 2. Mise à jour du système ─────────────────────────────────────────────────

update_system() {
    print_info "Mise à jour du système..."
    sudo dnf upgrade -y
    print_success "Système mis à jour."
}

# ── 3. Installation des paquets ───────────────────────────────────────────────

install_virtualization_packages() {
    print_info "Installation du groupe Virtualisation Fedora..."
    # Le groupe installe l'essentiel : qemu-kvm, libvirt, virt-install, libvirt-client
    sudo dnf group install -y "Virtualization"

    print_info "Installation des paquets complémentaires..."
    sudo dnf install -y \
        virt-manager \
        virt-viewer \
        swtpm \
        swtpm-tools \
        libvirt-daemon-driver-swtpm \
        edk2-ovmf \
        policycoreutils-python-utils

    # Explication des paquets installés :
    # virt-manager -  # Interface graphique pour qemu-kvm
    # virt-viewer -  # Visionneuse pour l'affichage graphique des machines virtuelles
    # swtpm -  # Émulateur logiciel TPM (Trusted Platform Module)
    # swtpm-tools -  # Outils pour l'émulateur TPM logiciel swtpm
    # libvirt-daemon-driver-swtpm -  # Pilote démon libvirt pour swTPM
    # edk2-ovmf -  # Firmware UEFI pour machines virtuelles (Open Virtual Machine Firmware)
    # policycoreutils-python-utils  - Utilitaires Python pour la gestion des politiques SELinux

    # Paquets optionnels (décommenter si besoin) :
    # libguestfs-tools     — inspection et modification d'images disque
    # virt-top             — monitoring des VMs en temps réel
    # python3-libvirt      — bindings Python pour libvirt
    # bridge-utils         — réseau bridgé (si vous ne voulez pas NAT)

    print_success "Paquets de virtualisation installés."
}

# ── 4. Firewall ───────────────────────────────────────────────────────────────

configure_firewalld() {
    print_info "Configuration de firewalld pour la virtualisation..."

    if sudo systemctl is-active --quiet firewalld; then
        # Autoriser le réseau NAT libvirt (192.168.122.0/24) en zone trusted
        sudo firewall-cmd --permanent --zone=trusted --add-source=192.168.122.0/24
        sudo firewall-cmd --permanent --zone=trusted --add-interface=virbr0
        sudo firewall-cmd --reload
        print_success "Firewalld configuré (zone trusted pour le réseau libvirt NAT)."
    else
        print_warning "Firewalld n'est pas actif — configuration ignorée."
    fi
}

# ── 5. Groupes utilisateur ────────────────────────────────────────────────────

add_user_to_libvirt() {
    print_info "Ajout de '$USER' aux groupes libvirt et kvm..."
    sudo usermod -aG libvirt "$USER"
    sudo usermod -aG kvm "$USER"
    print_success "Utilisateur '$USER' ajouté aux groupes libvirt et kvm."
    print_warning "Déconnexion/reconnexion requise pour activer ces groupes."
}

# ── 6. Services (mode monolithique libvirtd) ──────────────────────────────────

start_services() {
    print_info "Activation et démarrage des services libvirt..."
    # Mode monolithique : libvirtd gère tout (recommandé pour usage standard)
    sudo systemctl enable --now libvirtd
    sudo systemctl enable --now virtlogd
    sudo systemctl enable --now virtlockd
    print_success "Services libvirtd, virtlogd et virtlockd actifs."
}

# ── 7. Réseau virtuel par défaut ──────────────────────────────────────────────

configure_networks() {
    print_info "Configuration du réseau virtuel par défaut..."

    if sudo virsh net-list --all | grep -q "default"; then
        # Démarrer seulement s'il n'est pas déjà actif
        if ! sudo virsh net-list | grep -q "default"; then
            sudo virsh net-start default 2>/dev/null || true
        fi
        sudo virsh net-autostart default
        print_success "Réseau 'default' (NAT 192.168.122.0/24) actif avec autostart."
    else
        print_warning "Réseau 'default' introuvable — libvirtd doit être redémarré."
    fi
}

# ── 8. Vérification post-installation ────────────────────────────────────────

verify_installation() {
    print_info "Vérification de l'installation..."
    local all_ok=true

    if lsmod | grep -q kvm; then
        print_success "Modules KVM chargés."
    else
        print_warning "Modules KVM non chargés — un redémarrage peut être nécessaire."
    fi

    if sudo systemctl is-active --quiet libvirtd; then
        print_success "Service libvirtd actif."
    else
        print_error "Service libvirtd non actif."
        all_ok=false
    fi

    if command -v virt-manager &>/dev/null; then
        print_success "virt-manager installé."
    else
        print_error "virt-manager introuvable."
        all_ok=false
    fi

    if groups "$USER" | grep -q libvirt; then
        print_success "Utilisateur dans le groupe libvirt."
    else
        print_warning "Groupe libvirt pas encore actif — déconnectez-vous et reconnectez-vous."
    fi

    if ! $all_ok; then
        print_error "Des erreurs ont été détectées — consultez les messages ci-dessus."
        return 1
    fi
}

# ── 9. Résumé ─────────────────────────────────────────────────────────────────

post_install_info() {
    echo
    echo -e "${BOLD}=== Installation terminée ===${NC}"
    echo -e "  • Lancer virt-manager     : ${CYAN}virt-manager${NC}"
    echo -e "  • Lister les VMs          : ${CYAN}virsh list --all${NC}"
    echo -e "  • Lister les réseaux      : ${CYAN}virsh net-list --all${NC}"
    echo -e "  • Statut libvirt          : ${CYAN}systemctl status libvirtd${NC}"
    echo -e "  • Images VM stockées dans : ${CYAN}/var/lib/libvirt/images/${NC}"
    echo
    print_warning "Déconnectez-vous et reconnectez-vous pour activer les groupes libvirt/kvm."
}

# ── Fonction principale ───────────────────────────────────────────────────────

main() {
    echo -e "\n${BOLD}=== Installation QEMU/virt-manager — Fedora 44 ===${NC}\n"

    check_root
    check_kvm_support
    check_fedora

    print_info "Début de l'installation..."
    echo

    update_system
    install_virtualization_packages
    configure_firewalld
    add_user_to_libvirt
    start_services
    configure_networks

    echo
    verify_installation
    post_install_info
}

main "$@"
