#!/usr/bin/env python3
"""Automated NiraOS QEMU test - logs in via serial, checks system state."""
import subprocess
import os
import sys
import time
import signal

IMAGE = sys.argv[1] if len(sys.argv) > 1 else "/mnt/d/AetherOS/NiraOS.raw"
OVMF = "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
SERIAL_LOG = f"/tmp/niraos-test-{int(time.time())}.log"
QMP_SOCK = f"/tmp/niraos-qmp-{int(time.time())}.sock"

log_file = open(SERIAL_LOG, "wb")

cmd = [
    "qemu-system-x86_64",
    "-accel", "kvm", "-accel", "tcg",
    "-cpu", "qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt",
    "-m", "8192", "-smp", "4",
    "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF}",
    "-drive", f"if=virtio,format=raw,file={IMAGE}",
    "-vga", "none",
    "-device", "virtio-gpu-pci,edid=on,xres=1920,yres=1080",
    "-device", "virtio-keyboard-pci",
    "-device", "virtio-tablet-pci",
    "-fw_cfg", "name=opt/nira/graphics-mode,string=software",
    "-display", "none",
    "-serial", "stdio",
    "-monitor", "none",
    "-netdev", "user,id=nira-net",
    "-device", "virtio-net-pci,netdev=nira-net",
    "-no-reboot",
    "-qmp", f"unix:{QMP_SOCK},server=on,wait=off",
]

proc = subprocess.Popen(
    cmd,
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
) 

def write_serial(text):
    proc.stdin.write(text.encode())
    proc.stdin.flush()

def read_serial(timeout=0.5):
    """Read available serial output."""
    import select
    data = b""
    while True:
        r, _, _ = select.select([proc.stdout], [], [], timeout)
        if not r:
            break
        chunk = proc.stdout.read1(4096)
        if not chunk:
            break
        data += chunk
        log_file.write(chunk)
        log_file.flush()
    return data.decode(errors="replace")

output = ""
print("Booting...", flush=True)

for _ in range(120):
    data = read_serial(0.5)
    output += data
    if "NiraOS login:" in output or "login:" in output:
        print(f"Login prompt found at ~{_}s", flush=True)
        break
    if "DEBUG: Starting greeter" in output:
        print(f"Greeter started at ~{_}s", flush=True)
    if "=== NiraOS session" in output or "NiraOS session" in output:
        print(f"Session detected at ~{_}s", flush=True)
    if "EXIT_STATUS" in output or "Session process exited" in output:
        print(f"Session exited at ~{_}s", flush=True)

print("Sending login...", flush=True)
write_serial("root\n")
time.sleep(3)
data = read_serial(1.0)
output += data

# Send diagnostic commands
commands = [
    "id",
    "ls -la /usr/bin/nira-*",
    "ls -la /run/user/",
    "ls -la /run/user/1000/ 2>/dev/null; ls -la /tmp/",
    "cat /tmp/nira-session.log 2>/dev/null | head -80 || echo NO_SESSION_LOG",
    "cat /tmp/nira-compositor.log 2>/dev/null | head -80 || echo NO_COMPOSITOR_LOG",
    "cat /tmp/nira-shell.log 2>/dev/null | head -80 || echo NO_SHELL_LOG",
    "journalctl -u greetd --no-pager -n 30 2>/dev/null || echo NO_GREETD_LOG",
    "journalctl -t nira-session --no-pager -n 50 2>/dev/null || echo NO_SESSION_JOURNAL",
    "journalctl -t nira-compositor --no-pager -n 50 2>/dev/null || echo NO_COMPOSITOR_JOURNAL",
    "journalctl -t nira-shell --no-pager -n 50 2>/dev/null || echo NO_SHELL_JOURNAL",
    "journalctl -t nira-greeter --no-pager -n 50 2>/dev/null || echo NO_GREETER_JOURNAL",
    "ls -la /var/log/niraos/ 2>/dev/null || echo NO_NIRA_LOG_DIR",
    "cat /var/log/niraos/nira-session.log 2>/dev/null | head -80 || echo NO_PERSISTENT_LOG",
    "systemctl status greetd --no-pager 2>/dev/null",
    "systemctl status nira-compositor --no-pager 2>/dev/null || echo NO_COMPOSITOR_SERVICE",
    "systemctl status nira-shell --no-pager 2>/dev/null || echo NO_SHELL_SERVICE",
    "ps aux | grep -E '(nira|compositor|shell|greeter|greetd)' | grep -v grep",
]

for cmd_txt in commands:
    print(f"\n--- Running: {cmd_txt} ---", flush=True)
    write_serial(f"{cmd_txt}\n")
    time.sleep(2)
    data = read_serial(1.0)
    output += data

write_serial("poweroff\n")
time.sleep(5)

proc.terminate()
try:
    proc.wait(timeout=5)
except:
    proc.kill()

log_file.close()

# Print the relevant parts of the output
print("\n\n======== RELEVANT OUTPUT ========")
for line in output.split("\n"):
    if any(kw in line for kw in [
        "nira-", "Nira", "compositor", "compositor", "shell", 
        "greeter", "greetd", "wayland", "Wayland", "wayland",
        "ERROR", "error", "FATAL", "failed", "Cannot", "cannot",
        "XDG", "DRM", "dri", "card0", "llvmpipe", "kms",
        "qt", "Qt", "QML", "QPA", "EGLFS", "eglfs",
        "starting", "Starting", "ready", "exited",
        "=== ", "--- ", "DEBUG", "Warning", "warning",
        "not found", "Missing", "missing",
    ]):
        print(line)

if os.path.exists(QMP_SOCK):
    os.unlink(QMP_SOCK)
print(f"\nFull log: {SERIAL_LOG}")
