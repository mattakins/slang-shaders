Authentic GBC Fast: cached grid with live placement
=================================================

Load either preset directly. Change "Grid placement" in Shader Parameters:
  0 = below effects (default)
  1 = above effects
No preset reload is required. All existing integrated-grid controls remain,
including tint, strength, brightness bias and Authentic's four subpixel layouts.
Paper, rainbow/glare and dithering remain at their existing quality defaults.

  sunlight_shimmer-authentic_gbc_fast.slangp    9 passes
  pixel_transparency-authentic_gbc_fast.slangp  7 passes

This is a separate experiment. Production fast presets and standalone LCD
shaders are unchanged. The slower full-screen integrated and initial fused
routes have been retired; their records remain in ../archive-notes/.

What changed
------------
Authentic's rectangle overlap separates into horizontal and vertical parts.
Two thin floating-point caches calculate those parts once per output column
and row. The grid input and final compositor reuse them. This replaces the
previous full-screen grid-coverage cache and its repeated geometry calculation.

  Shadow cache -> native restore -> native colour conversion
  -> horizontal overlap cache -> vertical overlap cache -> grid input
  -> optional film noise and light caches -> final transparency/Shimmer blend

The caches are viewport-width x 6 and 6 x viewport-height, both RGBA32F. At
1200x1080 they use about 0.21 MiB, versus 9.89 MiB for the previous RGBA16F
coverage image. There is one more declared pass, but much less per-pixel work.
Cache coordinates use output pixel centres. Sampling decisions travel with the
weights so half-cell rounding cannot select a different neighbouring texel.

The heavy effects compositor stays last. Grid-above applies coverage after
paper and sunlight without reducing their resolution. Dither is added once,
after the selected grid placement. The usual effect bypass and hidden-content
controls still apply. Shared Authentic control definitions are local to this
route and are also reused by the live-grid experiment.

RPC performance
---------------
Mario Tennis, screen fit, full-quality Sunlight Shimmer, three alternating runs:
  Current fast                           62.59 FPS
  Previous integrated, below             49.66 FPS (previous three-run median)
  Previous integrated, above             37.69 FPS (previous three-run median)
  Cached grid, below                     64.75 FPS
  Cached grid, above                     55.60 FPS

Above remains below the 60 FPS goal on this demanding case. Fast background
texture only raised it to 55.99 FPS, so full texture remains the default.
These are uncapped live-core measurements; normal playback confirmed about
60 FPS below and 55 FPS above. They are not isolated GPU timings or thermal-soak
results. See VALIDATION.txt for images, test conditions and limitations.
