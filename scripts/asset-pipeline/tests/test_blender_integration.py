#
#  test_blender_integration.py
#  AniMagic
#
#  Created by dimaswisodewo on 22/07/26.
#

from __future__ import annotations

import json
import hashlib
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


TEST_DIRECTORY = Path(__file__).resolve().parent
PIPELINE = TEST_DIRECTORY.parent / "ar_asset_pipeline.py"
FIXTURE_SCRIPT = TEST_DIRECTORY / "create_test_fixture.py"
BLENDER = Path("/Applications/Blender.app/Contents/MacOS/Blender")
REQUIRED_TOOLS = ("usdzip", "usdchecker", "usdcat", "usdrecord", "sips", "file")
ENABLED = os.environ.get("ANIMAGIC_RUN_BLENDER_INTEGRATION") == "1"
TOOLS_AVAILABLE = BLENDER.is_file() and all(shutil.which(tool) for tool in REQUIRED_TOOLS)


@unittest.skipUnless(ENABLED and TOOLS_AVAILABLE, "set ANIMAGIC_RUN_BLENDER_INTEGRATION=1 to run")
class BlenderIntegrationTests(unittest.TestCase):
    def test_exports_visible_meshes_with_mixed_material_graph(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "ExportFixture.blend"
            subprocess.run(
                [
                    str(BLENDER),
                    "--background",
                    "--python",
                    str(FIXTURE_SCRIPT),
                    "--",
                    str(source),
                    "--ambiguous",
                    "--export-compatible",
                ],
                check=True,
            )
            source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
            output = root / "report"
            subprocess.run(
                [
                    str(PIPELINE),
                    "export",
                    str(source),
                    "--output-dir",
                    str(output),
                ],
                check=True,
            )
            report = json.loads((output / "report.json").read_text(encoding="utf-8"))
            deliverable = source.with_suffix(".usdz")
            self.assertTrue(deliverable.is_file())
            self.assertEqual(report["status"], "technical_pass")
            self.assertEqual(report["buildOptions"]["mode"], "export")
            self.assertEqual(report["buildOptions"]["textureResolution"], "preserved")
            self.assertEqual(len(report["geometry"]["objects"]), 2)
            self.assertEqual(
                report["geometry"]["sourceTriangles"],
                report["geometry"]["optimizedTriangles"],
            )
            self.assertEqual(
                {(texture["width"], texture["height"]) for texture in report["textures"]},
                {(128, 64)},
            )
            self.assertEqual(report["package"]["usdchecker"], "Success!")
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), source_hash)

    def test_builds_procedural_static_prop(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "home"
            home.mkdir()
            source = root / "Fixture.blend"
            environment = os.environ.copy()
            environment["HOME"] = str(home)
            environment["PATH"] = str(home / ".local" / "bin") + os.pathsep + environment["PATH"]
            subprocess.run(
                [str(BLENDER), "--background", "--python", str(FIXTURE_SCRIPT), "--", str(source)],
                check=True,
            )
            source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
            subprocess.run(
                [str(PIPELINE), "install", "--no-path-update"],
                check=True,
                env=environment,
            )
            launcher = home / ".local" / "bin" / "ar-asset"
            doctor_result = subprocess.run(
                [str(launcher), "doctor", "--json"],
                check=False,
                capture_output=True,
                text=True,
                env=environment,
            )
            self.assertEqual(doctor_result.returncode, 0)
            self.assertEqual(json.loads(doctor_result.stdout)["status"], "pass")
            inspection_result = subprocess.run(
                [str(launcher), "inspect", str(source), "--json"],
                check=True,
                capture_output=True,
                text=True,
                env=environment,
            )
            inspection = json.loads(inspection_result.stdout)
            self.assertEqual(len(inspection["visibleMeshes"]), 1)
            self.assertTrue(inspection["visibleMeshes"][0]["plausibleMetricScale"])
            subprocess.run(
                [
                    str(launcher),
                    "build",
                    str(source),
                    "--target-triangles",
                    "1000",
                ],
                check=True,
                env=environment,
            )
            output = home / "Documents" / "AniMagic AR Assets" / "Fixture"
            report = json.loads((output / "report.json").read_text(encoding="utf-8"))
            self.assertEqual(report["status"], "technical_pass")
            self.assertLessEqual(report["geometry"]["optimizedTriangles"], 1000)
            self.assertEqual(report["visualReview"]["status"], "pending")
            self.assertEqual(report["package"]["usdchecker"], "Success!")
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), source_hash)

    def test_texture_only_build_preserves_triangles_and_resizes_textures(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "TextureOnlyFixture.blend"
            subprocess.run(
                [str(BLENDER), "--background", "--python", str(FIXTURE_SCRIPT), "--", str(source)],
                check=True,
            )
            source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
            output = root / "output"
            subprocess.run(
                [
                    str(PIPELINE),
                    "build",
                    str(source),
                    "--textures-only",
                    "--max-texture-size",
                    "64",
                    "--output-dir",
                    str(output),
                ],
                check=True,
            )
            report = json.loads((output / "report.json").read_text(encoding="utf-8"))
            self.assertEqual(report["status"], "technical_pass")
            self.assertTrue(report["buildOptions"]["texturesOnly"])
            self.assertIsNone(report["buildOptions"]["targetTriangles"])
            self.assertEqual(report["buildOptions"]["maxTextureSize"], 64)
            self.assertEqual(
                report["geometry"]["sourceTriangles"],
                report["geometry"]["optimizedTriangles"],
            )
            self.assertTrue(report["textures"])
            for texture in report["textures"]:
                self.assertLessEqual(max(texture["width"], texture["height"]), 64)
                self.assertEqual(texture["width"], texture["height"] * 2)
            self.assertEqual(report["package"]["usdchecker"], "Success!")
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), source_hash)

    def test_inspection_reports_ambiguous_meshes_and_missing_scale(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "Ambiguous.blend"
            subprocess.run(
                [
                    str(BLENDER),
                    "--background",
                    "--python",
                    str(FIXTURE_SCRIPT),
                    "--",
                    str(source),
                    "--ambiguous",
                    "--nonmetric",
                ],
                check=True,
            )
            result = subprocess.run(
                [str(PIPELINE), "inspect", str(source), "--json"],
                check=True,
                capture_output=True,
                text=True,
            )
            inspection = json.loads(result.stdout)
            self.assertEqual(len(inspection["visibleMeshes"]), 2)
            self.assertTrue(
                all(not mesh["plausibleMetricScale"] for mesh in inspection["visibleMeshes"])
            )


if __name__ == "__main__":
    unittest.main()
