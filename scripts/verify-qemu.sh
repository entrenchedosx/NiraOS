#!/usr/bin/env bash
# Headless artifact smoke test. This proves that QEMU remains alive long
# enough to produce a framebuffer and preserves serial/QEMU evidence; it does
# not claim that login or desktop interaction succeeded.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
image=${1:-"$repo_root/NiraOS.raw"}
ovmf=${NIRA_OVMF:-/usr/share/edk2/x64/OVMF_CODE.4m.fd}
wait_seconds=${NIRA_VERIFY_SECONDS:-90}
artifact_dir=${NIRA_VERIFY_OUTPUT_DIR:-"$repo_root/verification-artifacts"}

test -r "$image" || { echo "Image not found: $image" >&2; exit 1; }
test -r "$ovmf" || { echo "OVMF not found: $ovmf" >&2; exit 1; }
[[ "$wait_seconds" =~ ^[0-9]+$ ]] || { echo "NIRA_VERIFY_SECONDS must be an integer" >&2; exit 1; }

mkdir -p "$artifact_dir"
runtime=$(mktemp -d /tmp/nira-verify.XXXXXX)
overlay="$runtime/guest.qcow2"
qmp_socket="$runtime/qmp.sock"
vnc_socket="$runtime/vnc.sock"
serial_log="$artifact_dir/serial.log"
qemu_log="$artifact_dir/qemu.log"
screenshot="$artifact_dir/framebuffer.ppm"
qemu_pid=""

cleanup() {
    if [[ -n "$qemu_pid" ]] && kill -0 "$qemu_pid" 2>/dev/null; then
        kill "$qemu_pid" 2>/dev/null || true
        wait "$qemu_pid" 2>/dev/null || true
    fi
    rm -rf -- "$runtime"
}
trap cleanup EXIT INT TERM

qemu-img create -q -f qcow2 -F raw -b "$image" "$overlay"

echo "Booting a disposable copy of $(basename -- "$image") for ${wait_seconds}s..."
qemu-system-x86_64 \
    -name nira-verifier \
    -machine q35 \
    -accel kvm -accel tcg \
    -cpu qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt \
    -m 4096 -smp 4 \
    -drive if=pflash,format=raw,readonly=on,file="$ovmf" \
    -drive if=virtio,format=qcow2,file="$overlay" \
    -vga none \
    -device virtio-gpu-pci,edid=on,xres=1280,yres=800 \
    -device virtio-keyboard-pci \
    -device virtio-tablet-pci \
    -fw_cfg name=opt/nira/graphics-mode,string=software \
    -vnc unix:"$vnc_socket" \
    -serial file:"$serial_log" \
    -qmp unix:"$qmp_socket",server=on,wait=off \
    -monitor none \
    -net none \
    -no-reboot \
    >"$qemu_log" 2>&1 &
qemu_pid=$!

for ((second = 0; second < wait_seconds; ++second)); do
    kill -0 "$qemu_pid" 2>/dev/null || {
        echo "QEMU exited before the evidence window completed." >&2
        exit 1
    }
    [[ -S "$qmp_socket" ]] && sleep 1 || sleep 1
done

python3 "$repo_root/scripts/dump_screen.py" \
    --socket "$qmp_socket" \
    --output "$screenshot" \
    --require-visible-content

test -s "$screenshot"
echo "Smoke-test artifacts written to: $artifact_dir"
echo "Manual/automated image inspection is still required to prove graphical login."
