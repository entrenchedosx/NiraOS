# PowerShell script to build NiraOS via Docker
# Use this fallback if WSL is broken or natively unavailable on Windows.

Write-Host "Starting NiraOS Build via Docker Container..." -ForegroundColor Cyan

# Check for Docker
if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install Docker Desktop for Windows to use this fallback." -ForegroundColor Yellow
    exit 1
}

$WorkspaceDir = (Get-Item .).FullName

Write-Host "Pulling Arch Linux image and starting build..." -ForegroundColor Yellow

# Run a privileged container (required for mkosi loop devices)
# Mount the current workspace directory to /src
docker run --rm --privileged -v "${WorkspaceDir}:/src" -w /src archlinux:latest bash -c "
    echo 'Installing build dependencies inside container...' &&
    pacman -Syu --noconfirm mkosi systemd btrfs-progs e2fsprogs &&
    echo 'Running mkosi...' &&
    mkosi
"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Docker build completed successfully. NiraOS.raw generated." -ForegroundColor Green
} else {
    Write-Host "Docker build failed." -ForegroundColor Red
    exit $LASTEXITCODE
}
