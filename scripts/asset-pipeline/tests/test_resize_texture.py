#
#  test_resize_texture.py
#  AniMagic
#
#  Created by dimaswisodewo on 23/07/26.
#

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPOSITORY_ROOT = Path(__file__).resolve().parents[3]
COMMAND = REPOSITORY_ROOT / "scripts" / "resize-texture"
SOURCE_ICON = (
    REPOSITORY_ROOT
    / "Animagic"
    / "Resources"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
    / "Untitled design-8.png"
)
SIPS = "/usr/bin/sips"


def dimensions(path: Path) -> tuple[int, int]:
    result = subprocess.run(
        [SIPS, "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    properties = {}
    for line in result.stdout.splitlines():
        if ":" in line:
            key, value = line.strip().split(":", maxsplit=1)
            properties[key] = value.strip()
    return int(properties["pixelWidth"]), int(properties["pixelHeight"])


class ResizeTextureTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def make_source(self, width: int, height: int) -> Path:
        source = self.root / "Texture Source.png"
        shutil.copy2(SOURCE_ICON, source)
        subprocess.run(
            [SIPS, "-z", str(height), str(width), str(source)],
            check=True,
            capture_output=True,
            text=True,
        )
        return source

    def run_command(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(COMMAND), *arguments],
            capture_output=True,
            text=True,
        )

    def test_generates_landscape_variants_and_preserves_source(self) -> None:
        source = self.make_source(5000, 2500)

        result = self.run_command(str(source))

        self.assertEqual(result.returncode, 0, result.stderr)
        output_directory = self.root / "Texture Source-resized"
        for size in (512, 1024, 2048, 4096):
            self.assertEqual(
                dimensions(output_directory / f"Texture Source-{size}.png"),
                (size, size // 2),
            )
        self.assertEqual(dimensions(source), (5000, 2500))

    def test_preserves_portrait_aspect_ratio(self) -> None:
        source = self.make_source(2500, 5000)

        result = self.run_command(str(source))

        self.assertEqual(result.returncode, 0, result.stderr)
        output = self.root / "Texture Source-resized" / "Texture Source-512.png"
        self.assertEqual(dimensions(output), (256, 512))

    def test_skips_presets_that_would_upscale(self) -> None:
        source = self.make_source(1000, 500)

        result = self.run_command(str(source))

        self.assertEqual(result.returncode, 0, result.stderr)
        output_directory = self.root / "Texture Source-resized"
        self.assertTrue((output_directory / "Texture Source-512.png").exists())
        self.assertFalse((output_directory / "Texture Source-1024.png").exists())
        self.assertIn("Skipped 1024 px", result.stdout)

    def test_collision_fails_before_writing_other_variants(self) -> None:
        source = self.make_source(2500, 1250)
        output_directory = self.root / "Texture Source-resized"
        output_directory.mkdir()
        collision = output_directory / "Texture Source-1024.png"
        collision.write_bytes(b"existing")

        result = self.run_command(str(source))

        self.assertEqual(result.returncode, 1)
        self.assertEqual(collision.read_bytes(), b"existing")
        self.assertFalse((output_directory / "Texture Source-512.png").exists())
        self.assertIn("--force", result.stderr)

    def test_force_replaces_existing_variant(self) -> None:
        source = self.make_source(1000, 500)
        output_directory = self.root / "Texture Source-resized"
        output_directory.mkdir()
        output = output_directory / "Texture Source-512.png"
        output.write_bytes(b"existing")
        unrelated = output_directory / "artist-notes.txt"
        unrelated.write_text("keep me", encoding="utf-8")

        result = self.run_command("--force", str(source))

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(dimensions(output), (512, 256))
        self.assertEqual(unrelated.read_text(encoding="utf-8"), "keep me")

    def test_reports_missing_and_non_image_inputs(self) -> None:
        missing = self.run_command(str(self.root / "missing.png"))
        non_image_path = self.root / "notes.txt"
        non_image_path.write_text("not an image", encoding="utf-8")
        non_image = self.run_command(str(non_image_path))

        self.assertEqual(missing.returncode, 1)
        self.assertIn("was not found", missing.stderr)
        self.assertEqual(non_image.returncode, 1)
        self.assertIn("Error:", non_image.stderr)

    def test_reports_missing_arguments_and_unknown_options(self) -> None:
        missing_argument = self.run_command()
        source = self.make_source(1000, 500)
        unknown_option = self.run_command("--unknown", str(source))

        self.assertEqual(missing_argument.returncode, 2)
        self.assertIn("the following arguments are required: image", missing_argument.stderr)
        self.assertEqual(unknown_option.returncode, 2)
        self.assertIn("unrecognized arguments", unknown_option.stderr)


if __name__ == "__main__":
    unittest.main()
