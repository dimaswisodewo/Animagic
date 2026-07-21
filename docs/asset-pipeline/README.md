# AR Asset Pipeline

This directory is the source of truth for converting Blender scenes into compact, textured USDZ assets for AniMagic. It is written for both people and AI agents: the rules explain why a step exists, while the runbooks define commands and pass/fail criteria.

## Documents

- [Blender to USDZ](BLENDER_TO_USDZ.md) — optimize a Blender scene, normalize its materials and textures, export USDC, and package USDZ.
- [Validation and troubleshooting](VALIDATION_AND_TROUBLESHOOTING.md) — prove the package is structurally and visually correct and diagnose common failures.

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
