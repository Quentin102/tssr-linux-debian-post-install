# Installation des rôles AD DS et outils de gestion
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Vérification de l’installation
if ((Get-WindowsFeature -Name AD-Domain-Services).InstallState -ne "Installed") {
    Write-Host "L'installation d'Active Directory a échoué !" -ForegroundColor Red
    exit 1
}

# Promotion du serveur en contrôleur de domaine
Install-ADDSForest `
-DomainName "quentin.com" `
-CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "Win2016" `
-ForestMode "Win2016" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$true `
-SysvolPath "C:\Windows\SYSVOL" `
-Force:$true

# Redémarrage du serveur pour finaliser l’installation
Write-Host "Redémarrage du serveur dans 10 secondes..."
Start-Sleep -Seconds 10
Restart-Computer -Force
