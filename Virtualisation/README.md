# Installation QEMU et virt-manager — Fedora 44

Ce dossier contient un script complet pour installer et configurer QEMU/KVM et virt-manager sur Fedora 44.

## Fichiers

- `installation_qemu.sh` — Script d'installation et configuration
- `README.md` — Ce fichier de documentation

## Fonctionnalités du script

- Vérifie le support de la virtualisation matérielle (KVM/VMX)
- Vérifie la version de Fedora
- Installe le groupe "Virtualization" de Fedora + compléments utiles
- Configure firewalld pour le réseau libvirt (zone trusted)
- Ajoute l'utilisateur aux groupes `libvirt` et `kvm`
- Active les services libvirt en mode monolithique (`libvirtd`)
- Configure le réseau virtuel NAT par défaut
- Vérifie l'installation et affiche un résumé

## Prérequis

- Fedora 44
- Virtualisation matérielle activée dans le BIOS/UEFI (VT-x pour Intel, AMD-V pour AMD)
- Droits sudo
- Connexion internet

## Utilisation

```bash
chmod +x installation_qemu.sh
./installation_qemu.sh
```

> ⚠️ Ne pas lancer avec `sudo` — le script l'utilisera lui-même quand nécessaire.

## Paquets installés

### Via le groupe Fedora "Virtualization"
Le groupe installe l'essentiel : `qemu-kvm`, `libvirt`, `virt-install`, `libvirt-client`.

### Compléments installés explicitement

| Paquet | Utilité |
|---|---|
| `virt-manager` | Interface graphique de gestion des VMs |
| `virt-viewer` | Affichage console/graphique des VMs |
| `swtpm` + `swtpm-tools` | Émulation TPM (requis pour Windows 11) |
| `libvirt-daemon-driver-swtpm` | Support TPM dans libvirt |
| `edk2-ovmf` | Firmware UEFI pour les VMs |
| `policycoreutils-python-utils` | Gestion des politiques SELinux |

### Paquets optionnels (commentés dans le script)

| Paquet | Utilité |
|---|---|
| `libguestfs-tools` | Inspection et modification d'images disque |
| `virt-top` | Monitoring des VMs en temps réel |
| `python3-libvirt` | Bindings Python pour libvirt |
| `bridge-utils` | Réseau bridgé (si vous ne voulez pas NAT) |

## Après l'installation

**⚠️ Déconnectez-vous et reconnectez-vous** pour activer les groupes `libvirt` et `kvm`.

```bash
# Lancer virt-manager
virt-manager

# Lister les VMs
virsh list --all

# Lister les réseaux virtuels
virsh net-list --all

# Statut des services
systemctl status libvirtd
```

## Emplacements importants

| Chemin | Description |
|---|---|
| `/var/lib/libvirt/images/` | Images disque des VMs |
| `/etc/libvirt/qemu/` | Fichiers de configuration des VMs |
| `/etc/libvirt/qemu/networks/` | Configuration des réseaux virtuels |
| `/var/log/libvirt/` | Logs libvirt |

## Dépannage

### Permission denied lors de l'accès à libvirt
```bash
# Vérifier vos groupes (après reconnexion)
groups $USER
```

### Services ne démarrent pas
```bash
sudo systemctl status libvirtd
sudo journalctl -u libvirtd -f
```

### Réseau virtuel non fonctionnel
```bash
sudo virsh net-start default
sudo virsh net-autostart default
```

### Modules KVM non chargés
```bash
lsmod | grep kvm
sudo modprobe kvm_intel   # Intel
sudo modprobe kvm_amd     # AMD
```

### Vérifier le support matériel
```bash
grep -cE '(vmx|svm)' /proc/cpuinfo
ls -la /dev/kvm
```
