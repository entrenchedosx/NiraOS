#!/bin/bash
IMG=/mnt/d/AetherOS/NiraOS.raw
for dev in $(losetup -a 2>/dev/null | grep "$IMG" | cut -d: -f1); do
    losetup -d "$dev" 2>/dev/null || true
done
LOOPDEV=$(losetup -f)
losetup -P "$LOOPDEV" "$IMG"
mount -o ro "${LOOPDEV}p2" /tmp/img-mount
echo "=== /etc/pam.d/systemd-user ==="
cat /tmp/img-mount/etc/pam.d/systemd-user 2>&1
echo ""
echo "=== permissions ==="
ls -la /tmp/img-mount/etc/pam.d/systemd-user 2>&1
umount /tmp/img-mount
losetup -d "$LOOPDEV"
echo "DONE"
