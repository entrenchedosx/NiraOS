param(
    [string]$Version = "0.1.0-alpha"
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Write-Host "Starting NiraOS Alpha Integration Build..." -ForegroundColor Cyan

# 1. Compile Rust Daemons
$daemons = @("ai-daemon", "context-broker", "permission-manager", "action-manager", "model-manager", "settings-service")

$Env:NIRA_VERSION = $Version

Write-Host "Generating BUILD_MANIFEST.json..." -ForegroundColor Cyan
$commitHash = (git -C $RepoRoot rev-parse --verify HEAD 2>$null)
if ($LASTEXITCODE -ne 0) { $commitHash = "uncommitted" }
$buildTimestamp = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$manifest = @{
    version = $Env:NIRA_VERSION
    commit = $commitHash
    timestamp = $buildTimestamp
}
$manifest | ConvertTo-Json | Out-File -FilePath (Join-Path $RepoRoot "BUILD_MANIFEST.json") -Encoding utf8
Write-Host "Manifest generated." -ForegroundColor Green

Write-Host "Building Core Daemons (Rust)..." -ForegroundColor Cyan
Push-Location $RepoRoot
try {
    cargo build --release --locked --workspace
    if ($LASTEXITCODE -ne 0) { throw "Cargo build failed with exit code $LASTEXITCODE." }
} finally {
    Pop-Location
}

# 2. Compile Qt/C++ Components
Write-Host "Qt Components are built internally by mkosi.build.chroot during image generation." -ForegroundColor Yellow

Write-Host "Build Pipeline Completed Successfully!" -ForegroundColor Green
