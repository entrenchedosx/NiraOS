# NiraOS Recovery Audit

Audit date: 2026-07-17

This document records the repository state observed before the recovery changes.
Nothing listed as implemented below was accepted based on source presence or prior
documentation alone.

## Release blocker summary

The checked-in project was not an operating-system release candidate.  The image
could boot systemd, but the graphical session exited repeatedly and the AI daemon
entered a crash loop.  Multiple subsystems returned simulated success or fabricated
data.  The project must not claim immutable A/B updates, a functional desktop, or
an AI safety boundary until the relevant runtime validation passes.

## Build and image pipeline

- `mkosi.build.chroot` commented out `cargo build --release --workspace`, then
  copied release binaries that may not exist or may be stale.
- The AI engine was built with host CPU features.  The recorded QEMU journal shows
  `SIGILL` in `ggml_cpu_init`, consistent with emitting instructions unsupported
  by the virtual CPU.
- The CMake root comments out all gRPC generation and all desktop applications
  other than the compositor and shell.
- CI installs an incomplete Qt dependency set, does not run Rust tests, and uses
  image names and mkosi invocations inconsistent with the local configuration.
- The release workflow builds individual crates, does not build the compositor,
  and publishes a path that the mkosi configuration does not produce.
- Build scripts reference hard-coded Windows and WSL paths and cannot be relied on
  as a portable build interface.

## Boot, storage, recovery, and package management

- `mkosi.conf` creates a generic bootable disk but defines no A/B layout, read-only
  root filesystem, verity protection, or persistent `/var`/`/home` layout.
- The `systemd-sysupdate` file refers to a placeholder release origin and target
  partition labels that are not created by the image configuration.
- The recovery script changes the boot default to `@saved`; it does not identify,
  validate, or activate a known-good deployment.
- The developer overlay script overlays `/usr` on its own mount point and has no
  mount validation or teardown path.
- The documentation promises Flatpak-based app management, but Flatpak is not an
  image dependency and the app manager crate is not a workspace member.
- Image and user passwords are hard-coded in tracked configuration.

## Service graph and privilege separation

- There are two divergent sets of systemd units.  The installed set differs from
  the root `systemd/` set and several user units name services that the image does
  not consistently install or start.
- The action service runs as `root`; its code has no allowlist and claimed success
  without dispatching an action.
- Permission, context, action, and AI gRPC servers use unauthenticated loopback
  TCP.  A local process can impersonate a caller; `CapabilityRequest` contains no
  authenticated principal.
- The permission database is always in-memory despite declaring a persistent path.
- Permission evaluation automatically allowed every capability except names
  containing `wipe` or `format`; no user approval, expiry, or audit record was
  implemented.
- Service hardening, writable-path restrictions, model directory ownership, and
  socket ownership were absent or inconsistent.

## AI system

- The AI daemon initialized llama.cpp even with no model and crashed at startup in
  QEMU with `SIGILL` in `ggml_cpu_init`.
- `generate_stream` did not call llama.cpp.  It streamed a formatted echo of the
  prompt and reported fabricated hardware/VRAM values.
- The model configuration did not control context length or batch size.
- The agent loop, model registry, downloader abstractions, validator, and security
  manager were skeletons.
- Model download was an unauthenticated direct URL fetch with no manifest,
  checksum, signature, size limit, atomic staging, disk-space check, or retry
  policy.
- The shell's C++ `AiClient` emitted the hard-coded text `Live gRPC Stream!`; it
  neither linked gRPC nor contacted the daemon.

## Context, permissions, and actions

- The context broker fabricated the active window and subscription event.
- The process collector fabricated Firefox/compositor CPU values.  The window
  collector fabricated a VS Code title.
- File reading checked only a string for `..`, did not canonicalize symlinks, did
  not constrain roots, and did not ask the permission service.
- The context cache has no get/set/invalidate implementation.
- Actions were not dispatched.  Application launch and wallpaper changes only
  logged a line; action RPC returned successful completion after permission.
- File move accepted any absolute paths and did not enforce a user-owned root,
  destination policy, symlink policy, or audit trail.

## Desktop and graphics

- The C++ `NiraCompositor` class is not included in the compositor target.  Its
  implementation creates a dummy `QWindow` and has no window-management logic.
- The QML compositor has no configured seat/input policy, maps every client to the
  full output, and has no focus, move, resize, stacking, output, or lifecycle
  management.  It cannot be considered a desktop compositor.
- The session wrapper assumes an `eglfs` compositor, polls a single socket, starts
  background processes without supervising the shell, and exits whenever the
  compositor exits.  The recorded journal contains repeated greetd sessions ending
  without a created graphical session.
- The shell offers static Wi-Fi, audio, battery, time, applications, model status,
  and AI memory values.  Its buttons do not connect to system services.
- Permission and action dialogs are visual-only; clicking them has no IPC effect.
- No GPU/input/display fallback policy or automated graphical smoke test existed.

## Tests, diagnostics, and documentation

- The Rust integration test and all Python QA tests asserted `true` rather than
  exercising a daemon, image, or service contract.
- QEMU scripts use conflicting image and firmware paths and do not capture or
  assert boot/service/desktop readiness.
- The GPU diagnostic always reported an unknown OpenGL version and treated merely
  spawning `vulkaninfo`/`nvidia-smi` as successful acceleration.
- Existing release, architecture, security, benchmark, and hardware documents
  contain claims contradicted by the source and journal evidence.  They are not
  validation records.

## Recovery acceptance rule

Until a component has an automated test and an observed runtime check, its state
is **unverified**.  Any unavailable operation must return an explicit error; it
must never emit placeholder output or a successful result.
