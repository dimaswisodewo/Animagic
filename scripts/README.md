# AniMagic Scripts

## Resize a standalone texture

`resize-texture` creates aspect-ratio-preserving variants of one source image at
512, 1024, 2048, and 4096 pixels on the longest edge. It never enlarges an image
or modifies the source, and it preserves the source image format and extension.

```bash
./scripts/resize-texture "/path/to/My Texture.png"
```

Generated variants are written beside the source:

```text
My Texture-resized/
├── My Texture-512.png
├── My Texture-1024.png
├── My Texture-2048.png
└── My Texture-4096.png
```

Presets equal to or larger than the source image are skipped. Existing generated
files are protected by default; replace them explicitly when needed:

```bash
./scripts/resize-texture --force "/path/to/My Texture.png"
```

The command requires macOS, Python 3, and `/usr/bin/sips`.

## AR asset pipeline

`ar-asset` turns a static Blender prop into a compact, validated USDZ for AniMagic. It preserves the artist's source Blend, creates an optimized working copy, packages every texture dependency, runs Apple's USD checks, and produces a Metal validation render for human review.

The current CLI version is `0.3.0` and supports macOS only.

## Prerequisites

Install or confirm these tools before running the pipeline:

- Blender with Python support. The validated workflow uses Blender 5.1.2 at `/Applications/Blender.app`.
- Xcode command-line tools providing `usdzip`, `usdchecker`, `usdcat`, and `usdrecord`.
- macOS tools including `file`, `sips`, and `unzip`.
- Python 3.9 or newer for the host CLI.

Check the complete environment after installing the CLI:

```bash
ar-asset doctor
```

Use `ar-asset doctor --json` when another script needs machine-readable results.

## Choose How to Run It

### From this repository

Run the repository command from the AniMagic checkout:

```bash
./scripts/ar-asset
```

With no arguments, the repository command starts guided mode. Its default output location is:

```text
build/asset-pipeline/<Asset>/
```

### Install it as a user command

Install `ar-asset` for use from any directory:

```bash
./scripts/ar-asset install
```

The installer:

- requires no `sudo`;
- stores versioned payloads under `~/.local/share/animagic-ar-asset/`;
- creates `~/.local/bin/ar-asset`;
- offers to add `~/.local/bin` to `.zprofile` if it is not already on `PATH`.

Open a new terminal after accepting the PATH update, then verify the installation:

```bash
ar-asset --version
ar-asset doctor
```

Start the installed guided workflow with:

```bash
ar-asset guided
```

The installed command writes to this location by default:

```text
~/Documents/AniMagic AR Assets/<Asset>/
```

## Recommended Guided Workflow

Start guided mode:

```bash
# Repository command
./scripts/ar-asset

# Installed command
ar-asset guided
```

The workflow will:

1. Ask for the source `.blend` file. Type its path or drag the file from Finder into Terminal.
2. Inspect the Blend without modifying it.
3. Select the only visible mesh automatically, or show a numbered choice when several meshes are visible.
4. Ask for the intended real-world height when the scene is not plausibly authored in meters.
5. Show the resolved mesh, triangle budget, scale, and output directory.
6. Ask for confirmation before starting Blender and the Apple USD tools.
7. Generate and open the Metal validation PNG.
8. Ask whether the render looks correct. Only an explicit `yes` records visual approval.

Answering `no`, cancelling, or closing the process leaves a technically valid result in `pending` review. It does not mark the USDZ as accepted.

## Explicit Commands

Explicit commands are useful for repeatable runs, automation, and troubleshooting.

### Export the authored asset for Xcode

Export every render-visible mesh with Xcode-compatible textures and materials:

```bash
ar-asset export "/path/to/Asset.blend"
```

The command preserves geometry, transforms, real-world dimensions, and texture
resolution. It repairs supported base-color and normal connections in a temporary
Blender process, packages the textures explicitly, and writes `Asset.usdz` beside
the Blend only after Apple structural and Metal-render validation passes. An
existing `Asset.usdz` remains untouched unless its replacement passes every check.
Detailed staging artifacts and `report.json` stay in the normal asset-pipeline
output directory; use `--output-dir` to override that directory.

### Inspect a Blend

Inspect visible meshes, evaluated triangle counts, dimensions, units, materials, modifiers, UV maps, armatures, and shape keys:

```bash
ar-asset inspect "/path/to/Asset.blend"
```

Request JSON output:

```bash
ar-asset inspect "/path/to/Asset.blend" --json
```

Inspection is read-only and verifies that the source hash remains unchanged.

### Build and validate an asset

```bash
ar-asset build "/path/to/Asset.blend"
```

Common options:

```bash
ar-asset build "/path/to/Asset.blend" \
  --name Broccoli \
  --object bro_body \
  --target-triangles 15000 \
  --target-height-m 0.20 \
  --output-dir "/path/to/output"
```

| Option | Purpose |
| --- | --- |
| `--name <name>` | Override the asset name derived from the source filename. |
| `--object <mesh>` | Select the delivery mesh when the scene has several visible meshes. |
| `--target-triangles <count>` | Override the default 15,000-triangle budget. |
| `--target-height-m <meters>` | Set the intended final height when source scale cannot be trusted. |
| `--output-dir <path>` | Override the repository or installed default output directory. |
| `--blender <path>` | Use a Blender executable outside `/Applications/Blender.app`. |

The source Blend is never overwritten. Scaling, decimation, material normalization, and texture conversion happen only in the optimized copy.

### Approve a validation render

A successful build has `technical_pass` status with visual review still `pending`. Inspect `<Asset>_Validation.png`, then approve the output directory:

```bash
ar-asset approve "/path/to/output/<Asset>"
```

The CLI verifies that neither the USDZ nor validation PNG changed after technical validation. It uses `git user.name` as the reviewer when available. Override the reviewer when necessary:

```bash
ar-asset approve "/path/to/output/<Asset>" --reviewer "Reviewer Name"
```

## Output Files

A successful build produces:

```text
<Asset>/
├── <Asset>_AR_Optimized.blend
├── <Asset>_Fixed.usdz
├── <Asset>_Validation.png
├── report.json
└── staging/
    ├── <Asset>.usdc
    ├── <Asset>_Fixed.usdz
    └── textures/
        ├── ..._base.jpg
        └── ..._normal.png
```

- `<Asset>_AR_Optimized.blend` is the clean mobile working copy.
- `<Asset>_Fixed.usdz` is the delivered package after technical validation.
- `<Asset>_Validation.png` is Apple's Metal reference render.
- `report.json` records source and artifact hashes, geometry, materials, dependencies, tool results, and review status.
- `staging/` contains the intermediate USDC and explicit texture dependencies used to create the package.

Do not copy a USDZ into the app merely because it exists. It must pass the technical checks and human Metal-render review first.

## Common Problems

### `Scene scale is not plausibly meter-based`

Supply the intended real-world height in meters:

```bash
ar-asset build "/path/to/Asset.blend" --target-height-m 0.20
```

For example, `0.20` means 20 cm. Guided mode asks for this value automatically. The pipeline applies it only to the optimized copy.

Alternatively, correct a separate copy in Blender by setting Scene Units to Metric, Unit Scale to `1.0`, setting the intended dimensions, and applying object scale.

### More than one visible mesh

Inspect the scene:

```bash
ar-asset inspect "/path/to/Asset.blend"
```

Then select the delivery mesh explicitly:

```bash
ar-asset build "/path/to/Asset.blend" --object "MeshName"
```

Guided mode presents a numbered mesh selector instead.

### `ar-asset: command not found`

Open a new terminal after installation. If `~/.local/bin` is still missing from `PATH`, run:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

To persist it manually in zsh:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zprofile
```

Avoid adding the line repeatedly. The installer can add an idempotent marked block with:

```bash
./scripts/ar-asset install --add-to-path
```

### A required tool is missing

Run:

```bash
ar-asset doctor
```

Resolve every required failure before building. The pipeline does not substitute another exporter or treat partial validation as success.

### The build passed but review is pending

This is expected until a person inspects the Metal render. Approve the output directory with `ar-asset approve`, or rerun guided mode and answer the final review prompt.

### Metal rendering fails

Confirm `usdrecord` and its Metal renderer are registered with `ar-asset doctor`. A successful `usdchecker` result is not a replacement for the Metal render.

### Installation is reported as modified or unsafe

The CLI refuses to uninstall payloads with changed hashes or unexpected files. Repair the managed payload from the repository, then retry:

```bash
./scripts/ar-asset install
ar-asset doctor
ar-asset uninstall
```

Do not manually delete broad `~/.local` directories. The verified uninstaller removes only the managed `ar-asset` paths.

## Update, Repair, and Remove

Update or repair the installed CLI from the repository:

```bash
./scripts/ar-asset install
```

If an unrelated `~/.local/bin/ar-asset` exists, installation stops without replacing it. Use `--force` only when you have inspected that exact command and intentionally want to replace it:

```bash
./scripts/ar-asset install --force
```

Remove the verified per-user installation:

```bash
ar-asset uninstall
```

Uninstall also removes the marked `.zprofile` PATH block when this installer originally added it. It preserves unrelated shell configuration.

## Further Reading

- [AR asset pipeline](../docs/asset-pipeline/README.md)
- [Blender-to-USDZ runbook](../docs/asset-pipeline/BLENDER_TO_USDZ.md)
- [USDZ validation and troubleshooting](../docs/asset-pipeline/VALIDATION_AND_TROUBLESHOOTING.md)
