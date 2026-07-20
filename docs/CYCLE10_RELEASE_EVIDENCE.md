# NiraOS Cycle 10 recovery evidence

Date: 2026-07-19

## Summary

Cycle 10 is a verified development image, not a production release. It boots
to the NiraOS greeter, starts the core services, provides a working Qt/Wayland
desktop, and includes Falkon as a real QtWebEngine browser and default HTTP(S)
handler. The base image is never attached read-write by the maintained QEMU
launchers.

Artifact: `NiraOS-cycle10.raw`

SHA-256: `982FBF0BD4A64D973B9A6F9D0D9A3659537DEEE4CEDEBCC37C1915C59F542C5F`

Raw size: 4,490,960,896 bytes

## Root causes and repairs

1. QtWayland repositions maximized clients from `availableGeometry`. Exposing
   the panel work area before the shell acknowledged its first configure moved
   the fullscreen shell below the panel. The compositor now establishes the
   shell against the physical output first and enables the application work
   area only after the shell is committed.
2. XDG application ID and title arrive after initial surface creation. The
   compositor previously registered empty metadata, which broke taskbar
   identity. Explicit metadata signal connections now reconcile live changes.
3. Host GL/VirGL was an unsafe default for the reported host-instability
   scenario. QEMU now defaults to 2D VirtIO plus guest software rendering and
   communicates the mode through QEMU `fw_cfg`. VirGL is diagnostic opt-in.
4. The headless verifier used `-display none`; QMP could create a valid-sized
   all-black capture and the verifier accepted it. It now uses a local Unix VNC
   surface and rejects captures without visible pixel content.
5. The image had no supported web browser. Falkon, QtWebEngine dependencies,
   URL-handler defaults, Breeze icons, and its PySide runtime are installed.
6. Falkon's packaged Python support plugin was present without PySide6. The
   dependency is now explicit, eliminating the broken shared-library load.
7. Wallpaper startup deliberately tried a missing mutable path before falling
   back, producing a false error. The watcher now exposes the existing custom
   wallpaper or installed default as one observable property.
8. An unused AI agent-loop file was only a commented skeleton. The real tool
   dispatch path lives in the gRPC implementation, so the dead skeleton was
   removed rather than presented as functionality.

## Files changed in this cycle

- `CMakeLists.txt`
- `mkosi.conf`
- `mkosi.postinst.chroot`
- `run-qemu.sh`
- `scripts/run-qemu.ps1`
- `scripts/verify-qemu.sh`
- `scripts/dump_screen.py`
- `mkosi/mkosi.extra/usr/bin/start-nira-session`
- `mkosi/mkosi.extra/etc/xdg/mimeapps.list`
- `desktop/compositor/qml/Main.qml`
- `desktop/compositor/src/WallpaperWatcher.cpp`
- `desktop/compositor/src/WallpaperWatcher.h`
- `desktop/shell/qml/TopPanel.qml`
- `desktop/shell/src/main.cpp`
- `core/ai-daemon/src/agent/mod.rs`
- `core/ai-daemon/src/agent/loop.rs` (removed)
- `core/ai-daemon/src/security/mod.rs`
- `tests/integration/test_dump_screen.py`
- `tests/integration/test_image_contract.py`
- `tests/qa/test_guest_runtime.py`

## Verification performed

- Clean Cycle 10 mkosi build: passed.
- Qt compositor, shell, greeter, and settings release build: passed.
- Rust release build: passed. NiraOS-owned warnings were removed; five warnings
  remain in bindgen-generated `llama-cpp-sys-2` output.
- Host integration tests: 11 passed.
- Bash syntax checks and PowerShell parser checks: passed.
- Read-only artifact audit: Falkon 26.04.3, PySide6 6.11.1, default HTTPS
  handler, executable session wrapper, no embedded GGUF, and all five enabled
  units verified.
- `systemd-analyze --root ... verify` for greetd and the four core daemons:
  passed.
- Repaired 75-second QEMU verifier: passed; serial reached
  `graphical.target`, QEMU remained alive, and a 1280x800 non-black greeter
  framebuffer was captured.
- Full interactive Cycle 9 test after the runtime changes: graphical login,
  panel browser launch, Falkon start page, HTTPS `example.com`, live taskbar
  title, maximize with reserved panel, minimize, and taskbar restore all
  passed. Cycle 10 then rebuilt the same runtime plus build/dead-code cleanup
  and passed the artifact verifier.
- Runtime Cycle 9 service check: zero failed units, zero core-service restarts,
  and no coredumps. HTTPS returned status 200 with TLS verification result 0.
- QtWebEngine renderer check: `NoNewPrivs=1` and seccomp filtering mode 2.

Evidence is stored in `verification-artifacts-cycle10/`, plus the
`screenshot-cycle9-*.png` captures in the repository root.

## Measured development-VM behavior

- TCG boot to `graphical.target`: 27.355 seconds.
- Four-GiB VM after desktop and browser workload: 1,405 MiB used and 2,495 MiB
  available.
- Settled sampling showed the compositor and browser idle during the interval,
  but llvmpipe/TCG is not representative of hardware-accelerated performance.

## Risks and production blockers

1. The root filesystem is mutable ext4. There is no verified read-only root,
   dm-verity, signed A/B update, rollback, installer, or recovery environment.
2. The image contains a fixed development account and password. A first-boot
   account flow, secret rotation, and credential policy are mandatory.
3. Hardware graphics and VirGL remain unverified. Safe QEMU mode deliberately
   uses llvmpipe, and two harmless Mesa Vulkan-probe errors remain on Falkon
   startup. A physical Intel/AMD/NVIDIA matrix is required.
4. The custom QtWayland compositor supports the tested Qt clients but does not
   yet expose the protocol breadth expected by a general desktop, including
   complete data-device, clipboard, drag-and-drop, portal, and application
   sandbox integration.
5. No local model is embedded. The AI daemon correctly reports that no model
   is loaded; model provenance, signed downloads, resource admission, and a
   full approval UI remain incomplete.
6. IPC permission design is not yet a production authorization boundary. Peer
   credential validation, per-capability grants, revocation, audit review, and
   adversarial tests remain required.
7. File manager, software center, multi-monitor/workspace behavior, update UI,
   accessibility coverage, Bluetooth/network UI, notifications, and recovery
   tooling are not complete daily-driver features.
8. A WSL instance reset was observed after an interactive VM run. The guest
   had no failed unit or coredump immediately beforehand, and the reset removed
   the entire WSL PID namespace and `/tmp`, so causation is unresolved. A
   native-QEMU/host event-trace stress campaign is required before claiming
   the original host-instability problem is closed.
9. CI configuration was inspected locally but not proven on a remote runner in
   this cycle.

## Recommended next gate

Do not add visual features before the production foundation gate: implement a
signed immutable A/B image and recovery boot, remove the development account,
run native-host and physical-hardware stress tests, broaden required Wayland
protocols, and complete capability enforcement for AI actions. Only after
those gates pass should this image be promoted beyond development status.
