#!/bin/bash
# Headless NiraOS QEMU test
set -e
IMAGE="${1:-/mnt/d/AetherOS/NiraOS.raw}"
OVMF="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
SERIAL_LOG="/tmp/niraos-serial-$(date +%s).log"
echo "SERIAL_LOG=$SERIAL_LOG"
echo "Timeout: 90s"
if [ ! -f "$OVMF" ]; then echo "OVMF missing"; exit 1; fi
if [ ! -f "$IMAGE" ]; then echo "Image missing"; exit 1; fi
timeout 90 qemu-system-x86_64 \
    -accel kvm -accel tcg \
    -cpu qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt \
    -m 8192 -smp 4 \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF" \
    -drive if=virtio,format=raw,file="$IMAGE" \
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
QEMU_EXIT=$?
echo "QEMU_EXIT=$QEMU_EXIT"
if [ -f "$SERIAL_LOG" ]; then
    echo "SERIAL_SIZE=$(wc -c < "$SERIAL_LOG")"
    echo "=== LAST 120 LINES ==="
    tail -120 "$SERIAL_LOG"
    echo "=== END ==="
else
    echo "No serial log generated"
fi
