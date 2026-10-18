#define PT_ADAPTIVE_CACHE
#define PT_SHIFTED_SHADOW_CACHE
#define PT_VERTEX_SHADOW_OFFSET
#define PT_CUSTOM_FINAL_DITHER
#define PT_CUSTOM_LCD
#include "parameters.inc"
#include "../../../pixel_transparency/cached_common.inc"
#include "vertex.inc"
#pragma stage fragment
#include "grid.inc"
#ifdef PT_LIGHT_FIELD
#include "../../../pixel_transparency/cached_sunlight.inc"
#endif
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
