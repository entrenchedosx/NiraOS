#!/bin/bash
# Sync the NiraOS source tree from the Windows mount into the WSL filesystem.
set -e

SRC=${1:-/mnt/d/NiraOS}
DEST=${2:-$HOME/niraos}

mkdir -p "$DEST"
rsync -a --delete \
    --exclude '.git' \
    --exclude 'target/' \
    --exclude 'build/' \
    --exclude 'mkosi.output/' \
    --exclude 'mkosi.cache/' \
    --exclude 'initrd' \
    --exclude 'initrd.cpio.zst' \
    --exclude '*.raw' \
    "$SRC/" "$DEST/"

# Normalize CRLF -> LF on scripts that execute inside the image build.
for f in "$DEST"/mkosi.build "$DEST"/mkosi.postinst "$DEST"/scripts/*.sh \
         "$DEST"/mkosi/mkosi.extra/usr/bin/* "$DEST"/mkosi.extra/usr/bin/*; do
    [ -f "$f" ] && sed -i 's/\r$//' "$f" && chmod +x "$f"
done

echo "Synced to $DEST"
