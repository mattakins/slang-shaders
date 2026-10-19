/*
  ____  _          _
 |  _ \(_)_  _____| |
 | |_) | \ \/ / _ \ |
 |  __/| |>  <  __/ |
 |_|___|_/_/\_\___|_|
 |_   _| __ __ _ _ __  ___ _ __   __ _ _ __ ___ _ __   ___ _   _
   | || '__/ _` | '_ \/ __| '_ \ / _` | '__/ _ \ '_ \ / __| | | |
   | || | | (_| | | | \__ \ |_) | (_| | | |  __/ | | | (__| |_| |
   |_||_|  \__,_|_| |_|___/ .__/ \__,_|_|  \___|_| |_|\___|\__, |
                          |_|                               |___/

    PT | FINAL COMPOSITOR
    v2.4 integrated grid pipeline

    Final-pass entry logic for the five non-Authentic grid families.
    Combines transparency, optional sunlight, Above placement and final dither.
*/

#define PT_ADAPTIVE_CACHE
#define PT_SHIFTED_SHADOW_CACHE
#define PT_VERTEX_SHADOW_OFFSET
#define PT_CUSTOM_FINAL_DITHER
#define PT_CUSTOM_LCD
#include "pt-grid-parameters.inc"
#include "pixel_transparency.inc"
#include "pt-grid.inc"
#pragma stage fragment

#ifdef PT_LIGHT_FIELD
#include "sunlight_shimmer.inc"
#endif
vec4 sampleLCD() { return texture(LCDInput, vTexCoord); }
void main() {
    vec3 original_pixel;
    float original_brightness;
    bool effects_enabled = renderPixelTransparency(original_pixel, original_brightness);
    // Like the real screen, the grid sits over the paper and shadows but under
    // the front glare and rainbow films, so it is applied before Sunlight.
    if (global.PT_FUSED_LAYER > 0.5) {
        // Gamma-based grids require nonnegative display colour.
        FragColor.rgb = applyGrid(max(FragColor.rgb, vec3(0.0)), vTexCoord, param.OutputSize.xy);
#ifdef PT_GRID_LCD_GRID_V2
        FragColor.a = 1.0;
#endif
    }
#ifdef PT_LIGHT_FIELD
    if (effects_enabled)
        FragColor = applyCachedSunlight(FragColor, original_pixel, original_brightness);
#endif
#ifdef PT_LIGHT_FIELD
    if (effects_enabled)
#else
    if (effects_enabled && param.PT_DEFER_DITHER < 0.5)
#endif
        FragColor.rgb += (hash(floor(vTexCoord * param.OutputSize.xy) + vec2(0.5)) - 0.5) / 255.0;
}
