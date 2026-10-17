#version 450
// Keep effects at viewport resolution until the LCD stage and final dither.
#pragma format R16G16B16A16_SFLOAT
#define PT_ADAPTIVE_CACHE
#define PT_SHIFTED_SHADOW_CACHE
#define PT_VERTEX_SHADOW_OFFSET
#define PT_CUSTOM_FINAL_DITHER
#include "../cached_common.inc"

#pragma stage fragment
void main() {
    vec3 original_pixel;
    float original_brightness;
    bool enabled = renderPixelTransparency(original_pixel, original_brightness);
    // Alpha carries the dither flag to the final pass; it is not display alpha.
    FragColor.a = (enabled && param.PT_DEFER_DITHER < 0.5) ? 1.0 : 0.0;
}
