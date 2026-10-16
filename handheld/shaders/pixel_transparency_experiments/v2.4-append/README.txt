Pixel Transparency v2.4 all-append experiment
============================================

All preset chains in presets/pixel_transparency_experiments/v2.4-append/ keep
the LCD chain first, then append the generic Pixel Transparency sequence.
The standalone entries can be appended after another normal grid/LCD preset.
No LCD-specific shadow-cache entry points are required. The frontlit preset
retains reflective glass as its final post effect.

The sequence copies the LCD result, prepares a bounded 1536x512 shadow cache
from Original, and composites over the saved LCD image. Sunlight Shimmer also
uses the 128x128 film-noise and 256x256 optical-field passes. Larger source
inputs fall back to direct shadow calculations. Rendering parameters retain
their existing IDs, defaults, ranges and ordering.

The standard production presets and programs remain unchanged. This experiment
has not been benchmarked on Retroid Pocket Classic; its full-resolution copy
and fixed cache have different costs from the measured native-cache pipeline.
See the preset catalog's README.txt and VALIDATION.txt for observed differences.
