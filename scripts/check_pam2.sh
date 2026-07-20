#!/bin/bash
IMG=/mnt/d/AetherOS/NiraOS.raw

for dev in $(losetup -a 2>/dev/null | grep "$IMG" | cut -d: -f1); do
    losetup -d "$dev" 2>/dev/null || true
done

LOOPDEV=$(losetup -f)
losetup -P "$LOOPDEV" "$IMG"
mount -o ro "${LOOPDEV}p2" /tmp/img-mount

echo "=== /usr/lib/pam.d/ in image ==="
ls /tmp/img-mount/usr/lib/pam.d/ 2>&1

echo ""
echo "=== /etc/pam.d/ in image ==="
ls /tmp/img-mount/etc/pam.d/ 2>&1

echo ""
echo "=== pam version in image ==="
grep "^NAME\|^VERSION" /tmp/img-mount/usr/share/libalpm/local/pam-*/desc 2>/dev/null | head -4

echo ""
echo "=== systemd version in image ==="
grep "^NAME\|^VERSION" /tmp/img-mount/usr/share/libalpm/local/systemd-*/desc 2>/dev/null | head -4

echo ""
echo "=== pam_systemd.so in image ==="
find /tmp/img-mount/usr/lib/security -name "pam_systemd*" 2>/dev/null

echo ""
echo "=== /usr/lib/pam.d/systemd-user content ==="
cat /tmp/img-mount/usr/lib/pam.d/systemd-user 2>&1

umount /tmp/img-mount
losetup -d "$LOOPDEV"
echo "DONE"
