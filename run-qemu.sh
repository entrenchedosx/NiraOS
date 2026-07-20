#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
image=${1:-"$repo_root/NiraOS.raw"}
ovmf=${NIRA_OVMF:-/usr/share/edk2/x64/OVMF_CODE.4m.fd}

test -r "$image" || { echo "Image not found: $image" >&2; exit 1; }
test -r "$ovmf" || { echo "OVMF not found: $ovmf" >&2; exit 1; }

overlay=$(mktemp /tmp/niraos-run.XXXXXX)
rm -f -- "$overlay"
qemu-img create -q -f qcow2 -F raw -b "$image" "$overlay"
cleanup() { rm -f -- "$overlay"; }
trap cleanup EXIT INT TERM

qemu-system-x86_64 \
    -accel kvm -accel tcg \
    -cpu qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt \
    -m 8192 -smp 4 \
    -drive if=pflash,format=raw,readonly=on,file="$ovmf" \
    -drive if=virtio,format=qcow2,file="$overlay" \
    -vga none \
    -device virtio-gpu-pci,edid=on,xres=1920,yres=1080 \
    -device virtio-keyboard-pci -device virtio-tablet-pci \
    -fw_cfg name=opt/nira/graphics-mode,string=software \
    -display gtk,gl=off \
    -netdev user,id=nira-net -device virtio-net-pci,netdev=nira-net \
    -serial tcp:127.0.0.1:4444,server,nowait
