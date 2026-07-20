#!/bin/bash
set -e
INITRD=/mnt/d/AetherOS/NiraOS.initrd

echo "=== Checking initrd for drm modules ==="
zstd -dc "$INITRD" 2>/dev/null | cpio -t 2>/dev/null | grep -E "bochs|drm" | head -20

echo ""
echo "=== Checking for /dev/dri in initrd ==="
zstd -dc "$INITRD" 2>/dev/null | cpio -t 2>/dev/null | grep "dev/dri" | head -5

echo ""
echo "=== Total files in initrd ==="
zstd -dc "$INITRD" 2>/dev/null | cpio -t 2>/dev/null | wc -l

echo ""
echo "=== Checking mkosi initrd ==="
find /root/mkosi-workspace -name "*.initrd" -type f 2>/dev/null | head -3
