# Session Context: Moiré Reduction for GB Shader & Sharp-Shimmerless-Plus

## Branch
`claude/gameboy-shader-pixel-grid-IA6J5`

## Problem
The Game Boy Dot Matrix Shader (gb-pass0.slang) exhibits moiré artifacts with dark pixels at non-integer (fractional) display scales. The moiré is caused by the beat frequency between the source texel grid and the output pixel grid — at fractional scales, different output pixels have genuinely different dot coverage, and this periodic variation is visible as banding. It's worse with dark pixels due to Weber's law (the human eye is more sensitive to brightness changes in darker regions).

## What Was Implemented

### Two new user toggles (both default OFF) added to both shaders:

### 1. Adaptive Softness (`moire_adapt` / `MOIRE_ADAPT`)
Auto-increases dot edge softness based on how far the scale factor is from an integer.

**Math:** `fract_factor = max(0.5 - abs(fract(scale.x) - 0.5), 0.5 - abs(fract(scale.y) - 0.5))`
- 0 at integer scales (no moiré, no softening)
- 0.5 at worst-case x.5 scales (maximum softening)

**GB shader (gb-pass0.slang):**
- Computed in vertex shader as `effective_softness = pixel_softness + fract_factor * 4.0`
- Fed into `sample_average_coverage()` for grey balance compensation
- Also used in `softness_comp` empirical correction
- Passed as varying (location 11) to fragment shader
- Fragment shader uses `effective_softness` instead of `registers.pixel_softness` in all sharpening paths (power curve, sigmoid, both rectangular and circular methods)

**SSP (sharp-shimmerless-plus.slang):**
- Reduces effective SHARPNESS: `sharpness *= (1.0 - fract_factor)`
- At integer scales: full user sharpness. At x.5: sharpness halved.

### 2. Perceptual Blend (`perceptual_blend` / `PERCEPTUAL_BLEND`)
Linearizes RGB before alpha compositing / grid blending, then re-encodes to sRGB. This equalizes the perceptual impact of coverage variation across brightness levels.

**GB shader (gb-pass4.slang):**
- `pow(rgb, 2.2)` on foreground, shadows, and background AFTER color setup but BEFORE alpha compositing
- `pow(max(rgb, 0.0), 1/2.2)` on the final result AFTER compositing
- Placed between the background color application and the shadow/foreground blend operations

**SSP (sharp-shimmerless-plus.slang):**
- Linearizes both `FragColor.rgb` and grid color before `mix()`, then de-linearizes
- Only applies to the grid overlay blend (pixel content doesn't need it since weights sum to 1.0)

## Files Modified

| File | Changes |
|------|---------|
| `handheld/shaders/gameboy/shader-files/gb-params.inc` | Added `moire_adapt` and `perceptual_blend` pragma parameters under "Fullscreen pixel appearance" after `pixel_size` |
| `handheld/shaders/gameboy/shader-files/gb-pass0.slang` | Added `moire_adapt` to push_constant. Added `effective_softness` varying (location 11). Compute adaptive softness in vertex shader before grey balance. Use `effective_softness` in fragment sharpening (4 locations). Updated `softness_comp` to use `effective_softness`. |
| `handheld/shaders/gameboy/shader-files/gb-pass4.slang` | Added `perceptual_blend` to push_constant. Wrapped compositing with linearize/delinearize. |
| `pixel-art-scaling/shaders/sharp-shimmerless-plus.slang` | Added "Moiré Reduction" section header + `MOIRE_ADAPT` and `PERCEPTUAL_BLEND` parameters and push_constant fields. Adaptive sharpness reduction in fragment. Perceptual grid overlay blend. |

## Architecture Notes

- **GB shader is multi-pass:** pass0 (dot matrix + coverage) → pass1 (horizontal blur) → pass2 (horizontal blur for shadows) → pass3 (vertical blur) → pass4 (final compositing with background, shadows, palette colors). Coverage is stored as alpha.
- **SSP is single-pass:** area-overlap + sharpening curve + optional grid overlay. Grid uses line-segment intersection (already moiré-free by design via linear area-weighting).
- **Push constant sizes** are close to the 128-byte Vulkan minimum — be careful adding more fields. gb-pass0 is ~120 bytes, gb-pass4 is ~120 bytes, SSP is ~100 bytes.
- **The console-border variant** (`handheld/console-border/shader-files/`) is the original Harlequin v0.2.2 — completely separate codebase, does NOT share `gb-params.inc`, was NOT modified.
- **Grey balance compensation** in gb-pass0 uses numerical 4x4 coverage sampling in the vertex shader. The adaptive softness must be computed BEFORE grey balance and fed into `sample_average_coverage()` to keep brightness correct.

## Research Summary

A comprehensive survey of moiré reduction techniques was conducted. The full taxonomy:

**Family A — Correct Resampling:** Sharp-Shimmerless, bandlimited pixel, box filter AA, pixel AA (slopestep), AANN, sharp-bilinear. These treat pixels as areas, not points.

**Family B — Oversampling:** crt-geom 3x beam, crt-pi multisampling, cathode-retro analytic sinusoidal integration, Advanced CRT de-moiré convolution (up to 256 taps).

**Family C — Break Coherence:** moire-resolve (temporal noise + jittered Gaussian), Koko-AIO phosphor stagger (`PIXELGRID_H_ANTIMOIRE`), MAME HLSL noise.

**Family D — Architectural Avoidance:** Un-curved mask coordinates, integer scaling, resolution matching.

The two approaches chosen (adaptive softness + perceptual blend) were selected for being single-pass, zero extra texture reads, and targeting both the coverage variation magnitude and its perceptual visibility in dark regions.

## Potential Future Work
- **3x coverage oversampling** (like crt-geom's OVERSAMPLE) — run intersection math at 3 sub-pixel positions and average. More accurate but 9x the ALU.
- **Integer pre-render + bilinear remainder** (2-pass) — render dots at nearest integer scale, then bilinear to final. Best quality but requires intermediate render target.
- **Stochastic dithering** — add noise to break coherent moiré into grain. Different aesthetic.
- **Bandlimited dot rendering** — convolve coverage with cosine kernel sized to output pixel footprint. Signal-theoretically correct.
