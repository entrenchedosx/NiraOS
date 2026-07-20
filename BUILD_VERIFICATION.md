# NiraOS Build & Verification Guide

I cannot run mkosi or QEMU from this Windows environment. The build
requires a Linux environment (WSL/Arch Linux per the project setup).

Below are the exact commands to build and boot, and the checklist
for each verification point.

---

## 1. Build the disk image (WSL/Arch Linux)

From the WSL Arch Linux distribution:

```bash
cd /mnt/d/AetherOS

# Ensure mkosi is installed
sudo pacman -S mkosi

# Build the image (this runs mkosi.build.chroot which compiles
# all Rust daemons + Qt C++ components)
sudo mkosi --force build
```

Expected output:
- `NiraOS.raw` (or `AetherOS.raw` since the host dir is still named AetherOS)
- All Rust crates compile in the mkosi sandbox
- Qt compositor, shell, greeter, settings apps compile
- Proto files are compiled to C++ bindings

**If mkosi fails:** check `mkosi.build.chroot` line 28 —
`cargo build` uses the workspace Cargo.toml. The UDS-dependent
daemons (`permission-manager`, `action-manager`, etc.) require
`tokio::net::UnixListener` which only exists on Linux — this is
correct for the mkosi build.

---

## 2. Boot in QEMU

```bash
# From Windows PowerShell:
.\scripts\test-qemu.ps1

# Or from WSL:
qemu-system-x86_64 \
    -accel kvm -accel tcg \
    -cpu qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt \
    -m 8192 -smp 4 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
    -drive format=raw,file=/mnt/d/AetherOS/AetherOS.raw \
    -device virtio-gpu-pci,xres=1920,yres=1080 \
    -device virtio-keyboard-pci -device virtio-tablet-pci \
    -display gtk,gl=on \
    -serial stdio
```

---

## 3. Verification Checklist

### 3.1 Boot splash
**Check:** Does the system show the NiraOS initrd boot messages,
then the greeter login screen?

**If black screen:** Verify greetd is running (`systemctl status greetd`).
Check `/run/greetd.sock` exists. The greeter binary is at
`/usr/bin/nira-greeter`.

### 3.2 Greeter UI
**Check:** Glassmorphism login card with:
- NiraOS logo at top
- User list (shows "nira" from `/etc/passwd`)
- Password field with cyan focus border
- Sign In button with purple gradient

**If greeter crashes:** Run manually from a TTY:
```bash
sudo -u greeter /usr/bin/nira-greeter 2>&1
```
Common issues:
- Missing `/usr/share/niraos/wallpapers/wallpaper-lock.jpg`
- Missing `/usr/share/niraos/nira-logo.svg`
- `greetd` socket not readable by the `greeter` user

### 3.3 Session start
**Check:** After typing password and hitting Sign In:
- 600ms fade-to-black animation plays
- Greeter exits, `start-nira-session` launches
- Compositor starts (check `journalctl -t nira-compositor`)
- Shell starts and renders fullscreen

**If session fails:** 
```bash
journalctl -t nira-session -f
journalctl -t nira-compositor -f
journalctl -t nira-shell -f
```

### 3.4 IPC / UDS verification
**Check:** Settings app toggles Dark Mode:
1. Open a terminal (`foot`)
2. Run `/usr/bin/nira-settings`
3. Click the Dark Mode switch
4. Check the Rust backend received it:
```bash
journalctl -t nira-settings -f
# Expected: "[SettingsService] set appearance.darkMode = false"
```

**Check UDS sockets exist:**
```bash
ls -la /run/niraos/
# Should show: ai.sock, context.sock, actions.sock,
#              permissions.sock, settings.sock, hardware.sock
# All owned by the session user, mode 0600
```

### 3.5 AI Quick Action
**Check:** Super+Space opens the AI overlay:
1. Click "Optimize my PC"
2. The response `**Action: Optimize my PC**\n\nI've completed that task...`
   should appear immediately (no LLM delay — it's a hardcoded action
   execution path)

**If AI doesn't respond:**
```bash
journalctl -t nira-ai -f
# Check that ai-daemon is running and listening on /run/niraos/ai.sock
```

---

## 4. Known Build Caveats

| Issue | Workaround |
|---|---|
| Root dir is still `D:\AetherOS` | Code references are all NiraOS. The dir name doesn't affect the build. |
| `build.ps1` references `D:\NiraOS` | Run from WSL, not Windows. The mkosi build doesn't use build.ps1. |
| UDS code won't compile on Windows | Only the mkosi Linux build compiles daemons. This is expected. |
| `sys-utils/uds.rs` requires tonic 0.11 | The `Connected` trait and `serve_with_incoming` exist in 0.11.0. We verified the API from the local registry copy. |
