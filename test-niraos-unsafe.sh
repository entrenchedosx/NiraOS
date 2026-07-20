#!/bin/bash
# Headless NiraOS QEMU test with cache=unsafe for persistent logs
set -e
IMAGE="${1:-/mnt/d/AetherOS/NiraOS.raw}"
OVMF="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
SERIAL_LOG="/tmp/niraos-serial-unsafe-$(date +%s).log"
echo "SERIAL_LOG=$SERIAL_LOG"
echo "Timeout: 120s"
if [ ! -f "$OVMF" ]; then echo "OVMF missing"; exit 1; fi
if [ ! -f "$IMAGE" ]; then echo "Image missing"; exit 1; fi
timeout 120 qemu-system-x86_64 \
    -accel kvm -accel tcg \
    -cpu qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt \
    -m 8192 -smp 4 \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF" \
    -drive if=virtio,format=raw,file="$IMAGE",cache=unsafe \
    -vga none \
    -device virtio-gpu-pci,edid=on,xres=1920,yres=1080 \
    -device virtio-keyboard-pci \
    -device virtio-tablet-pci \
    -fw_cfg name=opt/nira/graphics-mode,string=software \
    -display none \
    -serial file:"$SERIAL_LOG" \
    -netdev user,id=nira-net \
    -device virtio-net-pci,netdev=nira-net \
    -no-reboot \
    </dev/null 2>&1
EXIT_CODE=$?
echo "QEMU_EXIT=$EXIT_CODE"
echo "SERIAL_LOG=$SERIAL_LOG"
echo "SERIAL_SIZE=$(wc -c < "$SERIAL_LOG")"
echo "=== LAST 50 LINES ==="
tail -50 "$SERIAL_LOG"
echo "=== END ==="
# Now try to mount and read logs from the image
echo "=== Mounting image to read session logs ==="
DEV=$(losetup -fP --show "$IMAGE" 2>/dev/null || true)
if [ -n "$DEV" ]; then
    sleep 1
    mkdir -p /tmp/img-mount
    mount "${DEV}p2" /tmp/img-mount 2>/dev/null || echo "mount failed"
    if [ -f /tmp/img-mount/var/log/niraos/nira-session.log ]; then
        echo "=== SESSION LOG ==="
        head -200 /tmp/img-mount/var/log/niraos/nira-session.log
    else
        echo "No session log found at /var/log/niraos/"
        ls -la /tmp/img-mount/var/log/niraos/ 2>/dev/null || echo "Directory missing"
        ls -la /tmp/img-mount/run/user/ 2>/dev/null || echo "No run/user"
    fi
    # Check journal too
    if [ -f /tmp/img-mount/var/log/journal/*/system.journal ]; then
        echo "Journal found - use journalctl to read"
    else
        echo "No persistent journal"
    fi
    umount /tmp/img-mount 2>/dev/null || true
    losetup -d "$DEV" 2>/dev/null || true
fi
echo "=== DONE ==="
