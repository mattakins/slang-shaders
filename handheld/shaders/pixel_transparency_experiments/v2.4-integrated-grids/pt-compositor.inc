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
#define PT_GRID_TRANSPARENT_LINES
#define PT_CUSTOM_LCD
#include "pt-grid-parameters.inc"
#include "pixel_transparency.inc"
#include "pt-grid.inc"
#pragma stage fragment

#ifdef PT_LIGHT_FIELD
#include "sunlight_shimmer.inc"
#endif
vec3 applyPaperGridBelow(vec4 color) {
#ifdef PT_GRID_LCD_GRID_V2
    vec4 left, right, vertical;
    gridWeights(vTexCoord, left, right, vertical);
    vec3 gaps = clamp(vec3(1.0) - (left.rgb + right.rgb) * (vertical.x + vertical.y), 0.0, 1.0);
    vec3 line = paperGridLine(vec3(global.PT_FUSED_BRIGHTNESS));
    // Fill the gaps after colour reconstruction. Do not run
    // the LCD gamma or subpixel colour matrix over the game a second time.
    vec3 linear = pow(max(color.rgb, vec3(0.0)), vec3(2.2));
    linear += pow(line, vec3(2.2)) * gaps;
    return pow(max(linear, vec3(0.0)), vec3(1.0 / 2.2));
#else
    return applyGrid(color.rgb, vTexCoord, param.OutputSize.xy);
#endif
}
vec4 sampleLCD() { return texture(LCDInput, vTexCoord); }
void main() {
    vec3 original_pixel;
    float original_brightness;
    bool effects_enabled = renderPixelTransparency(original_pixel, original_brightness);
#ifdef PT_LIGHT_FIELD
    if (effects_enabled)
        FragColor = applyCachedSunlight(FragColor, original_pixel, original_brightness);
#endif
    if (global.PT_FUSED_LAYER > 0.5) {
        FragColor.rgb = applyGrid(FragColor.rgb, vTexCoord, param.OutputSize.xy);
#ifdef PT_GRID_LCD_GRID_V2
        FragColor.a = 1.0;
#endif
    }
#ifdef PT_LIGHT_FIELD
    if (effects_enabled)
#else
    if (effects_enabled && param.PT_DEFER_DITHER < 0.5)
#endif
        FragColor.rgb += (hash(floor(vTexCoord * param.OutputSize.xy) + vec2(0.5)) - 0.5) / 255.0;
}
