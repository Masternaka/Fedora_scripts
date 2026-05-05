# Installation QEMU et virt-manager pour Fedora 44

Ce dossier contient un script complet pour installer et configurer QEMU, virt-manager et tous les composants nécessaires pour la virtualisation sur Fedora 44.

## Fichiers

- `installation_qemu_virt_manager.sh` - Script d'installation et configuration complet
- `README.md` - Ce fichier de documentation

## Fonctionnalités du script

### Installation des paquets
- Installation du groupe "Virtualization" de Fedora
- Installation de QEMU KVM et des outils associés
- Installation de virt-manager (interface graphique)
- Installation des pilotes et firmwares nécessaires (OVMF, SeaBIOS)
- Installation des outils de gestion et de diagnostic

### Configuration système
- **Firewalld**: Configuration automatique des services libvirt, libvirt-tls, vnc-server, spice-server
- **Groupes utilisateurs**: Ajout automatique de l'utilisateur aux groupes `libvirt` et `kvm`
- **Services**: Démarrage et activation de tous les services libvirt nécessaires
- **Réseaux**: Configuration du réseau virtuel par défaut (NAT 192.168.122.0/24)

### Services configurés
- `libvirtd` - Service principal de libvirt
- `virtlogd` - Gestion des logs
- `virtlockd` - Gestion des verrous
- `virtstoraged` - Gestion du stockage
- `virtqemud` - Support QEMU
- `virt-networkd` - Gestion des réseaux virtuels
- `virt-nwfilterd` - Filtres réseau
- `virt-interfaced` - Interfaces réseau
- `virt-proxyd` - Services proxy
- `virt-secretd` - Gestion des secrets

## Utilisation

### Prérequis
- Fedora 44 (peut fonctionner sur d'autres versions avec adaptations)
- Connexion internet
- Droits sudo pour l'utilisateur

### Installation

1. **Rendre le script exécutable:**
   ```bash
   chmod +x installation_qemu_virt_manager.sh
   ```

2. **Exécuter le script:**
   ```bash
   ./installation_qemu_virt_manager.sh
   ```

3. **Déconnexion et reconnexion:**
   Après l'exécution du script, déconnectez-vous et reconnectez-vous pour que les changements de groupes prennent effet.

### Vérification de l'installation

Après reconnexion, vérifiez que tout fonctionne correctement:

```bash
# Vérifier les services
systemctl status libvirtd

# Vérifier les groupes
groups $USER

# Lister les réseaux virtuels
virsh net-list --all

# Lancer virt-manager
virt-manager
```

## Post-installation

### Lancement de virt-manager
```bash
virt-manager
```

### Commandes utiles
```bash
# Lister les VMs
virsh list --all

# Gérer les réseaux
virsh net-list --all
virsh net-info default

# Gérer le stockage
virsh pool-list --all
virsh pool-info default

# Surveillance des VMs
virt-top
```

### Emplacements importants
- **Images VM**: `/var/lib/libvirt/images/`
- **Configuration réseaux**: `/etc/libvirt/qemu/networks/`
- **Logs**: `/var/log/libvirt/`
- **Socket libvirt**: `/var/run/libvirt/libvirt-sock`

## Dépannage

### Problèmes courants

1. **Permission denied lors de l'accès à libvirt**
   - Vérifiez que vous êtes bien dans le groupe libvirt: `groups $USER`
   - Déconnectez-vous et reconnectez-vous si nécessaire

2. **Services ne démarrent pas**
   ```bash
   sudo systemctl status libvirtd
   sudo journalctl -u libvirtd -f
   ```

3. **Réseau virtuel non fonctionnel**
   ```bash
   sudo virsh net-start default
   sudo virsh net-autostart default
   ```

4. **Modules KVM non chargés**
   ```bash
   lsmod | grep kvm
   sudo modprobe kvm
   sudo modprobe kvm_intel  # ou kvm_amd
   ```

### Vérification du support matériel
```bash
# Vérifier le support de la virtualisation matérielle
egrep -c '(vmx|svm)' /proc/cpuinfo

# Vérifier KVM
ls -la /dev/kvm
```

## Notes importantes

- Le script doit être exécuté en tant qu'utilisateur normal (pas root), il utilisera sudo quand nécessaire
- Un redémarrage peut être nécessaire après l'installation pour que tous les changements soient appliqués
- Le script configure automatiquement firewalld pour autoriser les services de virtualisation
- Le réseau par défaut utilise NAT avec la plage 192.168.122.0/24

## Support

En cas de problème avec le script, vérifiez:
1. Que vous êtes sur Fedora 44
2. Que vous avez les droits sudo
3. Que votre connexion internet fonctionne
4. Les logs des services libvirt: `sudo journalctl -u libvirtd`
