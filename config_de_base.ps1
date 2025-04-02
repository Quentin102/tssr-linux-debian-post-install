# Définition du nom du serveur
Rename-Computer -NewName "AD-Server" -Force

# Configuration de l'adresse IP statique
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.1.100 -PrefixLength 24 -DefaultGateway 192.168.1.254
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 192.168.1.100

# Activation du pare-feu avec règles spécifiques
New-NetFirewallRule -DisplayName "Allow AD Traffic" -Direction Inbound -Protocol TCP -LocalPort 389,636,53 -Action Allow

