# Paramètres réseau
$ipAddress = "192.168.0.100"
$subnetMask = 24  # Windows utilise un préfixe (ex: 255.255.255.0 = 24)
$gateway = "192.168.0.254"
$dnsServer = "1.1.1.1"
$interfaceName = "Ethernet0"  # ⚠️ Vérifie avec Get-NetAdapter

# Vérifier si l'interface existe
$interface = Get-NetAdapter | Where-Object { $_.Name -eq $interfaceName -and $_.Status -eq "Up" }

if ($interface) {
    Write-Host "Interface trouvée : $interfaceName"
    
    # Supprimer toutes les adresses IP existantes
    Write-Host "Suppression des IPs existantes..."
    Get-NetIPAddress -InterfaceAlias $interfaceName -AddressFamily IPv4 | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

    # Supprimer la passerelle existante
    Write-Host "Suppression de la passerelle existante..."
    Remove-NetRoute -InterfaceAlias $interfaceName -Confirm:$false -ErrorAction SilentlyContinue

    # Appliquer la nouvelle configuration IP
    Write-Host "Application de la nouvelle configuration IP..."
    New-NetIPAddress -InterfaceAlias $interfaceName -IPAddress $ipAddress -PrefixLength $subnetMask -DefaultGateway $gateway -ErrorAction Stop

    # Configuration du DNS
    Write-Host "Configuration du DNS manuel : $dnsServer"
    Set-DnsClientServerAddress -InterfaceAlias $interfaceName -ServerAddresses $dnsServer -ErrorAction Stop

    # Vérification des paramètres appliqués
    Write-Host "Configuration appliquée :"
    Get-NetIPAddress -InterfaceAlias $interfaceName | Format-Table
    Get-DnsClientServerAddress -InterfaceAlias $interfaceName | Format-Table

} else {
    Write-Host "⚠️ Erreur : L'interface réseau '$interfaceName' n'a pas été trouvée ou est inactive."
}
