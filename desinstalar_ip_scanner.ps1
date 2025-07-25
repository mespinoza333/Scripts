Write-Host "🔍 Buscando instalación de Advanced IP Scanner..."

$found = $false

$registryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($path in $registryPaths) {
    Get-ItemProperty $path 2>$null |
    Where-Object { $_.DisplayName -like "*Advanced IP Scanner*" } |
    ForEach-Object {
        Write-Host "📦 Encontrado: $($_.DisplayName)"

        $uninstallRaw = $_.UninstallString

        if ($uninstallRaw) {
            # Caso especial para MsiExec
            if ($uninstallRaw -match "msiexec\.exe") {
                Write-Host "🔧 Detectado desinstalador MSI"

                $msiArgs = $uninstallRaw -replace '(?i)msiexec\.exe', '' # Quitar el ejecutable
                $msiArgs = $msiArgs.Trim()

                $msiExec = "$env:SystemRoot\System32\msiexec.exe"

                Write-Host "🚀 Ejecutando: $msiExec $msiArgs"
                Start-Process -FilePath $msiExec -ArgumentList $msiArgs -Wait
                Write-Host "✅ Desinstalación completada (MSI)."
                $found = $true
            }
            # Para otros desinstaladores .exe tradicionales
            elseif ($uninstallRaw -match '^(?:"?)([^"]+\.exe)(?:"?\s?)(.*)$') {
                $exePath = $matches[1]
                $args = $matches[2]

                if (Test-Path $exePath) {
                    Write-Host "🚀 Ejecutando: $exePath $args"
                    Start-Process -FilePath $exePath -ArgumentList $args -Wait
                    Write-Host "✅ Desinstalación completada (EXE)."
                    $found = $true
                } else {
                    Write-Host "❌ El ejecutable no existe: $exePath"
                }
            } else {
                Write-Host "⚠️ No se pudo interpretar correctamente el UninstallString: $uninstallRaw"
            }
        }
    }
}

# Borrar posibles carpetas residuales
$portablePaths = @(
    "$env:APPDATA\Advanced IP Scanner",
    "$env:ProgramFiles\Advanced IP Scanner",
    "$env:ProgramFiles(x86)\Advanced IP Scanner"
)

foreach ($folder in $portablePaths) {
    if (Test-Path $folder) {
        Write-Host "🗑️ Eliminando carpeta residual: $folder"
        Remove-Item -Path $folder -Recurse -Force
        $found = $true
    }
}

if (-not $found) {
    Write-Host "⚠️ No se encontró Advanced IP Scanner instalado o ya fue eliminado."
} else {
    Write-Host "🧹 Limpieza de Advanced IP Scanner finalizada."
}
