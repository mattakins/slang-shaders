Integrated grid shader layout
=============================

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
This prepares an independent effect pipeline without promoting it to production.
Existing preset filenames remain valid. External custom presets that directly
reference former shader paths must use the current root or grids/<family>/
paths; custom presets that reference the supplied preset files need no changes.
