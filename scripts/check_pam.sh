#!/bin/bash
# No set -e — we want to see ALL files even if some are missing
IMG=/mnt/d/AetherOS/NiraOS.raw

for dev in $(losetup -a 2>/dev/null | grep "$IMG" | cut -d: -f1); do
    losetup -d "$dev" 2>/dev/null || true
done

LOOPDEV=$(losetup -f)
losetup -P "$LOOPDEV" "$IMG"
mount -o ro "${LOOPDEV}p2" /tmp/img-mount

echo "=== /etc/pam.d/greetd ==="
cat /tmp/img-mount/etc/pam.d/greetd 2>&1

echo ""
echo "=== /etc/pam.d/systemd-user ==="
cat /tmp/img-mount/etc/pam.d/systemd-user 2>&1

echo ""
echo "=== /etc/pam.d/system-auth ==="
cat /tmp/img-mount/etc/pam.d/system-auth 2>&1

echo ""
echo "=== /etc/pam.d/system-login ==="
cat /tmp/img-mount/etc/pam.d/system-login 2>&1

echo ""
echo "=== /etc/pam.d/login ==="
cat /tmp/img-mount/etc/pam.d/login 2>&1

echo ""
echo "=== /etc/pam.d/su ==="
cat /tmp/img-mount/etc/pam.d/su 2>&1

echo ""
echo "=== /etc/pam.d/sudo ==="
cat /tmp/img-mount/etc/pam.d/sudo 2>&1

echo ""
echo "=== Check pam_systemd.so ==="
find /tmp/img-mount/usr/lib -name "pam_systemd*" 2>/dev/null

echo ""
echo "=== Check pam_unix.so ==="
find /tmp/img-mount/usr/lib -name "pam_unix*" 2>/dev/null

echo ""
echo "=== Check pam_env.so ==="
find /tmp/img-mount/usr/lib -name "pam_env*" 2>/dev/null

echo ""
echo "=== Check pam_limits.so ==="
find /tmp/img-mount/usr/lib -name "pam_limits*" 2>/dev/null

echo ""
echo "=== Check pam_loginuid.so ==="
find /tmp/img-mount/usr/lib -name "pam_loginuid*" 2>/dev/null

echo ""
echo "=== /etc/passwd nira entry ==="
grep nira /tmp/img-mount/etc/passwd

echo ""
echo "=== /etc/shadow nira entry ==="
grep nira /tmp/img-mount/etc/shadow 2>/dev/null || echo "Cannot read shadow"

echo ""
echo "=== /etc/group nira entries ==="
grep nira /tmp/img-mount/etc/group

echo ""
echo "=== user-runtime-dir tmpfiles ==="
cat /tmp/img-mount/usr/lib/tmpfiles.d/niraos.conf 2>/dev/null

echo ""
echo "=== systemd user directory ==="
ls /tmp/img-mount/usr/lib/systemd/user/ 2>/dev/null | head -20

echo ""
echo "=== Check start-nira-session ==="
cat /tmp/img-mount/usr/bin/start-nira-session 2>/dev/null | head -20

umount /tmp/img-mount
losetup -d "$LOOPDEV"
echo "DONE"
