#!/bin/bash
set -e

# Check if the compositor Main.qml has cursor code
echo "=== Cursor code in compositor Main.qml ==="
grep -n "cursor" /mnt/d/AetherOS/desktop/compositor/qml/Main.qml | head -15

echo ""
echo "=== __cursorX property ==="
grep "__cursorX\|__cursorY\|__cursorVisible\|cursorCanvas\|pointerPosition" /mnt/d/AetherOS/desktop/compositor/qml/Main.qml | head -10

echo ""
echo "=== Check binary for cursor strings ==="
# Mount the image first
IMG=/mnt/d/AetherOS/NiraOS.raw
LOOPDEV=$(losetup -f)
losetup -P "$LOOPDEV" "$IMG"
echo "Loop: $LOOPDEV"
mount -o ro "${LOOPDEV}p2" /tmp/img-mount 2>&1

echo "=== Cursor strings in compositor binary ==="
strings /tmp/img-mount/usr/bin/nira-compositor | grep -c "cursor" || echo "0"
strings /tmp/img-mount/usr/bin/nira-compositor | grep -i "pointer" | head -5
strings /tmp/img-mount/usr/bin/nira-compositor | grep "__cursor" | head -5
strings /tmp/img-mount/usr/bin/nira-compositor | grep "Canvas" | head -5

echo ""
echo "=== Cursor strings in greeter binary ==="
strings /tmp/img-mount/usr/bin/nira-greeter | grep -i "cursor" | head -5

umount /tmp/img-mount
losetup -d "$LOOPDEV"
echo "DONE"
