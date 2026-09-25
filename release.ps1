param([string]$version)

if (-not $version) {
    Write-Host "Sahi tareeka: .\release.ps1 -version 1.0.3" -ForegroundColor Red
    exit 1
}

$tag = "v$version"

Write-Host "[1/4] APK release build..." -ForegroundColor Cyan
flutter clean
flutter pub get
flutter analyze
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter build apk --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[2/4] Git commit + tag push..." -ForegroundColor Cyan
git add .
git commit -m "Release $tag"
if ($LASTEXITCODE -ne 0) { Write-Host "No new changes to commit; continuing..." -ForegroundColor Yellow }
git push
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git tag $tag
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git push origin $tag
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[3/4] GitHub Actions release..." -ForegroundColor Cyan
Write-Host "Tag $tag pushed. GitHub Actions will build and attach MeterPro.apk automatically." -ForegroundColor Green
Write-Host "Release URL: https://github.com/UmairSiddique-SE/MeterPro/releases/tag/$tag" -ForegroundColor Yellow

Write-Host "[4/4] Firebase Hosting deploy..." -ForegroundColor Cyan
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$apkUrl = "https://github.com/UmairSiddique-SE/MeterPro/releases/latest/download/MeterPro.apk"
Write-Host "Release workflow started successfully." -ForegroundColor Green
Write-Host "Website APK URL: $apkUrl" -ForegroundColor Yellow
Write-Host "GitHub Actions may take a few minutes to publish the APK." -ForegroundColor Cyan