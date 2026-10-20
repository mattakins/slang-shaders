Integrated grid shader layout
=============================

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
  pt-grid-parameters.inc          Shared grid controls and uniform layouts.
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

Load the presets in presets/pixel_transparency_experiments/v2.4-integrated-grids/
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
