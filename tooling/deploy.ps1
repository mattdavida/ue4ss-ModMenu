# Local iteration only. Official downloads come from the v* tag job
# in .github/workflows/ci.yml — do not upload a local publish as the public build.
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "Player zip..."
npm run deploy
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

New-Item -ItemType Directory -Force -Path publish/win-x64 | Out-Null
Copy-Item dist/ModMenu.zip publish/win-x64/ModMenu.zip

Write-Host "Publishing CLI win-x64..."
dotnet publish tooling/CLI/ModMenu.CLI.csproj -c Release -r win-x64 --self-contained true -o publish/win-x64
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Publishing Studio win-x64..."
dotnet publish tooling/Studio/ModMenu.Studio.csproj -c Release -r win-x64 --self-contained true -o publish/win-x64
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Get-ChildItem publish/win-x64 -File | ForEach-Object {
    $mb = [math]::Round($_.Length / 1MB, 1)
    Write-Host "  $($_.Name) ($mb MB)"
}
