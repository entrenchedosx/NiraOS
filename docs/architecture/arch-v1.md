# NiraOS Architecture — Master Plan v1

## Design Philosophy

NiraOS is a production-quality Linux desktop where AI is a native capability,
not an overlay. The core desktop experience — windows, files, settings, apps —
must be flawless with or without AI. AI enhances and automates; it does not
replace fundamental desktop paradigms.

---

## 1. Hardware Targets

Modern hardware minimums; no compromise on UX for underpowered machines.

| Tier | RAM | Storage | GPU | AI Model |
|---|---|---|---|---|
| Minimum | 8 GB | 64 GB SSD | Intel UHD / AMD Vega / Nvidia entry | 1.5B–3B Q4 |
| Standard | 16 GB | 256 GB SSD | Modern integrated GPU | Phi-4 Mini (3.8B Q4) |
| Performance | 32 GB | 1 TB NVMe | Dedicated GPU (RTX / RDNA / Arc) | Larger local models, GPU accel |

The OS is fully usable without AI. No feature depends on the AI daemon being
available.

---

## 2. Application Packaging — Flatpak First

The system root is immutable (mkosi-generated). Normal applications must never
write to `/usr`.

| Layer | Technology | Purpose |
|---|---|---|
| System | mkosi image | Immutable base OS |
| GUI apps | Flatpak | Primary application format. Flathub-compatible |
| App discovery | Nira Store | GUI for browsing/installing Flatpaks |
| Developer tools | Distrobox containers | Isolated pacman/apt environments for dev |

**.deb / .rpm are explicitly prohibited from modifying the primary OS root.**

---

## 3. Desktop Environment

### 3.1 Login & Session Management
**Component:** `nira-greeter` — QML frontend for greetd.
- Password / biometric auth via PAM
- Multi-user switching
- Unlocks secure keyring on session start

### 3.2 Desktop Space
**Component:** `nira-shell/desktop` — QML Desktop Grid.
- Draggable icons with grid snapping
- Right-click context menus
- Backed by `~/Desktop` directory via native File Manager daemon
- Rendered in `backgroundLayer` above wallpaper, below windows

### 3.3 Taskbar & Start Menu
**Component:** `nira-shell/panel`.
- Pinned apps, running window indicators
- System tray (Wi-Fi, Bluetooth, Audio, Battery, Clock)
- AI Indicator (daemon connection status)
- Start Menu: search-first UI (apps via .desktop parsing, files via Tracker3)

### 3.4 Window Manager
**Component:** `nira-compositor`.
- Server-side decorations (SSD) for non-CSD clients
- Snap-to-edge, dynamic tiling, floating windows
- Virtual workspaces
- Alt+Tab switcher overlay
- **Protocol:** `wlr-foreign-toplevel-management` for taskbar integration

### 3.5 Native Applications
| App | Stack | Purpose |
|---|---|---|
| Nira Files | Qt/C++ | File manager (tabs, SMB/NFS, udisks2, thumbnails) |
| Nira Settings | QML + gRPC | Modular settings frontend for settings-service |
| Nira Store | QML + Flatpak backend | Flatpak discovery and installation |
| Nira Terminal | Qt/VTE or Alacritty core | GPU-accelerated terminal |
| Nira Monitor | Qt/C++ | Per-process CPU/RAM/GPU monitor |

---

## 4. IPC Architecture

All Rust daemons communicate via gRPC over **Unix Domain Sockets** (Phase 2).

| Service | Socket | Purpose |
|---|---|---|
| `permission-manager` | `/run/niraos/permission.sock` | Capability evaluation + audit log |
| `action-manager` | `/run/niraos/action.sock` | Execute filesystem/desktop/app actions |
| `context-broker` | `/run/niraos/context.sock` | Active window, clipboard, system context |
| `ai-daemon` | `/run/niraos/ai.sock` | LLM inference (actor model worker) |
| `settings-service` | `/run/niraos/settings.sock` | Persistent key-value config store |
| `hardware-service` | `/run/niraos/hardware.sock` | CPU/memory/battery telemetry |
| `notification-service` | D-Bus `org.freedesktop.Notifications` | Desktop notifications |

Peer credential verification (`SO_PEERCRED`) on `permission.sock` enforces that
only the trusted `nira` user can request capability evaluations.

---

## 5. AI Integration

AI is a background intelligence layer, invoked explicitly.

| Trigger | Action |
|---|---|
| `Super+A` | AI overlay for natural-language prompts |
| Right-click → AI Actions | Summarize / Organize / Rename files |
| Settings → natural language | Translate user intent into action-manager RPCs |
| Notification summary | Background low-priority summarization |

All AI actions require explicit Polkit-style user approval unless a session
allowance is granted. The `permission-manager` blocks every action until the
user confirms via a graphical dialog spawned by the shell.

---

## 6. Development Roadmap

### Phase 1 — Desktop Foundations (Non-AI)
- Window manager: minimize/maximize, SSD, movement, resizing
- Taskbar: `wlr-foreign-toplevel-management` protocol support
- Start Menu: `.desktop` file parsing
- Basic settings GUI: wallpaper, theme, display resolution
- **Success:** User can launch apps, switch between them, resize, change wallpaper

### Phase 2 — Security & App Ecosystem
- **IPC UDS migration** — all daemons to Unix sockets + `SO_PEERCRED`
- Nira Files (Qt/C++ file manager)
- Nira Store (Flatpak installer GUI)
- Desktop Grid (`~/Desktop` icons)
- **Success:** Unprivileged processes can't access system RPCs. Flatpak installation works.

### Phase 3 — AI Tooling & Context
- Adaptive AI model loader (hardware detection → model selection)
- AI context menus in File Manager and Desktop
- Context-broker reads Wayland clipboard via D-Bus
- **Success:** User highlights text, presses Super+A, asks "Explain this", gets answer

### Phase 4 — Polish & Developer Tools
- nira-greeter login screen
- Micro-animations (hover states, window transitions, blur)
- Distrobox developer containers
- **Success:** Boot → Login → Desktop with fluid animations. Developers work without breaking immutable root.

---

## 7. Confirmed Decisions

**IPC Security:** UDS migration is approved for Phase 2. TCP loopback is acceptable
for alpha but must be replaced before beta.

**Window Manager Protocol:** `wlr-foreign-toplevel-management` is the approved
protocol for taskbar integration. No proprietary Qt-only IPC.

**Application Model:** Flatpak-first. .deb/.rpm explicitly prohibited. Developer
containers for advanced users.

**Hardware Targets:** Minimum 8 GB RAM, 64 GB SSD. Adaptive AI model selection
by tier. OS fully functional without AI.
