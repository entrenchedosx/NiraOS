#!/bin/bash
set -e
IMG=/mnt/d/AetherOS/NiraOS.raw
LOOPDEV=$(losetup -f)
losetup -P "$LOOPDEV" "$IMG"
mount -o ro "${LOOPDEV}p2" /tmp/img-mount
echo "=== Cursor assets installed ==="
ls /tmp/img-mount/usr/share/niraos/cursors/ | head -10
echo ""
echo "=== pointer-24.png exists? ==="
ls -la /tmp/img-mount/usr/share/niraos/cursors/pointer-24.png
echo ""
echo "=== pointer.svg exists? ==="
ls -la /tmp/img-mount/usr/share/niraos/cursors/pointer.svg
umount /tmp/img-mount
losetup -d "$LOOPDEV"
echo "DONE"
