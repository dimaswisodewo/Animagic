# AR Asset Pipeline

This directory is the source of truth for converting Blender scenes into compact, textured USDZ assets for AniMagic. It is written for both people and AI agents: the rules explain why a step exists, while the runbooks define commands and pass/fail criteria.

## Documents

- [Blender to USDZ](BLENDER_TO_USDZ.md) — optimize a Blender scene, normalize its materials and textures, export USDC, and package USDZ.
- [Validation and troubleshooting](VALIDATION_AND_TROUBLESHOOTING.md) — prove the package is structurally and visually correct and diagnose common failures.

## Automation

Install the CLI app for use from any terminal directory:

```bash
./scripts/ar-asset install
ar-asset doctor
```

Installation is per-user under `~/.local`, requires no `sudo`, and offers to add `~/.local/bin` to `.zprofile` when needed. Rerun the repository install command to update or repair version `0.3.0`. Use `ar-asset uninstall` for verified removal; it refuses modified payloads or installation directories containing unexpected files.

Launch the guided terminal workflow for a static prop:

```bash
./scripts/ar-asset
```

Guided mode accepts a typed or Finder-dragged Blend path, inspects the scene, asks only about ambiguous mesh selection or missing scale, and opens the Metal validation render before offering approval. It writes to `build/asset-pipeline/<Asset>/` and leaves the artist source and app bundle untouched.

The installed command writes to `~/Documents/AniMagic AR Assets/<Asset>/` by default. The repository-local command retains `build/asset-pipeline/<Asset>/`; `--output-dir` overrides either default.

Explicit commands remain available for automation:

```bash
./scripts/ar-asset inspect /path/to/Asset.blend
./scripts/ar-asset export /path/to/Asset.blend
./scripts/ar-asset build /path/to/Asset.blend
./scripts/ar-asset build /path/to/Asset.blend --textures-only --max-texture-size 512
```

Use `export` when the authored geometry, transforms, dimensions, visible meshes,
and texture resolution are already correct. It rebuilds only supported opaque
materials, packages and validates the result, then atomically writes
`<Asset>.usdz` beside the Blend. Use `build` when the asset also needs scale,
centering, geometry, or texture-size optimization.

Use `--textures-only` when the delivery mesh should retain its evaluated triangle count and only
its used base-color and normal textures need optimization. The command still performs the normal
mesh selection, scale preparation, material normalization, USDZ packaging, and validation.
`--max-texture-size` controls the longest texture side and defaults to 1024 pixels for every build.

A successful build is only a technical pass. Inspect `<Asset>_Validation.png`, then record human visual acceptance without changing the validated artifacts:

```bash
./scripts/ar-asset approve build/asset-pipeline/<Asset>
```

The approval command verifies the USDZ and render hashes before updating `report.json`. It uses `git user.name` as the reviewer unless `--reviewer` is supplied.

Run the fast host-side tests with `python3 -m unittest discover -s scripts/asset-pipeline/tests -v`. Set `ANIMAGIC_RUN_BLENDER_INTEGRATION=1` to include the procedural Blender-to-Metal smoke test; it requires all pipeline tools and may open Metal resources outside restricted shells.

### CLI lifecycle

```bash
ar-asset --version
ar-asset doctor
ar-asset doctor --json
ar-asset uninstall
```

`doctor` checks the managed payload and hashes, PATH, Python, Blender, Apple USD tools, Metal renderer command, and default output location. Installation refuses an unrelated `~/.local/bin/ar-asset`; use `install --force` only when replacing that exact command intentionally. Non-interactive installation never edits shell startup files unless `--add-to-path` is supplied; use `--no-path-update` to suppress PATH setup explicitly.

## Delivery contract

Treat the artist's source Blend as immutable. A normal conversion produces these artifacts:

```text
<Asset>.blend                    # Artist master; never overwrite
<Asset>_AR_Optimized.blend       # Clean mobile working copy
<staging>/<Asset>.usdc           # Intermediate USD scene
<staging>/textures/*             # Explicit texture dependencies
<Asset>_Fixed.usdz               # Validated deliverable
```

Do not call an asset finished merely because Blender exported it or `usdchecker` passed. A deliverable must also render with its expected colors through Apple's Metal USD renderer.

## Compact mobile defaults

These are defaults for a single static placeable prop, not universal engine limits:

| Property | Default |
| --- | --- |
| Color and normal maps | Maximum 1024 px on the longest side |
| Geometry | Approximately 15,000 triangles or fewer |
| USDZ package | 15 MB or smaller |
| Units | Meters |
| Scale | Intended real-world size |
| Base color | Opaque RGB JPEG, quality about 82 |
| Normal map | 8-bit RGB PNG, Non-Color data |
| Metallic | `0` unless the asset is actually metallic |
| Roughness | `0.65` unless art direction requires otherwise |
| Specular IOR level | `0.25` |
| Opacity | `1` for opaque props |

Record and justify exceptions before conversion. Hero assets may use larger textures or geometry when close-up presentation materially benefits, but they still require the same packaging and validation gates.

## Responsibility boundaries

- Blender owns geometry cleanup, UVs, real-world scale, image conversion, and PBR material intent.
- Apple USD tools own dependency-aware USDZ packaging, structural validation, and the reference Metal render.
- Xcode owns target membership and bundle delivery. Adding a USDZ to the filesystem alone does not guarantee that it is copied into the app.
- RealityKit consumes the authored scale and PBR materials. Do not rely on runtime code to repair a malformed asset.

## Required tools

- Blender with Python support. The validated reference workflow used Blender 5.1.2.
- macOS with Xcode command-line tools providing `usdzip`, `usdchecker`, `usdcat`, and `usdrecord`.
- Standard macOS tools including `file`, `sips`, and `unzip`.

If a required tool is unavailable, stop and report which validation could not be performed. Do not silently substitute an unchecked exporter or declare the asset complete.
