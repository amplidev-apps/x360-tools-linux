# x360 Tools v2.0 - Windows Build & Bundle Script
# This script builds the Flutter app and bundles the Python backend.

$ErrorActionPreference = "Stop"

Write-Host "--- Packaging x360 Tools for Windows ---" -ForegroundColor Cyan

# 1. Check for Flutter
if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "Flutter not found in PATH. Please install Flutter for Windows."
}

# 2. Build Flutter App
Write-Host "[1/3] Building Flutter Windows executable..." -ForegroundColor Yellow
Set-Location "x360_tools_flutter"
flutter build windows --release
Set-Location ".."

# 3. Define Paths
$BuildDir = "x360_tools_flutter\build\windows\x64\runner\Release"
$AssetDest = "$BuildDir\data\flutter_assets\assets\python_backend"

# 4. Copy Python Backend
Write-Host "[2/3] Bundling Python backend to assets..." -ForegroundColor Yellow
if (Test-Path $AssetDest) { Remove-Item -Recurse -Force $AssetDest }
New-Item -ItemType Directory -Path $AssetDest -Force | Out-Null

# Copy core modules and bridge
Get-ChildItem -Exclude "x360_tools_flutter", "build_linux", "build_windows.ps1", ".git" | ForEach-Object {
    Copy-Item $_.FullName -Destination $AssetDest -Recurse -Force
}

# 5. Cleanup
Write-Host "[3/3] Finalizing bundle..." -ForegroundColor Yellow
# (Optional: Add python-portable folder here if the user wants a self-contained bundle)

Write-Host "`nSUCCESS! Your Windows build is ready in:" -ForegroundColor Green
Write-Host "$BuildDir" -ForegroundColor White
Write-Host "`nTo run the app, execute: x360_tools_flutter.exe" -ForegroundColor Cyan
