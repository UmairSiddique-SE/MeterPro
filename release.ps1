param([string]$version)

if (-not $version) {
    Write-Host "Sahi tareeka: .\release.ps1 -version 1.0.1" -ForegroundColor Red
    exit
}

Write-Host "`n[1/4] APK build ho rahi hai..." -ForegroundColor Cyan
flutter clean
flutter pub get
flutter build apk --release

# Rename the APK to MeterPro.apk
Rename-Item \"build\app\outputs\flutter-apk\app-release.apk\" \"MeterPro.apk\" -Force

Write-Host "`n[2/4] GitHub Release ban rahi hai..." -ForegroundColor Cyan
# Purani release delete karna (agar koi error wali bani ho)
gh release delete "v$version" --yes --cleanup-tag 2>$null

# Nayi release banana aur APK attach karna
gh release create "v$version" "build\app\outputs\flutter-apk\MeterPro.apk" --title "MeterPro v$version" --notes "Update v$version"

$apkUrl = "https://github.com/UmairSiddique-SE/MeterPro/releases/download/v$version/MeterPro.apk"

Write-Host "`n[3/4] Code GitHub par push ho raha hai..." -ForegroundColor Cyan
git add .
git commit -m "Release v$version"
git push

Write-Host "`n[4/4] Website deploy ho rahi hai..." -ForegroundColor Cyan
firebase deploy --only hosting

Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "DONE! Ab sirf yeh 1 kaam manually karein:" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Firebase Console -> Firestore -> app_config -> android document mein:"
Write-Host "  version      = $version"
Write-Host "  apkUrl       = $apkUrl"
Write-Host ""
Write-Host "Naya APK link (copy kar lein):" -ForegroundColor Yellow
Write-Host $apkUrl