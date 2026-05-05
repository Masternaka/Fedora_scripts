# Script d'installation modulaire — Fedora 44

Script d'installation automatisé et modulaire pour Fedora 44 (KDE). Chaque catégorie de logiciels est gérée dans un fichier `.conf` indépendant.

## Utilisation

```bash
sudo bash install.sh
```

Le script :
1. Met à jour le système (`dnf upgrade`)
2. Affiche la liste des modules disponibles
3. Vous demande lesquels exécuter (numéros ou `all`)
4. Demande confirmation avant de démarrer

Un fichier `install.log` est créé dans le même dossier pour garder une trace complète.

---

## Structure

```
Installation de paquets/
├── install.sh          # Script principal
├── install.log         # Journal généré à l'exécution
├── README.md
└── modules/
    ├── fedora.conf         # Paquets des dépôts officiels Fedora
    ├── rpmfusion.conf      # Paquets RPM Fusion (free + nonfree)
    ├── flathub.conf        # Applications Flatpak depuis Flathub
    ├── third-party.conf    # Logiciels tiers (Brave, VSCode, etc.)
    └── remove-defaults.conf # Suppression des apps KDE non désirées
```

---

## Modules disponibles

| Module | Description |
|---|---|
| `fedora` | Paquets officiels Fedora (git, curl, btop…) |
| `rpmfusion` | Active RPM Fusion et installe ses paquets |
| `flathub` | Active Flathub et installe les Flatpaks |
| `third-party` | Logiciels tiers (Brave, Vivaldi, VSCode, Discord…) |
| `remove-defaults` | Supprime les apps KDE installées par défaut non désirées |

---

## Créer un nouveau module

Créez un fichier `modules/mon-module.conf` avec la structure suivante :

```bash
# Description du module
MODULE_NAME="Mon Module"

# Commande d'installation (ex: dnf install -y, flatpak install -y flathub)
INSTALL_CMD="dnf install -y"

# Paquets prérequis (optionnel, installés avant PACKAGES)
PREREQS=""

# Liste des paquets à installer
PACKAGES="

# Les commentaires sont supportés
nom-du-paquet

# Commande personnalisée: format NOM|COMMANDE
mon-logiciel|wget https://exemple.com/app.rpm -O /tmp/app.rpm && dnf localinstall -y /tmp/app.rpm && rm /tmp/app.rpm

"
```

### Règles

- **Commentaires** : Les lignes commençant par `#` dans `PACKAGES` sont ignorées.
- **Commandes personnalisées** : Utilisez le format `NOM|COMMANDE`. La commande est exécutée via `eval`.
- **Variables requises** : `MODULE_NAME` et `INSTALL_CMD` sont obligatoires.
- **PREREQS** : Installés un par un avec `$INSTALL_CMD` avant `PACKAGES`.

---

## Notes importantes

- **Notion** : Pas de RPM officiel. Installer via Flatpak dans `flathub.conf`.
- **OpenRGB** : Utilise le dépôt COPR `ianhattendorf/openrgb`.
- **RPM Fusion** : La version Fedora est détectée automatiquement avec `$(rpm -E %fedora)`.
