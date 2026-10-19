Grid under sunlight (experiment)
================================

Copy of the integrated grids (2026-10-19) where placement 1 puts the grid
over the paper and shadows but under Sunlight (glare, rainbow, reflection),
instead of over everything:
  0 = Below effects               grid baked into the LCD image (unchanged)
  1 = Over paper, under light     integrated's Above blend, moved before Sunlight

This follows the real GBC stack: the dark pixel gaps sit in the LCD plane, in
front of the reflector (paper, shadows) and behind the front polarizer and
screen lens (glare, film rainbow). The existing blend moves; no code is added.

RPC cost (GBC fit, live Mario Tennis, 3 interleaved rounds), even though the
compiled size is unchanged; the earlier blend position changes register use:
                                     Integrated   This experiment
  Authentic Shimmer, Below             66.6         65.6
  Authentic Shimmer, placement 1       56.6 Above   56.2 under light
  LCD1x Shimmer, Below                 90.0         88.2
Evidence: /Volumes/Ensemble/Screenshots/Reviews/pixel-transparency-moved-grid-rpc-zkkoa1ni/
Plain Pixel Transparency has no Sunlight, so its placement 1 matches
integrated Above exactly.

A version offering Below, Above and this placement as three options cost
about 4 FPS on the RPC even in Below (Authentic Sunlight Shimmer 66.6 -> 62.4)
because the grid blend was compiled into the final pass twice. Evidence:
/Volumes/Ensemble/Screenshots/Reviews/pixel-transparency-under-sunlight-rpc-t2w7atbm/

Presets: presets/pixel_transparency_experiments/v2.4-grid-under-sunlight/.
Later integrated-grid changes do not propagate here.

Shader layout
-------------

Root pass shaders: pt-<stage>-<name>.slang
  pt-0-shadow-cache.slang          Build the source-cell shadow cache.
  pt-2-film-noise-cache.slang      Cache film-noise corners for sunlight.
  pt-3-light-cache.slang           Render the smooth rainbow/glare field.

  Each contains its pass implementation. The shadow and light caches no
  longer have a separate implementation include behind an empty entry file.

  Numbers start at zero and describe the logical pipeline. Stage 1 (grid
  input) and stage 4 (final composition) use the entries in grids/<family>/.
  These are not fixed shaderN indices: plain transparency omits stages 2/3,
  and Authentic and LCD Grid v2 expand the grid stage into several passes.
  Authentic runs its native colour conversion before the shadow cache.

  No restore pass: grid inputs read Original (or Authentic's converted
  colour) directly, so nothing after the shadow cache consumes it as Source.

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
  Removed 2026-10-19: the option cost about 8 FPS on the RPC even when off
  (Authentic Sunlight Shimmer 64.8 -> 56.9 FPS). It continues as its own
  experiment in ../v2.4-transparent-lines/ with presets in
  presets/pixel_transparency_experiments/v2.4-transparent-lines/.

The Simpletex paper texture also remains an external grid asset. All Pixel
Transparency implementation code is local, including the integrated grid
adaptations; no preset here depends on an older Pixel Transparency pipeline.
Original production sources and older grid experiments remain unchanged.
The local files are a snapshot owned by this experiment; future changes do
not propagate to production.

The universal selector in ../v2.4-live-grid/ also reuses some grid settings
and Grid v2's integral helpers from this folder.

Load the presets in presets/pixel_transparency_experiments/v2.4-grid-under-sunlight/
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
