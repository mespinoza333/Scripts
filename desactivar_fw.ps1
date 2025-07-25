# Desactivar Firewall para los 3 perfiles
Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False
