# Fedora Scripts

Collection de scripts Bash pour gérer les paquets sur Fedora 44.

## 📋 Scripts disponibles

### Scripts modulaires de gestion de paquets

| Script | Description | Usage |
|--------|-------------|-------|
| `dnf_manager.sh` | Gestion des paquets DNF standards | `sudo ./dnf_manager.sh install` |
| `copr_manager.sh` | Gestion des dépôts et paquets COPR | `sudo ./copr_manager.sh enable` |
| `rpmfusion_manager.sh` | Gestion des paquets RPM Fusion | `sudo ./rpmfusion_manager.sh enable` |
| `flatpak_manager.sh` | Gestion des applications Flatpak | `sudo ./flatpak_manager.sh install` |

### Script complet (existante)

| Script | Description | Usage |
|--------|-------------|-------|
| `Installation de logiciels/installation_logiciels.sh` | Script unifié pour toutes les sources | `sudo ./Installation\ de\ logiciels/installation_logiciels.sh` |

## 🚀 Installation rapide

```bash
# Rendre tous les scripts exécutables
chmod +x *.sh
chmod +x "Installation de logiciels/installation_logiciels.sh"

# Exemple d'utilisation
sudo ./dnf_manager.sh install
sudo ./flatpak_manager.sh install
```

## ⚙️ Configuration

Chaque script modulaire crée automatiquement son fichier de configuration au premier lancement :

- `dnf_packages.conf` - Paquets DNF à installer/désinstaller
- `copr_repos.conf` - Dépôts et paquets COPR
- `rpmfusion_packages.conf` - Paquets RPM Fusion
- `flatpak_apps.conf` - Applications Flatpak

## 🔧 Options communes

Tous les scripts supportent :

- `--dry-run` : Mode simulation (aucune modification)
- `--help` : Afficher l'aide détaillée
- `config` : Ouvrir le fichier de configuration

## 📖 Exemples d'utilisation

```bash
# Installer des paquets DNF standards
sudo ./dnf_manager.sh install

# Activer les dépôts COPR et installer des paquets
sudo ./copr_manager.sh enable
sudo ./copr_manager.sh install

# Activer RPM Fusion et installer des logiciels multimédias
sudo ./rpmfusion_manager.sh enable
sudo ./rpmfusion_manager.sh install

# Installer des applications Flatpak depuis Flathub
sudo ./flatpak_manager.sh install

# Mode simulation pour prévisualiser
sudo ./dnf_manager.sh --dry-run install

# Mettre à jour toutes les applications
sudo ./dnf_manager.sh update
sudo ./flatpak_manager.sh update
```

## 🎯 Recommandations

1. **Commencez par DNF** : Installez d'abord les paquets de base avec `dnf_manager.sh`
2. **Activez RPM Fusion** : Pour les logiciels multimédias (VLC, Steam, codecs)
3. **Utilisez COPR** : Pour les logiciels plus récents ou expérimentaux
4. **Terminez avec Flatpak** : Pour les applications modernes et sandboxées

## 🔒 Sécurité

- Tous les scripts nécessitent les privilèges root (`sudo`)
- Mode simulation disponible pour prévisualiser les actions
- Logs détaillés dans `/var/log/*_manager.log`
- Vérification automatique de la compatibilité Fedora 44

## 📝 Notes

- Compatible avec Fedora 44 (avertissement pour autres versions)
- Scripts en français avec interface intuitive
- Configuration personnalisable via fichiers séparés
- Gestion automatique des dépendances
