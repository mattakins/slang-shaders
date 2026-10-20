// Final-pass entry logic for Authentic's Pixel Transparency and Sunlight
// Shimmer presets. Grid geometry stays in separate passes; preserve the final
// compositor's coordinates.
#define PT_ADAPTIVE_CACHE
#define PT_SHIFTED_SHADOW_CACHE
#define PT_VERTEX_SHADOW_OFFSET
#define PT_CUSTOM_FINAL_DITHER
#define PT_COMPOSITOR_UNIFORMS \
    float PT_FUSED_LAYER; \
    float PT_FUSED_STRENGTH; \
    float PT_FUSED_BRIGHTNESS;
#include "parameters.inc"
#include "../../pixel_transparency.inc"

#pragma stage fragment
#include "composite_grid.inc"
#ifdef PT_LIGHT_FIELD
#include "../../sunlight_shimmer.inc"
#endif
void main() {
    vec3 original_pixel;
    float original_brightness;
    bool effects_enabled = renderPixelTransparency(original_pixel, original_brightness);
#ifdef PT_LIGHT_FIELD
    // Sunlight places the grid between the rainbow and the front-surface glare.
    FragColor = applyCachedSunlight(FragColor, original_pixel, original_brightness, effects_enabled);
    if (effects_enabled)
#else
    FragColor = finishGrid(FragColor);
    if (effects_enabled && param.PT_DEFER_DITHER < 0.5)
#endif
        FragColor.rgb += (hash(floor(vTexCoord * param.OutputSize.xy) + vec2(0.5)) - 0.5) / 255.0;
}
