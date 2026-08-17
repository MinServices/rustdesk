# ==============================================================================
# Script: Build RustDesk Flutter UI & Package Single-File Installer (.exe) on Windows
# ==============================================================================
$ErrorActionPreference = "Stop"

# 0. Set up environment variables
$env:LIBCLANG_PATH = "C:\Program Files\LLVM\bin"
$env:PATH = "C:\Program Files\LLVM\bin;G:\Tool code\flutter\bin;" + $env:PATH

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "1. Generate Flutter-Rust bridge code" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
flutter_rust_bridge_codegen --rust-input ./src/flutter_ffi.rs --dart-output ./flutter/lib/generated_bridge.dart --c-output ./flutter/macos/Runner/bridge_generated.h

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "2. Build Virtual Display dylib" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Push-Location "libs/virtual_display/dylib"
cargo build --locked --release
Pop-Location

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "3. Build Rust Core Library (librustdesk.dll)" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
cargo build --locked --features flutter --lib --release

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "4. Build Flutter Desktop App (Windows Release)" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Push-Location "flutter"
flutter pub get
flutter build windows --release
Pop-Location

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "5. Copy supplementary dependencies" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
$releaseDir = "flutter\build\windows\x64\runner\Release"
if (Test-Path "target\release\deps\dylib_virtual_display.dll") {
    Copy-Item "target\release\deps\dylib_virtual_display.dll" -Destination $releaseDir -Force
    Write-Host "Copied dylib_virtual_display.dll to $releaseDir"
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "6. Package into single-file installer (.exe)" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Push-Location "libs/portable"
python -m pip install -q -r requirements.txt
python ./generate.py -f "../../$releaseDir" -o . -e "$releaseDir/rustdesk.exe" -l 6
cargo build --locked --release
Pop-Location

# Copy setup file to root directory
$installerName = "rustdesk-setup.exe"
if (Test-Path "target\release\rustdesk-portable-packer.exe") {
    Copy-Item "target\release\rustdesk-portable-packer.exe" -Destination $installerName -Force
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "FLUTTER BUILD & PACKAGING COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "Extracted App Directory: $releaseDir" -ForegroundColor Cyan
Write-Host "Single-File Installer:   .\$installerName" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
