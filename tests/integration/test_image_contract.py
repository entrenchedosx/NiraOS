import pathlib
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]


class ImageContractTests(unittest.TestCase):
    def test_image_boots_to_graphical_target(self) -> None:
        config = (REPO_ROOT / "mkosi.conf").read_text(encoding="utf-8")
        self.assertIn("systemd.unit=graphical.target", config)
        self.assertIn("Bootable=yes", config)

    def test_default_terminal_matches_compositor_protocol_support(self) -> None:
        config = (REPO_ROOT / "mkosi.conf").read_text(encoding="utf-8")
        self.assertIn("    qterminal\n", config)
        self.assertNotIn("    foot\n", config)

    def test_real_browser_is_packaged_and_registered_as_default(self) -> None:
        config = (REPO_ROOT / "mkosi.conf").read_text(encoding="utf-8")
        self.assertIn("    falkon\n", config)
        self.assertIn("    pyside6\n", config)
        defaults = (
            REPO_ROOT / "mkosi" / "mkosi.extra" / "etc" / "xdg" / "mimeapps.list"
        ).read_text(encoding="utf-8")
        for mime in (
            "text/html",
            "application/xhtml+xml",
            "x-scheme-handler/http",
            "x-scheme-handler/https",
        ):
            self.assertIn(f"{mime}=org.kde.falkon.desktop", defaults)

    def test_base_image_is_never_attached_read_write_by_launchers(self) -> None:
        powershell = (REPO_ROOT / "scripts" / "run-qemu.ps1").read_text(encoding="utf-8")
        shell = (REPO_ROOT / "run-qemu.sh").read_text(encoding="utf-8")
        verifier = (REPO_ROOT / "scripts" / "verify-qemu.sh").read_text(encoding="utf-8")
        for launcher in (powershell, shell, verifier):
            self.assertIn("qemu-img", launcher)
            self.assertIn("qcow2", launcher)
        self.assertNotIn('"-drive", "format=raw,file=$Image"', powershell)

    def test_safe_qemu_mode_is_explicitly_propagated_to_the_guest(self) -> None:
        session = (
            REPO_ROOT / "mkosi" / "mkosi.extra" / "usr" / "bin" / "start-nira-session"
        ).read_text(encoding="utf-8")
        self.assertIn("opt/nira/graphics-mode/raw", session)
        self.assertIn("GRAPHICS_MODE=software", session)
        for path in (
            REPO_ROOT / "scripts" / "run-qemu.ps1",
            REPO_ROOT / "run-qemu.sh",
            REPO_ROOT / "scripts" / "verify-qemu.sh",
        ):
            launcher = path.read_text(encoding="utf-8")
            self.assertIn("opt/nira/graphics-mode", launcher, str(path))

    def test_headless_verifier_rejects_a_black_framebuffer(self) -> None:
        verifier = (REPO_ROOT / "scripts" / "verify-qemu.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn('-vnc unix:"$vnc_socket"', verifier)
        self.assertIn("--require-visible-content", verifier)
        self.assertNotIn("-display none", verifier)

    def test_unverified_model_is_not_embedded_as_a_visual_asset(self) -> None:
        build_script = (REPO_ROOT / "mkosi.build.chroot").read_text(encoding="utf-8")
        self.assertNotIn('cp -r "$SRCDIR/assets/"*', build_script)
        self.assertIn("model provisioning belongs to the model", build_script)
        embedded_models = list(
            (REPO_ROOT / "mkosi" / "mkosi.extra").rglob("*.gguf")
        )
        self.assertEqual(embedded_models, [], f"embedded models: {embedded_models}")

    def test_boot_blocking_network_wait_is_masked(self) -> None:
        post_install = (REPO_ROOT / "mkosi.postinst.chroot").read_text(encoding="utf-8")
        self.assertIn("systemctl mask NetworkManager-wait-online.service", post_install)


if __name__ == "__main__":
    unittest.main()
