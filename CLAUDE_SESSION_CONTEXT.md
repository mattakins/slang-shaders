# Session Context: Sharp-Shimmerless-Plus & GB Shader Moiré Reduction

## Branch
`claude/gameboy-shader-pixel-grid-IA6J5`

## Commit History (chronological)
1. `fadf623` — **Create Sharp-Shimmerless-Plus** (new shader + preset)
2. `b37d60f` — **Add area-correct pixel grid overlay** to SSP
3. `8a5307f` — **Add moiré reduction toggles** to both GB shader and SSP
4. `bca5b90` — Add this context document

---

## Part 1: Creating Sharp-Shimmerless-Plus

### Motivation
The user wanted a general-purpose pixel art upscaler with tunable sharpness AND an optional pixel grid overlay — combining the best of Sharp-Shimmerless (area-correct fractional scaling, zero shimmer) with the sharpening curves from the Game Boy Dot Matrix Shader (crisp dot edges without binary harshness).

### How Sharp-Shimmerless Works (the foundation)
Sharp-Shimmerless by zadpos treats both input texels and output pixels as rectangles. For each output pixel, it computes how much area overlaps the left/upper texel vs the right/lower texel. This linear overlap weight is encoded into texture coordinates so hardware bilinear does the actual blending in a single sample. Key insight: when an output pixel falls entirely within one texel, overlap = 0 or 1 → no blending → nearest-neighbor sharpness. Blending only occurs at actual texel boundaries → zero shimmer.

### What SSP Adds

**Sharpening curves** — The linear overlap weight (soft transitions) is passed through a nonlinear curve before encoding into the bilinear coordinate:

- **Sigmoid mode:** `s(x) = (sigmoid(k*(x-0.5)) - sigmoid(-k/2)) / (1 - 2*sigmoid(-k/2))` — S-curve with parametric steepness k. Produces a "digital" feel with flat extremes and sharp transition zone. k maps SHARPNESS [0,1] to steepness [0,20].

- **Power mode:** Symmetric power curve using `0.5 * pow(2x, p)` for x < 0.5 and `1 - 0.5 * pow(2(1-x), p)` for x >= 0.5. Smoother, more gradual transitions. p maps SHARPNESS [0,1] to exponent [1,10].

Both curves satisfy `f(0)=0, f(1)=1, f(x)+f(1-x)=1` — so blend weights always sum to 1.0, brightness is preserved by construction, no grey balance compensation needed.

- **SHARPNESS = 0:** Identical to Sharp-Shimmerless (linear area blend)
- **SHARPNESS = 1:** Near point-sampling, still shimmer-free

### Design Decisions
- **Single bilinear texture read** — the sharpened weight is encoded as a UV offset, so hardware bilinear does the blend. No extra texture fetches.
- **Why not just use the GB shader's curves directly?** — The GB shader applies sharpening to 1D coverage values (intersect_line_segment output). SSP applies sharpening to 2D area-overlap weights. Same math, different coordinate system.
- **Why two curve types?** — Sigmoid gives "crispy LCD" feel (from the GB shader's sharp_mode=1), power gives "soft analog" feel (from sharp_mode=0). User preference.

### Files Created
- `pixel-art-scaling/shaders/sharp-shimmerless-plus.slang` — The shader
- `pixel-art-scaling/sharp-shimmerless-plus.slangp` — Preset file (single pass, references the .slang)

---

## Part 2: Adding the Pixel Grid Overlay

### Motivation
The user wanted SSP to have an optional pixel grid (like CRT phosphor grids or the GB dot matrix gaps) that works correctly at fractional scales without moiré.

### Technique: Line-Segment Intersection (ported from GB shader)
The grid overlay uses the exact same area-intersection technique as gb-pass0's dot matrix:

```glsl
// Signed distance from pixel center to nearest texel boundary
vec2 s = tc_frac - step(0.5, tc_frac);  // maps [0,1) → [-0.5, 0.5)

// Output pixel half-width in texel space
vec2 ph = 0.5 * OriginalSize.xy * OutputSize.zw;

// Grid line half-width
vec2 gh = vec2(GRID_WIDTH * 0.5);

// 1D intersection: pixel extent [s-ph, s+ph] vs grid line [-gh, gh]
vec2 cov_lo = max(s - ph, -gh);
vec2 cov_hi = min(s + ph,  gh);
vec2 grid_1d = clamp((cov_hi - cov_lo) / (2.0 * ph), 0.0, 1.0);

// 2D: union of horizontal and vertical grid lines
float grid_cov = grid_1d.x + grid_1d.y - grid_1d.x * grid_1d.y;
```

### Critical Design Decision: No Sharpening on Grid Coverage
Grid coverage is kept at **linear area-weighting intentionally**. Applying the sharpening curve to grid coverage would amplify small coverage differences between adjacent output pixels, reintroducing the moiré that the area-correct approach eliminates. This is documented in comments in the shader.

### Grid Uses OriginalSize
The grid texel-space coordinates use `OriginalSize` (not `SourceSize`) so the grid aligns with the game's native pixel grid even in multi-pass setups where SourceSize might differ.

### Parameters Added
- `GRID_ENABLE` — Toggle (0/1)
- `GRID_WIDTH` — Line width in texel space [0.01, 0.5]
- `GRID_INTENSITY` — Blend strength [0, 1]
- `GRID_BRIGHT` — Grid line brightness [0, 1]

---

## Part 3: Moiré Reduction Toggles

### Problem
The GB Dot Matrix Shader (gb-pass0.slang) exhibits moiré artifacts with dark pixels at non-integer scales. The moiré is the beat frequency between the source texel grid and the output pixel grid — at fractional scales, different output pixels have genuinely different dot coverage. This periodic coverage variation is visible as banding. It's worse with dark pixels due to Weber's law (the eye is more sensitive to brightness changes in darker regions).

### Research Conducted
A comprehensive survey of moiré reduction techniques was performed across the entire slang-shaders repo and web literature:

**Family A — Correct Resampling:** Sharp-Shimmerless, bandlimited pixel (Themaister), box filter AA (fishku), pixel AA slopestep (fishku), AANN (jimbo1qaz/wareya), sharp-bilinear. These treat pixels as areas, not points.

**Family B — Oversampling:** crt-geom 3x beam (`#define OVERSAMPLE`), crt-pi multisampling, cathode-retro analytic sinusoidal integration, Advanced CRT de-moiré convolution (up to 256 taps).

**Family C — Break Coherence:** moire-resolve (temporal noise + jittered Gaussian, hunterk/Lottes), Koko-AIO phosphor stagger (`PIXELGRID_H_ANTIMOIRE`), MAME HLSL noise.

**Family D — Architectural Avoidance:** Un-curved mask coordinates (crt-yah, crt-gdv-mini), integer scaling, resolution matching.

### What Was Chosen and Why
Two approaches selected for being single-pass, zero extra texture reads, and targeting both the coverage variation magnitude AND its perceptual visibility:

### Toggle 1: Adaptive Softness (`moire_adapt` / `MOIRE_ADAPT`)
Auto-adjusts dot/pixel edge softness based on how far the scale factor is from an integer.

**Math:** `fract_factor = max(0.5 - abs(fract(scale.x) - 0.5), 0.5 - abs(fract(scale.y) - 0.5))`
- 0 at integer scales (no moiré → no softening needed)
- 0.5 at worst-case x.5 scales (maximum softening)

**GB shader (gb-pass0.slang):**
- Computed in vertex shader as `effective_softness = pixel_softness + fract_factor * 4.0`
- Fed into `sample_average_coverage()` for grey balance compensation
- Also used in `softness_comp` empirical correction (changed from `registers.pixel_softness` to `effective_softness`)
- Passed as varying (location 11) to fragment shader
- Fragment shader uses `effective_softness` instead of `registers.pixel_softness` in all 4 sharpening paths (power rect, sigmoid rect, power circ, sigmoid circ)

**SSP (sharp-shimmerless-plus.slang):**
- Reduces effective SHARPNESS: `sharpness *= (1.0 - fract_factor)`
- At integer scales: full user sharpness. At x.5: sharpness halved.

### Toggle 2: Perceptual Blend (`perceptual_blend` / `PERCEPTUAL_BLEND`)
Linearizes RGB before alpha compositing / grid blending, then re-encodes to sRGB. Equalizes the perceptual impact of coverage variation across brightness levels.

**GB shader (gb-pass4.slang):**
- `pow(rgb, 2.2)` on foreground, shadows, and background AFTER color setup but BEFORE alpha compositing
- `pow(max(rgb, 0.0), 1/2.2)` on the final result AFTER compositing
- Placed between the background color application and the shadow/foreground blend operations

**SSP (sharp-shimmerless-plus.slang):**
- Linearizes both `FragColor.rgb` and grid color before `mix()`, then de-linearizes
- Only applies to the grid overlay blend (pixel content doesn't need it since sharpened weights sum to 1.0)

Both toggles default OFF to preserve existing behavior.

---

## All Files Modified/Created

| File | What |
|------|------|
| `pixel-art-scaling/shaders/sharp-shimmerless-plus.slang` | **Created** in commit 1, then extended in commits 2 and 3. The complete shader with sharpening curves, grid overlay, and moiré reduction. |
| `pixel-art-scaling/sharp-shimmerless-plus.slangp` | **Created** in commit 1. Single-pass preset. |
| `handheld/shaders/gameboy/shader-files/gb-params.inc` | Added `moire_adapt` and `perceptual_blend` pragma parameters under "Fullscreen pixel appearance" after `pixel_size` |
| `handheld/shaders/gameboy/shader-files/gb-pass0.slang` | Added `moire_adapt` to push_constant. Added `effective_softness` varying (location 11). Compute adaptive softness in vertex shader before grey balance. Use `effective_softness` in fragment sharpening (4 locations). Updated `softness_comp` to use `effective_softness`. |
| `handheld/shaders/gameboy/shader-files/gb-pass4.slang` | Added `perceptual_blend` to push_constant. Wrapped compositing with linearize/delinearize. |

## Architecture Notes

- **GB shader is multi-pass:** pass0 (dot matrix + coverage) → pass1 (horizontal blur) → pass2 (horizontal blur for shadows) → pass3 (vertical blur) → pass4 (final compositing with background, shadows, palette colors). Coverage is stored as alpha.
- **SSP is single-pass:** area-overlap + sharpening curve + optional grid overlay. Grid uses line-segment intersection (already moiré-free by design via linear area-weighting).
- **Push constant sizes** are close to the 128-byte Vulkan minimum — be careful adding more fields. gb-pass0 is ~120 bytes, gb-pass4 is ~120 bytes, SSP is ~100 bytes.
- **The console-border variant** (`handheld/console-border/shader-files/`) is the original Harlequin v0.2.2 — completely separate codebase, does NOT share `gb-params.inc`, was NOT modified.
- **Grey balance compensation** in gb-pass0 uses numerical 4×4 coverage sampling in the vertex shader. Any changes to effective softness must be computed BEFORE grey balance and fed into `sample_average_coverage()` to keep brightness correct.
- **The sharpening curves are shared between GB and SSP** in concept but implemented independently — GB applies them to 1D coverage (intersect_line_segment output), SSP applies them to 2D area-overlap weights. Same mathematical functions, different usage.

## Potential Future Work
- **3x coverage oversampling** (like crt-geom's OVERSAMPLE) — run intersection math at 3 sub-pixel positions and average. More accurate but 9x the ALU.
- **Integer pre-render + bilinear remainder** (2-pass) — render dots at nearest integer scale, then bilinear to final. Best quality but requires intermediate render target.
- **Stochastic dithering** — add noise to break coherent moiré into grain. Different aesthetic.
- **Bandlimited dot rendering** — convolve coverage with cosine kernel sized to output pixel footprint. Signal-theoretically correct.
