# Installation Samba Fedora

Ce dossier contient un script d'installation et de configuration de **Samba** pour Fedora.

## 📌 Ce que fait le script

Le script `installation_samba_fedora.sh` :

- Installe les paquets **samba**, **samba-common** et **samba-client**
- Sauvegarde l'ancien fichier de configuration `/etc/samba/smb.conf` (si existant)
- Écrit un fichier `/etc/samba/smb.conf` minimal
- Configure des options SELinux utiles pour Samba (si SELinux est activé)
- Active et démarre les services **smb** et **nmb**
- Configure le pare-feu (firewalld ou ufw) pour autoriser Samba

## ▶️ Utilisation

Ouvrez un terminal puis exécutez :

```bash
sudo bash Fedora_scripts/samba/installation_samba_fedora.sh
```

### 👇 Après l'installation

- Vérifiez la configuration :
  ```bash
testparm
```
- Ajoutez un utilisateur Samba :
  ```bash
sudo smbpasswd -a <utilisateur>
```
- Vérifiez le statut des services :
  ```bash
systemctl status smb nmb
```

## 📝 Personnaliser le partage

Le fichier `/etc/samba/smb.conf` contient un exemple de partage commenté. Pour ajouter un partage :

1) Décommentez et adaptez la section `[#partage]`
2) Créez le dossier de partage et ajustez les permissions
3) Redémarrez Samba :

```bash
sudo systemctl restart smb nmb
```

---

> Note : Ce script est conçu pour Fedora. Sur d'autres distributions, adaptez les commandes d'installation et de gestion de pare-feu.
