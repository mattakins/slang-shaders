Pixel Transparency experiments
=============================

The production fast presets remain in ../pixel_transparency/.

Retained grid experiments
-------------------------
v2.4-integrated-grids/
  Dedicated presets for six grid styles, each with live above/below placement.
  Prefer these when performance matters more than switching grid styles live.

v2.4-grid-axis-cache/
  Authentic GBC Fast's dedicated live-placement presets and shared grid caches.
  Also used by the Authentic presets in v2.4-integrated-grids/.

v2.4-live-grid/
  One Sunlight Shimmer preset with live grid-style and above/below selection.
  Retained as an option; it is slower than the dedicated-style presets on RPC.

See each folder's VALIDATION.txt for measured performance and image results.
Fixed placement variants remain in ../pixel_transparency/grid-before/ and
../pixel_transparency/grid-after/. The original v2.3 archive and other earlier
experiments remain available in their existing folders.

Retired routes
--------------
v2.4-append, v2.4-fused-authentic and v2.4-integrated-authentic were retired
on 2026-10-18. Their 19 presets and unused shader code were removed. Historical
benchmark and comparison notes are preserved in archive-notes/. Shared Authentic
controls were moved into the retained v2.4-grid-axis-cache shader folder.
