# Walkthrough - Conversion des scripts pour Fedora

Toutes les étapes de conversion des scripts Debian vers Fedora ont été réalisées avec succès.

## Modifications effectuées

### 1. Correction de syntaxe dans `03 - install_nerd_fonts.sh`
- Ajout du mot-clé `fi` fermant le bloc conditionnel `if [[ "$DRY_RUN" -eq 0 ]]` à la ligne 86, corrigeant ainsi l'erreur de syntaxe Bash qui empêchait son chargement.

### 2. Dépôt RPM Fusion (`07 - install_rpmfusion.sh`)
- Remplacé l'ancien code Debian/Apt par une détection automatique de la version de Fedora (`$(rpm -E %fedora)`) et une installation propre/idempotente des dépôts RPM Fusion Free et Nonfree.

### 3. Dépôt Terra (`08 - install_terrarepo.sh`)
- Remplacé l'ancien code par l'installation du dépôt officiel Terra de Fyra Labs via DNF, avec vérification préalable de la présence du paquet `terra-release`.

### 4. Dépôts COPR (`09 - install_copr.sh`)
- Créé un script pour activer automatiquement les dépôts COPR requis par les autres scripts :
  - `lihaohong/yazi` (Yazi)
  - `lilay/topgrade` (Topgrade)
  - `ianhattendorf/openrgb` (OpenRGB)
  - `danklinux/dankmaterialshell` (DankMaterialShell)

### 5. Installateur de paquets DNF (`10 - install_dnf.sh`)
- Remplacé complètement l'ancien script `install_dnf.sh` (basé sur Apt) par un système robuste sous DNF :
  - Paquets triés par dépôts : `OFFICIAL_PACKAGES`, `RPMFUSION_PACKAGES`, `TERRA_PACKAGES`, et `COPR_PACKAGES`.
  - Vérification préalable de l'activation des dépôts RPM Fusion, Terra et COPR correspondants pour chaque paquet ciblé (avec des messages d'erreur et des conseils d'exécution si un dépôt manque).

### 6. Script parent d'orchestration (`00 - super_script.sh`)
- Mis à jour la liste des scripts `SCRIPTS_SUDO` et `SCRIPTS_USER` pour correspondre précisément aux noms de fichiers réels dans le dossier et respecter l'ordre de dépendance des dépôts.

---

## Fichiers modifiés

- [00 - super_script.sh](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/00%20-%20super_script.sh)
- [03 - install_nerd_fonts.sh](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/03%20-%20install_nerd_fonts.sh)
- [07 - install_rpmfusion.sh](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/07%20-%20install_rpmfusion.sh)
- [08 - install_terrarepo.sh](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/08%20-%20install_terrarepo.sh)
- [09 - install_copr.sh](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/09%20-%20install_copr.sh)
- [10 - install_dnf.sh](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/10%20-%20install_dnf.sh)
- [TODO.md](file:///Users/gchapdelaine/Desktop/Github/Fedora_scripts/TODO.md)
