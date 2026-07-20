# Hardware Failure Matrix

Tracking system recovery when drivers crash or hardware state changes radically.

## Scenario 1: GPU Driver Panic
- **Trigger**: `nvidia-open` crashes during an intense Wayland rendering session.
- **Recovery**: `systemd` detects `nira-compositor.service` died. It instantly restarts the service. The `ai-daemon` continues running uninterrupted in the background because it is a decoupled system service.

## Scenario 2: Storage Exhaustion
- **Trigger**: AI attempts to download a 20GB model with only 5GB of free space.
- **Recovery**: `model-manager` gracefully catches the `ENOSPC` error, aborts the stream, and emits a DBus notification to the QML shell informing the user, rather than hard-crashing the OS.
