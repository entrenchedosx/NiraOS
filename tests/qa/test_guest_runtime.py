import os
import pathlib
import stat
import subprocess
import unittest


IN_GUEST_QA = os.environ.get("NIRA_QA_GUEST") == "1"


def command(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, text=True, capture_output=True, check=False)


@unittest.skipUnless(IN_GUEST_QA, "set NIRA_QA_GUEST=1 inside a booted NiraOS guest")
class GuestRuntimeTests(unittest.TestCase):
    def assert_unit_active(self, unit: str) -> None:
        result = command("systemctl", "is-active", "--quiet", unit)
        self.assertEqual(result.returncode, 0, f"{unit} is not active: {result.stderr}")

    def test_graphical_boot_and_login_manager(self) -> None:
        self.assert_unit_active("graphical.target")
        self.assert_unit_active("greetd.service")

    def test_core_services_are_really_active(self) -> None:
        for unit in (
            "nira-ai.service",
            "nira-context.service",
            "nira-permission.service",
            "nira-action.service",
        ):
            with self.subTest(unit=unit):
                self.assert_unit_active(unit)

    def test_no_failed_system_units(self) -> None:
        result = command("systemctl", "--failed", "--no-legend", "--plain")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "", result.stdout)

    def test_ipc_sockets_are_group_restricted(self) -> None:
        sockets = list(pathlib.Path("/run/niraos").glob("*.sock"))
        self.assertGreater(len(sockets), 0, "no NiraOS IPC sockets were created")
        for socket_path in sockets:
            with self.subTest(socket=str(socket_path)):
                mode = stat.S_IMODE(socket_path.stat().st_mode)
                self.assertEqual(mode, 0o660)

    def test_terminal_is_installed(self) -> None:
        self.assertTrue(pathlib.Path("/usr/bin/qterminal").is_file())

    def test_browser_is_installed_and_is_the_url_handler(self) -> None:
        self.assertTrue(pathlib.Path("/usr/bin/falkon").is_file())
        self.assertTrue(
            any(pathlib.Path("/usr/lib").glob("python*/site-packages/PySide6")),
            "Falkon's packaged Python plugin is missing the PySide6 runtime",
        )
        result = command("xdg-mime", "query", "default", "x-scheme-handler/https")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "org.kde.falkon.desktop")

    def test_root_filesystem_is_immutable(self) -> None:
        # This is an explicit production gate. It currently fails on mutable
        # development images instead of reporting a fake immutable system.
        result = command("findmnt", "-n", "-o", "OPTIONS", "/")
        self.assertEqual(result.returncode, 0, result.stderr)
        options = set(result.stdout.strip().split(","))
        self.assertIn("ro", options, f"root filesystem is writable: {result.stdout.strip()}")


if __name__ == "__main__":
    unittest.main()
