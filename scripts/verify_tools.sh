#!/bin/bash
set -e
IMG=/mnt/d/AetherOS/NiraOS.raw
LOOPDEV=$(losetup -f)
losetup -P "$LOOPDEV" "$IMG"
mount -o ro "${LOOPDEV}p2" /tmp/img-mount

echo "=== Check essential tools ==="
for cmd in bash tee systemd-cat dbus-launch; do
    if [ -x "/tmp/img-mount/usr/bin/$cmd" ]; then
        echo "  $cmd: OK"
    elif [ -x "/tmp/img-mount/usr/bin/$cmd" ]; then
        echo "  $cmd: FOUND at /usr/bin"
    else
        echo "  $cmd: NOT FOUND"
        find /tmp/img-mount -name "$cmd" -type f 2>/dev/null | head -3
    fi
done

echo ""
echo "=== Check DRM/EGL libraries ==="
find /tmp/img-mount/usr/lib -name "libEGL*" -o -name "libGLES*" -o -name "libgbm*" 2>/dev/null | head -10

echo ""
echo "=== Check eglfs platform plugin ==="
find /tmp/img-mount/usr/lib/qt6/plugins/platforms -name "libqeglfs*" 2>/dev/null | head -5

echo ""
echo "=== Check kms integration ==="
find /tmp/img-mount/usr/lib/qt6/plugins/egldeviceintegrations -name "*kms*" 2>/dev/null | head -5

echo ""
echo "=== Check Mesa DRI drivers ==="
find /tmp/img-mount/usr/lib/dri -name "*kms*" -o -name "*swrast*" -o -name "*llvm*" 2>/dev/null | head -10

echo ""
echo "=== Greeter permissions ==="
grep "^greeter:" /tmp/img-mount/etc/group 2>/dev/null || grep "greeter" /tmp/img-mount/etc/passwd 2>/dev/null
echo "video group:"
grep "^video:" /tmp/img-mount/etc/group 2>/dev/null

echo ""
echo "=== Video group membership ==="
grep "^video:" /tmp/img-mount/etc/group | cut -d: -f4

umount /tmp/img-mount
losetup -d "$LOOPDEV"
echo "DONE"
