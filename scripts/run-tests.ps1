$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

# NiraOS Automated QA Test Suite
# Tests IPC, Permissions, and AI payload validation.

Write-Host "Running NiraOS Automated Test Suite..." -ForegroundColor Cyan

Push-Location $RepoRoot
Write-Host "Running Cargo tests across the workspace..." -ForegroundColor Yellow
cargo test --release --locked --workspace
$TestExitCode = $LASTEXITCODE
Pop-Location

if ($TestExitCode -eq 0) {
    Write-Host "All Cargo tests passed." -ForegroundColor Green
} else {
    Write-Host "Tests failed!" -ForegroundColor Red
    exit 1
}

Push-Location $RepoRoot
try {
    python -m unittest discover -s tests/integration -p "test_*.py" -v
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}
