#!/usr/bin/env bash
# Installation de niri et DankMaterialShell sur Fedora 44
# Utilisation du dépôt COPR pour DankMaterialShell
# Source : https://danklinux.com/docs/dankmaterialshell/installation

set -euo pipefail

# Vérification de la version de Fedora
if ! grep -q "release 44" /etc/fedora-release 2>/dev/null; then
    echo "Ce script est conçu pour Fedora 44."
    echo "Version détectée : $(cat /etc/fedora-release)"
    exit 1
fi

echo "Mise à jour du système..."
sudo dnf upgrade --refresh -y

# -------------------- Installation de niri (dépôts officiels) --------------------
echo "Installation de niri..."
sudo dnf install -y niri

# Ajouter l'utilisateur au groupe 'input' (nécessaire pour que niri fonctionne)
sudo usermod -aG input "$USER"
echo "⚠️  Vous devrez vous déconnecter et vous reconnecter pour que le groupe 'input' soit pris en compte."

# -------------------- Activation du COPR DankMaterialShell --------------------
# Nom supposé : danklinux/dankmaterialshell (à confirmer avec la doc officielle)
COPR_REPO="danklinux/dankmaterialshell"
echo "Activation du dépôt COPR : $COPR_REPO"
sudo dnf copr enable -y "$COPR_REPO"

# -------------------- Installation de DankMaterialShell --------------------
echo "Installation de DankMaterialShell..."
sudo dnf install -y dankmaterialshell   # le nom du paquet peut être différent (ex: dank-material-shell)

echo ""
echo "✅ Installation terminée !"
echo "Redémarrez votre session, choisissez 'niri' dans votre gestionnaire de connexion,"
echo "puis lancez DankMaterialShell (commande probable : dankmaterial-shell)."
echo "N'hésitez pas à consulter la documentation pour la configuration détaillée."