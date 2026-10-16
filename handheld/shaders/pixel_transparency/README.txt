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

shadow_cache.inc contains the cache algorithm. The shadow_cache_<lcd>.slang
entry points preload the selected LCD's parameter declarations because
RetroArch reflects this pass before compiling the LCD chain. Keep those
metadata declarations consistent with the LCD sources when updating them;
they preserve the existing control order without modifying the LCD shaders.
shadow_cache.slang declares only the shared transparency controls. The LCD
wrappers preserve the paired presets' control order; rendering does not require
one wrapper per LCD.

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
