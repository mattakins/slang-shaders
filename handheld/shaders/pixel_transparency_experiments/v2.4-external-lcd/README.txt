Pixel Transparency v2.4
======================

pixel_transparency.slang and sunlight_shimmer.slang are the production
compositors. Both use the source-sized moving shadow cache and vertex-stage
constant shadow offset from Adaptive RPC. Sunlight Shimmer applies cached
rainbow/glare inside the final compositor; LCD shaders remain separate.

Paired presets prepare shadows before the LCD chain, restore the exact native
input, and alias the final LCD stage as LCDInput. The compositor stays last
except in the existing front-surface preset, which retains its final surface
shader. Keep all cache, restore, alias, scale and filtering settings together.

shadow_cache.slang is the shared entry point for every paired preset and the
standalone append presets. shadow_cache.inc contains the cache algorithm.
No LCD-specific cache files or copied LCD parameter declarations are needed.
RetroArch discovers controls in pass order, so the shared transparency controls
appear before the LCD controls in paired presets. LCD rendering stays separate.

To append after another grid/LCD preset, load that preset, choose Append Preset,
and select handheld/pixel_transparency.slangp or handheld/sunlight_shimmer.slangp.
Append the complete preset rather than an individual compositor shader. These
generic append presets do not require LCD-specific files or parameter copies.

Standalone append presets use copy_lcd.slang to retain the current LCD image,
a fixed 1536x512 cache, and the *_append.slang compositors. The bounded lookup
uses the complete direct kernel when the original input exceeds the cache's
capacity. It never silently drops transparency or shadows on larger inputs.
This compatibility route has different memory/performance costs from paired
native-cache presets; use the paired route for the established Retroid profile.

v2.3 sources and all previous profile variants are frozen in the sibling
pixel_transparency_experiments/v2.3 directory. Their includes and preset paths
resolve to that archived program rather than these production helpers.
