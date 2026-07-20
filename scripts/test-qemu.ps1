param(
    [switch]$EnableVirgl,
    [string]$WslDistribution = "archlinux"
)

# Keep one authoritative QEMU device topology. This compatibility entry point
# exists for older documentation and delegates to the maintained launcher.
& (Join-Path $PSScriptRoot "run-qemu.ps1") `
    -EnableVirgl:$EnableVirgl `
    -WslDistribution $WslDistribution
exit $LASTEXITCODE
