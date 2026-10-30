# PolyVoice AI - Automated Android APK Builder Script
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "       POLYVOICE AI - ANDROID APK BUILDER         " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Check if flutter command is available
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue

if (-not $flutterCmd) {
    # Check common installation locations
    $possiblePaths = @(
        "C:\flutter\bin\flutter.bat",
        "C:\src\flutter\bin\flutter.bat",
        "$env:LOCALAPPDATA\flutter\bin\flutter.bat",
        "$env:USERPROFILE\flutter\bin\flutter.bat"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $flutterCmd = $path
            break
        }
    }
}

if (-not $flutterCmd) {
    Write-Host "`n[!] Flutter SDK chua duoc tim thay tren may cua ban." -ForegroundColor Yellow
    Write-Host "Ban co 2 cach de tao file .apk:" -ForegroundColor White
    Write-Host "  Cach 1 (Khuyen dung - Khong can cai dat gi):" -ForegroundColor Green
    Write-Host "    Day code len GitHub repo, GitHub Actions se tu dong build ra file .apk san de tai ve." -ForegroundColor White
    Write-Host "  Cach 2 (Build truc tiep tren may):" -ForegroundColor Green
    Write-Host "    Cai Flutter SDK tai https://docs.flutter.dev va chay: flutter build apk --release`n" -ForegroundColor White
    Exit 1
}

Write-Host "`n[*] Dang tai cac goi thu vien (flutter pub get)..." -ForegroundColor Yellow
& $flutterCmd pub get

if ($LASTEXITCODE -ne 0) {
    Write-Host "[x] Loi khi chay flutter pub get" -ForegroundColor Red
    Exit $LASTEXITCODE
}

Write-Host "`n[*] Dang tien hanh bien dich file APK (flutter build apk --release)..." -ForegroundColor Yellow
& $flutterCmd build apk --release --android-skip-build-dependency-validation

if ($LASTEXITCODE -eq 0) {
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        Write-Host "`n[v] THANH CONG! File APK da duoc tao tai:" -ForegroundColor Green
        Write-Host "    $((Get-Item $apkPath).FullName)" -ForegroundColor Cyan
    }
} else {
    Write-Host "[x] Qua trinh build APK gap loi." -ForegroundColor Red
}
