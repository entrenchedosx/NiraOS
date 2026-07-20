# Getting Started with NiraOS Alpha

Welcome to the NiraOS Developer Preview! NiraOS is an immutable, Wayland-native Linux distribution with a deeply integrated local AI agent.

## First Boot
1. Download the `NiraOS-Alpha.raw` image from the Releases tab.
2. Flash it to a USB drive using BalenaEtcher or `dd`.
3. Boot your system in UEFI mode.

## The Nira AI Overlay
Once you reach the desktop, press **`Super + Space`**.
This opens the Nira AI overlay. The AI operates entirely locally on your GPU. It can see your active Wayland windows, battery status, and file system, allowing you to ask highly contextual questions like *"Summarize this document"* or *"Why is my computer running hot?"*.

## Updating
NiraOS is immutable. Updates are delivered as full image replacements via `systemd-sysupdate`. To check for updates, simply open the Nira Shell settings!
