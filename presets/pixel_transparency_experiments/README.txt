Pixel Transparency experiments
=============================

Production presets are in ../pixel_transparency/: six grid styles with the
grid built in and live Soft/Accurate placement. They were promoted from the
v2.4-integrated-grids experiment on 2026-10-21.

Retained grid experiments
-------------------------
v2.4-external-lcd/
  The former production pipeline: the original LCD shader as its own pass,
  fixed grid-before/ and grid-after/ placement sets, append presets for
  stacking on any LCD shader, and the former frontlit preset.

v2.4-grid-axis-cache/
  Authentic GBC Fast's dedicated live-placement presets and shared grid caches.
  The newer integrated presets own a separate copy of these grid helpers.

v2.4-live-grid/
  One Sunlight Shimmer preset with live grid-style and above/below selection.
  Retained as an option; it is slower than the dedicated-style presets on RPC.

See each folder's VALIDATION.txt for measured performance and image results.
Fixed placement variants remain in v2.4-external-lcd/grid-before/ and
v2.4-external-lcd/grid-after/. The original v2.3 archive and other earlier
experiments remain available in their existing folders.

Retired routes
--------------
v2.4-append, v2.4-fused-authentic and v2.4-integrated-authentic were retired
on 2026-10-18. Their 19 presets and unused shader code were removed. Historical
benchmark and comparison notes are preserved in archive-notes/. Shared Authentic
controls were moved into the retained v2.4-grid-axis-cache shader folder.
