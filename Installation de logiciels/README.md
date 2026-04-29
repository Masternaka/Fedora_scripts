## 📝 Description


Ce script Bash **automatise l'installation et la désinstallation** de logiciels sur Fedora. Il propose une interface interactive simple pour gérer vos applications préférées sans taper de commandes complexes.

> 💡 **Astuce** : Modifiez les listes de paquets en début de script pour personnaliser vos installations.

---

## ✨ Fonctionnalités

| Fonctionnalité | Description |
|----------------|-------------|
| 📦 **Paquets DNF** | Installation via le gestionnaire de paquets natif |
| 🔄 **RPM Fusion** | Dépôts additionnels pour logiciels multimédias |
| 📱 **Flatpak** | Applications modernes via Flathub |
| 🛠️ **COPR** | Dépôts communautaires personnalisés |
| 🗑️ **Désinstallation** | Suppression de paquets et nettoyage |
| 🎮 **Mode simulation** | Aperçu sans modification (`--dry-run`) |

---

## 🔧 Prérequis

- ✅ Fedora
- ✅ Droits administrateur (`sudo`)
- ✅ Connexion Internet active

---

## 🚀 Installation

```bash
# Cloner le dépôt
git clone https://github.com/Masternaka/Fedora_scripts.git
cd Fedora_scripts/Installation\ de\ logiciels

# Rendre le script exécutable
chmod +x installation_logiciels.sh
```

---

## ▶️ Utilisation

### Menu interactif (recommandé)

```bash
sudo ./installation_logiciels.sh
```

### Commandes directes

```bash
# Installation complète
sudo ./installation_logiciels.sh install

# Désinstallation complète
sudo ./installation_logiciels.sh remove

# Afficher les listes configurées
sudo ./installation_logiciels.sh list

# Nettoyer le système
sudo ./installation_logiciels.sh clean

# Mode simulation (aperçu sans exécuter)
sudo ./installation_logiciels.sh --dry-run install
```

### Aide

```bash
sudo ./installation_logiciels.sh --help
```

---

## ⚙️ Configuration

Modifiez les tableaux ci-dessous au **début du script** (`installation_logiciels.sh`) :

```bash
# Paquets DNF standards
DNF_PACKAGES_INSTALL=(
    curl
    wget
    git
    vim
    htop
)

# Paquets RPM Fusion (multimédia)
RPMFUSION_DNF_PACKAGES_INSTALL=(
    vlc
    steam
)

# Applications Flatpak
FLATPAK_APPS_INSTALL=(
    com.spotify.Client
    org.gimp.GIMP
)

# Dépôts COPR
COPR_REPOS_ENABLE=(
    atim/starship
)

# Paquets à désinstaller
DNF_PACKAGES_REMOVE=(
    rhythmbox
)
```

---

## 📋 Menu principal

```
=== Installation / désinstallation de logiciels - Fedora ===

1) Installer tous les logiciels configurés
2) Installer les paquets DNF configurés
3) Activer RPM Fusion
4) Installer les paquets DNF RPM Fusion configurés
5) Activer les dépôts COPR configurés
6) Installer les applications Flatpak configurées
7) Désinstaller tous les logiciels configurés
8) Désinstaller les paquets DNF configurés
9) Désinstaller les applications Flatpak configurées
10) Afficher les listes configurées
11) Nettoyer le système
12) Quitter
```

---

## ⚠️ Remarques importantes

- 🔒 Le script vérifie automatiquement les privilèges root
- ⚠️ Compatible Fedora 40-46 (un avertissement apparaît pour les versions non testées)
- 📊 Les logs sont enregistrés dans `/var/log/installation_logiciels.log`
- 🔄 RPM Fusion est recommandé pour VLC, Steam et certains codecs