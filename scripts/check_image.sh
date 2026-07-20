#!/bin/bash
set -e

# Mount NiraOS.raw and check installed files
IMG=/mnt/d/AetherOS/NiraOS.raw

echo "Setting up loop device..."
LOOPDEV=$(losetup -f "$IMG" -P --show)
echo "Loop device: $LOOPDEV"
sleep 1

MNT=/tmp/img-mount
mkdir -p "$MNT"

echo "Mounting root partition..."
mount -o ro "${LOOPDEV}p2" "$MNT"

echo ""
echo "=== nira-greeter binary ==="
ls -la "$MNT/usr/bin/nira-greeter" 2>&1
echo "Strings:"
strings "$MNT/usr/bin/nira-greeter" 2>/dev/null | grep -iE "gallium|llvm|quick" | head -10

echo ""
echo "=== nira-compositor binary ==="
ls -la "$MNT/usr/bin/nira-compositor" 2>&1
echo "Strings:"
strings "$MNT/usr/bin/nira-compositor" 2>/dev/null | grep -iE "gallium|llvm|quick" | head -10

echo ""
echo "=== start-nira-greeter wrapper ==="
head -5 "$MNT/usr/bin/start-nira-greeter" 2>&1

echo ""
echo "=== start-nira-session wrapper ==="
grep "Breeze_Snow" "$MNT/usr/bin/start-nira-session" 2>&1 || echo "Breeze_Snow NOT FOUND"
grep "dbus-launch" "$MNT/usr/bin/start-nira-session" 2>&1 || echo "dbus-launch NOT FOUND"

echo ""
echo "=== Cursor themes installed ==="
ls "$MNT/usr/share/icons/" 2>&1 | head -20
find "$MNT/usr/share/icons/" -name "cursors" -type d 2>/dev/null

echo ""
echo "=== greetd config ==="
cat "$MNT/etc/greetd/config.toml" 2>&1

echo ""
echo "=== Checking for breeze-cursors ==="
ls "$MNT/usr/share/icons/Breeze_Snow/" 2>/dev/null | head -5
echo "---"
pacman --root "$MNT" -Q breeze-cursors 2>/dev/null || echo "Not a pacman database"

echo ""
echo "=== Cleaning up ==="
umount "$MNT"
losetup -d "$LOOPDEV"
echo "DONE"
