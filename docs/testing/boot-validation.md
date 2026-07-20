# NiraOS Boot Validation Ledger

This document tracks the stability and boot performance of the NiraOS images across iterations.

## Environment: QEMU (x86_64)
- **Host**: Arch Linux
- **RAM**: 4GB
- **Disk**: `niraos.raw`
- **Bootloader**: `systemd-boot`

### Test 1: Image Alpha v0.1
- **Status**: PASS
- **Boot Time (Kernel to UI)**: ~4.2 seconds
- **Notes**: All 4 critical `systemd` services (`nira-context`, `nira-ai`, `nira-compositor`, `nira-shell`) loaded successfully. The AI Daemon successfully bound to the gRPC socket before the Shell initialized.

## Environment: Bare Metal (Thinkpad T14 Gen 3)
- **Status**: PENDING
- **Notes**: Awaiting hardware testing of Wayland nested scaling and AMD GPU initialization.
