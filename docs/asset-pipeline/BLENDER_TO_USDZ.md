# Blender to USDZ

This runbook defines the authoritative script-first conversion. Blender UI operations are acceptable for inspection and art review, but automation should produce the delivery artifact so results are repeatable.

## Automated workflow

Install the per-user CLI once with `./scripts/ar-asset install`, then run `ar-asset doctor`. The installed command can be invoked from any directory and defaults to `~/Documents/AniMagic AR Assets`; repository-local commands continue to use the ignored repository build directory.

When the Blend is already authored at the desired geometry, transforms, scale,
and texture resolution, export it directly:

```bash
./scripts/ar-asset export /path/to/Asset.blend
```

This exports every render-visible mesh, preserves authored geometry and texture
dimensions, normalizes supported opaque materials, performs the same explicit
Apple packaging and validation gates, and writes `<Asset>.usdz` beside the source
only after validation succeeds.

For the supported static-prop workflow, run:

```bash
./scripts/ar-asset build /path/to/Asset.blend \
  --target-triangles 15000
```

Useful options:

- `--name <Asset>` overrides the sanitized source filename used for artifacts.
- `--object <mesh>` resolves a scene with multiple visible meshes.
- `--target-height-m <meters>` supplies intended scale when scene metadata is not plausibly meter-based.
- `--textures-only` skips triangle-budget enforcement and mesh decimation while retaining the rest of the build and validation workflow.
- `--max-texture-size <pixels>` sets the maximum texture width or height; the default is 1024.
- `--output-dir <path>` overrides `build/asset-pipeline/<Asset>`.
- `--blender <path>` selects a non-default Blender executable.

`--textures-only` and `--target-triangles` are mutually exclusive. For example, to retain the
evaluated mesh geometry while limiting its used textures to 512 pixels:

```bash
./scripts/ar-asset build /path/to/Asset.blend \
  --textures-only \
  --max-texture-size 512
```

Texture-only builds still select a single delivery mesh, apply its render modifiers and transforms,
validate or set metric scale, center it on the ground, normalize its supported materials, package
the USDZ, and generate a Metal validation render. They skip only triangle decimation.

The CLI implements the inventory, optimization, texture conversion, material normalization, USDC export, Apple packaging, structural checks, and Metal render described below. It supports one static delivery mesh with Principled BSDF materials, direct base-color image connections or constants, and optional normal images connected through Normal Map nodes. It deliberately rejects rigs, shape keys, multi-object delivery props, and shader graphs whose intent cannot be inferred safely.

After inspecting the generated Metal render, record approval:

```bash
./scripts/ar-asset approve build/asset-pipeline/<Asset>
```

`report.json` remains `technical_pass` with visual review `pending` until this command verifies the artifact hashes and records the reviewer.

## 1. Preserve and inventory the source

Never overwrite `<Asset>.blend`. Open it read-only or in a separate background process and collect:

- object counts and types;
- raw and evaluated triangle counts;
- visible/exported objects;
- modifiers and their render settings;
- material slots and image-node usage;
- texture dimensions, encodings, color spaces, packed sizes, and file paths;
- armatures, actions, shape keys, lights, cameras, and world textures;
- object dimensions, transforms, origin, and scene units.

A background inspection follows this shape:

```bash
/Applications/Blender.app/Contents/MacOS/Blender \
  --background /path/to/<Asset>.blend \
  --python /path/to/audit_asset.py
```

Select the intended delivery object from evidence such as the current export, render visibility, or product requirements. Do not export hidden drafts and duplicate scans merely because they share a collection.

## 2. Create the optimized working copy

Save changes to `<Asset>_AR_Optimized.blend` and leave the artist master untouched.

For a static placeable prop:

1. Keep only the delivery geometry and its dependencies.
2. Apply intentional modifiers after confirming the evaluated result meets the triangle budget.
3. Preserve the UV map used by the materials.
4. Set scene units to meters.
5. Scale the asset to its intended real-world dimensions.
6. Center it horizontally and place its lowest point at `Z = 0`.
7. Apply scale and position as appropriate; retain rotation only when it represents the intended default orientation.
8. Remove unused objects, materials, images, world HDRs, render results, and orphaned datablocks.

Aim for approximately 15,000 triangles or fewer. Judge decimation by silhouette, seams, and shading rather than by ratio alone.

## 3. Normalize textures

Process only images that are actually connected to delivered materials.

### Base color

- Resize so the longest side is at most the `--max-texture-size` value (1024 px by default) while preserving aspect ratio.
- Save as a genuine baseline RGB JPEG at quality about 82.
- Use an `.jpg` extension and `sRGB` interpretation.
- Do not retain an alpha channel for an opaque prop.

### Normal maps

- Resize so the longest side is at most the `--max-texture-size` value (1024 px by default).
- Save as a genuine 8-bit RGB PNG.
- Use a `.png` extension and Blender's `Non-Color` interpretation.
- Connect through a Normal Map node, never directly to Principled BSDF Normal.

### Encoding rule

The filename extension, encoded bytes, Blender `Image.file_format`, and color-space intent must agree. Packed images may retain stale metadata after conversion. The safe automated sequence is:

1. Render/save each source image to an external staging path using explicit output settings.
2. Verify that the file exists.
3. Load it as a fresh Blender image datablock with `check_existing=False`.
4. Set the fresh datablock's color space.
5. Replace every material-node reference from the old image to the fresh image.

Do not trust an image named `texture.jpg` if Blender reports PNG or OpenEXR internally.

## 4. Normalize materials

Use one Principled BSDF feeding Material Output. The supported opaque-prop contract is:

| Principled input | Source |
| --- | --- |
| Base Color | RGB output of the sRGB base-color texture |
| Normal | Normal Map node using the Non-Color normal texture |
| Roughness | Constant `0.65` |
| Specular IOR Level | Constant `0.25` |
| Metallic | Constant `0` |
| Alpha | Constant `1` |

Disconnect base-color textures from Roughness and Specular IOR Level. Reusing the red channel of a color atlas for those properties caused the watermelon to render nearly mirror-black in Apple's Metal renderer even though the texture files were present.

Use multiple material slots only when the existing UV/material partition requires them. A moderate number of slots is preferable to a risky atlas rebake when geometry and package budgets are already satisfied.

## 5. Export plain USDC

Export the selected optimized object to a staging directory as `<Asset>.usdc`, not directly to USDZ.

Required export behavior:

- selected object only;
- render evaluation mode;
- UV maps and normals enabled;
- Preview Surface materials enabled;
- relative texture paths;
- no animation, armatures, shape keys, world material, lights, cameras, volumes, or custom properties unless the asset explicitly requires them;
- scene units converted to meters.

The staged tree should be:

```text
<staging>/
├── <Asset>.usdc
└── textures/
    ├── ...base.jpg
    └── ...normal.png
```

Inspect authored dependencies before packaging:

```bash
usdcat <staging>/<Asset>.usdc | rg 'asset inputs:file'
```

Every path must resolve inside staging and must not point to a user directory, a previous USDZ, or Blender's temporary export directory.

## 6. Package with Apple USD tools

Do not use Blender's one-step USDZ export for delivery. In the watermelon incident it authored eight texture references but copied only one texture, producing a package that looked valid by size yet failed dependency validation.

From the staging directory, package the USDC and its dependencies:

```bash
cd <staging>
usdzip <Asset>_Fixed.usdz --arkitAsset <Asset>.usdc -v
```

Keep the deliverable in staging until it passes every check in [Validation and troubleshooting](VALIDATION_AND_TROUBLESHOOTING.md). Copy it to its final destination only after validation.

## Blender UI fallback

When automation is unavailable, use Blender's Statistics overlay, Material Properties, Shader Editor, Image Editor, Item transform panel, and Orphan Data view to perform the same checks. Save external textures with explicit formats, reopen them in Blender, export USDC, and package with `usdzip`. The budgets, material contract, and validation gates do not change.

## Worked example: WaterMelon

The reference repair produced:

- `WaterMelon.blend`: approximately 997 MB;
- `WaterMelon_AR_Optimized.blend`: approximately 34 MB;
- `WaterMelon_Fixed.usdz`: approximately 3.3 MB;
- one mesh at 11,720 triangles;
- five material slots and eight packaged 1K textures;
- dimensions of approximately `0.256 × 0.300 × 0.135 m`.

The original file-size problem came from packed 8K images, including normal maps larger than 150 MB. The first optimized USDZ then failed twice: missing packaged dependencies and incorrect roughness/specular wiring. Both structural and Metal-render validation were necessary to catch the complete problem.
