# NiraOS Hardware Compatibility

This ledger tracks the out-of-the-box driver experience of the immutable Arch Linux image.

## Device: Thinkpad T14 Gen 3 (AMD)
- **Status**: PASSED
- **Display**: Wayland session native resolution (2560x1600).
- **WiFi**: Intel AX211 initialized successfully via NetworkManager.
- **Audio**: Pipewire detected speakers and mic instantly.
- **GPU**: AMD Radeon 680M utilized via Vulkan backend for AI inference.

## Device: Desktop (NVIDIA RTX 3050)
- **Status**: PENDING
- **Notes**: Need to verify if the open-source `nouveau` driver handles Vulkan offloading sufficiently, or if we must bundle the proprietary NVIDIA driver inside the `mkosi` build image.
