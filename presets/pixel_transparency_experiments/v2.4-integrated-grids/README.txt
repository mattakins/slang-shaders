Integrated grids — Pixel Transparency v2.4 experiment
===================================================

Twelve presets: Pixel Transparency and Sunlight Shimmer for Authentic GBC
Fast, LCD1x, LCD3x, LCD Grid v2, Simpletex LCD, and zfast LCD.

Load a preset from this folder, then change this shader parameter:

  Grid Placement: 0 Below / 1 Physical order

Both positions use the same preset and pass structure. No preset reload or
reordering is required when changing the parameter. Below is the default.
The production presets remain unchanged. See ../README.txt for the retained
experiments and the records of retired routes.

Below applies the LCD before transparency and lighting. Physical order
follows a real Game Boy Color screen, front to back: glare and front sheen,
grid gaps, rainbow, pixel colour, then paper and pixel shadows. The grid is
applied at full resolution over the paper, after the rainbow (which tints
light passing through the pixels) and before the front-surface sheen and
glare. Plain Pixel Transparency has no Sunlight, so there the grid is simply
drawn over the finished effects. Moving the grid also changes the LCD colour
used by the transparency controls that mix grid brightness into pixel alpha.
Physical order replaced the earlier "Above" placement (grid over everything,
including glare) on 2026-10-19.

Front polarizer tint: single pass (0.97, 1.0, 0.93), chosen for appearance
over the physical double pass (0.94, 1.0, 0.865) used before 2026-10-19.
Rainbow: tinted by the pixel colour once (single pass) instead of squared,
which keeps slightly more rainbow on coloured pixels. Its brightness gating
through the LC layer is unchanged.

Each preset retains its LCD's parameter names, defaults, ranges and saved
values. Simpletex retains its paper texture, bias and white/black lines;
zfast retains its gamma adjustment; LCD Grid v2 retains its colour matrix
and BGR setting. Authentic retains native colour conversion, optional
screen subpixels in all four orientations, and the integrated line-colour,
strength and bias controls from the axis-cache experiment.

For LCD1x, LCD3x, Simpletex and zfast, native pixels are reconstructed before
the effects. Physical order then applies that family's LCD operation to the finished
colour, including Simpletex darkening/paper and zfast gamma. LCD Grid v2
retains four-native-pixel reconstruction below; physical order evaluates its colour
transfer, matrix and grid coverage on the finished effects colour. Authentic
keeps its existing normalized reconstruction and grid-overlay behaviour.

Implementation
--------------

The five non-Authentic families share input, compositor and grid code.
Thin entries select a family at compile time so unused styles do not burden
the fragment shader. LCD1x/LCD3x share the sine implementation; Simpletex
and zfast share distance and polynomial calculations while retaining their
different constants and colour operations. Authentic's geometry caches, input,
grid helpers and effect compositors live locally in grids/authentic_gbc_fast/.
They preserve the previously verified axis-cache implementation.

Shared rendering and all Pixel Transparency effect dependencies are in the
integrated shader folder's root. Root .slang files carry their logical stage
number; shared .inc files have descriptive, unnumbered names. The shadow and
light cache implementations live directly in their .slang files. Numbers
are not fixed shaderN indices, and includes add no passes. See the shader
folder's README.txt for the file map.
grids/<family>/ holds each family's entries and settings.
Only the original Authentic LCD's conversion, shared geometry
and parameters, plus Simpletex's texture, remain external references. There
are no dependencies on older Pixel Transparency pipelines. Original production
and external LCD sources are unchanged.
The local effect code is an independent snapshot; this is not a promotion.
Preset filenames are unchanged; internal shader paths were updated. Custom
presets referencing moved shader files directly must follow the new paths;
preset references still work.

This is integrated shader code, not a single rendering pass. A combined
single-pass prototype for the four simple grids ran slower on RPC and was
not retained. Local shadow-cache and sunlight-field calculations are unchanged.
Final dithering remains after the grid and lighting, once per output pixel.

Declared passes                Transparency   Shimmer
  LCD1x / LCD3x / Simpletex / zfast     3           5
  LCD Grid v2                          5           7
  Authentic GBC Fast                   6           8

LCD Grid v2 caches horizontal weights in viewport-width x 2 and vertical
weights in 1 x viewport-height RGBA32F textures. Native indices travel with
the weights to keep sampling consistent at cell boundaries. Its full
colour reconstruction remains in the input pass. Authentic uses its own
previously verified one-dimensional geometry caches.

Performance and validation
--------------------------

See VALIDATION.txt for device measurements and image results. These are
experiments: a live placement control is not a guarantee of unchanged FPS.
Keep the production fast preset when its measured performance is preferable.
