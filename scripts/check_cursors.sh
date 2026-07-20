#!/bin/bash
set -e
IMG=/mnt/d/AetherOS/NiraOS.raw
LOOPDEV=$(losetup -f "$IMG" -P --show)
mount -o ro "${LOOPDEV}p2" /tmp/img-mount

echo "=== Cursor themes ==="
ls /tmp/img-mount/usr/share/icons/ | sort

echo ""
echo "=== Breeze_Light cursor list (first 30) ==="
ls /tmp/img-mount/usr/share/icons/Breeze_Light/cursors/ 2>/dev/null | head -30

echo ""
echo "=== breeze_cursors type ==="
file /tmp/img-mount/usr/share/icons/breeze_cursors 2>/dev/null
ls -la /tmp/img-mount/usr/share/icons/breeze_cursors 2>/dev/null

echo ""
echo "=== Default cursors ==="
ls /tmp/img-mount/usr/share/icons/default/cursors/ 2>/dev/null | head -5
cat /tmp/img-mount/usr/share/icons/default/index.theme 2>/dev/null

echo ""
echo "=== index.theme for Breeze_Light ==="
cat /tmp/img-mount/usr/share/icons/Breeze_Light/index.theme 2>/dev/null | head -20

echo ""
echo "=== Compositor QML (checking cursor sprite) ==="
strings /tmp/img-mount/usr/bin/nira-compositor 2>/dev/null | grep -iE "cursorCanvas|__cursor|pointerPosition" | head -5

umount /tmp/img-mount
losetup -d "$LOOPDEV"
echo "DONE"
