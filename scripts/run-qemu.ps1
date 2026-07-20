param(
    [switch]$EnableVirgl,
    [switch]$DisableNetwork,
    [switch]$KeepOverlay,
    [string]$ImagePath,
    [string]$WslDistribution = "archlinux"
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ImageWindows = if ([string]::IsNullOrWhiteSpace($ImagePath)) {
    Join-Path $RepoRoot "NiraOS.raw"
} else {
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ImagePath)
}

if (!(Test-Path -LiteralPath $ImageWindows -PathType Leaf)) {
    throw "NiraOS.raw was not found at $ImageWindows. Build the image before booting it."
}

$Image = (wsl -d $WslDistribution -u root -e wslpath -a $ImageWindows).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Image)) {
    throw "Could not translate the image path for WSL distribution '$WslDistribution'."
}

$OVMF = "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
wsl -d $WslDistribution -u root -e test -r $OVMF
if ($LASTEXITCODE -ne 0) {
    throw "OVMF firmware was not found at $OVMF in '$WslDistribution'."
}

# Never attach the build artifact read-write. A disposable qcow2 overlay makes
# every test run reproducible and prevents a crash or guest update from
# corrupting the image that is being evaluated.
$Overlay = "/tmp/niraos-run-$([guid]::NewGuid().ToString('N')).qcow2"
wsl -d $WslDistribution -u root -e qemu-img create -q -f qcow2 -F raw -b $Image $Overlay
if ($LASTEXITCODE -ne 0) {
    throw "Could not create the disposable QEMU overlay at $Overlay."
}

# VirGL crosses the guest/host graphics boundary and has caused host-driver
# instability during development. The default is deliberately 2D VirtIO KMS
# with no host OpenGL. Hardware acceleration is an explicit diagnostic opt-in.
$Gpu = if ($EnableVirgl) {
    "virtio-gpu-gl-pci,edid=on,xres=1920,yres=1080"
} else {
    "virtio-gpu-pci,edid=on,xres=1920,yres=1080"
}
$Display = if ($EnableVirgl) { "gtk,gl=on" } else { "gtk,gl=off" }
$GraphicsMode = if ($EnableVirgl) { "hardware" } else { "software" }

$QemuArgs = @(
    "-accel", "kvm"
    "-accel", "tcg"
    "-cpu", "qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt"
    "-m", "8192"
    "-smp", "4"
    "-drive", "if=pflash,format=raw,readonly=on,file=$OVMF"
    "-drive", "if=virtio,format=qcow2,file=$Overlay"
    "-vga", "none"
    "-device", $Gpu
    "-device", "virtio-keyboard-pci"
    "-device", "virtio-tablet-pci"
    "-fw_cfg", "name=opt/nira/graphics-mode,string=$GraphicsMode"
    "-display", $Display
    "-serial", "stdio"
)

if ($DisableNetwork) {
    $QemuArgs += @("-net", "none")
} else {
    $QemuArgs += @(
        "-netdev", "user,id=nira-net"
        "-device", "virtio-net-pci,netdev=nira-net"
    )
}

$Mode = if ($EnableVirgl) { "VirGL diagnostic mode" } else { "safe 2D mode" }
Write-Host "Booting NiraOS in $Mode with one VirtIO GPU..." -ForegroundColor Cyan
try {
    wsl -d $WslDistribution -u root -e env GDK_BACKEND=x11 qemu-system-x86_64 @QemuArgs
    $QemuExitCode = $LASTEXITCODE
} finally {
    if ($KeepOverlay) {
        Write-Host "Preserved guest overlay: $Overlay" -ForegroundColor Yellow
    } else {
        wsl -d $WslDistribution -u root -e rm -f -- $Overlay
    }
}
exit $QemuExitCode
