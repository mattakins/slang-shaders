Authentic GBC Fast: integrated grid controls
==========================================

This is a separate experiment. Production presets and other LCD families are
unchanged. Load either preset directly:

  sunlight_shimmer-authentic_gbc_fast.slangp    8 passes
  pixel_transparency-authentic_gbc_fast.slangp  6 passes

Controls under "Integrated grid experiment"
-------------------------------------------
Grid placement: 0 = below effects (default); 1 = above effects. This is a live
shader parameter; switching placement does not require changing presets.
Grid strength: 1 = full grid (default); 0 = no grid attenuation.
Grid line brightness: 0 = black (default); 1 = white.
Grid tint: Red / Green / Blue, each 1 by default; multiply line brightness.
Grid brightness bias: 0 = uniform (default); 1 = reduce grid over dark content.

White lines retain Authentic's RGB subpixel geometry. They do not duplicate
Simpletex's line shape. Reduce grid strength or increase brightness bias to
retain dark content. The usual Authentic brightness, blur and subpixel controls
still apply.

Above-effects mode keeps fine paper and rainbow/glare detail at output
resolution. It is a new presentation, not the literal prepend route that
samples those effects at native game resolution. Grid strength zero removes
grid attenuation; Authentic's native reconstruction filter remains.

Pipeline
--------
  Source-sized shadow cache -> native restore -> native colour conversion
  -> grid input -> grid coverage cache
  -> optional film noise and light caches -> final transparency/Shimmer blend

There is one extra pass compared with production (5 plain / 7 Shimmer).
Grid geometry is calculated in small, separate shaders. The heavy compositor
stays last, sharing production transparency and sunlight code. In above mode,
it reads the coverage cache and performs only the final colour/coverage blend.
Below mode skips that read, and the coverage pass writes a constant mask.

The coverage cache uses viewport-sized RGBA16F to retain fine subpixel edges.
This costs an additional 8 bytes per output pixel of framebuffer storage
(about 9.9 MiB at 1200x1080), plus rendering/bandwidth. Both placements allocate
the cache because its size/format cannot change with a shader parameter.

Dither is applied once, after light and the selected grid placement. PT_ENABLE
bypasses the effects and retains the grid. PT_HIDE_CONTENT hides the grid for
background inspection. Existing parameter defaults are preserved.

The earlier v2.4-fused-authentic route remains available for investigation.
Matt reported about 22 FPS on RPC with its initial default Shimmer build. That
report motivated separating grid work; it does not establish the cost or
speed of this new route. See VALIDATION.txt for measured results and limits.

RPC results (2026-10-17)
------------------------
Mario Tennis fit Shimmer: current fast 62.55 FPS, integrated below 49.66,
integrated above 37.69. The default below-grid images match the current preset
pixel-for-pixel in the tested GB/GBA cases; all four Authentic subpixel layouts
are supported. Keep the current fast presets for RPC performance. See
RPC-BENCHMARK.txt for repeated measurements, images and limitations.
