#!/usr/bin/env python3
#
#  ar_asset_pipeline.py
#  AniMagic
#
#  Created by dimaswisodewo on 22/07/26.
#

"""Build and approve compact, validated USDZ assets from Blender scenes."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from typing import Any, Sequence


DEFAULT_BLENDER = Path("/Applications/Blender.app/Contents/MacOS/Blender")
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_TRIANGLES = 15_000
DEFAULT_TEXTURE_SIZE = 1_024
MIN_PLAUSIBLE_METERS = 0.005
MAX_PLAUSIBLE_METERS = 10.0
REPORT_SCHEMA_VERSION = 1
CLI_VERSION = "0.3.0"
INSTALL_SCHEMA_VERSION = 1
OUTPUT_ROOT_ENV = "ANIMAGIC_AR_ASSET_OUTPUT_ROOT"
MANAGED_LAUNCHER_MARKER = "# AniMagic ar-asset managed launcher"
PATH_BLOCK_START = "# >>> AniMagic ar-asset >>>"
PATH_BLOCK_END = "# <<< AniMagic ar-asset <<<"
PATH_BLOCK = (
    f"{PATH_BLOCK_START}\n"
    'export PATH="$HOME/.local/bin:$PATH"\n'
    f"{PATH_BLOCK_END}\n"
)


class PipelineError(RuntimeError):
    """A user-actionable asset pipeline failure."""


def sanitize_asset_name(value: str) -> str:
    words = re.findall(r"[A-Za-z0-9]+", value)
    if not words:
        raise PipelineError("Asset name must contain at least one letter or number.")
    return "_".join(words)


def positive_integer(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def dimensions_plausible(dimensions: Sequence[float]) -> bool:
    return (
        len(dimensions) == 3
        and all(value > 0 for value in dimensions)
        and max(dimensions) <= MAX_PLAUSIBLE_METERS
        and max(dimensions) >= MIN_PLAUSIBLE_METERS
    )


def scaled_dimensions(width: int, height: int, maximum: int) -> tuple[int, int]:
    if width <= 0 or height <= 0:
        raise PipelineError("Texture dimensions must be greater than zero.")
    if maximum <= 0:
        raise PipelineError("Maximum texture size must be greater than zero.")
    factor = min(1.0, maximum / max(width, height))
    return max(1, round(width * factor)), max(1, round(height * factor))


def output_dimensions(
    width: int, height: int, maximum: int | None
) -> tuple[int, int]:
    if maximum is None:
        if width <= 0 or height <= 0:
            raise PipelineError("Texture dimensions must be greater than zero.")
        return width, height
    return scaled_dimensions(width, height, maximum)


def validate_relative_dependencies(usdc_path: Path, references: Sequence[str]) -> list[Path]:
    staging = usdc_path.parent.resolve()
    resolved: list[Path] = []
    for reference in references:
        if os.path.isabs(reference) or "[" in reference or "]" in reference:
            raise PipelineError(f"USD dependency is not a plain relative path: {reference}")
        candidate = (staging / reference).resolve()
        try:
            candidate.relative_to(staging)
        except ValueError as error:
            raise PipelineError(f"USD dependency escapes staging: {reference}") from error
        if not candidate.is_file():
            raise PipelineError(f"USD dependency does not exist: {reference}")
        resolved.append(candidate)
    return resolved


def record_visual_approval(
    report: dict[str, Any], reviewer: str, approved_at: str
) -> dict[str, Any]:
    if report.get("status") != "technical_pass":
        raise PipelineError("Only a technically passing build can be approved.")
    if not reviewer.strip():
        raise PipelineError("A reviewer name is required for visual approval.")
    report["visualReview"] = {
        "status": "approved",
        "reviewer": reviewer.strip(),
        "approvedAt": approved_at,
    }
    report["status"] = "approved"
    return report


def run_command(
    command: Sequence[str | Path],
    *,
    cwd: Path | None = None,
    require_success: bool = True,
) -> subprocess.CompletedProcess[str]:
    printable = [str(item) for item in command]
    result = subprocess.run(
        printable,
        cwd=cwd,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if require_success and result.returncode != 0:
        raise PipelineError(
            f"Command failed ({result.returncode}): {' '.join(printable)}\n{result.stdout.strip()}"
        )
    return result


def require_tools(blender: Path) -> dict[str, str]:
    tools = {"blender": require_blender(blender)}
    for name in ("file", "sips", "usdzip", "usdchecker", "usdcat", "usdrecord"):
        resolved = shutil.which(name)
        if resolved is None:
            raise PipelineError(f"Required tool was not found on PATH: {name}")
        tools[name] = resolved
    return tools


def require_blender(blender: Path) -> str:
    if not blender.is_file():
        raise PipelineError(f"Blender executable was not found: {blender}")
    return str(blender)


def extract_asset_references(usd_text: str) -> list[str]:
    return re.findall(r"asset inputs:file\s*=\s*@([^@]+)@", usd_text)


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def replace_validated_file(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{destination.name}.",
        suffix=".tmp",
        dir=destination.parent,
    )
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        shutil.copy2(source, temporary)
        if sha256(source) != sha256(temporary):
            raise PipelineError("Copied USDZ hash differs from the validated package.")
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def default_output_root() -> Path:
    configured = os.environ.get(OUTPUT_ROOT_ENV)
    if configured:
        return Path(configured).expanduser().resolve()
    return (Path.cwd() / "build" / "asset-pipeline").resolve()


def resolve_output_directory(asset_name: str, explicit: str | None = None) -> Path:
    if explicit:
        return Path(explicit).expanduser().resolve()
    return (default_output_root() / asset_name).resolve()


def installation_layout(home: Path | None = None) -> dict[str, Path]:
    user_home = (home or Path.home()).expanduser().resolve()
    app_root = user_home / ".local" / "share" / "animagic-ar-asset"
    return {
        "home": user_home,
        "appRoot": app_root,
        "versionDirectory": app_root / CLI_VERSION,
        "payload": app_root / CLI_VERSION / "ar_asset_pipeline.py",
        "current": app_root / "current",
        "manifest": app_root / "manifest.json",
        "binDirectory": user_home / ".local" / "bin",
        "launcher": user_home / ".local" / "bin" / "ar-asset",
        "zprofile": user_home / ".zprofile",
        "documentsOutput": user_home / "Documents" / "AniMagic AR Assets",
    }


def managed_launcher_text() -> str:
    return f'''#!/bin/sh
{MANAGED_LAUNCHER_MARKER}
set -eu

payload="$HOME/.local/share/animagic-ar-asset/current/ar_asset_pipeline.py"
export {OUTPUT_ROOT_ENV}="$HOME/Documents/AniMagic AR Assets"
exec "$payload" "$@"
'''


def launcher_is_managed(path: Path) -> bool:
    try:
        return MANAGED_LAUNCHER_MARKER in path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return False


def path_contains(directory: Path, path_value: str | None = None) -> bool:
    entries = (path_value if path_value is not None else os.environ.get("PATH", "")).split(os.pathsep)
    expected = directory.expanduser().resolve()
    return any(Path(entry).expanduser().resolve() == expected for entry in entries if entry)


def add_path_block(zprofile: Path) -> bool:
    existing = zprofile.read_text(encoding="utf-8") if zprofile.exists() else ""
    if PATH_BLOCK_START in existing and PATH_BLOCK_END in existing:
        return False
    zprofile.parent.mkdir(parents=True, exist_ok=True)
    prefix = existing
    if prefix and not prefix.endswith("\n"):
        prefix += "\n"
    if prefix:
        prefix += "\n"
    zprofile.write_text(prefix + PATH_BLOCK, encoding="utf-8")
    return True


def remove_path_block(zprofile: Path) -> bool:
    if not zprofile.exists():
        return False
    existing = zprofile.read_text(encoding="utf-8")
    pattern = re.compile(
        rf"(?:\n)?{re.escape(PATH_BLOCK_START)}\n"
        rf"export PATH=\"\$HOME/\.local/bin:\$PATH\"\n"
        rf"{re.escape(PATH_BLOCK_END)}\n?"
    )
    updated, count = pattern.subn("\n" if "\n" in existing else "", existing, count=1)
    if count == 0:
        return False
    zprofile.write_text(updated.strip("\n") + ("\n" if updated.strip("\n") else ""), encoding="utf-8")
    return True


def read_install_manifest(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise PipelineError(f"Installation manifest is unreadable: {path}") from error
    if manifest.get("schemaVersion") != INSTALL_SCHEMA_VERSION:
        raise PipelineError(f"Unsupported installation manifest: {path}")
    return manifest


def validate_manifest_layout(manifest: dict[str, Any], layout: dict[str, Path]) -> None:
    expected = {
        "appRoot": str(layout["appRoot"]),
        "launcher": str(layout["launcher"]),
    }
    for key, value in expected.items():
        if manifest.get(key) != value:
            raise PipelineError(f"Installation manifest has an unsafe {key} path.")
    versions = manifest.get("versions")
    if not isinstance(versions, dict) or not versions:
        raise PipelineError("Installation manifest contains no managed versions.")
    for version, details in versions.items():
        expected_payload = layout["appRoot"] / version / "ar_asset_pipeline.py"
        if not isinstance(details, dict) or details.get("payload") != str(expected_payload):
            raise PipelineError(f"Installation manifest has an unsafe payload for version {version}.")


def install_command(
    args: argparse.Namespace,
    *,
    home: Path | None = None,
    input_fn: Any = input,
) -> int:
    layout = installation_layout(home)
    manifest = read_install_manifest(layout["manifest"])
    if layout["appRoot"].exists() and manifest is None:
        raise PipelineError(
            f"Refusing to use an unowned installation directory: {layout['appRoot']}"
        )
    if manifest:
        validate_manifest_layout(manifest, layout)

    launcher = layout["launcher"]
    if launcher.exists() and not launcher_is_managed(launcher) and not args.force:
        raise PipelineError(
            f"An unrelated command already exists at {launcher}. Use --force to replace it."
        )
    current = layout["current"]
    if current.exists() and not current.is_symlink():
        raise PipelineError(f"Refusing to replace non-symlink installation target: {current}")

    layout["versionDirectory"].mkdir(parents=True, exist_ok=True)
    source = Path(__file__).resolve()
    payload = layout["payload"]
    if source != payload.resolve():
        shutil.copy2(source, payload)
    payload.chmod(0o755)

    current.unlink(missing_ok=True)
    current.symlink_to(CLI_VERSION)

    layout["binDirectory"].mkdir(parents=True, exist_ok=True)
    launcher.write_text(managed_launcher_text(), encoding="utf-8")
    launcher.chmod(0o755)

    previous_path_added = bool(manifest and manifest.get("pathBlockAdded"))
    path_added = previous_path_added
    path_is_ready = path_contains(layout["binDirectory"])
    should_add_path = bool(args.add_to_path)
    if not args.add_to_path and not args.no_path_update and not path_is_ready:
        if is_interactive_terminal():
            should_add_path = is_affirmative(
                input_fn(f"Add {layout['binDirectory']} to PATH in {layout['zprofile']}? [y/N]: ")
            )
    if should_add_path:
        path_added = add_path_block(layout["zprofile"]) or previous_path_added

    versions = dict(manifest.get("versions", {})) if manifest else {}
    versions[CLI_VERSION] = {
        "payload": str(payload),
        "sha256": sha256(payload),
    }
    new_manifest = {
        "schemaVersion": INSTALL_SCHEMA_VERSION,
        "version": CLI_VERSION,
        "installedAt": utc_now(),
        "appRoot": str(layout["appRoot"]),
        "launcher": str(launcher),
        "launcherSha256": sha256(launcher),
        "pathBlockAdded": path_added,
        "versions": versions,
    }
    write_json(layout["manifest"], new_manifest)

    previous_version = manifest.get("version") if manifest else None
    action = "Updated" if previous_version and previous_version != CLI_VERSION else (
        "Repaired" if previous_version else "Installed"
    )
    print(f"{action} ar-asset {CLI_VERSION} at {launcher}")
    if not path_contains(layout["binDirectory"]):
        print(f'PATH is not active in this shell. Run: export PATH="{layout["binDirectory"]}:$PATH"')
    print("Run 'ar-asset doctor' to verify the installation.")
    return 0


def validate_installed_tree(layout: dict[str, Path], manifest: dict[str, Any]) -> None:
    validate_manifest_layout(manifest, layout)
    if not layout["launcher"].is_file() or not launcher_is_managed(layout["launcher"]):
        raise PipelineError("Managed launcher is missing or no longer has its ownership marker.")
    if sha256(layout["launcher"]) != manifest.get("launcherSha256"):
        raise PipelineError("Managed launcher differs from the installation manifest.")
    allowed_root_entries = {"manifest.json", "current", *manifest["versions"].keys()}
    actual_root_entries = {entry.name for entry in layout["appRoot"].iterdir()}
    unexpected = actual_root_entries - allowed_root_entries
    if unexpected:
        raise PipelineError(
            f"Installation contains unexpected files; refusing removal: {', '.join(sorted(unexpected))}"
        )
    for version, details in manifest["versions"].items():
        version_directory = layout["appRoot"] / version
        expected_payload = Path(details["payload"])
        if not version_directory.is_dir() or {item.name for item in version_directory.iterdir()} != {
            "ar_asset_pipeline.py"
        }:
            raise PipelineError(f"Managed version directory is incomplete or unexpected: {version}")
        if not expected_payload.is_file() or sha256(expected_payload) != details.get("sha256"):
            raise PipelineError(f"Managed payload hash mismatch for version {version}.")
    if not layout["current"].is_symlink() or os.readlink(layout["current"]) != manifest["version"]:
        raise PipelineError("Managed current-version link is missing or unsafe.")


def uninstall_command(args: argparse.Namespace, *, home: Path | None = None) -> int:
    del args
    layout = installation_layout(home)
    manifest = read_install_manifest(layout["manifest"])
    if manifest is None:
        raise PipelineError(f"ar-asset is not installed under {layout['appRoot']}")
    validate_installed_tree(layout, manifest)

    layout["launcher"].unlink()
    if manifest.get("pathBlockAdded"):
        remove_path_block(layout["zprofile"])
    shutil.rmtree(layout["appRoot"])
    print(f"Removed ar-asset and its managed payload from {layout['home']}")
    return 0


def writable_destination(path: Path) -> bool:
    candidate = path.expanduser()
    while not candidate.exists() and candidate != candidate.parent:
        candidate = candidate.parent
    return candidate.exists() and os.access(candidate, os.W_OK)


def doctor_report(*, home: Path | None = None) -> dict[str, Any]:
    layout = installation_layout(home)
    checks: list[dict[str, Any]] = []

    def add(name: str, passed: bool, message: str, required: bool = True) -> None:
        checks.append(
            {
                "name": name,
                "status": "pass" if passed else ("fail" if required else "warning"),
                "required": required,
                "message": message,
            }
        )

    add(
        "python",
        sys.version_info >= (3, 9),
        f"Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
    )
    manifest: dict[str, Any] | None = None
    try:
        manifest = read_install_manifest(layout["manifest"])
        if manifest is None:
            raise PipelineError("managed installation not found")
        validate_installed_tree(layout, manifest)
        add("installation", True, f"managed ar-asset {manifest['version']}")
    except PipelineError as error:
        add("installation", False, str(error))
    add(
        "path",
        path_contains(layout["binDirectory"]),
        f"{layout['binDirectory']} is "
        + ("on PATH" if path_contains(layout["binDirectory"]) else "not on PATH"),
    )
    add("blender", DEFAULT_BLENDER.is_file(), str(DEFAULT_BLENDER))
    for tool in ("file", "sips", "usdzip", "usdchecker", "usdcat", "usdrecord"):
        resolved = shutil.which(tool)
        add(tool, resolved is not None, resolved or f"{tool} not found on PATH")
    usdrecord = shutil.which("usdrecord")
    if usdrecord:
        renderer_help = run_command([usdrecord, "--help"], require_success=False)
        metal_available = renderer_help.returncode == 0 and "TEXT:{Metal}" in renderer_help.stdout
        add(
            "metal",
            metal_available,
            "Metal renderer is registered" if metal_available else "Metal renderer is not registered",
        )
    else:
        add("metal", False, "usdrecord is unavailable, so Metal cannot be checked")
    output = layout["documentsOutput"]
    add("output", writable_destination(output), f"default output: {output}")
    required_failures = [check for check in checks if check["required"] and check["status"] == "fail"]
    return {
        "schemaVersion": 1,
        "cliVersion": CLI_VERSION,
        "status": "pass" if not required_failures else "fail",
        "checks": checks,
    }


def doctor_command(args: argparse.Namespace, *, home: Path | None = None) -> int:
    report = doctor_report(home=home)
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print(f"ar-asset {CLI_VERSION} doctor: {report['status']}")
        for check in report["checks"]:
            symbol = "✓" if check["status"] == "pass" else ("!" if check["status"] == "warning" else "✗")
            print(f"{symbol} {check['name']}: {check['message']}")
    return 0 if report["status"] == "pass" else 1


def normalize_prompted_path(value: str) -> Path:
    literal = Path(value.strip()).expanduser()
    if literal.exists():
        return literal.resolve()
    try:
        parts = shlex.split(value.strip())
    except ValueError as error:
        raise PipelineError(f"Could not parse source path: {error}") from error
    if len(parts) != 1:
        raise PipelineError("Enter exactly one .blend path.")
    return Path(parts[0]).expanduser().resolve()


def is_affirmative(value: str) -> bool:
    return value.strip().lower() in {"y", "yes"}


def is_interactive_terminal() -> bool:
    return sys.stdin.isatty() and sys.stdout.isatty()


def inspect_asset(source: Path, blender: Path) -> dict[str, Any]:
    source = source.expanduser().resolve()
    if not source.is_file() or source.suffix.lower() != ".blend":
        raise PipelineError(f"Source must be an existing .blend file: {source}")
    blender_path = require_blender(blender.expanduser().resolve())
    source_hash = sha256(source)
    with tempfile.TemporaryDirectory(prefix="animagic-ar-inspect-") as directory:
        temporary = Path(directory)
        report_path = temporary / "inspection.json"
        options_path = temporary / "options.json"
        write_json(
            options_path,
            {
                "mode": "inspect",
                "source": str(source),
                "reportPath": str(report_path),
            },
        )
        result = run_command(
            [
                blender_path,
                "--background",
                str(source),
                "--python",
                str(Path(__file__).resolve()),
                "--",
                "--blender-worker",
                str(options_path),
            ]
        )
        if not report_path.is_file():
            raise PipelineError(f"Blender did not create an inspection report.\n{result.stdout.strip()}")
        report = json.loads(report_path.read_text(encoding="utf-8"))
    if sha256(source) != source_hash:
        raise PipelineError("The artist source changed during inspection.")
    report["source"] = {"path": str(source), "sha256": source_hash, "unchanged": True}
    return report


def inspect_command(args: argparse.Namespace) -> int:
    report = inspect_asset(Path(args.source), Path(args.blender))
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
        return 0
    scene = report["scene"]
    print(f"Source: {report['source']['path']}")
    print(
        f"Units: {scene['unitSystem']} (scale length {scene['scaleLength']}); "
        f"Blender {report['blenderVersion']}"
    )
    meshes = report["visibleMeshes"]
    print(f"Visible meshes: {len(meshes)}")
    for mesh in meshes:
        dimensions = " × ".join(f"{value:.4f}" for value in mesh["dimensionsMeters"])
        scale_note = "plausible meters" if mesh["plausibleMetricScale"] else "height required"
        print(
            f"- {mesh['name']}: {mesh['evaluatedTriangles']} triangles, "
            f"{dimensions} m, {scale_note}"
        )
    return 0


def guided_command(
    args: argparse.Namespace,
    *,
    input_fn: Any = input,
    repository_root: Path = REPOSITORY_ROOT,
) -> int:
    if not is_interactive_terminal():
        raise PipelineError(
            "Guided mode requires an interactive terminal. "
            "Use './scripts/ar-asset build --help' for non-interactive usage."
        )

    print("AniMagic AR Asset Builder")
    source = normalize_prompted_path(input_fn("Blend source (type or drag from Finder): "))
    blender = Path(args.blender).expanduser().resolve()
    inspection = inspect_asset(source, blender)
    meshes = inspection["visibleMeshes"]
    if not meshes:
        raise PipelineError("The source contains no visible renderable mesh.")

    if len(meshes) == 1:
        selected = meshes[0]
        object_name = None
        print(f"Detected delivery mesh: {selected['name']}")
    else:
        print("Visible meshes:")
        for index, mesh in enumerate(meshes, start=1):
            print(f"  {index}. {mesh['name']} ({mesh['evaluatedTriangles']} triangles)")
        selected = prompt_mesh_choice(meshes, input_fn)
        object_name = selected["name"]

    target_height: float | None = None
    if not selected["plausibleMetricScale"]:
        target_height = prompt_positive_float(
            "Intended real-world height in meters (for example 0.20): ", input_fn
        )

    name = sanitize_asset_name(source.stem)
    guided_root = (
        default_output_root()
        if os.environ.get(OUTPUT_ROOT_ENV)
        else (repository_root / "build" / "asset-pipeline").resolve()
    )
    output_root = (guided_root / name).resolve()
    print("\nBuild summary")
    print(f"  Source: {source}")
    print(f"  Mesh: {selected['name']}")
    print(f"  Triangle budget: {DEFAULT_TRIANGLES}")
    if target_height is not None:
        print(f"  Target height: {target_height:g} m")
    else:
        print("  Scale: preserve source metric dimensions")
    print(f"  Output: {output_root}")
    if not is_affirmative(input_fn("Build this asset? [y/N]: ")):
        print("Build cancelled.")
        return 0

    build_args = argparse.Namespace(
        source=str(source),
        name=name,
        object=object_name,
        target_triangles=DEFAULT_TRIANGLES,
        textures_only=False,
        max_texture_size=DEFAULT_TEXTURE_SIZE,
        target_height_m=target_height,
        output_dir=str(output_root),
        blender=str(blender),
    )
    result = build_command(build_args)
    report_path = output_root / "report.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    render = Path(report["artifacts"]["validationRender"])
    opener = shutil.which("open")
    if opener:
        opened = run_command([opener, render], require_success=False)
        if opened.returncode != 0:
            print(f"Could not open the Metal render automatically: {render}")
    else:
        print(f"Open the Metal render manually: {render}")

    if is_affirmative(input_fn("Does the Metal render look correct? [y/N]: ")):
        approve_command(argparse.Namespace(output_directory=str(output_root), reviewer=None))
    else:
        print(f"Visual review remains pending: {report_path}")
    return result


def prompt_mesh_choice(meshes: Sequence[dict[str, Any]], input_fn: Any) -> dict[str, Any]:
    while True:
        response = input_fn(f"Select delivery mesh [1-{len(meshes)}]: ").strip()
        if response.isdigit() and 1 <= int(response) <= len(meshes):
            return meshes[int(response) - 1]
        print("Enter one of the listed mesh numbers.")


def prompt_positive_float(prompt: str, input_fn: Any) -> float:
    while True:
        response = input_fn(prompt).strip()
        try:
            value = float(response)
        except ValueError:
            value = 0.0
        if value > 0:
            return value
        print("Enter a number greater than zero.")


def build_command(args: argparse.Namespace) -> int:
    source = Path(args.source).expanduser().resolve()
    if not source.is_file() or source.suffix.lower() != ".blend":
        raise PipelineError(f"Source must be an existing .blend file: {source}")

    export_mode = getattr(args, "command", None) == "export"
    name = sanitize_asset_name(args.name or source.stem)
    output_root = resolve_output_directory(name, args.output_dir)
    staging = output_root / "staging"
    textures = staging / "textures"
    report_path = output_root / "report.json"
    blender = Path(args.blender).expanduser().resolve()
    tools = require_tools(blender)
    source_hash = sha256(source)

    output_root.mkdir(parents=True, exist_ok=True)
    textures.mkdir(parents=True, exist_ok=True)
    worker_report_path = output_root / "worker-report.json"
    worker_options = {
        "mode": "export" if export_mode else "build",
        "source": str(source),
        "name": name,
        "object": None if export_mode else args.object,
        "targetTriangles": (
            None if export_mode or args.textures_only else args.target_triangles
        ),
        "texturesOnly": export_mode or args.textures_only,
        "maxTextureSize": None if export_mode else args.max_texture_size,
        "targetHeightMeters": None if export_mode else args.target_height_m,
        "outputRoot": str(output_root),
        "reportPath": str(worker_report_path),
    }
    options_path = output_root / "worker-options.json"
    write_json(options_path, worker_options)

    initial_report: dict[str, Any] = {
        "schemaVersion": REPORT_SCHEMA_VERSION,
        "asset": name,
        "status": "building",
        "source": {"path": str(source), "sha256": source_hash},
        "outputDirectory": str(output_root),
        "startedAt": utc_now(),
        "visualReview": {"status": "not_ready"},
    }
    write_json(report_path, initial_report)

    try:
        worker_result = run_command(
            [
                tools["blender"],
                "--background",
                str(source),
                "--python",
                str(Path(__file__).resolve()),
                "--",
                "--blender-worker",
                str(options_path),
            ]
        )
        if not worker_report_path.is_file():
            raise PipelineError(f"Blender did not create its report.\n{worker_result.stdout.strip()}")
        worker_report = json.loads(worker_report_path.read_text(encoding="utf-8"))
        if sha256(source) != source_hash:
            raise PipelineError("The artist source changed during conversion; refusing delivery.")

        optimized_blend_value = worker_report["artifacts"].get("optimizedBlend")
        optimized_blend = Path(optimized_blend_value) if optimized_blend_value else None
        usdc = Path(worker_report["artifacts"]["usdc"])
        texture_paths = [Path(path) for path in worker_report["artifacts"]["textures"]]
        texture_validation = validate_texture_files(
            texture_paths, tools, None if export_mode else args.max_texture_size
        )

        usd_text = run_command([tools["usdcat"], usdc]).stdout
        references = extract_asset_references(usd_text)
        resolved_dependencies = validate_relative_dependencies(usdc, references)
        validate_usdc_contract(usd_text)

        staged_usdz = staging / f"{name}_Fixed.usdz"
        if staged_usdz.exists():
            staged_usdz.unlink()
        packaging = run_command(
            [tools["usdzip"], staged_usdz.name, "--arkitAsset", usdc.name, "-v"],
            cwd=staging,
        )
        package_inventory = validate_package(staged_usdz, usdc, resolved_dependencies)

        checker = run_command([tools["usdchecker"], staged_usdz])
        if "Success!" not in checker.stdout:
            raise PipelineError(f"usdchecker did not report Success!\n{checker.stdout.strip()}")

        flattened = run_command([tools["usdcat"], staged_usdz, "--flatten"]).stdout
        validate_flattened_contract(flattened)

        validation_render = output_root / f"{name}_Validation.png"
        if validation_render.exists():
            validation_render.unlink()
        metal = run_command(
            [tools["usdrecord"], staged_usdz, validation_render, "-w", "1200", "-r", "Metal"]
        )
        if not validation_render.is_file() or validation_render.stat().st_size == 0:
            raise PipelineError("Apple Metal validation did not produce a non-empty PNG.")

        delivered_usdz = source.with_suffix(".usdz") if export_mode else output_root / staged_usdz.name
        if export_mode:
            replace_validated_file(staged_usdz, delivered_usdz)
        else:
            shutil.copy2(staged_usdz, delivered_usdz)
        staged_hash = sha256(staged_usdz)
        delivered_hash = sha256(delivered_usdz)
        if staged_hash != delivered_hash:
            raise PipelineError("Delivered USDZ hash differs from the validated staging package.")

        report = {
            **initial_report,
            "status": "technical_pass",
            "completedAt": utc_now(),
            "source": {"path": str(source), "sha256": source_hash, "unchanged": True},
            "buildOptions": {
                "mode": "export" if export_mode else "build",
                "texturesOnly": export_mode or args.textures_only,
                "targetTriangles": (
                    None if export_mode or args.textures_only else args.target_triangles
                ),
                "maxTextureSize": None if export_mode else args.max_texture_size,
                "textureResolution": "preserved" if export_mode else "capped",
            },
            "tools": {
                **tools,
                "blenderVersion": worker_report["blenderVersion"],
            },
            "geometry": worker_report["geometry"],
            "materials": worker_report["materials"],
            "textures": texture_validation,
            "dependencies": {
                "references": references,
                "resolved": [str(path) for path in resolved_dependencies],
            },
            "package": {
                "inventory": package_inventory,
                "bytes": delivered_usdz.stat().st_size,
                "sha256": delivered_hash,
                "usdchecker": "Success!",
            },
            "validation": {
                "shaderContract": "pass",
                "metalRender": "generated",
                "metalOutput": metal.stdout.strip(),
            },
            "artifacts": {
                "optimizedBlend": str(optimized_blend) if optimized_blend else None,
                "stagedUsdc": str(usdc),
                "stagedUsdz": str(staged_usdz),
                "deliverableUsdz": str(delivered_usdz),
                "validationRender": str(validation_render),
                "deliverableSha256": delivered_hash,
                "validationRenderSha256": sha256(validation_render),
            },
            "logs": {
                "blender": worker_result.stdout.strip(),
                "usdzip": packaging.stdout.strip(),
                "usdchecker": checker.stdout.strip(),
            },
            "visualReview": {"status": "pending"},
        }
        write_json(report_path, report)
        options_path.unlink(missing_ok=True)
        worker_report_path.unlink(missing_ok=True)
        if export_mode:
            print_export_summary(report, report_path)
        else:
            print_build_summary(report, report_path)
        return 0
    except Exception as error:
        initial_report["status"] = "failed"
        initial_report["failedAt"] = utc_now()
        initial_report["error"] = str(error)
        write_json(report_path, initial_report)
        raise


def validate_texture_files(
    paths: Sequence[Path], tools: dict[str, str], max_texture_size: int | None
) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for path in paths:
        if not path.is_file():
            raise PipelineError(f"Expected staged texture is missing: {path}")
        file_output = run_command([tools["file"], path]).stdout.strip()
        sips_output = run_command(
            [tools["sips"], "-g", "pixelWidth", "-g", "pixelHeight", "-g", "format", path]
        ).stdout
        width_match = re.search(r"pixelWidth:\s*(\d+)", sips_output)
        height_match = re.search(r"pixelHeight:\s*(\d+)", sips_output)
        format_match = re.search(r"format:\s*(\w+)", sips_output)
        if not (width_match and height_match and format_match):
            raise PipelineError(f"Could not inspect texture metadata: {path}\n{sips_output}")
        width = int(width_match.group(1))
        height = int(height_match.group(1))
        image_format = format_match.group(1).lower()
        if max_texture_size is not None and max(width, height) > max_texture_size:
            raise PipelineError(
                f"Texture exceeds {max_texture_size} px: {path} ({width}x{height})"
            )
        suffix = path.suffix.lower()
        if suffix in (".jpg", ".jpeg"):
            if image_format not in ("jpeg", "jpg") or "components 3" not in file_output:
                raise PipelineError(f"Base-color texture is not a genuine RGB JPEG: {path}")
        elif suffix == ".png":
            if image_format != "png" or "8-bit/color RGB" not in file_output:
                raise PipelineError(f"Normal texture is not a genuine 8-bit RGB PNG: {path}")
        else:
            raise PipelineError(f"Unsupported staged texture extension: {path}")
        results.append(
            {
                "path": str(path),
                "width": width,
                "height": height,
                "format": image_format,
                "sha256": sha256(path),
            }
        )
    return results


def validate_usdc_contract(usd_text: str) -> None:
    required = (
        'metersPerUnit = 1',
        'upAxis = "Z"',
        "primvars:st",
        "material:binding",
        "float inputs:roughness = 0.65",
        "float inputs:specular = 0.25",
    )
    missing = [value for value in required if value not in usd_text]
    if missing:
        raise PipelineError(f"USDC contract is missing: {', '.join(missing)}")
    if re.search(r"inputs:(roughness|specular)\.connect", usd_text):
        raise PipelineError("A texture is connected to roughness or specular.")


def validate_flattened_contract(usd_text: str) -> None:
    validate_usdc_contract(usd_text)
    references = extract_asset_references(usd_text)
    if any(".usdz[" not in reference for reference in references):
        raise PipelineError("Flattened USDZ texture references do not resolve inside the package.")


def validate_package(
    usdz: Path, usdc: Path, dependencies: Sequence[Path]
) -> list[dict[str, Any]]:
    if not zipfile.is_zipfile(usdz):
        raise PipelineError(f"Packaged output is not a ZIP-compatible USDZ: {usdz}")
    with zipfile.ZipFile(usdz) as archive:
        inventory = [
            {"name": item.filename, "bytes": item.file_size}
            for item in archive.infolist()
            if not item.is_dir()
        ]
    names = [item["name"] for item in inventory]
    if usdc.name not in names:
        raise PipelineError(f"USDZ does not contain its root layer: {usdc.name}")
    packaged_basenames = {Path(name).name for name in names}
    missing = [path.name for path in dependencies if path.name not in packaged_basenames]
    if missing:
        raise PipelineError(f"USDZ is missing texture dependencies: {', '.join(missing)}")
    return inventory


def approve_command(args: argparse.Namespace) -> int:
    output_root = Path(args.output_directory).expanduser().resolve()
    report_path = output_root / "report.json"
    if not report_path.is_file():
        raise PipelineError(f"Build report was not found: {report_path}")
    report = json.loads(report_path.read_text(encoding="utf-8"))
    if report.get("status") != "technical_pass":
        raise PipelineError("The build must have status 'technical_pass' before approval.")

    artifacts = report.get("artifacts", {})
    deliverable = Path(artifacts.get("deliverableUsdz", ""))
    render = Path(artifacts.get("validationRender", ""))
    if not deliverable.is_file() or not render.is_file():
        raise PipelineError("The deliverable USDZ or validation render is missing.")
    if sha256(deliverable) != artifacts.get("deliverableSha256"):
        raise PipelineError("The deliverable USDZ changed after technical validation.")
    if sha256(render) != artifacts.get("validationRenderSha256"):
        raise PipelineError("The validation render changed after technical validation.")

    reviewer = args.reviewer or git_user_name()
    record_visual_approval(report, reviewer, utc_now())
    write_json(report_path, report)
    print(f"Approved {report['asset']} after visual review by {reviewer}.")
    print(f"Report: {report_path}")
    return 0


def git_user_name() -> str:
    result = run_command(["git", "config", "user.name"], require_success=False)
    reviewer = result.stdout.strip()
    if not reviewer:
        raise PipelineError("No reviewer supplied and git user.name is not configured.")
    return reviewer


def print_build_summary(report: dict[str, Any], report_path: Path) -> None:
    geometry = report["geometry"]
    artifacts = report["artifacts"]
    print(f"Technical validation passed for {report['asset']}.")
    print(f"Triangles: {geometry['sourceTriangles']} -> {geometry['optimizedTriangles']}")
    print(f"Optimized Blend: {artifacts['optimizedBlend']}")
    print(f"USDZ: {artifacts['deliverableUsdz']}")
    print(f"Metal render: {artifacts['validationRender']}")
    print(f"Report: {report_path}")
    print("Visual review is pending; run the approve command after inspecting the render.")


def print_export_summary(report: dict[str, Any], report_path: Path) -> None:
    artifacts = report["artifacts"]
    print(f"Technical validation passed for {report['asset']}.")
    print(f"USDZ: {artifacts['deliverableUsdz']}")
    print(f"Metal render: {artifacts['validationRender']}")
    print(f"Report: {report_path}")


def blender_worker(options_path: Path) -> int:
    import bpy  # type: ignore[import-not-found]
    from mathutils import Vector  # type: ignore[import-not-found]

    options = json.loads(options_path.read_text(encoding="utf-8"))
    if options.get("mode") == "inspect":
        report = inspect_blender_scene(bpy, Vector)
        write_json(Path(options["reportPath"]), report)
        return 0
    if options.get("mode") == "export":
        return export_blender_scene(bpy, Vector, options)

    output_root = Path(options["outputRoot"])
    staging = output_root / "staging"
    textures_dir = staging / "textures"
    name = options["name"]
    optimized_blend = output_root / f"{name}_AR_Optimized.blend"
    usdc = staging / f"{name}.usdc"
    worker_report_path = Path(options["reportPath"])
    textures_dir.mkdir(parents=True, exist_ok=True)

    visible_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and not obj.hide_render]
    requested_object = options.get("object")
    if requested_object:
        delivery = bpy.data.objects.get(requested_object)
        if delivery is None or delivery.type != "MESH":
            raise PipelineError(f"Requested mesh was not found: {requested_object}")
    elif len(visible_meshes) == 1:
        delivery = visible_meshes[0]
    else:
        names = ", ".join(obj.name for obj in visible_meshes) or "none"
        raise PipelineError(
            f"Expected one visible mesh, found {len(visible_meshes)} ({names}). Use --object."
        )

    if delivery.data.shape_keys:
        raise PipelineError("Shape keys are not supported for static prop automation.")
    if any(mod.type == "ARMATURE" for mod in delivery.modifiers) or delivery.find_armature():
        raise PipelineError("Armature-driven meshes are not supported for static prop automation.")

    for obj in list(bpy.data.objects):
        if obj != delivery:
            bpy.data.objects.remove(obj, do_unlink=True)

    bpy.context.view_layer.objects.active = delivery
    delivery.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for modifier in list(delivery.modifiers):
        if modifier.show_render:
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        else:
            delivery.modifiers.remove(modifier)

    source_dimensions = world_dimensions(delivery, Vector)
    scene = bpy.context.scene
    is_metric = scene.unit_settings.system == "METRIC" and abs(scene.unit_settings.scale_length - 1.0) < 1e-6
    target_height = options.get("targetHeightMeters")
    if target_height is None and (not is_metric or not dimensions_plausible(source_dimensions)):
        raise PipelineError(
            "Scene scale is not plausibly meter-based. Supply --target-height-m with the intended height."
        )
    if target_height is not None:
        if target_height <= 0:
            raise PipelineError("--target-height-m must be greater than zero.")
        factor = target_height / source_dimensions[2]
        delivery.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    delivery.data.calc_loop_triangles()
    source_triangles = len(delivery.data.loop_triangles)
    target_triangles = options.get("targetTriangles")
    if target_triangles is not None:
        target_triangles = int(target_triangles)
        if target_triangles <= 0:
            raise PipelineError("--target-triangles must be greater than zero.")
        if source_triangles > target_triangles:
            modifier = delivery.modifiers.new(name="AR Triangle Budget", type="DECIMATE")
            modifier.decimate_type = "COLLAPSE"
            modifier.ratio = target_triangles / source_triangles
            modifier.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=modifier.name)
            delivery.data.calc_loop_triangles()
            if len(delivery.data.loop_triangles) > target_triangles:
                raise PipelineError(
                    f"Decimation produced {len(delivery.data.loop_triangles)} triangles, "
                    f"above the requested {target_triangles}."
                )

    center_on_ground(delivery, Vector)
    if not delivery.data.uv_layers:
        raise PipelineError("The delivery mesh has no UV map.")
    delivery.data.uv_layers.active.active_render = True

    texture_cache: dict[tuple[str, str], Any] = {}
    max_texture_size = int(options["maxTextureSize"])
    if max_texture_size <= 0:
        raise PipelineError("--max-texture-size must be greater than zero.")
    staged_textures: list[str] = []
    material_reports: list[dict[str, Any]] = []
    rebuilt_materials = []
    original_materials = [slot.material for slot in delivery.material_slots]
    if not original_materials or any(material is None for material in original_materials):
        raise PipelineError("Every delivery material slot must contain a material.")

    for index, original in enumerate(original_materials):
        material, report, outputs = rebuild_material(
            bpy,
            scene,
            original,
            delivery.data.uv_layers.active.name,
            textures_dir,
            index,
            texture_cache,
            max_texture_size,
        )
        rebuilt_materials.append(material)
        material_reports.append(report)
        staged_textures.extend(str(path) for path in outputs)

    delivery.data.materials.clear()
    for material in rebuilt_materials:
        delivery.data.materials.append(material)

    for collection in (bpy.data.materials, bpy.data.images, bpy.data.worlds):
        for block in list(collection):
            if block.users == 0:
                collection.remove(block)

    bpy.ops.wm.save_as_mainfile(filepath=str(optimized_blend), check_existing=False)
    for image in texture_cache.values():
        image.filepath = f"//staging/textures/{Path(bpy.path.abspath(image.filepath)).name}"
    bpy.ops.wm.save_as_mainfile(filepath=str(optimized_blend), check_existing=False)

    bpy.ops.object.select_all(action="DESELECT")
    delivery.select_set(True)
    bpy.context.view_layer.objects.active = delivery
    bpy.ops.wm.usd_export(
        filepath=str(usdc),
        check_existing=False,
        selected_objects_only=True,
        export_animation=False,
        export_hair=False,
        export_uvmaps=True,
        rename_uvmaps=True,
        export_mesh_colors=False,
        export_normals=True,
        export_materials=True,
        generate_preview_surface=True,
        generate_materialx_network=False,
        export_armatures=False,
        export_shapekeys=False,
        export_lights=False,
        export_cameras=False,
        export_volumes=False,
        export_custom_properties=False,
        convert_world_material=False,
        evaluation_mode="RENDER",
        export_textures_mode="KEEP",
        relative_paths=True,
        convert_scene_units="METERS",
        meters_per_unit=1.0,
        triangulate_meshes=True,
    )

    delivery.data.calc_loop_triangles()
    final_dimensions = world_dimensions(delivery, Vector)
    min_z = min((delivery.matrix_world @ Vector(corner)).z for corner in delivery.bound_box)
    report = {
        "blenderVersion": bpy.app.version_string,
        "geometry": {
            "object": delivery.name,
            "sourceTriangles": source_triangles,
            "optimizedTriangles": len(delivery.data.loop_triangles),
            "sourceDimensionsMeters": source_dimensions,
            "dimensionsMeters": final_dimensions,
            "minimumZ": min_z,
            "uvMap": delivery.data.uv_layers.active.name,
            "units": "meters",
        },
        "materials": material_reports,
        "artifacts": {
            "optimizedBlend": str(optimized_blend),
            "usdc": str(usdc),
            "textures": sorted(set(staged_textures)),
        },
    }
    write_json(worker_report_path, report)
    return 0


def export_blender_scene(bpy: Any, vector_type: Any, options: dict[str, Any]) -> int:
    output_root = Path(options["outputRoot"])
    staging = output_root / "staging"
    textures_dir = staging / "textures"
    name = options["name"]
    usdc = staging / f"{name}.usdc"
    worker_report_path = Path(options["reportPath"])
    textures_dir.mkdir(parents=True, exist_ok=True)

    visible_meshes = [
        obj
        for obj in bpy.context.scene.objects
        if obj.type == "MESH" and not obj.hide_render
    ]
    if not visible_meshes:
        raise PipelineError("The source contains no render-visible mesh.")

    for obj in visible_meshes:
        if obj.data.shape_keys:
            raise PipelineError(
                f"Shape keys are not supported for static prop export: {obj.name}"
            )
        if any(mod.type == "ARMATURE" for mod in obj.modifiers) or obj.find_armature():
            raise PipelineError(
                f"Armature-driven meshes are not supported for static prop export: {obj.name}"
            )
        if not obj.data.uv_layers:
            raise PipelineError(f"Visible mesh has no UV map: {obj.name}")
        obj.data.uv_layers.active.active_render = True
        if not obj.material_slots or any(slot.material is None for slot in obj.material_slots):
            raise PipelineError(
                f"Every material slot on a visible mesh must contain a material: {obj.name}"
            )

    texture_cache: dict[tuple[str, str], Any] = {}
    rebuilt_materials: dict[str, Any] = {}
    material_reports: list[dict[str, Any]] = []
    staged_textures: list[str] = []
    for obj in visible_meshes:
        for slot in obj.material_slots:
            original = slot.material
            key = original.name_full
            if key not in rebuilt_materials:
                material, report, outputs = rebuild_material(
                    bpy,
                    bpy.context.scene,
                    original,
                    obj.data.uv_layers.active.name,
                    textures_dir,
                    len(rebuilt_materials),
                    texture_cache,
                    None,
                    export_compatible=True,
                )
                rebuilt_materials[key] = material
                material_reports.append(report)
                staged_textures.extend(str(path) for path in outputs)
            slot.material = rebuilt_materials[key]

    bpy.ops.object.select_all(action="DESELECT")
    selected: set[Any] = set(visible_meshes)
    for obj in visible_meshes:
        parent = obj.parent
        while parent is not None:
            selected.add(parent)
            parent = parent.parent
    for obj in selected:
        obj.hide_set(False)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = visible_meshes[0]

    bpy.ops.wm.usd_export(
        filepath=str(usdc),
        check_existing=False,
        selected_objects_only=True,
        export_animation=False,
        export_hair=False,
        export_uvmaps=True,
        rename_uvmaps=True,
        export_mesh_colors=False,
        export_normals=True,
        export_materials=True,
        generate_preview_surface=True,
        generate_materialx_network=False,
        export_armatures=False,
        export_shapekeys=False,
        export_lights=False,
        export_cameras=False,
        export_volumes=False,
        export_custom_properties=False,
        convert_world_material=False,
        evaluation_mode="RENDER",
        export_textures_mode="KEEP",
        relative_paths=True,
        convert_scene_units="METERS",
        meters_per_unit=1.0,
        triangulate_meshes=False,
    )

    depsgraph = bpy.context.evaluated_depsgraph_get()
    object_reports: list[dict[str, Any]] = []
    triangle_total = 0
    for obj in visible_meshes:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        if mesh is None:
            triangles = 0
        else:
            mesh.calc_loop_triangles()
            triangles = len(mesh.loop_triangles)
            evaluated.to_mesh_clear()
        triangle_total += triangles
        object_reports.append(
            {
                "object": obj.name,
                "triangles": triangles,
                "dimensionsMeters": world_dimensions(obj, vector_type),
                "uvMap": obj.data.uv_layers.active.name,
                "parent": obj.parent.name if obj.parent else None,
            }
        )

    report = {
        "blenderVersion": bpy.app.version_string,
        "geometry": {
            "sourceTriangles": triangle_total,
            "optimizedTriangles": triangle_total,
            "objects": object_reports,
            "units": "meters",
            "preserved": True,
        },
        "materials": material_reports,
        "artifacts": {
            "optimizedBlend": None,
            "usdc": str(usdc),
            "textures": sorted(set(staged_textures)),
        },
    }
    write_json(worker_report_path, report)
    return 0


def inspect_blender_scene(bpy: Any, vector_type: Any) -> dict[str, Any]:
    scene = bpy.context.scene
    depsgraph = bpy.context.evaluated_depsgraph_get()
    is_metric = scene.unit_settings.system == "METRIC" and abs(scene.unit_settings.scale_length - 1.0) < 1e-6
    meshes: list[dict[str, Any]] = []
    for obj in scene.objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        obj.data.calc_loop_triangles()
        evaluated = obj.evaluated_get(depsgraph)
        evaluated_mesh = evaluated.to_mesh()
        if evaluated_mesh is None:
            evaluated_triangles = 0
        else:
            evaluated_mesh.calc_loop_triangles()
            evaluated_triangles = len(evaluated_mesh.loop_triangles)
            evaluated.to_mesh_clear()
        dimensions = world_dimensions(obj, vector_type)
        meters = [value * scene.unit_settings.scale_length for value in dimensions]
        meshes.append(
            {
                "name": obj.name,
                "sourceTriangles": len(obj.data.loop_triangles),
                "evaluatedTriangles": evaluated_triangles,
                "dimensionsSceneUnits": dimensions,
                "dimensionsMeters": meters,
                "plausibleMetricScale": is_metric and dimensions_plausible(meters),
                "materials": [slot.material.name if slot.material else None for slot in obj.material_slots],
                "modifiers": [modifier.type for modifier in obj.modifiers if modifier.show_render],
                "hasShapeKeys": bool(obj.data.shape_keys),
                "hasArmature": bool(
                    any(modifier.type == "ARMATURE" for modifier in obj.modifiers)
                    or obj.find_armature()
                ),
                "uvMaps": [layer.name for layer in obj.data.uv_layers],
            }
        )
    return {
        "blenderVersion": bpy.app.version_string,
        "scene": {
            "name": scene.name,
            "unitSystem": scene.unit_settings.system,
            "scaleLength": scene.unit_settings.scale_length,
            "meterBased": is_metric,
        },
        "visibleMeshes": meshes,
        "unsupported": {
            "armatures": len(bpy.data.armatures),
            "actions": len(bpy.data.actions),
        },
    }


def world_dimensions(obj: Any, vector_type: Any) -> list[float]:
    corners = [obj.matrix_world @ vector_type(corner) for corner in obj.bound_box]
    return [
        max(point.x for point in corners) - min(point.x for point in corners),
        max(point.y for point in corners) - min(point.y for point in corners),
        max(point.z for point in corners) - min(point.z for point in corners),
    ]


def center_on_ground(obj: Any, vector_type: Any) -> None:
    corners = [vector_type(corner) for corner in obj.bound_box]
    minimum = vector_type(
        (min(point.x for point in corners), min(point.y for point in corners), min(point.z for point in corners))
    )
    maximum = vector_type(
        (max(point.x for point in corners), max(point.y for point in corners), max(point.z for point in corners))
    )
    offset = vector_type((-(minimum.x + maximum.x) / 2, -(minimum.y + maximum.y) / 2, -minimum.z))
    for vertex in obj.data.vertices:
        vertex.co += offset
    obj.location = (0.0, 0.0, 0.0)


def rebuild_material(
    bpy: Any,
    scene: Any,
    original: Any,
    uv_map: str,
    textures_dir: Path,
    material_index: int,
    texture_cache: dict[tuple[str, str], Any],
    max_texture_size: int | None,
    *,
    export_compatible: bool = False,
) -> tuple[Any, dict[str, Any], list[Path]]:
    if not original.use_nodes or original.node_tree is None:
        raise PipelineError(f"Material does not use nodes: {original.name}")
    outputs = [node for node in original.node_tree.nodes if node.type == "OUTPUT_MATERIAL" and node.is_active_output]
    if len(outputs) != 1 or not outputs[0].inputs["Surface"].is_linked:
        raise PipelineError(f"Material needs one linked active output: {original.name}")
    surface_source = outputs[0].inputs["Surface"].links[0].from_node
    if export_compatible:
        surface_source = find_unique_upstream_principled(surface_source, original.name)
    elif surface_source.type != "BSDF_PRINCIPLED":
        raise PipelineError(f"Material output must be driven directly by Principled BSDF: {original.name}")

    base_input = surface_source.inputs.get("Base Color")
    normal_input = surface_source.inputs.get("Normal")
    base_image = linked_image(base_input)
    normal_image = linked_normal_image(normal_input, allow_direct=export_compatible)
    if base_input.is_linked and base_image is None:
        raise PipelineError(f"Unsupported Base Color graph in material: {original.name}")
    if normal_input.is_linked and normal_image is None:
        raise PipelineError(f"Normal must use Image Texture through a Normal Map node: {original.name}")

    safe_material = sanitize_asset_name(original.name)
    material = bpy.data.materials.new(f"{safe_material}_AR")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    principled.inputs["Metallic"].default_value = 0.0
    principled.inputs["Roughness"].default_value = 0.65
    principled.inputs["Specular IOR Level"].default_value = 0.25
    principled.inputs["Alpha"].default_value = 1.0
    links.new(principled.outputs["BSDF"], output.inputs["Surface"])
    created_paths: list[Path] = []

    if base_image is not None:
        fresh, path = convert_image(
            bpy,
            scene,
            base_image,
            "base",
            textures_dir,
            material_index,
            safe_material,
            texture_cache,
            max_texture_size,
        )
        node = nodes.new("ShaderNodeTexImage")
        node.name = f"{safe_material} Base Color"
        node.image = fresh
        links.new(node.outputs["Color"], principled.inputs["Base Color"])
        created_paths.append(path)
        base_description: Any = str(path)
    else:
        principled.inputs["Base Color"].default_value = base_input.default_value
        base_description = list(base_input.default_value)

    if normal_image is not None:
        fresh, path = convert_image(
            bpy,
            scene,
            normal_image,
            "normal",
            textures_dir,
            material_index,
            safe_material,
            texture_cache,
            max_texture_size,
        )
        image_node = nodes.new("ShaderNodeTexImage")
        image_node.name = f"{safe_material} Normal"
        image_node.image = fresh
        normal_map = nodes.new("ShaderNodeNormalMap")
        normal_map.uv_map = uv_map
        links.new(image_node.outputs["Color"], normal_map.inputs["Color"])
        links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
        created_paths.append(path)

    report = {
        "source": original.name,
        "optimized": material.name,
        "baseColor": base_description,
        "normal": str(created_paths[-1]) if normal_image is not None else None,
        "metallic": 0.0,
        "roughness": 0.65,
        "specularIorLevel": 0.25,
        "alpha": 1.0,
    }
    return material, report, created_paths


def linked_image(input_socket: Any) -> Any | None:
    if not input_socket.is_linked or len(input_socket.links) != 1:
        return None
    node = input_socket.links[0].from_node
    return node.image if node.type == "TEX_IMAGE" and node.image else None


def find_unique_upstream_principled(start: Any, material_name: str) -> Any:
    stack = [start]
    visited: set[int] = set()
    principled: list[Any] = []
    while stack:
        node = stack.pop()
        identity = id(node)
        if identity in visited:
            continue
        visited.add(identity)
        if node.type == "BSDF_PRINCIPLED":
            principled.append(node)
            continue
        for socket in node.inputs:
            stack.extend(link.from_node for link in socket.links)
    if len(principled) != 1:
        raise PipelineError(
            f"Material must contain exactly one Principled BSDF upstream of its output: "
            f"{material_name} (found {len(principled)})."
        )
    return principled[0]


def linked_normal_image(input_socket: Any, *, allow_direct: bool = False) -> Any | None:
    if not input_socket.is_linked or len(input_socket.links) != 1:
        return None
    normal_map = input_socket.links[0].from_node
    if allow_direct and normal_map.type == "TEX_IMAGE" and normal_map.image:
        return normal_map.image
    if normal_map.type != "NORMAL_MAP":
        return None
    return linked_image(normal_map.inputs["Color"])


def convert_image(
    bpy: Any,
    scene: Any,
    source: Any,
    role: str,
    textures_dir: Path,
    material_index: int,
    material_name: str,
    cache: dict[tuple[str, str], Any],
    max_texture_size: int | None,
) -> tuple[Any, Path]:
    cache_key = (source.name_full, role)
    extension = ".jpg" if role == "base" else ".png"
    path = textures_dir / f"{material_index:02d}_{material_name}_{role}{extension}"
    if cache_key in cache:
        existing = cache[cache_key]
        return existing, Path(bpy.path.abspath(existing.filepath))

    width, height = source.size
    if width <= 0 or height <= 0:
        raise PipelineError(f"Texture has invalid dimensions: {source.name}")
    target_width, target_height = output_dimensions(width, height, max_texture_size)
    working = source.copy()
    working.scale(target_width, target_height)
    settings = scene.render.image_settings
    settings.file_format = "JPEG" if role == "base" else "PNG"
    settings.color_mode = "RGB"
    settings.color_depth = "8"
    if role == "base":
        settings.quality = 82
    working.save_render(str(path), scene=scene)
    bpy.data.images.remove(working)
    fresh = bpy.data.images.load(str(path), check_existing=False)
    fresh.colorspace_settings.name = "sRGB" if role == "base" else "Non-Color"
    cache[cache_key] = fresh
    return fresh, path


def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ar-asset", description=__doc__)
    parser.add_argument("--version", action="version", version=f"%(prog)s {CLI_VERSION}")
    subparsers = parser.add_subparsers(dest="command", required=True)

    build = subparsers.add_parser("build", help="Optimize and technically validate a Blender asset.")
    build.add_argument("source", help="Artist source .blend; it will never be overwritten.")
    build.add_argument("--name", help="Output asset name; defaults to the source filename.")
    build.add_argument("--object", help="Delivery mesh name when auto-detection is ambiguous.")
    geometry_group = build.add_mutually_exclusive_group()
    geometry_group.add_argument(
        "--target-triangles", type=positive_integer, default=DEFAULT_TRIANGLES
    )
    geometry_group.add_argument(
        "--textures-only",
        action="store_true",
        help="Optimize textures without enforcing or reducing the mesh triangle count.",
    )
    build.add_argument(
        "--max-texture-size",
        type=positive_integer,
        default=DEFAULT_TEXTURE_SIZE,
        metavar="PIXELS",
        help=f"Maximum texture width or height (default: {DEFAULT_TEXTURE_SIZE}).",
    )
    build.add_argument("--target-height-m", type=float)
    build.add_argument("--output-dir")
    build.add_argument("--blender", default=str(DEFAULT_BLENDER))

    export = subparsers.add_parser(
        "export",
        help="Export visible meshes as a validated Xcode-compatible USDZ.",
    )
    export.add_argument("source", help="Saved .blend file to export without modifying it.")
    export.add_argument("--output-dir", help="Override the staging and report directory.")
    export.add_argument("--blender", default=str(DEFAULT_BLENDER))
    export.set_defaults(
        name=None,
        object=None,
        target_triangles=None,
        textures_only=True,
        max_texture_size=None,
        target_height_m=None,
    )

    inspect = subparsers.add_parser("inspect", help="Inspect a Blender asset without modifying it.")
    inspect.add_argument("source")
    inspect.add_argument("--json", action="store_true", help="Print the complete inspection as JSON.")
    inspect.add_argument("--blender", default=str(DEFAULT_BLENDER))

    approve = subparsers.add_parser("approve", help="Record human approval of the Metal render.")
    approve.add_argument("output_directory")
    approve.add_argument("--reviewer")

    guided = subparsers.add_parser("guided", help="Interactively inspect, build, and review an asset.")
    guided.add_argument("--blender", default=str(DEFAULT_BLENDER))

    install = subparsers.add_parser("install", help="Install or upgrade the per-user CLI app.")
    install.add_argument("--force", action="store_true", help="Replace an unrelated launcher.")
    path_group = install.add_mutually_exclusive_group()
    path_group.add_argument("--add-to-path", action="store_true")
    path_group.add_argument("--no-path-update", action="store_true")

    subparsers.add_parser("uninstall", help="Remove the verified per-user CLI installation.")

    doctor = subparsers.add_parser("doctor", help="Check the CLI app and required tools.")
    doctor.add_argument("--json", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    arguments = list(argv if argv is not None else sys.argv[1:])
    if "--blender-worker" in arguments:
        index = arguments.index("--blender-worker")
        return blender_worker(Path(arguments[index + 1]))
    try:
        parser = create_parser()
        args = parser.parse_args(arguments)
        commands = {
            "build": build_command,
            "export": build_command,
            "inspect": inspect_command,
            "approve": approve_command,
            "guided": guided_command,
            "install": install_command,
            "uninstall": uninstall_command,
            "doctor": doctor_command,
        }
        return commands[args.command](args)
    except KeyboardInterrupt:
        print("\nCancelled. Any completed technical validation remains pending review.", file=sys.stderr)
        return 130
    except PipelineError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
