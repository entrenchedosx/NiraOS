# NiraOS Architecture Overview

NiraOS is not just a themed Linux distro; it is a fundamentally reimagined operating system built around isolated microservices communicating over gRPC and DBus.

## The Daemon Stack (Rust)
1. **`permission-manager` (Root)**: The impenetrable security gateway. No AI action executes without passing through this SQLite-backed capability verifier.
2. **`context-broker` (Root)**: Aggregates safe metadata (active windows, active processes) from the Compositor and feeds it to the AI.
3. **`ai-daemon` (Root)**: The intelligence kernel. Orchestrates `llama.cpp` inference and maintains the RAM-only short-term memory buffer.
4. **`action-manager` (User)**: Executes safe, rigidly-typed Protobuf actions (e.g. `application.launch`). It **never** executes generic bash commands.
5. **`settings-service` (User)**: Manages persistent desktop state (Dark Mode, Wallpapers) via DBus.
6. **`hardware-service` (User)**: Aggregates deep kernel telemetry (GPU drivers, thermals) for the Context Broker.

## The Desktop Stack (C++/QML)
- **`NiraCompositor`**: A QtWayland C++ compositor running strictly in the unprivileged `nira` user session. It traps global keybindings (Super+Space) securely.
- **`NiraShell`**: The beautiful QML desktop environment containing the NiraPanel and the signature AiOverlay.
