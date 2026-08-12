# Run AutoParts on a USB-connected Android phone.
# Prerequisites: USB debugging enabled, phone unlocked, same Wi‑Fi as PC.

$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
    Write-Host "ADB not found. Install Android Studio / SDK platform-tools." -ForegroundColor Red
    exit 1
}

Write-Host "Checking for phone..." -ForegroundColor Cyan
& $adb devices

$devices = & $adb devices | Select-String "device$"
if (-not $devices) {
    Write-Host ""
    Write-Host "No phone detected. On your Android phone:" -ForegroundColor Yellow
    Write-Host "  1. Settings -> About phone -> tap Build number 7 times"
    Write-Host "  2. Settings -> Developer options -> enable USB debugging"
    Write-Host "  3. Connect USB cable, tap Allow on the phone"
    Write-Host "  4. Run this script again"
    exit 1
}

$ip = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.InterfaceAlias -notmatch 'Loopback|vEthernet|WSL' -and $_.IPAddress -notlike '169.*' } |
    Select-Object -First 1).IPAddress

if ($ip) {
    Write-Host "Using API host: $ip (phone must use same Wi‑Fi)" -ForegroundColor Green
    flutter run -d android --dart-define=API_HOST=$ip
} else {
    Write-Host "Could not detect Wi‑Fi IP. Using default in app_constants.dart" -ForegroundColor Yellow
    flutter run -d android
}
