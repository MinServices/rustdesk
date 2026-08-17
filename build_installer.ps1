# ==============================================================================
# Script: Quick Package RustDesk Installer (.exe) from Existing Release Directory
# ==============================================================================
$ErrorActionPreference = "Stop"

$releaseDir = "flutter\build\windows\x64\runner\Release"

if (-not (Test-Path "$releaseDir\rustdesk.exe")) {
    Write-Host "Error: Cannot find $releaseDir\rustdesk.exe! Please run .\build_flutter.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Packaging installer from $releaseDir..." -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan

Push-Location "libs/portable"
python -m pip install -q -r requirements.txt
python ./generate.py -f "../../$releaseDir" -o . -e "$releaseDir/rustdesk.exe" -l 6
cargo build --locked --release
Pop-Location

$installerName = "rustdesk-setup.exe"
if (Test-Path "target\release\rustdesk-portable-packer.exe") {
    Copy-Item "target\release\rustdesk-portable-packer.exe" -Destination $installerName -Force
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "PACKAGING COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "Single-File Installer: .\\$installerName" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
