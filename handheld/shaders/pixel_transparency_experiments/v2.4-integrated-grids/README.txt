Integrated grid shader layout
=============================

common/
  Shared input, compositor, grid functions, vertex setup and uniform layouts.

grids/lcd1x/
grids/lcd3x/
grids/simpletex_lcd/
grids/zfast_lcd/
grids/lcd-grid-v2/
  Each family has input.slang, pixel_transparency.slang, sunlight_shimmer.slang
  and parameters.inc. The small .slang entries select the family at compile
  time and include common rendering code. One parameters.inc supplies the
  same control declarations to every stage that needs them.

  LCD Grid v2 also owns cache_x.slang, cache_y.slang and integral.inc.

Authentic GBC Fast uses ../v2.4-grid-axis-cache/ directly. Its cached geometry
and native colour conversion remain separate from these five families.
The universal selector in ../v2.4-live-grid/ also reuses some grid settings
and Grid v2's integral helpers from this folder.

Load the presets in presets/pixel_transparency_experiments/v2.4-integrated-grids/
from the repository root. The folder layout does not change rendering passes,
grid selection, parameter defaults or live above/below placement.

The 2026-10-18 reorganization only moved shader files and updated references.
Existing preset filenames remain valid. External custom presets that directly
reference the former shader paths must use the new grids/<family>/ paths;
custom presets that reference the supplied preset files need no changes.
