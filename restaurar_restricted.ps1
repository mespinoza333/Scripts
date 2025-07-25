# Ruta de log (puedes cambiarla si deseas)
$logPath = "C:\Windows\Temp\cambio_politica_ejecucion.log"

# Obtener la política actual
$policy = Get-ExecutionPolicy -Scope CurrentUser

# Registrar estado actual
Add-Content -Path $logPath -Value "$(Get-Date): Politica actual: $policy"

# Intentar cambiar a Restricted
try {
    Set-ExecutionPolicy Restricted -Scope CurrentUser -Force
    Add-Content -Path $logPath -Value "$(Get-Date): Politica cambiada a Restricted correctamente."
} catch {
    Add-Content -Path $logPath -Value "$(Get-Date): Error al cambiar la politica a Restricted: $_"
}
