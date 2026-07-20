#!/bin/bash
set -e
IMG=/mnt/d/AetherOS/NiraOS.raw
LOOPDEV=$(losetup -f)
losetup -P "$LOOPDEV" "$IMG"
mount -o ro "${LOOPDEV}p2" /tmp/img-mount

echo "=== DRM modules loaded ==="
find /tmp/img-mount/usr/lib/modules -name "*bochs*" -o -name "*drm*" 2>/dev/null | head -10

echo ""
echo "=== Kernel config ==="
find /tmp/img-mount/usr/lib/modules -name "config" -type f 2>/dev/null | head -3

echo ""
echo "=== Check bochs-drm in kernel ==="
# Check if bochs-drm is built-in or a module
zgrep "BOCHS\|DRM" /tmp/img-mount/usr/lib/modules/*/config 2>/dev/null | grep -E "=y|=m" | grep -i "bochs\|drm" | head -20

echo ""
echo "=== Check qemu fw_cfg ==="
# QEMU fw_cfg might provide additional graphics info
ls /tmp/img-mount/sys/firmware/qemu_fw_cfg/ 2>/dev/null | head -5

echo ""
echo "=== Greeter environment check ==="
cat /tmp/img-mount/usr/bin/start-nira-greeter | grep -E "^export|^set "

echo ""
echo "=== QT_QPA_PLATFORM settings ==="
strings /tmp/img-mount/usr/bin/nira-greeter 2>/dev/null | grep "QT_QPA" | head -5

umount /tmp/img-mount
losetup -d "$LOOPDEV"
echo "DONE"
