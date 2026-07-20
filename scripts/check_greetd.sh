#!/bin/bash
set -e
IMG=/mnt/d/AetherOS/NiraOS.raw

# Clean up any old loop devices
for dev in $(losetup -a 2>/dev/null | grep "$IMG" | cut -d: -f1); do
    losetup -d "$dev" 2>/dev/null || true
done

LOOPDEV=$(losetup -f)
losetup -P "$LOOPDEV" "$IMG"
mount -o ro "${LOOPDEV}p2" /tmp/img-mount

echo "=== greetd.service ==="
cat /tmp/img-mount/usr/lib/systemd/system/greetd.service

echo ""
echo "=== greetd config ==="
cat /tmp/img-mount/etc/greetd/config.toml

echo ""
echo "=== /tmp ==="
ls -la /tmp/img-mount/tmp/

echo ""
echo "=== logind.conf ==="
cat /tmp/img-mount/etc/systemd/logind.conf.d/niraos.conf

umount /tmp/img-mount
losetup -d "$LOOPDEV"
echo "DONE"
