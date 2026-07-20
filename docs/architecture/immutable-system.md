# NiraOS Immutable Architecture

## 1. Overview
NiraOS employs a read-only root filesystem built on Arch Linux.
By relying on `systemd-sysupdate` and an A/B partition scheme, NiraOS achieves atomic updates and zero-downtime rollbacks, mirroring the stability of modern appliance OSes like ChromeOS or SteamOS.

## 2. Filesystem Layout

| Partition / Mount | Type | Mutability | Purpose |
|------------------|------|------------|---------|
| `/` (Root A) | SquashFS/ext4 | Read-Only | Active system image (`/usr`, `/bin`, systemd services) |
| `/` (Root B) | SquashFS/ext4 | Read-Only | Inactive system image (updated in the background) |
| `/var` | Btrfs/ext4 | Writable | Persistent state: Flatpaks, containers, system logs, AI models |
| `/etc` | OverlayFS | Writable | System configurations (layered over `/usr/etc` or symlinked) |
| `/home` | Btrfs/ext4 | Writable | User files and application data |

## 3. Update Mechanism (`systemd-sysupdate`)
When an update is triggered:
1. A new system image `.raw` is downloaded to `/var/lib/niraos/updates`.
2. `systemd-sysupdate` verifies the signature.
3. The image is flashed to the inactive Root partition (e.g., Root B).
4. The bootloader (systemd-boot) configuration is updated to swap the active partition on the next boot.
5. If the new partition fails to boot (e.g., kernel panic), systemd-boot's boot counting mechanism automatically reverts to the known-good partition (Root A).

## 4. Package Management
Users **cannot** run `pacman -S` to install software to the host root filesystem.
- **Desktop Apps:** Installed via Flatpak (Flathub).
- **CLI/Dev Tools:** Installed inside Distrobox/Toolbx containers.
- **System Components:** Updated solely via NiraOS OS Images.

## 5. Security Model
- **Tamper-Proofing:** Malware cannot permanently modify system binaries.
- **Rollbacks:** A bad driver update can be instantly reversed.
- **AI Models:** Large language models are stored in `/var/lib/niraos/models`. They are decoupled from the OS image to prevent the root image from being 50GB+.
