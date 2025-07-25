# Ruta de log (puedes personalizarla)
$logPath = "C:\Windows\Temp\cambio_politica_ejecucion.log"

# Obtener la política actual
$policy = Get-ExecutionPolicy -Scope CurrentUser

# Registrar la política actual
Add-Content -Path $logPath -Value "$(Get-Date): Politica actual: $policy"

# Verificar si es Restricted
if ($policy -eq "Restricted") {
    try {
        Set-ExecutionPolicy Bypass -Scope CurrentUser -Force
        Add-Content -Path $logPath -Value "$(Get-Date): Politica cambiada a Bypass correctamente."
    } catch {
        Add-Content -Path $logPath -Value "$(Get-Date): Error al cambiar la politica: $_"
    }
} else {
    Add-Content -Path $logPath -Value "$(Get-Date): No se realizo ningun cambio. Politica ya es: $policy"
}
