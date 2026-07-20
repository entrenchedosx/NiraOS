# Alpha Installer Validation

Test Matrix for the initial ISO burn:

- [ ] ISO flashes successfully via `dd`.
- [ ] UEFI bootloader recognizes the partition.
- [ ] Systemd mounts the immutable rootfs.
- [ ] Greetd auto-logs into the `nira` user.
- [ ] GPU driver (`nvidia-open` or `mesa`) initializes successfully.
- [ ] Wayland Compositor displays the NiraShell.
- [ ] `nira-debug status` reports all 6 daemons are "active".
