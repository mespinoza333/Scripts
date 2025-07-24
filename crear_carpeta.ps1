# Ruta base
$basePath = "C:\Test1"
$folderName = "prueba1"

# Crea la carpeta base si no existe
if (-Not (Test-Path -Path $basePath)) {
    New-Item -ItemType Directory -Path $basePath | Out-Null
}

# Ruta completa
$fullPath = Join-Path -Path $basePath -ChildPath $folderName

# Crea la carpeta "prueba1" si no existe
if (-Not (Test-Path -Path $fullPath)) {
    New-Item -ItemType Directory -Path $fullPath
    Write-Host "La carpeta '$folderName' se ha creado exitosamente en $fullPath."
} else {
    Write-Host "La carpeta '$folderName' ya existe en $fullPath."
}
