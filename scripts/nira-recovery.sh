#!/bin/bash
# NiraOS Recovery Toolkit

echo "NiraOS Immutable Recovery System"

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

echo "Active partition: $(bootctl status | grep 'Boot loader sets')"
echo "Rolling back to previous deployment..."

# Swap the systemd-boot default target
bootctl set-default @saved

echo "Rollback configured. Please reboot."
