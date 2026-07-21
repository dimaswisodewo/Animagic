# USDZ Validation and Troubleshooting

A USDZ is ready only when its bytes, dependencies, shader graph, geometry metadata, and Apple Metal render all pass. Run these checks against the exact file intended for delivery.

## Required validation sequence

### 1. Check texture bytes and dimensions

Before packaging, verify every staged image:

```bash
file <staging>/textures/*
sips -g pixelWidth -g pixelHeight -g format <staging>/textures/*
```

Pass when:

- base-color files are genuine RGB JPEGs;
- normal maps are genuine 8-bit RGB PNGs;
- the encoded format matches the extension;
- the longest side is no more than 1024 px, unless an exception is documented.

### 2. Inventory the package

```bash
ls -lh <Asset>_Fixed.usdz
unzip -l <Asset>_Fixed.usdz
```

Pass when the archive contains one root USD layer and every referenced texture. Compare the inventory with the material image nodes; do not infer completeness from package size.

### 3. Validate USD dependencies

```bash
usdchecker <Asset>_Fixed.usdz
```

Pass only when the result is `Success!` with no missing or unresolvable dependencies. Tool-level registration warnings may be environmental, but dependency, shader, normal-map, and compliance errors are failures.

### 4. Inspect the shader graph

```bash
usdcat <Asset>_Fixed.usdz --flatten | \
  rg 'asset inputs:file|inputs:(diffuseColor|roughness|specular)(\.connect)?'
```

For the default opaque material, pass when:

- every base-color texture feeds `diffuseColor`;
- roughness is the constant `0.65`;
- specular is the constant `0.25`;
- no color texture feeds roughness or specular;
- all asset paths resolve inside the package.

Also confirm the mesh contains `primvars:st` UV data and that each material is bound to the intended mesh or geometry subset.

### 5. Confirm geometry and units

Inspect the USD metadata or the optimized Blend and confirm:

- `metersPerUnit = 1`;
- the intended up axis and default orientation;
- the real-world dimensions recorded for the asset;
- approximately 15,000 triangles or fewer for a standard prop;
- the base rests at ground level and the pivot supports expected placement.

### 6. Render with Apple's Metal USD renderer

```bash
usdrecord <Asset>_Fixed.usdz <Asset>_Validation.png \
  -w 1200 \
  -r Metal
```

Open the output image and compare it with the Blender reference. Pass when expected colors, material regions, normals, seams, and silhouette are visible. `usdchecker` cannot replace this step: it validates structure, not whether the material looks correct.

### 7. Deliver and verify identity

After copying the validated file, confirm that delivery did not change it:

```bash
shasum -a 256 <staging>/<Asset>_Fixed.usdz <delivery>/<Asset>_Fixed.usdz
```

The hashes must match.

## Troubleshooting matrix

| Symptom | Likely cause | Check | Resolution |
| --- | --- | --- | --- |
| Mesh appears but is untextured | Textures were referenced but not packaged | `unzip -l`, then `usdchecker` | Rebuild from staged USDC and explicit textures with `usdzip --arkitAsset` |
| Model is nearly black with bright reflections | Base-color red channel also drives roughness or specular | Inspect flattened shader inputs | Disconnect those links; use roughness `0.65` and specular `0.25` |
| `usdchecker` reports an unresolved dependency | Absolute, stale, or missing texture path | Inspect `asset inputs:file` | Rebind fresh external images and export relative paths |
| `.usdz` is not recognized as an archive | A raw USDC/USD file was given a `.usdz` extension or packaging was interrupted | `file`, `unzip -l` | Package the USDC with `usdzip`; do not rename formats |
| Only one of several textures appears in the archive | Blender's one-step USDZ packager dropped dependencies | Compare shader references with archive inventory | Export plain USDC and package all dependencies explicitly |
| Texture extension and decoded type disagree | Packed image metadata is stale | `file`, `sips`, Blender `Image.file_format` | Save externally with explicit settings, reload fresh datablocks, and rebind nodes |
| Texture exists but maps incorrectly | Missing/wrong UV set or transform | Inspect `primvars:st` and `UsdPrimvarReader_float2` | Export the active UV map as `st` and verify material UV selection |
| Normal detail looks inverted or distorted | Wrong color space, channel convention, or direct normal connection | Inspect normal texture and node wiring | Use Non-Color PNG through a Normal Map node and compare against Blender |
| Quick Look hangs or shows stale output | Preview service/cache issue or malformed asset | Run `usdrecord` and `usdchecker` directly | Fix structural errors first; restart preview services or Xcode only after the CLI artifact passes |
| Runtime reports a missing model | USDZ is absent from the app bundle or its resource name changed | Inspect Xcode target membership and built app resources | Add the validated asset to the target or update the catalog resource name |

## WaterMelon incident reference

The broken `WaterMelon.usdz` contained a USDC and only one normal map, while its shaders referenced eight textures. `usdchecker` correctly failed the missing dependencies. A separately packaged version then passed dependency validation but rendered black because several base-color textures also drove roughness or specular.

The accepted repair used fresh 1K JPEG/PNG images, constant PBR values, plain USDC export, explicit Apple USDZ packaging, and a Metal render showing green rind and red flesh. Its final package contained one USDC plus eight textures and was approximately 3.3 MB.

## Final acceptance checklist

- [ ] Artist master remains unchanged.
- [ ] Optimized Blend is a separate file.
- [ ] Geometry, scale, origin, and units meet the asset brief.
- [ ] Texture encodings, extensions, dimensions, and color spaces agree.
- [ ] Material inputs follow the opaque-prop PBR contract.
- [ ] Archive inventory contains every dependency.
- [ ] `usdchecker` succeeds.
- [ ] Apple Metal render shows the expected textured asset.
- [ ] Delivered file hash matches the validated staging file.
