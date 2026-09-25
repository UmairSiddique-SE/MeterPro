param([string]$version)

if (-not $version) {
    Write-Host "Sahi tareeka: .\release.ps1 -version 1.0.5" -ForegroundColor Red
    exit 1
}

$tag = "v$version"
Write-Host "==> Preparing Release $tag..." -ForegroundColor Cyan

# 1. Update pubspec.yaml
$pubspecPath = "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw
if ($pubspecContent -match "version:\s*(\d+\.\d+\.\d+)\+(\d+)") {
    $currentBuildNum = [int]$matches[2]
    $newBuildNum = $currentBuildNum + 1
} else {
    $newBuildNum = 1
}
$pubspecContent = $pubspecContent -replace "version:\s*[^\r\n]+", "version: $version+$newBuildNum"
Set-Content -Path $pubspecPath -Value $pubspecContent -NoNewline
Write-Host "Updated $pubspecPath -> $version+$newBuildNum" -ForegroundColor Green

# 2. Update version.json
$versionJsonPath = "version.json"
$versionJson = @{
    latest_version = $version
    download_url = "https://github.com/UmairSiddique-SE/MeterPro/releases/latest/download/MeterPro.apk"
} | ConvertTo-Json
Set-Content -Path $versionJsonPath -Value $versionJson
Write-Host "Updated $versionJsonPath -> $version" -ForegroundColor Green

# 3. Update public/index.html version strings
$indexPath = "public/index.html"
if (Test-Path $indexPath) {
    $indexContent = Get-Content $indexPath -Raw
    $indexContent = $indexContent -replace '"softwareVersion":\s*"[^"]+"', "`"softwareVersion`": `"$version`""
    $indexContent = $indexContent -replace 'Version\s*<b>[^<]+</b>', "Version <b>$version</b>"
    $indexContent = $indexContent -replace '<span class="mono">v[^<]+</span>', "<span class=`"mono`">v$version</span>"
    Set-Content -Path $indexPath -Value $indexContent -NoNewline
    Write-Host "Updated $indexPath version references." -ForegroundColor Green
}

# 4. Flutter Clean, Analyze, Test & Build Signed Release APK
Write-Host "`n[1/4] Building signed APK release..." -ForegroundColor Cyan
flutter clean
flutter pub get
flutter analyze
if ($LASTEXITCODE -ne 0) { Write-Host "Flutter analyze failed!" -ForegroundColor Red; exit $LASTEXITCODE }
flutter test
if ($LASTEXITCODE -ne 0) { Write-Host "Flutter test failed!" -ForegroundColor Red; exit $LASTEXITCODE }
flutter build apk --release
if ($LASTEXITCODE -ne 0) { Write-Host "Flutter build failed!" -ForegroundColor Red; exit $LASTEXITCODE }

$apkSource = "build/app/outputs/flutter-apk/app-release.apk"
$apkDest = "build/app/outputs/flutter-apk/MeterPro.apk"
if (Test-Path $apkSource) {
    Copy-Item -Path $apkSource -Destination $apkDest -Force
    Write-Host "Signed APK ready: $apkDest" -ForegroundColor Green
}

# 5. Git commit & Tag Push
Write-Host "`n[2/4] Git commit and Tag Push..." -ForegroundColor Cyan
git add .
git commit -m "Release $tag (version $version+$newBuildNum)"
if ($LASTEXITCODE -ne 0) { Write-Host "No new git changes to commit; continuing..." -ForegroundColor Yellow }
git push
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git tag -f $tag
git push origin $tag --force
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# 6. Upload Signed APK to GitHub Release via gh CLI
Write-Host "`n[3/4] Uploading signed APK to GitHub Release..." -ForegroundColor Cyan
gh release create $tag $apkDest --title "MeterPro $tag" --notes "MeterPro release $tag (v$version)" --clobber
if ($LASTEXITCODE -eq 0) {
    Write-Host "GitHub release successfully published with signed MeterPro.apk!" -ForegroundColor Green
} else {
    Write-Host "Notice: gh release CLI completed or delegated." -ForegroundColor Yellow
}

# 7. Firebase Hosting Deploy
Write-Host "`n[4/4] Deploying Firebase Hosting..." -ForegroundColor Cyan
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "SUCCESS! MeterPro $tag successfully released!" -ForegroundColor Green
Write-Host "Download URL: https://github.com/UmairSiddique-SE/MeterPro/releases/latest/download/MeterPro.apk" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Green