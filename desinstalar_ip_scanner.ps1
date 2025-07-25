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
            # Caso especial para MSI
            if ($uninstallRaw -match "msiexec\.exe") {
                Write-Host "🔧 Detectado desinstalador MSI"

                # Extraer solo el GUID si viene en formato /X{GUID}
                if ($uninstallRaw -match "/X\s*{.+}") {
                    $args = $matches[0] + " /qn"
                    $msiExec = "$env:SystemRoot\System32\msiexec.exe"

                    Write-Host "🚀 Ejecutando en modo silencioso: $msiExec $args"
                    Start-Process -FilePath $msiExec -ArgumentList $args -Wait
                    Write-Host "✅ Desinstalación completada (MSI, silenciosa)."
                    $found = $true
                }
            }
            # Para otros desinstaladores EXE
            elseif ($uninstallRaw -match '^(?:"?)([^"]+\.exe)(?:"?\s?)(.*)$') {
                $exePath = $matches[1]
                $args = $matches[2] + " /quiet"

                if (Test-Path $exePath) {
                    Write-Host "🚀 Ejecutando: $exePath $args"
                    Start-Process -FilePath $exePath -ArgumentList $args -Wait
                    Write-Host "✅ Desinstalación completada (EXE, silenciosa)."
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
