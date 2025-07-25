# Ruta del archivo de fondo
$wallpaper = "C:\SoporteTI\fondo.jpg"

# Validar que el archivo exista
if (Test-Path $wallpaper) {

    # Establecer el fondo en el registro
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $wallpaper

    # Opcional: establecer estilo (0=centrado, 2=ajustar, 6=rellenar, 10=ajustar sin distorsión)
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value "10"
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -Value "0"

    # Forzar actualización del fondo (esto es lo que suele fallar sin esto)
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
  [DllImport("user32.dll", SetLastError = true)]
  public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
    [Wallpaper]::SystemParametersInfo(20, 0, $wallpaper, 3)
    
    Write-Output " Fondo de pantalla aplicado correctamente."

} else {
    Write-Output " La imagen no se encuentra en la ruta especificada: $wallpaper"
}
