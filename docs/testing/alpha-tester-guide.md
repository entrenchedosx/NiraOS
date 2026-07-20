# NiraOS Alpha Tester Guide

Welcome to the bleeding edge. NiraOS is an immutable, AI-native desktop operating system. As an Alpha tester, your goal is to break it, find edge cases, and report them.

## 1. Installation

1. **Download**: Grab the `NiraOS-Alpha.raw.xz` image from GitHub Releases. Verify the SHA256 checksum.
2. **Flash**: Use a tool like `dd` or Rufus (Windows) to flash the `.raw` image to a USB drive (at least 16GB).
3. **Boot**: Reboot your machine, enter the UEFI BIOS, and boot from the USB.
4. **Login**: The Alpha image utilizes `greetd` auto-login. You will drop directly into the `nira` user session on Wayland.

## 2. Models & Network

NiraOS does NOT bundle LLM `.gguf` weights in the base ISO (to keep the ISO < 2GB).
1. Connect to WiFi via the NiraPanel (Top Right).
2. Open the `Model Manager` application from the app launcher.
3. Download the `Fast Profile` (Qwen 1.5B).

## 3. Telemetry

We collect **ZERO** telemetry by default. To report a bug, run `nira-debug upload` in the terminal. You will be prompted to review the sanitized JSON payload and explicitly type `YES` before it opens a GitHub Issue template.
