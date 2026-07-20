#!/bin/bash
qemu-system-x86_64 \
    -name NiraOS \
    -accel tcg \
    -cpu qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt \
    -m 8192 -smp 4 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
    -drive format=raw,file=/mnt/d/AetherOS/NiraOS.raw \
    -vga std \
    -vnc :2 \
    -k en-us \
    -device virtio-tablet-pci \
    -device virtio-keyboard-pci \
    -serial unix:/tmp/nira-serial.sock,server,nowait \
    -qmp tcp:0.0.0.0:4444,server,nowait
