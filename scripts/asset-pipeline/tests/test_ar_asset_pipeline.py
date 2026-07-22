#
#  test_ar_asset_pipeline.py
#  AniMagic
#
#  Created by dimaswisodewo on 22/07/26.
#

from __future__ import annotations

import importlib.util
import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock


MODULE_PATH = Path(__file__).parents[1] / "ar_asset_pipeline.py"
WRAPPER_PATH = MODULE_PATH.parents[1] / "ar-asset"
SPEC = importlib.util.spec_from_file_location("ar_asset_pipeline", MODULE_PATH)
assert SPEC and SPEC.loader
pipeline = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pipeline)


class AssetPipelineTests(unittest.TestCase):
    def test_wrapper_forwards_help_from_any_directory(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = pipeline.subprocess.run(
                [str(WRAPPER_PATH), "--help"],
                cwd=directory,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0)
            self.assertIn(
                "{build,export,inspect,approve,guided,install,uninstall,doctor}",
                result.stdout,
            )
            self.assertFalse((Path(directory) / "build").exists())

    def test_normalizes_quoted_and_dragged_paths(self) -> None:
        expected = Path("/tmp/Asset With Spaces.blend").resolve()
        self.assertEqual(
            pipeline.normalize_prompted_path("'/tmp/Asset With Spaces.blend'"), expected
        )
        self.assertEqual(
            pipeline.normalize_prompted_path(r"/tmp/Asset\ With\ Spaces.blend"), expected
        )

    def test_affirmative_requires_explicit_yes(self) -> None:
        self.assertTrue(pipeline.is_affirmative("YES"))
        self.assertFalse(pipeline.is_affirmative(""))
        self.assertFalse(pipeline.is_affirmative("sure"))

    def test_sanitizes_asset_name(self) -> None:
        self.assertEqual(pipeline.sanitize_asset_name("broccoli v3.1 Cycles"), "broccoli_v3_1_Cycles")

    def test_rejects_empty_asset_name(self) -> None:
        with self.assertRaises(pipeline.PipelineError):
            pipeline.sanitize_asset_name("---")

    def test_accepts_plausible_metric_dimensions(self) -> None:
        self.assertTrue(pipeline.dimensions_plausible([0.18, 0.18, 0.20]))

    def test_rejects_implausible_dimensions(self) -> None:
        self.assertFalse(pipeline.dimensions_plausible([18.0, 18.0, 20.0]))
        self.assertFalse(pipeline.dimensions_plausible([0.0, 0.1, 0.1]))

    def test_scales_texture_dimensions_without_changing_aspect_ratio(self) -> None:
        self.assertEqual(pipeline.scaled_dimensions(2048, 1024, 512), (512, 256))

    def test_does_not_enlarge_texture_below_maximum(self) -> None:
        self.assertEqual(pipeline.scaled_dimensions(32, 16, 512), (32, 16))

    def test_export_preserves_texture_dimensions(self) -> None:
        self.assertEqual(pipeline.output_dimensions(4096, 2048, None), (4096, 2048))

    def test_export_parser_uses_material_only_defaults(self) -> None:
        args = pipeline.create_parser().parse_args(["export", "Asset.blend"])
        self.assertEqual(args.command, "export")
        self.assertTrue(args.textures_only)
        self.assertIsNone(args.max_texture_size)
        self.assertIsNone(args.target_triangles)

    def test_build_parser_accepts_texture_only_options(self) -> None:
        args = pipeline.create_parser().parse_args(
            ["build", "Asset.blend", "--textures-only", "--max-texture-size", "512"]
        )
        self.assertTrue(args.textures_only)
        self.assertEqual(args.max_texture_size, 512)
        self.assertEqual(args.target_triangles, pipeline.DEFAULT_TRIANGLES)

    def test_build_parser_rejects_texture_only_with_triangle_target(self) -> None:
        with self.assertRaises(SystemExit), mock.patch("sys.stderr"):
            pipeline.create_parser().parse_args(
                ["build", "Asset.blend", "--textures-only", "--target-triangles", "1000"]
            )

    def test_build_parser_rejects_nonpositive_texture_size(self) -> None:
        with self.assertRaises(SystemExit), mock.patch("sys.stderr"):
            pipeline.create_parser().parse_args(
                ["build", "Asset.blend", "--max-texture-size", "0"]
            )

    def test_validates_dependencies_inside_staging(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            staging = Path(directory)
            usdc = staging / "Asset.usdc"
            texture = staging / "textures" / "Base.jpg"
            texture.parent.mkdir()
            texture.write_bytes(b"texture")
            self.assertEqual(
                pipeline.validate_relative_dependencies(usdc, ["textures/Base.jpg"]),
                [texture.resolve()],
            )

    def test_allows_constant_material_without_dependencies(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            usdc = Path(directory) / "Asset.usdc"
            self.assertEqual(pipeline.validate_relative_dependencies(usdc, []), [])

    def test_rejects_dependency_outside_staging(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            usdc = Path(directory) / "Asset.usdc"
            with self.assertRaises(pipeline.PipelineError):
                pipeline.validate_relative_dependencies(usdc, ["../Base.jpg"])

    def test_approval_records_reviewer_and_timestamp(self) -> None:
        report = {"status": "technical_pass", "visualReview": {"status": "pending"}}
        approved = pipeline.record_visual_approval(report, "Reviewer", "2026-07-22T00:00:00Z")
        self.assertEqual(approved["status"], "approved")
        self.assertEqual(approved["visualReview"]["reviewer"], "Reviewer")

    def test_approval_rejects_failed_build(self) -> None:
        with self.assertRaises(pipeline.PipelineError):
            pipeline.record_visual_approval({"status": "failed"}, "Reviewer", "now")

    def test_sha256_detects_file_changes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "asset.bin"
            path.write_bytes(b"first")
            first = pipeline.sha256(path)
            path.write_bytes(b"second")
            self.assertNotEqual(first, pipeline.sha256(path))

    def test_atomic_delivery_replaces_existing_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "validated.usdz"
            destination = root / "Asset.usdz"
            source.write_bytes(b"validated")
            destination.write_bytes(b"old")
            pipeline.replace_validated_file(source, destination)
            self.assertEqual(destination.read_bytes(), b"validated")
            self.assertFalse(list(root.glob(".Asset.usdz.*.tmp")))

    def test_failed_atomic_delivery_preserves_existing_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            destination = root / "Asset.usdz"
            destination.write_bytes(b"old")
            with self.assertRaises(FileNotFoundError):
                pipeline.replace_validated_file(root / "missing.usdz", destination)
            self.assertEqual(destination.read_bytes(), b"old")

    def test_finds_one_principled_shader_through_a_mix(self) -> None:
        principled = SimpleNamespace(type="BSDF_PRINCIPLED", inputs=[])
        other = SimpleNamespace(type="VALTORGB", inputs=[])
        mix = SimpleNamespace(
            type="MIX_SHADER",
            inputs=[
                SimpleNamespace(links=[SimpleNamespace(from_node=principled)]),
                SimpleNamespace(links=[SimpleNamespace(from_node=other)]),
            ],
        )
        self.assertIs(
            pipeline.find_unique_upstream_principled(mix, "MixedMaterial"),
            principled,
        )

    def test_rejects_ambiguous_principled_shaders(self) -> None:
        first = SimpleNamespace(type="BSDF_PRINCIPLED", inputs=[])
        second = SimpleNamespace(type="BSDF_PRINCIPLED", inputs=[])
        mix = SimpleNamespace(
            type="MIX_SHADER",
            inputs=[
                SimpleNamespace(links=[SimpleNamespace(from_node=first)]),
                SimpleNamespace(links=[SimpleNamespace(from_node=second)]),
            ],
        )
        with self.assertRaises(pipeline.PipelineError):
            pipeline.find_unique_upstream_principled(mix, "AmbiguousMaterial")

    def test_approval_rejects_changed_usdz(self) -> None:
        self.assert_changed_artifact_is_rejected("deliverableUsdz")

    def test_approval_rejects_changed_render(self) -> None:
        self.assert_changed_artifact_is_rejected("validationRender")

    def assert_changed_artifact_is_rejected(self, path_key: str) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            usdz = output / "Asset.usdz"
            render = output / "Validation.png"
            usdz.write_bytes(b"validated-usdz")
            render.write_bytes(b"validated-render")
            report = {
                "status": "technical_pass",
                "artifacts": {
                    "deliverableUsdz": str(usdz),
                    "deliverableSha256": pipeline.sha256(usdz),
                    "validationRender": str(render),
                    "validationRenderSha256": pipeline.sha256(render),
                },
            }
            pipeline.write_json(output / "report.json", report)
            changed = Path(report["artifacts"][path_key])
            changed.write_bytes(b"changed")
            with self.assertRaises(pipeline.PipelineError):
                pipeline.approve_command(SimpleNamespace(output_directory=str(output), reviewer="Reviewer"))

    def test_guided_mode_rejects_noninteractive_terminal(self) -> None:
        with mock.patch.object(pipeline, "is_interactive_terminal", return_value=False):
            with self.assertRaises(pipeline.PipelineError):
                pipeline.guided_command(SimpleNamespace(blender=str(pipeline.DEFAULT_BLENDER)))

    def test_guided_mode_uses_smart_defaults_and_leaves_review_pending(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "Friendly Asset.blend"
            source.write_bytes(b"fixture")
            responses = iter([str(source), "yes", "no"])
            inspection = {
                "visibleMeshes": [
                    {
                        "name": "DeliveryMesh",
                        "evaluatedTriangles": 20000,
                        "plausibleMetricScale": True,
                    }
                ]
            }
            captured: dict[str, object] = {}

            def fake_build(args):
                captured["args"] = args
                output = Path(args.output_dir)
                render = output / "Friendly_Asset_Validation.png"
                render.parent.mkdir(parents=True)
                render.write_bytes(b"png")
                pipeline.write_json(
                    output / "report.json",
                    {"artifacts": {"validationRender": str(render)}},
                )
                return 0

            completed = pipeline.subprocess.CompletedProcess(["open"], 0, "", "")
            with (
                mock.patch.object(pipeline, "is_interactive_terminal", return_value=True),
                mock.patch.object(pipeline, "inspect_asset", return_value=inspection),
                mock.patch.object(pipeline, "build_command", side_effect=fake_build),
                mock.patch.object(pipeline, "run_command", return_value=completed),
                mock.patch.object(pipeline, "approve_command") as approve,
            ):
                result = pipeline.guided_command(
                    SimpleNamespace(blender=str(pipeline.DEFAULT_BLENDER)),
                    input_fn=lambda _: next(responses),
                    repository_root=root,
                )

            self.assertEqual(result, 0)
            build_args = captured["args"]
            self.assertEqual(build_args.target_triangles, pipeline.DEFAULT_TRIANGLES)
            self.assertFalse(build_args.textures_only)
            self.assertEqual(build_args.max_texture_size, pipeline.DEFAULT_TEXTURE_SIZE)
            self.assertIsNone(build_args.object)
            self.assertEqual(
                Path(build_args.output_dir),
                (root / "build" / "asset-pipeline" / "Friendly_Asset").resolve(),
            )
            approve.assert_not_called()

    def test_main_returns_130_when_guided_mode_is_interrupted(self) -> None:
        with mock.patch.object(pipeline, "guided_command", side_effect=KeyboardInterrupt):
            self.assertEqual(pipeline.main(["guided"]), 130)


class InstallationTests(unittest.TestCase):
    def install_args(
        self,
        *,
        force: bool = False,
        add_to_path: bool = False,
        no_path_update: bool = True,
    ) -> SimpleNamespace:
        return SimpleNamespace(
            force=force,
            add_to_path=add_to_path,
            no_path_update=no_path_update,
        )

    def test_managed_install_creates_versioned_payload_and_working_launcher(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            pipeline.install_command(self.install_args(), home=home)
            layout = pipeline.installation_layout(home)
            manifest = pipeline.read_install_manifest(layout["manifest"])

            self.assertTrue(layout["payload"].is_file())
            self.assertTrue(layout["launcher"].is_file())
            self.assertTrue(pipeline.launcher_is_managed(layout["launcher"]))
            self.assertEqual(layout["current"].readlink(), Path(pipeline.CLI_VERSION))
            self.assertEqual(manifest["version"], pipeline.CLI_VERSION)
            self.assertEqual(manifest["versions"][pipeline.CLI_VERSION]["sha256"], pipeline.sha256(layout["payload"]))

            environment = os.environ.copy()
            environment["HOME"] = str(home)
            result = pipeline.subprocess.run(
                [str(layout["launcher"]), "--version"],
                env=environment,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout.strip(), f"ar-asset {pipeline.CLI_VERSION}")

    def test_same_version_reinstall_repairs_in_place(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            args = self.install_args()
            pipeline.install_command(args, home=home)
            pipeline.install_command(args, home=home)
            manifest = pipeline.read_install_manifest(pipeline.installation_layout(home)["manifest"])
            self.assertEqual(list(manifest["versions"]), [pipeline.CLI_VERSION])

    def test_upgrade_preserves_versions_and_moves_current_link(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            with mock.patch.object(pipeline, "CLI_VERSION", "0.1.0"):
                pipeline.install_command(self.install_args(), home=home)
            pipeline.install_command(self.install_args(), home=home)
            layout = pipeline.installation_layout(home)
            manifest = pipeline.read_install_manifest(layout["manifest"])
            self.assertEqual(set(manifest["versions"]), {"0.1.0", "0.3.0"})
            self.assertEqual(layout["current"].readlink(), Path("0.3.0"))

    def test_foreign_launcher_is_refused_without_force(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            layout = pipeline.installation_layout(home)
            layout["launcher"].parent.mkdir(parents=True)
            layout["launcher"].write_text("#!/bin/sh\necho foreign\n", encoding="utf-8")
            with self.assertRaises(pipeline.PipelineError):
                pipeline.install_command(self.install_args(), home=home)
            self.assertIn("foreign", layout["launcher"].read_text(encoding="utf-8"))

    def test_force_replaces_foreign_launcher(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            layout = pipeline.installation_layout(home)
            layout["launcher"].parent.mkdir(parents=True)
            layout["launcher"].write_text("foreign", encoding="utf-8")
            pipeline.install_command(self.install_args(force=True), home=home)
            self.assertTrue(pipeline.launcher_is_managed(layout["launcher"]))

    def test_path_block_is_idempotent_and_removed_on_uninstall(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            layout = pipeline.installation_layout(home)
            layout["zprofile"].write_text("export EXISTING=value\n", encoding="utf-8")
            args = self.install_args(add_to_path=True, no_path_update=False)
            pipeline.install_command(args, home=home)
            pipeline.install_command(args, home=home)
            self.assertEqual(
                layout["zprofile"].read_text(encoding="utf-8").count(pipeline.PATH_BLOCK_START),
                1,
            )
            pipeline.uninstall_command(SimpleNamespace(), home=home)
            profile = layout["zprofile"].read_text(encoding="utf-8")
            self.assertIn("export EXISTING=value", profile)
            self.assertNotIn(pipeline.PATH_BLOCK_START, profile)
            self.assertFalse(layout["appRoot"].exists())
            self.assertFalse(layout["launcher"].exists())

    def test_noninteractive_install_does_not_edit_path_without_flag(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            args = self.install_args(no_path_update=False)
            with mock.patch.object(pipeline, "is_interactive_terminal", return_value=False):
                pipeline.install_command(args, home=home)
            self.assertFalse(pipeline.installation_layout(home)["zprofile"].exists())

    def test_uninstall_refuses_tampered_payload(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            pipeline.install_command(self.install_args(), home=home)
            layout = pipeline.installation_layout(home)
            layout["payload"].write_text("tampered", encoding="utf-8")
            with self.assertRaises(pipeline.PipelineError):
                pipeline.uninstall_command(SimpleNamespace(), home=home)
            self.assertTrue(layout["appRoot"].exists())
            self.assertTrue(layout["launcher"].exists())

    def test_uninstall_refuses_tampered_manifest_paths(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            pipeline.install_command(self.install_args(), home=home)
            layout = pipeline.installation_layout(home)
            manifest = pipeline.read_install_manifest(layout["manifest"])
            manifest["appRoot"] = "/"
            pipeline.write_json(layout["manifest"], manifest)
            with self.assertRaises(pipeline.PipelineError):
                pipeline.uninstall_command(SimpleNamespace(), home=home)
            self.assertTrue(layout["appRoot"].exists())

    def test_uninstall_refuses_unexpected_managed_tree_files(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            pipeline.install_command(self.install_args(), home=home)
            layout = pipeline.installation_layout(home)
            (layout["appRoot"] / "foreign.txt").write_text("foreign", encoding="utf-8")
            with self.assertRaises(pipeline.PipelineError):
                pipeline.uninstall_command(SimpleNamespace(), home=home)
            self.assertTrue((layout["appRoot"] / "foreign.txt").exists())

    def test_doctor_passes_for_valid_temp_install(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            pipeline.install_command(self.install_args(), home=home)
            layout = pipeline.installation_layout(home)
            path_value = str(layout["binDirectory"]) + os.pathsep + os.environ.get("PATH", "")
            with mock.patch.dict(os.environ, {"PATH": path_value}):
                report = pipeline.doctor_report(home=home)
            self.assertEqual(report["status"], "pass")

    def test_doctor_fails_without_installation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            report = pipeline.doctor_report(home=Path(directory))
            self.assertEqual(report["status"], "fail")
            installation = next(check for check in report["checks"] if check["name"] == "installation")
            self.assertEqual(installation["status"], "fail")

    def test_installed_output_root_and_explicit_override(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            configured = home / "Documents" / "AniMagic AR Assets"
            with mock.patch.dict(os.environ, {pipeline.OUTPUT_ROOT_ENV: str(configured)}):
                self.assertEqual(pipeline.default_output_root(), configured.resolve())
                self.assertEqual(
                    pipeline.resolve_output_directory("Asset"),
                    (configured / "Asset").resolve(),
                )
            explicit = home / "custom"
            self.assertEqual(
                pipeline.resolve_output_directory("Asset", str(explicit)), explicit.resolve()
            )


if __name__ == "__main__":
    unittest.main()
