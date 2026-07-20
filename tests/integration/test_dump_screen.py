import importlib.util
import pathlib
import tempfile
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "dump_screen", REPO_ROOT / "scripts" / "dump_screen.py"
)
assert SPEC and SPEC.loader
DUMP_SCREEN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DUMP_SCREEN)


class FramebufferContentTests(unittest.TestCase):
    def write_ppm(self, pixels: bytes) -> pathlib.Path:
        temporary = tempfile.NamedTemporaryFile(suffix=".ppm", delete=False)
        self.addCleanup(pathlib.Path(temporary.name).unlink, missing_ok=True)
        with temporary:
            temporary.write(b"P6\n10 10\n255\n" + pixels)
        return pathlib.Path(temporary.name)

    def test_rejects_an_all_black_framebuffer(self) -> None:
        path = self.write_ppm(bytes(10 * 10 * 3))
        self.assertFalse(DUMP_SCREEN.ppm_has_visible_content(path))

    def test_accepts_a_framebuffer_with_visible_content(self) -> None:
        path = self.write_ppm(bytes([64]) * (10 * 10 * 3))
        self.assertTrue(DUMP_SCREEN.ppm_has_visible_content(path))

    def test_rejects_an_incomplete_framebuffer(self) -> None:
        path = self.write_ppm(bytes(20))
        with self.assertRaisesRegex(RuntimeError, "incomplete PPM payload"):
            DUMP_SCREEN.ppm_has_visible_content(path)


if __name__ == "__main__":
    unittest.main()
