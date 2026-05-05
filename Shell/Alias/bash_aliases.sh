# ─────────────────────────────────────────────────────────────────────────────
# bash_aliases.sh — Alias Bash pour Fedora
# Sourcé par install_aliases.sh dans ~/.bashrc
# ─────────────────────────────────────────────────────────────────────────────

# ── Navigation ────────────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'                   # Retour au répertoire précédent


# ── Listage de fichiers (ls de base, remplacé par eza si dispo) ───────────────
if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza --icons --group-directories-first -lh --git'
    alias la='eza --icons --group-directories-first -lha --git'
    alias lt='eza --icons --tree --level=2'
    alias lta='eza --icons --tree --level=2 -a'
else
    alias ls='ls --color=auto'
    alias ll='ls -lh --color=auto'
    alias la='ls -lha --color=auto'
    alias lt='ls -lhR --color=auto'
fi

# ── Affichage de fichiers (bat si dispo, sinon cat) ───────────────────────────
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
fi

# ── Grep coloré ───────────────────────────────────────────────────────────────
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# ── Gestion des paquets DNF ───────────────────────────────────────────────────
alias dni='sudo dnf install -y'             # Installer un paquet
alias dnr='sudo dnf remove -y'             # Supprimer un paquet
alias dnu='sudo dnf upgrade -y'            # Mettre à jour le système
alias dns='dnf search'                     # Rechercher un paquet
alias dninfo='dnf info'                    # Infos sur un paquet
alias dnlist='dnf list installed'          # Lister les paquets installés
alias dnauto='sudo dnf autoremove -y'      # Supprimer les dépendances orphelines
alias dnclean='sudo dnf clean all'         # Nettoyer le cache DNF


# ── Systemd ───────────────────────────────────────────────────────────────────
alias sstart='sudo systemctl start'
alias sstop='sudo systemctl stop'
alias srestart='sudo systemctl restart'
alias sstatus='systemctl status'
alias senable='sudo systemctl enable --now'
alias sdisable='sudo systemctl disable --now'
alias slist='systemctl list-units --type=service --state=running'
alias jlog='sudo journalctl -xe'           # Logs système récents

# ── Réseau ────────────────────────────────────────────────────────────────────
alias myip='curl -s https://ifconfig.me && echo'
alias localip="ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127"
alias ports='ss -tulnp'                    # Ports en écoute
alias pingg='ping -c 5 google.com'        # Test de connectivité rapide

# ── Firewall (firewalld) ──────────────────────────────────────────────────────
alias fwstatus='sudo firewall-cmd --state'
alias fwlist='sudo firewall-cmd --list-all'
alias fwreload='sudo firewall-cmd --reload'

# ── Disque & espace ───────────────────────────────────────────────────────────
alias df='df -hT'                          # Espace disque lisible
alias du='du -sh'                          # Taille d'un dossier
alias duh='du -h --max-depth=1 | sort -rh' # Top tailles dans le dossier courant
alias free='free -h'                       # RAM lisible

# ── Processus ─────────────────────────────────────────────────────────────────
alias psg='ps aux | grep -i'              # Rechercher un processus
alias topmem='ps aux --sort=-%mem | head -15'
alias topcpu='ps aux --sort=-%cpu | head -15'
alias k9='kill -9'

# ── Éditeur ───────────────────────────────────────────────────────────────────
# Décommentez et adaptez selon votre éditeur préféré
# alias edit='nano'
# alias edit='micro'
# alias edit='vim'

# ── Git ───────────────────────────────────────────────────────────────────────
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit -m'
alias gca='git commit -am'
alias gp='git push'
alias gpl='git pull'
alias gl='git log --oneline --graph --decorate -15'
alias gd='git diff'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gb='git branch'
alias gst='git stash'
alias gstp='git stash pop'

# ── Utilitaires divers ────────────────────────────────────────────────────────
alias h='history'
alias hg='history | grep'
alias cls='clear'
alias path='echo $PATH | tr ":" "\n"'      # Afficher le PATH formaté
alias reload='source ~/.bashrc && echo "~/.bashrc rechargé"'
alias bashrc='${EDITOR:-nano} ~/.bashrc'   # Éditer le .bashrc
alias aliases='${EDITOR:-nano} ~/.bash_aliases' # Éditer les alias

# Confirmer avant suppression / écrasement
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -pv'

# ── Archives ──────────────────────────────────────────────────────────────────
alias untar='tar -xvf'
alias untargz='tar -xzvf'
alias targz='tar -czvf'
alias untarbz='tar -xjvf'

# ── Raccourcis de navigation rapide (adapter selon vos chemins) ───────────────
alias home='cd ~'
alias dl='cd ~/Downloads'
alias docs='cd ~/Documents'
alias desk='cd ~/Desktop'
