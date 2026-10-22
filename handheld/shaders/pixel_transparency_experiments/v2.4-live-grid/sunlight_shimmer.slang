#version 450
#define PT_MATRIX_RED 12
#define PT_MATRIX_GREEN 13
#define PT_MATRIX_BLUE 14
// Runtime grid selection shares the existing effects and Authentic coverage.
#define PT_ADAPTIVE_CACHE
#define PT_SHIFTED_SHADOW_CACHE
#define PT_VERTEX_SHADOW_OFFSET
#define PT_CUSTOM_FINAL_DITHER
#define PT_CUSTOM_LCD
#define PT_LIGHT_FIELD
#include "parameters.inc"
#include "../v2.4-external-lcd/cached_common.inc"
#include "../v2.4-external-lcd/cached_light_parameters.inc"
#include "matrix.inc"
#pragma stage vertex
void prepareLCD() { prepareGridMatrix(); }
#pragma stage fragment
#include "../v2.4-grid-axis-cache/composite_grid.inc"
#include "grid.inc"
#include "../v2.4-external-lcd/cached_sunlight.inc"
vec4 sampleLCD() { return texture(LCDInput, vTexCoord); }
void main() {
    vec3 original_pixel;
    float original_brightness;
    bool effects_enabled = renderPixelTransparency(original_pixel, original_brightness);
    if (effects_enabled)
        FragColor = applyCachedSunlight(FragColor, original_pixel, original_brightness);
    if (global.PT_GRID_STYLE < 0.5) {
        FragColor = finishGrid(FragColor);
    } else if (global.PT_FUSED_LAYER > 0.5) {
        FragColor.rgb = applyGrid(FragColor.rgb, vTexCoord, param.OutputSize.xy);
        if (global.PT_GRID_STYLE > 2.5 && global.PT_GRID_STYLE < 3.5)
            FragColor.a = 1.0;
    }
    if (effects_enabled)
        FragColor.rgb += (hash(floor(vTexCoord * param.OutputSize.xy) + vec2(0.5)) - 0.5) / 255.0;
}
