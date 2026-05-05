# Installation Samba — Fedora

Ce dossier contient un script d'installation et de configuration de **Samba** pour Fedora.

## 📌 Ce que fait le script

Le script `installation_samba.sh` :

- Installe les paquets **samba**, **samba-common** et **samba-client**
- Sauvegarde l'ancien fichier de configuration `/etc/samba/smb.conf` (si existant)
- Écrit un fichier `/etc/samba/smb.conf` minimal avec un exemple de partage commenté
- Valide la configuration avec `testparm`
- Configure les booléens SELinux utiles pour Samba (si SELinux est activé)
- Active et démarre les services **smb** et **nmb**
- Configure le pare-feu (firewalld ou ufw) pour autoriser Samba
- Propose interactivement de créer un utilisateur Samba

## ▶️ Utilisation

Ouvrez un terminal puis exécutez :

```bash
sudo bash installation_samba.sh
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
- Listez les partages disponibles :
  ```bash
  smbclient -L localhost -U <utilisateur>
  ```

## 📝 Personnaliser le partage

Le fichier `/etc/samba/smb.conf` contient un exemple de partage commenté. Pour ajouter un partage :

1. Décommentez et adaptez la section `[partage]`
2. Créez le dossier et ajustez les permissions :
   ```bash
   mkdir -p /srv/samba/partage
   chown root:samba /srv/samba/partage
   chmod 2775 /srv/samba/partage
   ```
3. Si SELinux est actif, appliquez le contexte :
   ```bash
   chcon -t samba_share_t /srv/samba/partage
   ```
4. Redémarrez Samba :
   ```bash
   sudo systemctl restart smb nmb
   ```

---

> Note : Ce script est conçu pour Fedora. Sur d'autres distributions, adaptez les commandes d'installation et de gestion de pare-feu.
