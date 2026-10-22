#version 450
// Keep effects at viewport resolution until the LCD stage and final dither.
#pragma format R16G16B16A16_SFLOAT
#define PT_ADAPTIVE_CACHE
#define PT_SHIFTED_SHADOW_CACHE
#define PT_VERTEX_SHADOW_OFFSET
#define PT_CUSTOM_FINAL_DITHER
#define PT_LIGHT_FIELD
#include "../cached_common.inc"
#include "../cached_light_parameters.inc"

#pragma stage fragment
#include "../cached_sunlight.inc"
void main() {
    vec3 original_pixel;
    float original_brightness;
    bool enabled = renderPixelTransparency(original_pixel, original_brightness);
    if (enabled)
        FragColor = applyCachedSunlight(FragColor, original_pixel, original_brightness);
    // Preserve HDR highlights, but keep signed backing tint out of LCD gamma.
    FragColor.rgb = max(FragColor.rgb, vec3(0.0));
    // Alpha carries the dither flag to the final pass; it is not display alpha.
    FragColor.a = enabled ? 1.0 : 0.0;
}
