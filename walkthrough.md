# Walkthrough - Conversion des scripts pour Fedora

Toutes les étapes de conversion des scripts Debian vers Fedora ont été réalisées avec succès, incluant le support des dépôts, des codecs, des paquets officiels et des logiciels tiers.

## Modifications effectuées

### 1. Correction de syntaxe dans `03 - install_nerd_fonts.sh`
- Ajout du mot-clé `fi` fermant le bloc conditionnel `if [[ "$DRY_RUN" -eq 0 ]]` à la ligne 86, résolvant l'erreur de syntaxe Bash qui empêchait son chargement.

### 2. Dépôt RPM Fusion (`07 - install_rpmfusion.sh`)
- Configure les dépôts RPM Fusion (Free et Nonfree) de manière propre et idempotente.
- Remplace automatiquement `ffmpeg-free` (limité par défaut sur Fedora) par la version complète de `ffmpeg` de RPM Fusion en utilisant `--allowerasing`.
- Installe une suite complète de codecs audio/vidéo et de plugins de lecture (GStreamer plugins base/good/ugly/bad, faad2, flac, lame, x264, x265, libdvdcss, etc.).

### 3. Dépôt Terra (`08 - install_terrarepo.sh`)
- Configure le dépôt Terra (Fyra Labs) de manière propre.
- Permet d'installer directement des paquets issus de ce dépôt (la liste `PACKAGES` est prête à être éditée).

### 4. Dépôts COPR (`09 - install_copr.sh`)
- Active automatiquement les dépôts COPR configurés.
- Installe directement les paquets correspondants :
  - `lihaohong/yazi` -> `yazi`
  - `lilay/topgrade` -> `topgrade`
  - `ianhattendorf/openrgb` -> `openrgb`
  - `danklinux/dankmaterialshell` (seulement activé, car installé séparément dans le script `13`).

### 5. Paquets Officiels DNF (`10 - install_dnf.sh`)
- Simplifié pour installer uniquement les paquets officiels de Fedora : `git`, `curl`, `wget`, `btop`, `fastfetch`, `micro`, `meld`, `keepassxc`, `kitty`, etc.

### 6. NOUVEAU : Logiciels Tiers (`11 - install_thirdparty.sh`)
- Création du script d'installation de logiciels tiers, basé sur la configuration `third-party.conf` existante :
  - **Brave Browser** (dépôt RPM officiel)
  - **Vivaldi Browser** (dépôt RPM officiel)
  - **VS Code** (dépôt RPM officiel Microsoft)
  - **OpenRGB** (dépôt COPR)
  - **Warp Terminal** (RPM officiel)
  - **Discord** (extraction tar.gz dans `/opt/` et lien symbolique)
  - **Zed Editor** (script officiel exécuté sous l'identité de l'utilisateur réel via `sudo -u`)
  - **GitKraken** (RPM officiel)
  - **GitHub Desktop** (configuration du dépôt miroir shiftkey plus stable)
  - **Angry IP Scanner** (récupération dynamique et installation du dernier RPM depuis les Releases GitHub)

### 7. Renommage et décalage des scripts suivants
- `11 - flatpak_install.sh` a été renommé en `12 - flatpak_install.sh`.
- `12 - install_niridms.sh` a été renommé en `13 - install_niridms.sh`.

### 8. Script parent d'orchestration (`00 - super_script.sh`)
- Mis à jour la liste des scripts `SCRIPTS_SUDO` et `SCRIPTS_USER` pour correspondre précisément aux noms de fichiers réels dans le dossier (13 scripts gérés au total).

---

## Fichiers modifiés ou créés

- [00 - super_script.sh](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/00%20-%20super_script.sh)
- [03 - install_nerd_fonts.sh](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/03%20-%20install_nerd_fonts.sh)
- [07 - install_rpmfusion.sh](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/07%20-%20install_rpmfusion.sh)
- [08 - install_terrarepo.sh](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/08%20-%20install_terrarepo.sh)
- [09 - install_copr.sh](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/09%20-%20install_copr.sh)
- [10 - install_dnf.sh](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/10%20-%20install_dnf.sh)
- [11 - install_thirdparty.sh](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/11%20-%20install_thirdparty.sh) [NEW]
- [12 - flatpak_install.sh](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/12%20-%20flatpak_install.sh)
- [13 - install_niridms.sh](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/13%20-%20install_niridms.sh)
- [TODO.md](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/TODO.md)
