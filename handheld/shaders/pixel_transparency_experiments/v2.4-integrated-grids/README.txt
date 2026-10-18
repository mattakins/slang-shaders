Integrated grid shader layout
=============================

Folder root
  Shared input, compositor, grid functions, vertex setup and uniform layouts.
  Pixel Transparency's shadow cache, native restore, film-noise and light
  passes, effect parameters and shared effect calculations also live here.
  The former common/ files are now directly in this folder.

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
  and final grid blend live here. Only the original LCD's native colour
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

The 2026-10-18 reorganizations only relocated or copied code and updated paths.
This prepares an independent effect pipeline without promoting it to production.
Existing preset filenames remain valid. External custom presets that directly
reference the former shader paths must use the new grids/<family>/ paths;
custom presets that reference the supplied preset files need no changes.
