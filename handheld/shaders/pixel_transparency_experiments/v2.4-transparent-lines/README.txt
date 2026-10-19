Transparent paper lines (experiment)
====================================

Snapshot of the integrated grids with "Grid lines: reveal paper"
(PT_FUSED_TRANSPARENCY), taken 2026-10-19 when the feature was removed from
../v2.4-integrated-grids/. Presets: presets/pixel_transparency_experiments/
v2.4-transparent-lines/. Later integrated-grid changes do not propagate here.

Why it was split out: the paper-line code makes the final pass slower on the
Retroid Pocket Classic even when the option is off. Integrated Authentic
Sunlight Shimmer, GBC fit, live Mario Tennis slot 9, full-quality defaults:

  Before paper lines (c158d150)             64.8 FPS
  With paper lines (755016f6)               54.5 FPS
  This snapshot (single backing, no global) 56.9 FPS
  Paper-line code compiled out              66.0 FPS

Swapping single passes back to the pre-feature version located the whole
cost in the final pass. Removing only the Below or only the Above paper path
did not recover it, and [[dont_flatten]] branch hints had no effect.
Evidence: /Volumes/Ensemble/Screenshots/Reviews/pixel-transparency-paper-fix-rpc-2mhzitux/

Shader layout
-------------

Root pass shaders: pt-<stage>-<name>.slang
  pt-0-shadow-cache.slang          Build the source-cell shadow cache.
  pt-1-restore-original.slang      Restore native game pixels for the LCD.
  pt-3-film-noise-cache.slang      Cache film-noise corners for sunlight.
  pt-4-light-cache.slang           Render the smooth rainbow/glare field.

  Each contains its pass implementation. The shadow and light caches no
  longer have a separate implementation include behind an empty entry file.

  Numbers start at zero and describe the logical pipeline. Stage 2 (grid
  input) and stage 5 (final composition) use the entries in grids/<family>/.
  These are not fixed shaderN indices: plain transparency omits stages 3/4,
  and Authentic and LCD Grid v2 expand the grid stage into several passes.

Shared includes: unnumbered .inc files
  pt-shadow-kernel.inc            Shared cache and fallback sampling.
  pt-grid-input.inc               Reconstruct pixels and render Below grids.
  pt-grid.inc                     Shared vertex setup, LCD coverage and colour.
  pt-grid-parameters.inc          Placement control and grid uniform layouts.
  pt-params-sunlight.inc          Sunlight controls shared with compositing.
  pt-compositor.inc               Final composition for non-Authentic grids.
  pixel_transparency.inc          Paper, alpha, shadow lookup and tint effects.
  pt-params.inc                   Transparency controls shared across stages.
  sunlight_shimmer.inc            Apply sunlight to full-resolution output.

  Includes have no stage number because they are shared source, not passes.
  The two shadow lookup implementations live directly in pixel_transparency.inc.
  Grid vertex setup and fragment functions share pt-grid.inc. The remaining
  includes are reused across shader entries; parameters stay separate so
  each preset retains its controls and their order.
  All root code files retain a descriptive title and role header.

grids/lcd1x/
grids/lcd3x/
grids/simpletex_lcd/
grids/zfast_lcd/
grids/lcd-grid-v2/
  Each family has input.slang, pixel_transparency.slang, sunlight_shimmer.slang
  and parameters.inc. The small .slang entries select the family at compile
  time and include rendering code from the root. One parameters.inc supplies the
  same control declarations to every stage that needs them.

  LCD Grid v2 also owns cache_x.slang, cache_y.slang and integral.inc.

grids/authentic_gbc_fast/
  The effect compositors, geometry caches, grid input, integrated controls
  and final grid blend live here. Integrated controls and placement share
  parameters.inc. Only the original LCD's native colour
  conversion, shared geometry and parameters remain in the external
  authentic_gbc/ shader folder.

Line shade controls
  All six families support dark and light lines in both placements.
  Authentic, LCD1x, LCD3x, LCD Grid v2 and zfast use Grid line brightness:
  0=Dark (the existing default), 1=Light, with intermediate shades.
  Simpletex keeps its existing DARKEN_GRID setting and light default:
  Grid line shade is 0=Light, 1=Dark. Existing saved values still work.
  Authentic also retains RGB line tint. LCD Grid v2's subpixel colours remain
  separate from line brightness. No passes or texture reads are added.

Transparent paper lines
  Grid lines: reveal paper (PT_FUSED_TRANSPARENCY) blends the existing line
  shade into the Pixel Transparency paper backing: 0=Off, 1=Transparent.
  Intermediate values retain some dark/light line colour. The default is 0;
  saved brightness, Simpletex shade, Authentic tint and placement values keep
  their existing meanings. This is paper visible through the gaps, not a
  fade that removes the grid over the game image.

  Both effects and both placements support it. Paper, palette tint and
  shadows are calculated once at output resolution and shared with the
  transparency compositor. Below placement fills the grid before pixel
  transparency and sunlight; Above fills it after sunlight. Dither remains
  last. Turning Pixel Transparency off also bypasses this optional paper fill.

  The four simpler grids defer their grid styling to the compositor only
  while paper lines are enabled. Authentic and LCD Grid v2 retain native
  reconstruction, colour conversion and RGB coverage in the input stage;
  the compositor fills their gaps without applying the colour transform
  again. Authentic uses the existing input alpha channel for optional
  native-colour bias strength (8-bit only when bias is nonzero).

  No passes, framebuffers or texture assets are added. Enabled Below placement
  needs four existing axis-cache reads for Authentic, three for LCD Grid v2;
  Above reuses its existing grid reads. Paper must also be generated under
  otherwise opaque pixels when their grid gaps reveal it. These are real
  optional costs; unchanged pass counts do not prove unchanged GPU time.
  Device performance must be checked on the target hardware.

  Paper-line validation (2026-10-18): 88 shader stage variants passed compile
  and SPIR-V validation. Thirty original/default pairs and twelve alternate
  dark/light pairs were pixel-identical. Twelve disabled-effect checks and
  twelve fully-transparent dark/light endpoint checks were also identical.
  Fifty-two intentional appearance comparisons exercised both effects and
  placements, GBC/GBA, fit/integer, subpixels, custom strength/bias and both
  shadow modes. Captures use static native saved frames, not live gameplay.

  Mac Sunlight Shimmer timing (same 5000-frame method described below):
                            Before       Option off   Transparent
    Authentic Below         118.877794   118.863663    118.990957
    Authentic Above         119.033448   118.976800    119.033448
    LCD Grid v2 Below       118.891927   119.061793    118.962646
  These are presentation-limited Average monitor Hz readings, with substantial
  frame-time variation, not isolated GPU FPS. Differences were below 0.15%;
  no slowdown was observed in these capped Mac runs. RPC FPS remains untested.
  Reproducible evidence and an 18-case comparison viewer are saved under:
    /Volumes/Ensemble/Screenshots/Reviews/pixel-transparency-transparent-lines-zbygiy_8/

The Simpletex paper texture also remains an external grid asset. All Pixel
Transparency implementation code is local, including the integrated grid
adaptations; no preset here depends on an older Pixel Transparency pipeline.
Original production sources and older grid experiments remain unchanged.
The local files are a snapshot owned by this experiment; future changes do
not propagate to production.

Load the presets in presets/pixel_transparency_experiments/v2.4-transparent-lines/
from the repository root. The folder layout does not change rendering passes,
grid selection, parameter defaults or live above/below placement.

The 2026-10-18 reorganizations relocated or copied code, updated paths,
added descriptive headers and inlined single-use includes without changing
the compiled shaders.
Line shade validation (2026-10-18): 68 changed stage variants compiled and
passed SPIR-V validation. All 28 matched original/default Mac captures were
pixel-identical: both effects and placements for all six GBC grids, plus
LCD3x and LCD Grid v2 Sunlight Shimmer on GBA. Sixteen alternate-shade
captures also exercised both placements. These were static saved-frame
renders in RetroArch imageviewer, Vulkan/MoltenVK, screen fit, frame 10,
full quality with sensor motion disabled.

Mac Sunlight Shimmer timing, grid Above, 1200x1080 Mario Tennis saved frame:
                          Original     Default      Light lines
  LCD3x                   119.005117   119.146908    119.104335
  LCD Grid v2             119.189511   119.175307    118.990957
Values are RetroArch's Average monitor Hz counter, not isolated GPU FPS.
Each run used 5000 frames and the final 2048 samples. Mean differences were
under 0.2%, with substantial frame-time variation. No RPC was connected;
these Mac results cannot establish performance on that device.

This prepares an independent effect pipeline without promoting it to production.
Existing preset filenames remain valid. External custom presets that directly
reference former shader paths must use the current root or grids/<family>/
paths; custom presets that reference the supplied preset files need no changes.
