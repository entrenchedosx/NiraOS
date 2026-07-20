# NiraOS 0.1.0-alpha Release Notes

Welcome to the first public Alpha Release of NiraOS!

NiraOS is an immutable, Wayland-native operating system built entirely around a locally running AI intelligence layer. 

## Key Features in 0.1.0-alpha

- **Strict Capability Security**: The AI operates without root access. All actions it wishes to take (e.g., launching apps, modifying files) are rigorously parsed by the `PermissionManager` as statically-typed Protobufs.
- **The AI Overlay**: Press `Super + Space` to summon the Nira AI. It instantly reads context from your active Wayland windows.
- **Immutable Updates**: Root filesystems are flashed safely into A/B partitions. If an update fails to boot, `systemd-boot` natively rolls back to the previous image.
- **Local Model Manager**: To keep the initial download small (< 2GB), the base OS image does not include LLM weights. Simply connect to WiFi and use the QML `Model Manager` to download the Fast Profile (Qwen 1.5B) directly to your system.

## Known Issues
- Hardware acceleration for NVIDIA via proprietary CUDA modules must be explicitly tested. The standard ISO relies on the Mesa stack (`vulkan-radeon`, `iris`).
- The short-term memory buffer is volatile and explicitly flushes on reboot to preserve privacy.

*Thank you for testing the frontier of desktop operating systems.*
