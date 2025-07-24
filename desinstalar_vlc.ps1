$path = "C:\Program Files\VideoLAN\VLC\uninstall.exe"
if (Test-Path $path) {
    Start-Process -FilePath $path -ArgumentList "/S" -Wait
    Write-Host "✅ VLC desinstalado con uninstall.exe"
} else {
    Write-Host "⚠️ VLC no encontrado en la ruta predeterminada"
}
