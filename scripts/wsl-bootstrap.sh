#!/bin/bash
# Bootstrap the WSL Arch Linux build host for NiraOS image builds.
set -e

cat > /etc/pacman.d/mirrorlist <<'EOF'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirror.leaseweb.net/archlinux/$repo/os/$arch
EOF

pacman -Syu --noconfirm --needed \
    mkosi systemd arch-install-scripts \
    rust protobuf cmake ninja gcc make pkgconf \
    qt6-base qt6-declarative qt6-wayland \
    qemu-base edk2-ovmf \
    e2fsprogs dosfstools btrfs-progs \
    systemd-ukify cpio zstd \
    rsync git

echo "Bootstrap complete."
