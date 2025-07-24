# Ruta temporal para guardar el instalador
$vlcInstaller = "C:\Windows\Temp\vlc_installer.exe"

# URL directa al instalador de VLC (verificada)
$url = "https://download.videolan.org/pub/videolan/vlc/3.0.20/win64/vlc-3.0.20-win64.exe"

# Descargar el instalador
Invoke-WebRequest -Uri $url -OutFile $vlcInstaller -UseBasicParsing

# Validar si el archivo descargado es valido (mayor a 10MB)
if ((Get-Item $vlcInstaller).Length -gt 10000000) {
    # Ejecutar el instalador en modo silencioso
    Start-Process -FilePath $vlcInstaller -ArgumentList "/S" -Wait

    # Eliminar el instalador despues de instalar
    Remove-Item $vlcInstaller -Force

    Write-Host "✅ VLC Media Player instalado correctamente."
} else {
    Write-Host "❌ Error: el archivo descargado no es valido. Verifica la URL."
    Remove-Item $vlcInstaller -Force -ErrorAction SilentlyContinue
}
