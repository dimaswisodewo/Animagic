# Blender to USDZ

This runbook defines the authoritative script-first conversion. Blender UI operations are acceptable for inspection and art review, but automation should produce the delivery artifact so results are repeatable.

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

- Resize so the longest side is at most 1024 px while preserving aspect ratio.
- Save as a genuine baseline RGB JPEG at quality about 82.
- Use an `.jpg` extension and `sRGB` interpretation.
- Do not retain an alpha channel for an opaque prop.

### Normal maps

- Resize so the longest side is at most 1024 px.
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
