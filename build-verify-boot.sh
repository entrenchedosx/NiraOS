#!/bin/bash
set -e
losetup -fP --show /mnt/d/AetherOS/NiraOS.raw
sleep 1
mount /dev/loop0p2 /mnt

echo "=== Boot directory contents ==="
ls -la /mnt/boot/ 2>&1

echo "=== mkinitcpio.conf ==="
cat /mnt/etc/mkinitcpio.conf 2>/dev/null || echo "no mkinitcpio.conf"

echo "=== ESP Boot entry ==="
mount /dev/loop0p1 /mnt2 2>/dev/null || mkdir -p /mnt2 && mount /dev/loop0p1 /mnt2
cat /mnt2/loader/entries/*.conf 2>/dev/null

echo "=== Checking initrd for virtio drivers ==="
if [ -f /mnt/boot/initramfs-linux.img ]; then
    zcat /mnt/boot/initramfs-linux.img 2>/dev/null | strings | grep -i virtio | head -10 || echo "No virtio in initramfs"
    echo "Total virtio refs:" 
    zcat /mnt/boot/initramfs-linux.img 2>/dev/null | strings | grep -c virtio 2>/dev/null || echo "0"
fi

if [ -f /mnt2/arch/initrd ]; then
    echo "=== Checking ESP initrd ==="
    zcat /mnt2/arch/initrd 2>/dev/null | strings | grep virtio | head -5 || echo "No virtio in ESP initrd"
fi

umount /mnt2 2>/dev/null
umount /mnt 2>/dev/null
losetup -d /dev/loop0
echo "DONE"
