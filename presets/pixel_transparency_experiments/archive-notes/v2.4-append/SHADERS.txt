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
measures 46.07 FPS for Shimmer at Mario Tennis screen fit on Retroid Pocket
Classic, versus 62.60 FPS with the native-cache baseline. The full-resolution
copy, fixed cache and larger-input fallback have measurable costs. See the
preset catalog's RPC-BENCHMARKS.txt, README.txt and VALIDATION.txt for evidence.
