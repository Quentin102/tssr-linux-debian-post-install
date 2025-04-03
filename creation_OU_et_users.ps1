# Définition du domaine et des OU
$DomainDN = (Get-ADDomain).DistinguishedName
$OU_Core = "OU=CORE,$DomainDN"
$OU_Humans = "OU=HUMANS,$OU_Core"
$OU_Users = "OU=USERS,$OU_Humans"
$OU_Admin = "OU=ADMIN,$OU_Humans"

# Fonction pour vérifier si une OU existe
function Test-OUExists {
    param ($OU)
    return [bool](Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$OU'" -ErrorAction SilentlyContinue)
}

# Création des OU si elles n'existent pas
$OUs = @($OU_Core, $OU_Humans, $OU_Users, $OU_Admin)
foreach ($OU in $OUs) {
    if (-not (Test-OUExists -OU $OU)) {
        $OUName = $OU -split "," | Select-Object -First 1
        New-ADOrganizationalUnit -Name ($OUName -replace "OU=","") -Path ($OU -replace "$OUName,") -ProtectedFromAccidentalDeletion $true
        Write-Host "OU $OUName créée."
    } else {
        Write-Host "OU $OU existe déjà."
    }
}

# Vérification de la structure après création
Write-Host "`nVérification finale de la structure :"
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName | Where-Object { $_.DistinguishedName -like "*CORE*" } | Sort-Object DistinguishedName | Format-Table -AutoSize

# Lecture du fichier CSV et ajout des utilisateurs
$CSVFile = "C:\Users\admin\Desktop\add_users.csv"

if (Test-Path $CSVFile) {
    $Users = Import-Csv -Path $CSVFile

    foreach ($User in $Users) {
        $SamAccountName = $User.SamAccountName
        $GivenName = $User.GivenName
        $Surname = $User.Surname
        $Role = $User.Role
        $Password = ConvertTo-SecureString $User.Password -AsPlainText -Force

        # Déterminer l'OU cible en fonction du rôle
        if ($Role -eq "ADMIN") {
            $OU_Target = $OU_Admin
        } elseif ($Role -eq "USER") {
            $OU_Target = $OU_Users
        } else {
            Write-Host "Erreur : Rôle non valide pour $SamAccountName"
            continue
        }

        # Vérifier si l'utilisateur existe déjà
        if (Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -ErrorAction SilentlyContinue) {
            Write-Host "L'utilisateur $SamAccountName existe déjà."
        } else {
            # Créer l'utilisateur
            New-ADUser -SamAccountName $SamAccountName `
                       -UserPrincipalName "$SamAccountName@$((Get-ADDomain).Forest)" `
                       -GivenName $GivenName `
                       -Surname $Surname `
                       -Name "$GivenName $Surname" `
                       -Path $OU_Target `
                       -AccountPassword $Password `
                       -Enabled $true `
                       -PasswordNeverExpires $true

            Write-Host "Utilisateur $SamAccountName créé et ajouté à $OU_Target."
        }
    }
} else {
    Write-Host "Le fichier $CSVFile n'existe pas. Impossible d'ajouter des utilisateurs."
}
