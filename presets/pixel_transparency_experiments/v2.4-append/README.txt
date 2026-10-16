Pixel Transparency v2.4 all-append experiment
============================================

Every preset here renders its existing LCD/grid chain first, then appends the
same generic Pixel Transparency sequence. The standalone/ entries can be
appended after another grid preset. No LCD-specific cache wrapper is used.
Reflective glass remains last in authentic-gbc-frontlit.slangp.

To test the primary Retroid profile, load:

  sunlight_shimmer-authentic_gbc_fast.slangp

To append after your own grid, load the grid and choose Append Preset with:

  standalone/pixel_transparency.slangp
  standalone/sunlight_shimmer.slangp

Current standard presets and shaders remain unchanged. This candidate keeps
their control IDs, order, defaults and explicit overrides. It uses the same
rendering calculations as the existing generic append route.

The append sequence adds three passes for transparency or five for Shimmer.
With Authentic GBC Fast this is still five/seven passes total. The native-cache
route copies a small native image before the LCD; this route copies the LCD's
full-resolution result and allocates a fixed 1536x512 shadow target. Its RPC
performance has not been measured. Prior 60+ FPS results apply to the standard
native-cache profile, not this experiment.

Mac saved-frame checks match the current pipeline exactly for Authentic GBC
Fast, lcd1x, lcd3x and lcd-grid-v2 on both GB/GBA inputs. Simpletex, zfast and
frontlit differ. The frontlit feedback shader reads PassFeedback0; moving it
back to the first pass changes that binding from the native shadow-cache
feedback to its own feedback. Review these differences before promotion.
See VALIDATION.txt for the test scope and limitations.
