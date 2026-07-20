#!/bin/bash
# NiraOS Developer Mode Enabler

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

echo "Warning: Enabling Developer Mode."
echo "Mounting overlayfs over /usr to allow temporary pacman installations."

mkdir -p /var/lib/niraos/dev-upper
mkdir -p /var/lib/niraos/dev-work

mount -t overlay overlay -o lowerdir=/usr,upperdir=/var/lib/niraos/dev-upper,workdir=/var/lib/niraos/dev-work /usr

echo "Developer Mode active until next reboot."
