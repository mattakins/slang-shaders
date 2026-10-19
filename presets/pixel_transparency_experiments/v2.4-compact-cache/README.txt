Authentic GBC Fast: compact shadow cache
========================================

Promoted: all v2.4 presets using the shared shadow cache now use this sizing,
including ../../authentic-gbc-frontlit.slangp once its motion blur stopped
reading the cache. These two presets are now identical to the production fast
presets.

  pixel_transparency-authentic_gbc_fast.slangp  5 passes
  sunlight_shimmer-authentic_gbc_fast.slangp    7 passes

What changed
------------
The shadow cache was allocated at 6x2 source scale but only uses
3(W+1) x (H+1) texels. It is now 3.1x1.1, and the restore pass scales back by
1/3.1 x 1/1.1. RetroArch rounds pass sizes, so the restore returns exactly to
the source size. Shader code and lookups are unchanged.

  Source     Before (RGBA32F)   After
  160x144    960x288  4.22 MiB  496x158  1.20 MiB
  240x160    1440x320 7.03 MiB  744x176  2.00 MiB

The layout fits any source of at least 30x5.

Validation (Mac Vulkan/MoltenVK, static Mario Tennis slot 9 and GBA frames)
------------------------------------------------------------------------
28 of 28 paired captures are pixel-identical to production: both effects,
GBC and GBA, fit and integer, shadow offset +/-30, blur 0 and 5, fast and
smooth blur. Evidence:
/Volumes/Ensemble/Retro/Screenshots/Reviews/pixel-transparency-colour-cache-uf6ylcdh/

Mac GPU time (Metal System Trace, 1200x1080, median of 3 interleaved runs):

  Preset                 Before    After
  Pixel Transparency GBC 0.890 ms  0.799 ms
  Pixel Transparency GBA 0.856 ms  0.815 ms
  Sunlight Shimmer GBC   0.913 ms  0.915 ms
  Sunlight Shimmer GBA   0.829 ms  0.787 ms

Run-to-run spread is about +/-20%, so the Mac result is inconclusive: no
regression, possibly a small gain.

RPC (Retroid Pocket Classic, live Mario Tennis slot 9, GBC fit, frames
128-384, full-quality defaults, 3 interleaved rounds):

  Preset              Before     After      Change
  Pixel Transparency  78.56 FPS  80.64 FPS  +2.6%
  Sunlight Shimmer    62.59 FPS  63.84 FPS  +2.0%

Every round improved; run-to-run spread was under 0.2 FPS. Evidence:
/Volumes/Ensemble/Retro/Screenshots/Reviews/pixel-transparency-compact-cache-rpc-zwqq4w3s/
