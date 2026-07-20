#!/bin/bash
set -e
IMG=/mnt/d/AetherOS/NiraOS.raw

for dev in $(losetup -a 2>/dev/null | grep "$IMG" | cut -d: -f1); do
    losetup -d "$dev" 2>/dev/null || true
done

LOOPDEV=$(losetup -f)
losetup -P "$LOOPDEV" "$IMG"
mount -o ro "${LOOPDEV}p2" /tmp/img-mount

echo "=== Input devices in /dev ==="
ls /tmp/img-mount/dev/input/ 2>/dev/null || echo "No /dev/input"

echo ""
echo "=== Input-related kernel modules ==="
find /tmp/img-mount/usr/lib/modules -name "*input*" -o -name "*psmouse*" -o -name "*usbhid*" 2>/dev/null | head -10

echo ""
echo "=== libinput version ==="
find /tmp/img-mount/usr/lib -name "libinput*" -type f | head -3
pacman --root /tmp/img-mount -Q libinput 2>/dev/null || echo "Not in pacman db"

echo ""
echo "=== evdev config ==="
find /tmp/img-mount/usr/share/X11 -name "*evdev*" 2>/dev/null | head -5

echo ""
echo "=== libinput quirks ==="
ls /tmp/img-mount/usr/share/libinput/ 2>/dev/null | head -5

echo ""
echo "=== Check modules.alias for PS/2 ==="
grep "psmouse\|serio" /tmp/img-mount/usr/lib/modules/*/modules.alias 2>/dev/null | head -5

umount /tmp/img-mount
losetup -d "$LOOPDEV"
echo "DONE"
