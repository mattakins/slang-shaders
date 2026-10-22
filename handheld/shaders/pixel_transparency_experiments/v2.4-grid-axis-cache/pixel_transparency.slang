#version 450
// Grid geometry stays in separate passes; preserve the final compositor's coordinates.
#define PT_ADAPTIVE_CACHE
#define PT_SHIFTED_SHADOW_CACHE
#define PT_VERTEX_SHADOW_OFFSET
#define PT_CUSTOM_FINAL_DITHER
#define PT_COMPOSITOR_UNIFORMS \
    float PT_FUSED_LAYER; \
    float PT_FUSED_STRENGTH; \
    float PT_FUSED_BIAS; \
    float PT_FUSED_BRIGHTNESS; \
    float PT_FUSED_RED; \
    float PT_FUSED_GREEN; \
    float PT_FUSED_BLUE;
#include "grid_parameters.inc"
#include "../v2.4-external-lcd/cached_common.inc"

#pragma stage fragment
#include "composite_grid.inc"
void main() {
    vec3 original_pixel;
    float original_brightness;
    bool effects_enabled = renderPixelTransparency(original_pixel, original_brightness);
    FragColor = finishGrid(FragColor);
    if (effects_enabled && param.PT_DEFER_DITHER < 0.5)
        FragColor.rgb += (hash(floor(vTexCoord * param.OutputSize.xy) + vec2(0.5)) - 0.5) / 255.0;
}
