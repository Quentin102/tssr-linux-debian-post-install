# ParamÃ¨tres de l'AD
$DomainName = "quentin.local"  # Change avec le nom de domaine souhaitÃ©
$NetBiosName = "QUENTIN"       # Change avec ton nom NetBIOS
$SafeModePassword = "Root2024*"  # Mot de passe DSRM (mode rÃ©cupÃ©ration)
$IPAddress = "192.168.0.100"          # Change avec l'adresse IP de ton serveur
$SubnetMask = "255.255.255.0"         # Masque de sous-rÃ©seau
$Gateway = "192.168.0.254"            # Passerelle
$LocalAdminPassword = "Root2024*"  # Nouveau mot de passe pour l'administrateur local

# Ã‰tape 1 : VÃ©rifier si le rÃ´le AD DS est dÃ©jÃ  installÃ©
$ADDSRole = Get-WindowsFeature -Name AD-Domain-Services
if ($ADDSRole.Installed) {
    Write-Host "Le rÃ´le Active Directory Domain Services est dÃ©jÃ  installÃ©."
} else {
    Write-Host "Installation du rÃ´le Active Directory Domain Services..."
    Install-WindowsFeature -Name AD-Domain-Services
}

# Ã‰tape 2 : VÃ©rifier si le rÃ´le DNS est installÃ©
$DNSRole = Get-WindowsFeature -Name DNS
if ($DNSRole.Installed) {
    Write-Host "Le rÃ´le DNS est dÃ©jÃ  installÃ©."
} else {
    Write-Host "Installation du rÃ´le DNS..."
    Install-WindowsFeature -Name DNS
}

# Ã‰tape 3 : Modifier le mot de passe de l'administrateur local
Write-Host "Modification du mot de passe de l'administrateur local..."
$localAdmin = Get-LocalUser -Name "Administrateur"
if ($localAdmin) {
    Set-LocalUser -Name "Administrateur" -Password (ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force)
    Write-Host "Le mot de passe de l'administrateur local a Ã©tÃ© modifiÃ©."
} else {
    Write-Host "Le compte administrateur local n'existe pas."
}

# Ã‰tape 4 : VÃ©rifier si le serveur est dÃ©jÃ  un contrÃ´leur de domaine
try {
    $DomainCheck = Get-ADDomain -ErrorAction Stop
    Write-Host "Le serveur est dÃ©jÃ  un contrÃ´leur de domaine : $($DomainCheck.Name)"
} catch {
    Write-Host "Le serveur n'est pas encore promu, nous allons procÃ©der Ã  la promotion..."

    # Configurer l'adresse IP, masque et passerelle (au cas oÃ¹ ce n'est pas fait)
    Write-Host "Configuration des paramÃ¨tres rÃ©seau..."
    New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress $IPAddress -PrefixLength 24 -DefaultGateway $Gateway
    Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses $IPAddress

    # Promotion du serveur en contrÃ´leur de domaine avec l'installation du rÃ´le DNS
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainNetbiosName $NetBiosName `
        -SafeModeAdministratorPassword (ConvertTo-SecureString $SafeModePassword -AsPlainText -Force) `
        -InstallDns `
        -Force

    Write-Host "Promotion terminÃ©e, le serveur sera redÃ©marrÃ© maintenant..."
    Restart-Computer -Force
}

# VÃ©rification aprÃ¨s redÃ©marrage
Start-Sleep -Seconds 60  # Attendre 60 secondes aprÃ¨s le redÃ©marrage

# Tester si le serveur est bien un contrÃ´leur de domaine aprÃ¨s le redÃ©marrage
try {
    $DomainCheck = Get-ADDomain -ErrorAction Stop
    Write-Host "Le serveur est maintenant promu en contrÃ´leur de domaine : $($DomainCheck.Name)"
} catch {
    Write-Host "Erreur : Le serveur n'a pas Ã©tÃ© promu avec succÃ¨s."
}

# VÃ©rification des contrÃ´leurs de domaine
Get-ADDomainController
