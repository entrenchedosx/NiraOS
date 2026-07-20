#!/bin/bash
IMG=/mnt/d/AetherOS/NiraOS.raw

for dev in $(losetup -a 2>/dev/null | grep "$IMG" | cut -d: -f1); do
    losetup -d "$dev" 2>/dev/null || true
done

LOOPDEV=$(losetup -f)
losetup -P "$LOOPDEV" "$IMG"
mount -o ro "${LOOPDEV}p2" /tmp/img-mount

echo "=== pam package info ==="
ls /tmp/img-mount/var/lib/pacman/local/pam-*/ 2>/dev/null
cat /tmp/img-mount/var/lib/pacman/local/pam-*/desc 2>/dev/null | head -10

echo ""
echo "=== pam config file ==="
cat /tmp/img-mount/etc/pam.d/other 2>&1

echo ""
echo "=== Check if PAM supports /usr/lib/pam.d fallback ==="
# PAM 1.5.0+ supports /usr/lib/pam.d/ fallback
# Check the pam version
strings /tmp/img-mount/usr/lib/libpam.so* 2>/dev/null | grep -i "version\|1\.\|PAM" | head -5

echo ""
echo "=== libpam version ==="
ls -la /tmp/img-mount/usr/lib/libpam.so* 2>/dev/null

umount /tmp/img-mount
losetup -d "$LOOPDEV"
echo "DONE"
