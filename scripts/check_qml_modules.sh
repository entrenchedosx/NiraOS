#!/bin/bash
set -e
IMG=/mnt/d/AetherOS/NiraOS.raw

for dev in $(losetup -a 2>/dev/null | grep "$IMG" | cut -d: -f1); do
    losetup -d "$dev" 2>/dev/null || true
done

LOOPDEV=$(losetup -f)
losetup -P "$LOOPDEV" "$IMG"
mount -o ro "${LOOPDEV}p2" /tmp/img-mount

echo "=== QtWayland.Compositor module ==="
find /tmp/img-mount/usr/lib/qt6/qml -type d -name "QtWayland*" 2>/dev/null | head -5
find /tmp/img-mount/usr/lib/qt6/qml -type d -name "Compositor*" 2>/dev/null | head -5

echo ""
echo "=== QML module plugins ==="
find /tmp/img-mount/usr/lib/qt6/qml/QtWayland -name "*.so" 2>/dev/null | head -5

echo ""
echo "=== QtWayland.Compositor QML files ==="
find /tmp/img-mount/usr/lib/qt6/qml/QtWayland/Compositor -type f 2>/dev/null | head -20

echo ""
echo "=== libQt6WaylandCompositor ==="
find /tmp/img-mount/usr/lib -name "libQt6WaylandCompositor*" 2>/dev/null | head -5

umount /tmp/img-mount
losetup -d "$LOOPDEV"
echo "DONE"
