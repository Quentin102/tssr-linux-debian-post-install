#!/bin/bash

# === VARIABLES ===
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")  # Génère un timestamp pour les logs
LOG_DIR="./logs"  # Répertoire des logs
LOG_FILE="$LOG_DIR/postinstall_$TIMESTAMP.log"  # Fichier de log avec timestamp
CONFIG_DIR="./config"  # Répertoire de configuration
PACKAGE_LIST="./lists/packages.txt"  # Fichier contenant la liste des paquets à installer
USERNAME=$(logname)  # Récupère le nom de l'utilisateur connecté
USER_HOME="/home/$USERNAME"  # Définit le répertoire personnel de l'utilisateur

# === FONCTIONS ===

# Fonction pour écrire des logs avec timestamp
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Vérifie si un paquet est installé, sinon l'installe
check_and_install() {
  local pkg=$1
  if dpkg -s "$pkg" &>/dev/null; then # Vérifie si dpkg est installé 
    log "$pkg is already installed." # envoie un log pour qui qu'il est deja installé
  else
    log "Installing $pkg..." # sinon dire qu'il est en cours d'installation
    apt install -y "$pkg" &>>"$LOG_FILE" # installation du packet et envoie le code erreur dans log
    if [ $? -eq 0 ]; then # il prends le code de la derniere commande avec $? et si l'installation réussi, il envoie un log dans ce sens
      log "$pkg successfully installed."
    else # sinon il envoie un log dans le sens contraire
      log "Failed to install $pkg."
    fi
  fi
}

# Demande à l'utilisateur une confirmation (Oui/Non)
ask_yes_no() {
  read -p "$1 [y/N]: " answer # équivalent du input() en python
  case "$answer" in
    [Yy]* ) return 0 ;;  # Retourne vrai si la réponse est oui
    * ) return 1 ;;  # Retourne faux sinon
  esac
}

# === INITIALISATION ===

mkdir -p "$LOG_DIR"  # Création du répertoire des logs s'il n'existe pas
touch "$LOG_FILE"  # Création du fichier de log
log "Starting post-installation script. Logged user: $USERNAME"

# Vérifie si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then # EUID = l'utilisateur utilisé, -ne = n'est pas égal, 0 = user root.
#donc si l'utilisateur utilisé n'est pas root, le script s'arrete 
  log "This script must be run as root."
  exit 1
fi

# === 1. MISE À JOUR DU SYSTÈME ===
log "Updating system packages..."
apt update && apt upgrade -y &>>"$LOG_FILE" #installe et capture le code d'erreur

# === 2. INSTALLATION DES PAQUETS ===
if [ -f "$PACKAGE_LIST" ]; then #-f vérifie si le fichier exite
  log "Reading package list from $PACKAGE_LIST" #indique qu'il lit le fichier
  while IFS= read -r pkg || [[ -n "$pkg" ]]; do # faire une boucle qui parcours toutes les lignes en ignorant
  # les commentaires et les espaces vides, a chaque ligne il lui reste donc uniquement le nom du packet à installer et il l'installe
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue  # Ignore les lignes vides et les commentaires
    check_and_install "$pkg"
  done < "$PACKAGE_LIST"
else #si il ne trouve pas le fichier il renvoie ca
  log "Package list file $PACKAGE_LIST not found. Skipping package installation."
fi

# === 3. MISE À JOUR DU MESSAGE DU JOUR (MOTD) ===
if [ -f "$CONFIG_DIR/motd.txt" ]; then #vérifie si le fichier existe
  cp "$CONFIG_DIR/motd.txt" /etc/motd #si il existe il le copie vers le répertoire motd
  log "MOTD updated." #annonce que motd est mis a jour
else
  log "motd.txt not found."
fi

# === 4. PERSONNALISATION DU .bashrc ===
if [ -f "$CONFIG_DIR/bashrc.append" ]; then #vérifie si le fichier existe, 
  cat "$CONFIG_DIR/bashrc.append" >> "$USER_HOME/.bashrc" #si il existe il ajoute le contenu dans bashrc
  chown "$USERNAME:$USERNAME" "$USER_HOME/.bashrc" # change le proprio de bashrc
  log ".bashrc customized."
else # fichier non trouvé donc il renvoie cette erreur
  log "bashrc.append not found."
fi

# === 5. PERSONNALISATION DU .nanorc ===
if [ -f "$CONFIG_DIR/nanorc.append" ]; then # fait exactement pareil que pour bashrc
  cat "$CONFIG_DIR/nanorc.append" >> "$USER_HOME/.nanorc"
  chown "$USERNAME:$USERNAME" "$USER_HOME/.nanorc"
  log ".nanorc customized."
else
  log "nanorc.append not found."
fi

# === 6. AJOUT D'UNE CLÉ SSH PUBLIQUE ===
if ask_yes_no "Would you like to add a public SSH key?"; then # demande si tu veux add une clé ssh en appelant une autre fonction
  read -p "Paste your public SSH key: " ssh_key # Affiche un message et te dit d'écrire ta clé publique
  mkdir -p "$USER_HOME/.ssh" # crée le dossier .ssh
  echo "$ssh_key" >> "$USER_HOME/.ssh/authorized_keys" # crée le fichier authorized_keys et y ajoute ta clé publique
  chown -R "$USERNAME:$USERNAME" "$USER_HOME/.ssh" # te met propio du dossier
  chmod 700 "$USER_HOME/.ssh" # défini les droits du dossier
  chmod 600 "$USER_HOME/.ssh/authorized_keys"# défini les droits du fichier
  log "SSH public key added." #affiche que la clé ssh à été ajouté
fi

# === 7. CONFIGURATION DE SSH POUR AUTHENTIFICATION PAR CLÉ UNIQUEMENT ===
if [ -f /etc/ssh/sshd_config ]; then # si le fichier sshd_config existe il fait la suite
# pour les lignes suivantes, sed = modifier un fichier, -i = modifier sans créer de copie
# "s" en début du chemin pour dire que l'élément A sera remplacé par l'élément B
# "^#\?" signifie qu'il va commencer à chercher en début de ligne les hashtag puis ce qu'il y a derriere qui contient
# par exmple "PasswordAuthentication" pour remplacer tout ca par PasswordAuthentication no
# ce processus est répété 3 fois pour changer 3 paramètres différents
  sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
  sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  systemctl restart ssh # redémarre ssh
  log "SSH configured to accept key-based authentication only." # affiche que la conf ssh à été sécurisé
else # si il ne trouve pas sshd_config il affiche juste ce message d'erreur
  log "sshd_config file not found."
fi

#affiche que le script à fini d'etre exécuté
log "Post-installation script completed."

exit 0 # met fin au script
