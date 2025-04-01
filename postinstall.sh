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
  if dpkg -s "$pkg" &>/dev/null; then
    log "$pkg is already installed."
  else
    log "Installing $pkg..."
    apt install -y "$pkg" &>>"$LOG_FILE"
    if [ $? -eq 0 ]; then
      log "$pkg successfully installed."
    else
      log "Failed to install $pkg."
    fi
  fi
}

# Demande à l'utilisateur une confirmation (Oui/Non)
ask_yes_no() {
  read -p "$1 [y/N]: " answer
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
if [ "$EUID" -ne 0 ]; then
  log "This script must be run as root."
  exit 1
fi

# === 1. MISE À JOUR DU SYSTÈME ===
log "Updating system packages..."
apt update && apt upgrade -y &>>"$LOG_FILE"

# === 2. INSTALLATION DES PAQUETS ===
if [ -f "$PACKAGE_LIST" ]; then
  log "Reading package list from $PACKAGE_LIST"
  while IFS= read -r pkg || [[ -n "$pkg" ]]; do
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue  # Ignore les lignes vides et les commentaires
    check_and_install "$pkg"
  done < "$PACKAGE_LIST"
else
  log "Package list file $PACKAGE_LIST not found. Skipping package installation."
fi

# === 3. MISE À JOUR DU MESSAGE DU JOUR (MOTD) ===
if [ -f "$CONFIG_DIR/motd.txt" ]; then
  cp "$CONFIG_DIR/motd.txt" /etc/motd
  log "MOTD updated."
else
  log "motd.txt not found."
fi

# === 4. PERSONNALISATION DU .bashrc ===
if [ -f "$CONFIG_DIR/bashrc.append" ]; then
  cat "$CONFIG_DIR/bashrc.append" >> "$USER_HOME/.bashrc"
  chown "$USERNAME:$USERNAME" "$USER_HOME/.bashrc"
  log ".bashrc customized."
else
  log "bashrc.append not found."
fi

# === 5. PERSONNALISATION DU .nanorc ===
if [ -f "$CONFIG_DIR/nanorc.append" ]; then
  cat "$CONFIG_DIR/nanorc.append" >> "$USER_HOME/.nanorc"
  chown "$USERNAME:$USERNAME" "$USER_HOME/.nanorc"
  log ".nanorc customized."
else
  log "nanorc.append not found."
fi

# === 6. AJOUT D'UNE CLÉ SSH PUBLIQUE ===
if ask_yes_no "Would you like to add a public SSH key?"; then
  read -p "Paste your public SSH key: " ssh_key
  mkdir -p "$USER_HOME/.ssh"
  echo "$ssh_key" >> "$USER_HOME/.ssh/authorized_keys"
  chown -R "$USERNAME:$USERNAME" "$USER_HOME/.ssh"
  chmod 700 "$USER_HOME/.ssh"
  chmod 600 "$USER_HOME/.ssh/authorized_keys"
  log "SSH public key added."
fi

# === 7. CONFIGURATION DE SSH POUR AUTHENTIFICATION PAR CLÉ UNIQUEMENT ===
if [ -f /etc/ssh/sshd_config ]; then
  sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
  sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  systemctl restart ssh
  log "SSH configured to accept key-based authentication only."
else
  log "sshd_config file not found."
fi

log "Post-installation script completed."

exit 0
