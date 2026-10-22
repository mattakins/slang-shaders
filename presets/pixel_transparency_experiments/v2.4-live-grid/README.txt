Live grid style and placement experiment
=======================================

Load sunlight_shimmer.slangp, then open Shader Parameters.

Grid style (PT_GRID_STYLE):
  0  Authentic GBC Fast (default)
  1  LCD1x
  2  LCD3x
  3  LCD Grid v2
  4  Simpletex LCD
  5  zfast LCD

Grid placement (PT_FUSED_LAYER):
  0  Below the paper, shadows and sunlight (default)
  1  Above the completed effects

Both controls are live uniforms. Switching them does not require loading
another preset or recompiling the shaders. Each family's controls retain
their values while another style is selected; inactive controls do nothing.
The menu displays all families' controls. The two sets of scanline and LCD
brightness controls are labelled LCD1x and LCD3x to distinguish them.

Authentic retains its blur, brightness, display subpixels and orientation,
plus grid line brightness, tint, strength and bias. The other styles use
their original controls. The line-colour controls apply to Authentic only.
Simpletex retains its own white/dark grid and optional background texture.

Turn Sunlight Shimmer off to use transparency without the sunlight effect.
That changes the appearance; it does not remove passes from this preset.

Rendering
---------
Nine declared passes serve every style:
  shadow cache -> restored native input -> Authentic native colour conversion
  -> horizontal grid cache -> vertical grid cache -> LCD input
  -> film noise cache -> light field -> effects and optional grid overlay.

Authentic and LCD Grid v2 share the two narrow FP32 grid caches. Other
styles skip the cache calculations. Non-Authentic styles sample the restored
native input directly and bypass Authentic's converted colour texture.
Paper and sunlight never pass through the native-resolution conversion.
Dither is applied once after the final grid blend.

The preset keeps the separate-style experiments' effective defaults,
including the LCD Grid v2 matrix and Simpletex overrides. Their sampling,
colour math and placement semantics are retained. The grid-above look is
not literal prepending: it preserves the fine paper and lighting detail.

Performance and scope
---------------------
This is a separate experiment. It does not replace the production presets
or the earlier separate-style experiments. See VALIDATION.txt for measured
results and limitations.

A live style selector requires a fixed pass layout. The nine-pass layout
matches Authentic, adds one helper pass compared with LCD Grid v2, and adds
three compared with the four simpler grids. Unused calculations are skipped,
but the pass overhead remains. A larger runtime-selectable shader can also
cost more than a style-specific shader. Fewer preset files do not imply
equal FPS.

RPC measurements show a 9.2-27.0% throughput loss versus the dedicated
integrated-style presets at full-quality screen fit. Authentic measured
54.66 FPS below / 46.67 above, versus 64.84 / 55.47 for its dedicated preset.
LCD1x, LCD3x, Simpletex and zfast stayed around 62-64 FPS in this short test;
Authentic and Grid v2 did not reach 60. See VALIDATION.txt for exact scope.

For RPC performance, prefer the production presets in ../../pixel_transparency/
and choose the style
by preset. Those presets retain the live above/below control. Use this
experiment when live style selection is worth the measured overhead.
All 22 RPC image pairs matched exactly, including Authentic subpixel cases.
Both live controls were verified without reloading the running preset.
