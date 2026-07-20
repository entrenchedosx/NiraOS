# NiraOS Wayland Architecture

## 1. Component Overview
- **Nira Compositor**: The pure display server layer (Qt Wayland). It handles KMS/DRM, `libinput`, and surface buffers (Wayland clients).
- **Nira Shell**: The Desktop UI layer (Qt6/QML). Runs as a Wayland client to the compositor.

## 2. Data Flow
Hardware Input -> Libinput -> Compositor -> Wayland Input Events (XdgShell/LayerShell) -> Shell (UI) -> gRPC Client -> AI Daemon (llama.cpp) -> gRPC Streaming Response -> Shell UI Update.

## 3. Security Model
The compositor itself has no concept of AI or capabilities; it simply draws pixels and routes input securely.
The Shell talks to the AI via strict gRPC endpoints. The AI *cannot* inject inputs into the compositor directly to fake user input. Any AI-initiated action must return to the Context Broker which evaluates them against the Capability Manifests before executing them.

## 4. Future Roadmap
1. Test nesting under X11/Wayland before full DRM deployment.
2. Integrate `wlr-layer-shell` for true panel positioning independent of standard windowing.
3. Lock down shell-compositor IPC to prevent unauthorized apps from reading AI tokens off the screen.
