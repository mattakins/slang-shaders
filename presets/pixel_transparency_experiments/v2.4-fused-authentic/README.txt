Authentic GBC Fast: optional integrated grid experiment
====================================================

PERFORMANCE REGRESSION: Matt reported about 22 FPS on Retroid Pocket Classic
with the initial fused Sunlight Shimmer build at default grid settings. This
route is retained for investigation, not recommended as a replacement. Use
v2.4-integrated-authentic to try grid controls with separate rendering stages.

Retained presets:
  pixel_transparency-authentic_gbc_fast.slangp  (4 passes)
  sunlight_shimmer-authentic_gbc_fast.slangp    (6 passes)

The production presets remain in presets/pixel_transparency (5 and 7 passes).
This experiment combines Authentic's grid and the final compositor, removing
one viewport-sized RGBA8 framebuffer. Native colour conversion, source-sized
shadow caching, and Shimmer's noise and lighting caches are retained. Other LCD
presets continue using the existing separate-renderer path.

Controls under "Integrated grid experiment"
-------------------------------------------
Grid placement: 0 = below effects (default); 1 = above effects.
  Above applies Authentic's coverage over the finished paper and light at each
  output pixel. It does not resample those effects at native game resolution.
  This is a new look, not a pixel-exact recreation of literal preset prepend.
Grid strength: 1 = full grid (default); 0 = no grid attenuation.
  Authentic's reconstruction filter still blends neighbouring native pixels.
Grid line brightness: 0 = black (default); 1 = white.
Grid tint: Red / Green / Blue, each 1 by default. These multiply line brightness.
Grid brightness bias: 0 = uniform (default); 1 = reduced grid over dark content.

For white lines, set Grid line brightness to 1. Start with lower Grid strength
or increase brightness bias if the lines wash out dark content. Authentic's RGB
subpixel geometry is retained; this does not duplicate Simpletex's line shape.
Changing placement with zero grid strength leaves the same image to rounding.

PT_ENABLE still bypasses transparency and light, leaving the styled LCD grid.
PT_HIDE_CONTENT still hides the grid along with the game for effect inspection.
Dithering runs once, after the selected layer arrangement (unless explicitly
suppressed by PT_DEFER_DITHER in the plain transparency preset).

Implementation
--------------
The two entry points share grid.inc and the existing transparency/sunlight
includes. No transparency implementation is copied. The shared compositor has
optional input/vertex hooks and a final-dither override; ordinary presets do
not enable them. Production shader binaries remain unchanged in validation.

The removed LCD target's RGBA8 clipping and rounding are applied in the fused
shader; alpha stays opaque. Native inputs use nearest sampling with explicit
zero fill outside bounds. Grid coordinates occupy four additional varying
locations, staying within 16 total, including motion and light coordinates.
The light cache uses FinalViewportSize, because its former LCDInputSize is now
the native colour buffer. The shared lighting implementation remains the same.

Validation and performance
--------------------------
See VALIDATION.txt beside this file for measured image and timing results.
Fewer passes do not guarantee faster rendering: the combined shader carries
more live data. The reported RPC regression has not been independently profiled.
