# ParamÃ¨tres de l'AD
$DomainName = "quentin.local"  # Change avec le nom de domaine souhaitÃ©
$NetBiosName = "QUENTIN"       # Change avec ton nom NetBIOS
$SafeModePassword = ConvertTo-SecureString "Root2024*" -AsPlainText -Force  # Mot de passe DSRM (mode rÃ©cupÃ©ration)
$IPAddress = "192.168.0.100"          # Change avec l'adresse IP de ton serveur
$SubnetMask = "255.255.255.0"         # Masque de sous-rÃ©seau
$Gateway = "192.168.0.254"            # Passerelle
$LocalAdminPassword = "Root2024*"  # Nouveau mot de passe pour l'administrateur local
$DNSServer = $IPAddress  # Le serveur DNS doit pointer vers lui-même
$AdminUser = "admin"
$AdminPass = ConvertTo-SecureString "Root2024*" -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($AdminUser, $AdminPass)



# Vérifier si le rôle DNS est installé
if (-not (Get-WindowsFeature -Name DNS).Installed) {
    Write-Host "Installation du rôle DNS..."
    Install-WindowsFeature -Name DNS -IncludeManagementTools
    Write-Host "Rôle DNS installé."
} else {
    Write-Host "Le rôle DNS est déjà installé."
}

# Vérifier si le rôle AD DS est installé
if (-not (Get-WindowsFeature -Name AD-Domain-Services).Installed) {
    Write-Host "Installation du rôle AD DS..."
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    Write-Host "Rôle AD DS installé."
} else {
    Write-Host "Le rôle AD DS est déjà installé."
}

# Vérifier si le serveur est déjà contrôleur de domaine
try {
    $DomainCheck = Get-ADDomain -ErrorAction Stop
    Write-Host "Ce serveur est déjà un contrôleur de domaine."
} catch {
    Write-Host "Promotion en contrôleur de domaine..."

    # Promotion en tant que DC
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainNetbiosName $NetBIOSName `
        -SafeModeAdministratorPassword $SafeModePassword `
        -InstallDNS `
        -Confirm:$false `
        -Force

    Write-Host "Contrôleur de domaine installé."
}

# Configurer le serveur DNS pour qu'il se pointe sur lui-même
Write-Host "Configuration du DNS..."
Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses $DNSServer

# Redémarrage du serveur pour appliquer les modifications
Write-Host "Redémarrage du serveur dans 10 secondes..."
Start-Sleep -Seconds 10
"Restart-Computer -Force"
