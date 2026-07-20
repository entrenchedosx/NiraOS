#!/bin/bash
set -e
IMG=/mnt/d/AetherOS/NiraOS.raw
LOOPDEV=$(losetup -f)
losetup -P "$LOOPDEV" "$IMG"
mount -o ro "${LOOPDEV}p2" /tmp/img-mount

echo "=== Kernel version ==="
ls /tmp/img-mount/usr/lib/modules/

echo ""
echo "=== Check bochs module ==="
find /tmp/img-mount/usr/lib/modules -name "bochs*" -type f

echo ""
echo "=== Check modules.builtin for bochs ==="
grep -i bochs /tmp/img-mount/usr/lib/modules/*/modules.builtin 2>/dev/null | head -5

echo ""
echo "=== Check modules.dep for bochs dependencies ==="
grep bochs /tmp/img-mount/usr/lib/modules/*/modules.dep 2>/dev/null | head -5

echo ""
echo "=== Check if DRM is built-in ==="
grep "CONFIG_DRM=" /tmp/img-mount/usr/lib/modules/*/config 2>/dev/null | head -5
grep "CONFIG_DRM_BOCHS=" /tmp/img-mount/usr/lib/modules/*/config 2>/dev/null | head -5

echo ""
echo "=== Check udev rules for bochs ==="
cat /tmp/img-mount/usr/lib/udev/rules.d/60-drm.rules 2>/dev/null | head -20

echo ""
echo "=== Check if module is loaded by modalias ==="
find /tmp/img-mount/usr/lib/modules -name "modules.alias" -type f 2>/dev/null | head -3
grep -i "bochs\|1234" /tmp/img-mount/usr/lib/modules/*/modules.alias 2>/dev/null | head -10

umount /tmp/img-mount
losetup -d "$LOOPDEV"
echo "DONE"
