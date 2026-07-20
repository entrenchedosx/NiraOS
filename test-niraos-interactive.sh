#!/bin/bash
# Automated NiraOS test with serial login and journal check
set -e
IMAGE="${1:-/mnt/d/AetherOS/NiraOS.raw}"
OVMF="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
SERIAL_IN="/tmp/niraos-qemu-in"
SERIAL_OUT="/tmp/niraos-qemu-out"
SERIAL_LOG="/tmp/niraos-qemu-serial-$(date +%s).log"

rm -f "$SERIAL_IN" "$SERIAL_OUT"
mkfifo "$SERIAL_IN"

echo "SERIAL_LOG=$SERIAL_LOG"
echo "Timeout: 120s"

timeout 120 \
qemu-system-x86_64 \
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
    -serial pipe:/tmp/niraos-qemu \
    -netdev user,id=nira-net \
    -device virtio-net-pci,netdev=nira-net \
    -no-reboot \
    < /dev/null 2>&1 &

QEMU_PID=$!

# Wait for boot and login prompt
echo "Waiting for login prompt..."
for i in $(seq 1 60); do
    if grep -q "NiraOS login:" "$SERIAL_LOG" 2>/dev/null; then
        echo "Login prompt found after ${i}s"
        break
    fi
    sleep 1
done

# Send login as root (serial getty)
echo "Logging in..."
echo "root" > "$SERIAL_IN"
sleep 2

# Check if we got a shell prompt
if grep -q "\[root@" "$SERIAL_LOG" 2>/dev/null || grep -q "# " "$SERIAL_LOG" 2>/dev/null; then
    echo "Got shell prompt!"
    # Check NiraOS services
    echo "journalctl -u greetd --no-pager -n 50" > "$SERIAL_IN"
    sleep 2
    echo "journalctl -u nira-permission --no-pager -n 20" > "$SERIAL_IN"
    sleep 1
    echo "journalctl -t nira-greeter --no-pager -n 50" > "$SERIAL_IN"
    sleep 2
    echo "journalctl -t nira-session --no-pager -n 100" > "$SERIAL_IN"
    sleep 2
    echo "journalctl -t nira-compositor --no-pager -n 100" > "$SERIAL_IN"
    sleep 2
    echo "journalctl -t nira-shell --no-pager -n 100" > "$SERIAL_IN"
    sleep 2
    echo "ls -la /usr/bin/nira-*" > "$SERIAL_IN"
    sleep 1
    echo "ls -la /run/user/" > "$SERIAL_IN"
    sleep 1
    echo "ls -la /run/user/1000/ 2>/dev/null || echo no-user1000" > "$SERIAL_IN"
    sleep 1
    echo "journalctl --no-pager -n 30" > "$SERIAL_IN"
    sleep 2
fi

# Wait for QEMU to finish
wait "$QEMU_PID" 2>/dev/null || true
echo "QEMU_EXIT=$?"

echo "SERIAL_OUT last 200 lines (uncaptured):"
wc -l "$SERIAL_LOG" 2>/dev/null || echo "no log"
tail -200 "$SERIAL_LOG" 2>/dev/null || true
echo "=== END ==="

rm -f "$SERIAL_IN" 2>/dev/null || true
