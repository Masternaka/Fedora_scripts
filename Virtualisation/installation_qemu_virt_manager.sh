#!/bin/bash

# Script d'installation de QEMU, virt-manager et configuration pour Fedora 44
# Auteur: Assistant IA
# Date: $(date +%Y-%m-%d)

set -e  # Arrête le script en cas d'erreur

# Couleurs pour une meilleure lisibilité
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérification si le script est exécuté en tant que root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Ce script ne doit pas être exécuté en tant que root"
        print_info "Exécutez-le avec votre utilisateur normal (le script utilisera sudo quand nécessaire)"
        exit 1
    fi
}

# Vérification de la distribution Fedora
check_fedora() {
    if [[ ! -f /etc/fedora-release ]]; then
        print_error "Ce script est conçu pour Fedora uniquement"
        exit 1
    fi
    
    FEDORA_VERSION=$(cat /etc/fedora-release | grep -oE '[0-9]+' | head -1)
    if [[ "$FEDORA_VERSION" != "44" ]]; then
        print_warning "Ce script est optimisé pour Fedora 44, vous utilisez Fedora $FEDORA_VERSION"
        read -p "Voulez-vous continuer? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Mise à jour du système
update_system() {
    print_info "Mise à jour du système..."
    sudo dnf update -y
    print_success "Système mis à jour"
}

# Installation des paquets de virtualisation
install_virtualization_packages() {
    print_info "Installation des paquets de virtualisation..."
    
    # Group installation pour virtualisation
    sudo dnf group install -y "Virtualization"
    
    # Paquets additionnels pour une meilleure expérience
    sudo dnf install -y \
        qemu-kvm \
        libvirt-daemon \
        libvirt-daemon-config-network \
        libvirt-daemon-driver-network \
        libvirt-daemon-driver-qemu \
        libvirt-daemon-driver-interface \
        libvirt-daemon-driver-storage-core \
        virt-install \
        virt-manager \
        virt-viewer \
        libvirt-client \
        bridge-utils \
        python3-libvirt \
        python3-libguestfs \
        libguestfs-tools \
        virt-top \
        virt-what \
        virt-install \
        virt-manager \
        virt-viewer \
        libvirt-daemon-kvm \
        qemu-img \
        qemu-system-x86-core \
        qemu-system-x86 \
        qemu-img \
        qemu-kvm-common \
        swtpm \
        swtpm-tools \
        libvirt-daemon-driver-swtpm \
        edk2-ovmf \
        seabios-bin \
        augeas \
        policycoreutils-python-utils \
        firewalld
    
    print_success "Paquets de virtualisation installés"
}

# Configuration de firewalld
configure_firewalld() {
    print_info "Configuration de firewalld pour la virtualisation..."
    
    # Vérification si firewalld est actif
    if sudo systemctl is-active --quiet firewalld; then
        # Ajout des services de virtualisation
        sudo firewall-cmd --permanent --add-service=libvirt
        sudo firewall-cmd --permanent --add-service=libvirt-tls
        sudo firewall-cmd --permanent --add-service=vnc-server
        sudo firewall-cmd --permanent --add-service=spice-server
        
        # Configuration des zones pour le réseau libvirt
        sudo firewall-cmd --permanent --zone=trusted --add-source=192.168.122.0/24
        sudo firewall-cmd --permanent --zone=trusted --add-interface=virbr0
        
        # Rechargement de firewalld
        sudo firewall-cmd --reload
        
        print_success "Firewalld configuré pour la virtualisation"
    else
        print_warning "Firewalld n'est pas actif, configuration ignorée"
    fi
}

# Ajout de l'utilisateur au groupe libvirt
add_user_to_libvirt() {
    print_info "Ajout de l'utilisateur $USER au groupe libvirt..."
    
    sudo usermod -a -G libvirt "$USER"
    sudo usermod -a -G kvm "$USER"
    
    print_success "Utilisateur $USER ajouté aux groupes libvirt et kvm"
    print_warning "Vous devrez vous déconnecter et vous reconnecter pour que les changements prennent effet"
}

# Démarrage et activation des services
start_services() {
    print_info "Démarrage et activation des services de virtualisation..."
    
    # Services libvirt
    sudo systemctl enable libvirtd
    sudo systemctl start libvirtd
    
    # Service virtlogd pour les logs
    sudo systemctl enable virtlogd
    sudo systemctl start virtlogd
    
    # Service virtlockd pour le verrouillage
    sudo systemctl enable virtlockd
    sudo systemctl start virtlockd
    
    # Service virtstoraged pour le stockage
    sudo systemctl enable virtstoraged
    sudo systemctl start virtstoraged
    
    # Service virtqemud pour QEMU
    sudo systemctl enable virtqemud
    sudo systemctl start virtqemud
    
    # Service virt-networkd pour les réseaux
    sudo systemctl enable virt-networkd
    sudo systemctl start virt-networkd
    
    # Service virt-nwfilterd pour les filtres réseau
    sudo systemctl enable virt-nwfilterd
    sudo systemctl start virt-nwfilterd
    
    # Service virt-interface pour les interfaces
    sudo systemctl enable virt-interfaced
    sudo systemctl start virt-interfaced
    
    # Service virt-proxyd pour le proxy
    sudo systemctl enable virt-proxyd
    sudo systemctl start virt-proxyd
    
    # Service virt-secret pour les secrets
    sudo systemctl enable virt-secretd
    sudo systemctl start virt-secretd
    
    print_success "Services de virtualisation démarrés et activés"
}

# Configuration des réseaux virtuels
configure_networks() {
    print_info "Configuration des réseaux virtuels..."
    
    # Démarrage du réseau par défaut
    if sudo virsh net-list --all | grep -q "default"; then
        sudo virsh net-autostart default
        sudo virsh net-start default
        print_success "Réseau par défaut configuré"
    fi
    
    # Configuration du réseau NAT par défaut si nécessaire
    sudo virsh net-define /etc/libvirt/qemu/networks/default.xml 2>/dev/null || true
}

# Vérification de l'installation
verify_installation() {
    print_info "Vérification de l'installation..."
    
    # Vérification des modules KVM
    if lsmod | grep -q kvm; then
        print_success "Modules KVM chargés"
    else
        print_warning "Modules KVM non chargés, redémarrage peut être nécessaire"
    fi
    
    # Vérification des services
    if sudo systemctl is-active --quiet libvirtd; then
        print_success "Service libvirtd actif"
    else
        print_error "Service libvirtd non actif"
        return 1
    fi
    
    # Vérification de l'appartenance aux groupes
    if groups "$USER" | grep -q libvirt; then
        print_success "Utilisateur dans le groupe libvirt"
    else
        print_warning "Utilisateur pas encore dans le groupe libvirt (déconnexion/reconnexion requise)"
    fi
    
    # Vérification de virt-manager
    if command -v virt-manager &> /dev/null; then
        print_success "virt-manager installé"
    else
        print_error "virt-manager non trouvé"
        return 1
    fi
}

# Affichage des informations post-installation
post_install_info() {
    print_success "Installation terminée!"
    echo
    echo "=== INFORMATIONS POST-INSTALLATION ==="
    echo
    echo "1. **Déconnexion/Reconnexion requise:**"
    echo "   Vous devez vous déconnecter et vous reconnecter pour que les changements de groupes prennent effet."
    echo
    echo "2. **Lancement de virt-manager:**"
    echo "   Après reconnexion, lancez virt-manager avec:"
    echo "   $ virt-manager"
    echo
    echo "3. **Vérification des services:**"
    echo "   $ systemctl status libvirtd"
    echo "   $ virsh list --all"
    echo
    echo "4. **Réseaux virtuels:**"
    echo "   Le réseau par défaut (192.168.122.0/24) est configuré pour le NAT"
    echo "   $ virsh net-list --all"
    echo
    echo "5. **Stockage:**"
    echo "   Les images VM seront stockées dans /var/lib/libvirt/images par défaut"
    echo
    echo "6. **Dépannage:**"
    echo "   Si vous rencontrez des problèmes de permissions, vérifiez:"
    echo "   $ groups $USER"
    echo "   $ ls -la /var/run/libvirt/libvirt-sock"
    echo
}

# Fonction principale
main() {
    echo "=== SCRIPT D'INSTALLATION QEMU/VIRT-MANAGER POUR FEDORA 44 ==="
    echo
    
    check_root
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
    
    echo
    post_install_info
    
    print_success "Installation de QEMU/virt-manager terminée avec succès!"
}

# Exécution du script
main "$@"
