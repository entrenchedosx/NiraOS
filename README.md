# NiraOS

[![CI](https://github.com/entrenchedosx/NiraOS/actions/workflows/ci.yml/badge.svg)](https://github.com/entrenchedosx/NiraOS/actions/workflows/ci.yml)

**NiraOS** is an AI-first, immutable Linux distribution built on Arch Linux. It boots into a Qt6/Wayland compositor running a QML desktop shell, with a local LLM daemon (`nira-ai`, powered by `llama.cpp`) at its center. A fleet of Rust gRPC microservices provides system APIs that the desktop and apps consume over protobuf.

---

## Features

- **On-device AI** — Local LLM inference via `llama.cpp` (Phi-4-mini GGUF). No cloud dependency.
- **Wayland compositor** — Qt6-based `NiraCompositor` with hardware-accelerated rendering (Vulkan/EGL).
- **QML desktop shell** — `NiraShell` with a panel, application launcher, wallpaper picker, notification system, and AI overlay.
- **Greetd login** — greetd launches a QML greeter; after authentication, the user's Wayland session starts.
- **Rust microservices** — Context broker, permission manager, hardware monitor, settings service, and more, all communicating over gRPC.
- **First-party apps** — Notepad (Qt6 C++/QML), file manager (QML), settings panel, terminal (placeholder).
- **Immutable image** — Built with mkosi; updates delivered as full image replacements via `systemd-sysupdate`.
- **CI/CD** — GitHub Actions build the disk image on every push.

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Desktop (nira user)                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐  │
│  │NiraShell │  │Notepad   │  │Files     │  │Terminal │  │
│  │(QML)     │  │(Qt/QML)  │  │(Qt/QML)  │  │(planned)│  │
│  └────┬─────┘  └──────────┘  └──────────┘  └─────────┘  │
│       │              NiraCompositor (QtWayland)          │
│       └──────────────────────┬───────────────────────────┘
│                              │ gRPC over Unix socket
│  ┌──────────┬──────────┬─────┴─────┬──────────┬─────────┐│
│  │nira-ai   │nira-     │nira-      │nira-     │nira-    ││
│  │daemon    │context   │permission │settings  │hardware ││
│  │(LLM)     │broker    │manager    │service   │service  ││
│  └──────────┴──────────┴───────────┴──────────┴─────────┘│
└──────────────────────────────────────────────────────────┘
│ greetd → greeter (QML) → session (compositor + shell)    │
└──────────────────────────────────────────────────────────┘
```

All daemons communicate via protobuf-defined gRPC services (`ipc/proto/v1/`). The permission manager gates every AI action through a SQLite-backed capability verifier.

---

## Prerequisites

### Build host (recommended: WSL2 or native Linux)
- **mkosi** >= 26 (Arch: `pacman -S mkosi`)
- **qemu-system-x86_64** >= 8 (for testing in a VM)
- **Rust** toolchain (for the daemons)
- **CMake** + **Ninja** (for the Qt desktop stack)
- **Qt6** development packages: `qt6-base`, `qt6-declarative`, `qt6-wayland`, `qt6-tools`
- **protobuf** compiler (`protoc`) and `grpc` libraries

### Runtime (inside the image)
- Arch Linux base + `linux` kernel
- Mesa/Vulkan drivers (radeon, intel)
- greetd, pipewire, networkmanager
- Qt6, falkon, qterminal

---

## Build

```bash
# Clone the repository
git clone https://github.com/entrenchedosx/NiraOS.git
cd NiraOS

# Build the disk image
mkosi --force build
```

This produces `NiraOS.raw`, a bootable Arch Linux disk image with:
- All Rust daemons compiled in release mode
- The full Qt6 desktop stack (compositor, shell, greeter, settings, apps)
- Systemd units for all services
- The AI model GGUF file
- greetd configured to launch the NiraOS greeter

> **Note**: Building requires ~8 GB of disk space (cached packages + build artifacts). Rust compilation happens first (via `cargo build --release`), followed by CMake/Ninja for the Qt stack.

---

## Run (QEMU)

```bash
# Launch the VM
qemu-system-x86_64 -m 8G -smp 4 -accel kvm \
    -drive file=NiraOS.raw,format=raw \
    -display gtk,gl=on \
    -vga none -device virtio-vga-gl \
    -device virtio-keyboard -device virtio-mouse \
    -nic user,model=virtio-net-pci

# Headless mode (VNC)
qemu-system-x86_64 -m 8G -smp 4 -accel kvm \
    -drive file=NiraOS.raw,format=raw \
    -vnc :0 -k en-us \
    -serial stdio
```

On first boot, NiraOS boots to the greeter login screen. Log in with the `nira` user (password: `nira`).

---

## Project Structure

```
NiraOS/
├── mkosi.conf              # mkosi build configuration
├── mkosi.build.chroot      # Build script (Rust + CMake compilation)
├── mkosi.postinst.chroot   # Post-install setup (users, permissions, systemd)
├── mkosi/mkosi.extra/      # Extra files layered into the image
├── Cargo.toml              # Rust workspace root
├── CMakeLists.txt          # CMake build for the Qt desktop stack
├── ipc/proto/v1/           # Protobuf definitions (gRPC services)
├── core/                   # Rust microservices (workspace members)
│   ├── ai-daemon/          #   nira-ai: local LLM inference
│   ├── context-broker/     #   nira-context: active-window context
│   ├── permission-manager/ #   nira-permission: IPC access control
│   ├── action-manager/     #   nira-action: safe system actions
│   ├── hardware-service/   #   nira-hardware: telemetry
│   ├── settings-service/   #   nira-settings: persistent config
│   ├── notification-service/#   nira-notification: user notifications
│   └── model-manager/      #   nira-model: GGUF provisioning
├── desktop/                # Qt6 desktop stack (CMake + QML)
│   ├── compositor/         #   NiraCompositor (Wayland compositor)
│   ├── shell/              #   NiraShell (desktop shell QML)
│   ├── greeter/            #   NiraGreeter (login screen QML)
│   ├── settings/           #   Settings panel QML
│   ├── files/              #   File manager app
│   └── common/             #   Shared Qt utilities
├── apps/notepad/           # First-party Qt notepad app
├── systemd/                # Systemd unit files
├── assets/                 # Wallpapers, icons, cursors, models
├── scripts/                # Build, test, and utility scripts
├── docs/                   # Documentation
├── tests/                  # Integration and QA tests
└── .github/workflows/      # CI workflow
```

---

## Development

### Adding a new Rust daemon
1. Add the crate under `core/`.
2. Add it to the `members` list in `Cargo.toml`.
3. Define gRPC services in `ipc/proto/v1/`.
4. Add a systemd unit in `systemd/`.
5. The build script (`mkosi.build.chroot`) picks it up automatically.

### Modifying the desktop shell
QML files live in `desktop/shell/qml/`. After changes, rebuild just the shell:
```bash
cmake --build build --target nira-shell
```
Then rebuild the image (`mkosi --force build`).

### Testing in QEMU
The repository includes helper scripts for automated boot testing:
- `scripts/run-qemu.sh` — Launch QEMU with serial console
- `scripts/serial_login.py` — Automate login via serial
- `scripts/qmp_input.py` — Send keyboard input via QMP
- `scripts/vnc_screenshot.py` — Capture VNC screenshots

---

## License

NiraOS is released under the MIT License.
