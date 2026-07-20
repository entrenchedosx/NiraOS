#!/bin/bash
set -e
IMG=/mnt/d/AetherOS/NiraOS.raw

echo "=== Image info ==="
stat $IMG | grep -E "Size|Modify"

echo "=== Setting up loop ==="
LOOPDEV=$(losetup -f)
losetup -P "$LOOPDEV" "$IMG"

echo "=== Mounting ==="
mount -o ro "${LOOPDEV}p2" /tmp/img-mount

echo "=== start-nira-greeter (first 5 lines) ==="
head -5 /tmp/img-mount/usr/bin/start-nira-greeter

echo "=== MESA_LOADER check ==="
grep "MESA_LOADER" /tmp/img-mount/usr/bin/start-nira-greeter && echo "FOUND (BAD)" || echo "NOT found (GOOD)"

echo "=== XCURSOR_THEME ==="
grep "XCURSOR_THEME" /tmp/img-mount/usr/bin/start-nira-greeter

echo "=== Compositor llvmpipe ==="
strings /tmp/img-mount/usr/bin/nira-compositor 2>/dev/null | grep -c "llvmpipe"

echo "=== Cleaning ==="
umount /tmp/img-mount
losetup -d "$LOOPDEV"
echo "DONE"
