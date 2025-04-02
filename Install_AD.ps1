# Définition des paramètres du domaine
$DomainName = "quentin.local"  # Nom du domaine
$NetBiosName = "QUENTIN"       # Nom NetBIOS
$SafeModePassword = "M0tDeP@ssAD!"    # Mot de passe du mode restauration

# Vérifier si AD DS est déjà installé
if (Get-WindowsFeature -Name AD-Domain-Services | Where-Object { $_.Installed -eq $true }) {
    Write-Host "Le rôle AD DS est déjà installé."
} else {
    # Installation du rôle AD DS
    Write-Host "Installation du rôle Active Directory..."
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
}

# Vérifier si le domaine existe déjà
if (-not (Get-ADDomain -ErrorAction SilentlyContinue)) {
    Write-Host "Création d'un nouveau domaine : $DomainName"

    # Création du domaine Active Directory
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainNetbiosName $NetBiosName `
        -SafeModeAdministratorPassword (ConvertTo-SecureString $SafeModePassword -AsPlainText -Force) `
        -InstallDns `
        -Force

    Write-Host "Le contrôleur de domaine a été configuré avec succès !"
    
    # Redémarrage du serveur pour appliquer la configuration
    Write-Host "Redémarrage du serveur..."
    Restart-Computer -Force
} else {
    Write-Host "Le domaine existe déjà : $DomainName"
}
