# Paramètres de l'AD
$DomainName = "monentreprise.local"  # Change avec le nom de domaine souhaité
$NetBiosName = "MONENTREPRISE"       # Change avec ton nom NetBIOS
$SafeModePassword = "MonMotDePasseSecurise123!"  # Mot de passe DSRM (mode récupération)
$IPAddress = "192.168.1.100"          # Change avec l'adresse IP de ton serveur
$SubnetMask = "255.255.255.0"         # Masque de sous-réseau
$Gateway = "192.168.1.254"            # Passerelle
$LocalAdminPassword = "MotDePasseAdminLocal123!"  # Nouveau mot de passe pour l'administrateur local

# Étape 1 : Vérifier si le rôle AD DS est déjà installé
$ADDSRole = Get-WindowsFeature -Name AD-Domain-Services
if ($ADDSRole.Installed) {
    Write-Host "Le rôle Active Directory Domain Services est déjà installé."
} else {
    Write-Host "Installation du rôle Active Directory Domain Services..."
    Install-WindowsFeature -Name AD-Domain-Services
}

# Étape 2 : Vérifier si le rôle DNS est installé
$DNSRole = Get-WindowsFeature -Name DNS
if ($DNSRole.Installed) {
    Write-Host "Le rôle DNS est déjà installé."
} else {
    Write-Host "Installation du rôle DNS..."
    Install-WindowsFeature -Name DNS
}

# Étape 3 : Modifier le mot de passe de l'administrateur local
Write-Host "Modification du mot de passe de l'administrateur local..."
$localAdmin = Get-LocalUser -Name "Administrateur"
if ($localAdmin) {
    Set-LocalUser -Name "Administrateur" -Password (ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force)
    Write-Host "Le mot de passe de l'administrateur local a été modifié."
} else {
    Write-Host "Le compte administrateur local n'existe pas."
}

# Étape 4 : Vérifier si le serveur est déjà un contrôleur de domaine
try {
    $DomainCheck = Get-ADDomain -ErrorAction Stop
    Write-Host "Le serveur est déjà un contrôleur de domaine : $($DomainCheck.Name)"
} catch {
    Write-Host "Le serveur n'est pas encore promu, nous allons procéder à la promotion..."

    # Configurer l'adresse IP, masque et passerelle (au cas où ce n'est pas fait)
    Write-Host "Configuration des paramètres réseau..."
    New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress $IPAddress -PrefixLength 24 -DefaultGateway $Gateway
    Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses $IPAddress

    # Promotion du serveur en contrôleur de domaine avec l'installation du rôle DNS
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainNetbiosName $NetBiosName `
        -SafeModeAdministratorPassword (ConvertTo-SecureString $SafeModePassword -AsPlainText -Force) `
        -InstallDns `
        -Force

    Write-Host "Promotion terminée, le serveur sera redémarré maintenant..."
    Restart-Computer -Force
}

# Vérification après redémarrage
Start-Sleep -Seconds 60  # Attendre 60 secondes après le redémarrage

# Tester si le serveur est bien un contrôleur de domaine après le redémarrage
try {
    $DomainCheck = Get-ADDomain -ErrorAction Stop
    Write-Host "Le serveur est maintenant promu en contrôleur de domaine : $($DomainCheck.Name)"
} catch {
    Write-Host "Erreur : Le serveur n'a pas été promu avec succès."
}

# Vérification des contrôleurs de domaine
Get-ADDomainController
