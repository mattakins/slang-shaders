Grid after Pixel Transparency / Sunlight Shimmer
===============================================

These presets place the LCD grid over the finished effects while retaining
full-resolution paper and rainbow/glare detail. Choose pixel_transparency-*
for plain transparency or sunlight_shimmer-* for sunlight.

LCD1x, LCD3x, LCD Grid v2, Simpletex LCD and zfast LCD are included.
Plain transparency: 5 passes. Sunlight Shimmer: 7 passes.
For the existing placement, choose the same filename in ../grid-before/.

The extra pass applies display dither after the LCD, so the grid cannot
attenuate it. The native shadow cache, full paper and seven rainbow colours
are retained. Intermediate images use 16-bit float colour. The final image
is opaque; an internal alpha channel carries the dither-enable flag.
Plain transparency honours PT_DEFER_DITHER; Shimmer performs final dither
whenever Pixel Transparency is enabled, including with sunlight disabled.

Grid-after applies LCD brightness, gamma and any LCD background texture to
the entire effects image. It does not promise a pixel-identical literal
prepend: LCD Grid v2 deliberately samples the full-resolution effects image
instead of downsampling it to native pixel centres. Native grid spacing and
all existing parameters are retained. PT_HIDE_CONTENT hides the game while
leaving this separate grid visible over the effects.

These are fixed-placement alternatives, not live-toggle presets. Authentic
GBC Fast and the other families retain live placement in
../../pixel_transparency_experiments/v2.4-integrated-grids/.

More framebuffer bandwidth is required than the standard fast presets.
RPC speed has not been measured. See ../PRESETS.txt and VALIDATION.txt.
