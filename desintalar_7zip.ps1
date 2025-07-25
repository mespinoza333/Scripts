# Ejecutar como administrador
Write-Host " Buscando instalaciones de 7-Zip..." -ForegroundColor Cyan

# Parte 1: Buscar y desinstalar con Win32_Product (WMI)
try {
    $installedApps = Get-WmiObject -Class Win32_Product | Where-Object {
        $_.Name -like "*7-Zip*"
    }

    foreach ($app in $installedApps) {
        Write-Host " Desinstalando (WMI): $($app.Name)" -ForegroundColor Yellow
        try {
            $app.Uninstall() | Out-Null
            Write-Host " $($app.Name) desinstalado con exito." -ForegroundColor Green
        } catch {
            Write-Host " Error al desinstalar $($app.Name): $($_)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "⚠️ Error al consultar aplicaciones por WMI: $($_)" -ForegroundColor Red
}

# Parte 2: Buscar en el registro y desinstalar
$registryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

foreach ($path in $registryPaths) {
    try {
        Get-ChildItem $path | ForEach-Object {
            $appProps = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            $displayName = $appProps.DisplayName
            $uninstallString = $appProps.UninstallString

            if ($displayName -like "*7-Zip*") {
                Write-Host " Encontrado en el registro: $displayName" -ForegroundColor Yellow

                if ($uninstallString) {
                    # Manejo de comillas si hay espacios
                    if ($uninstallString -notlike '"*') {
                        $uninstallString = '"' + $uninstallString + '"'
                    }

                    Write-Host " Ejecutando: $uninstallString /S" -ForegroundColor Gray
                    try {
                        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallString /S" -Wait -NoNewWindow
                        Write-Host " $displayName desinstalado (registro)." -ForegroundColor Green
                    } catch {
                        Write-Host " Error al desinstalar $displayName desde registro: $($_)" -ForegroundColor Red
                    }
                }
            }
        }
    } catch {
        Write-Host "⚠ Error al leer el registro: $($_)" -ForegroundColor Red
    }
}

Write-Host "`n🧹 Proceso de limpieza de 7-Zip finalizado." -ForegroundColor Cyan
