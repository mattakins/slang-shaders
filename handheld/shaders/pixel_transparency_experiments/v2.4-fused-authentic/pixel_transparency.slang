#version 450
// Copyright (C) 2025-2026 Matt Akins.
// Optional Authentic GBC Fast grid fused into the cached compositor.
#define PT_ADAPTIVE_CACHE
#define PT_SHIFTED_SHADOW_CACHE
#define PT_VERTEX_SHADOW_OFFSET
#define PT_CUSTOM_LCD
#define PT_CUSTOM_FINAL_DITHER
#include "../v2.4-integrated-authentic/grid_controls.inc"
#pragma parameter PT_FUSED_LAYER "Grid placement (0=Below effects, 1=Above effects)" 0.0 0.0 1.0 1.0
#include "../../pixel_transparency/cached_common.inc"
#include "../v2.4-integrated-authentic/grid.inc"

#pragma stage fragment
void main() {
    vec3 original_pixel;
    float original_brightness;
    if (renderPixelTransparency(original_pixel, original_brightness)) {
        FragColor = finishLCD(FragColor);
        if (param.PT_DEFER_DITHER < 0.5)
            FragColor.rgb += (hash(floor(vTexCoord * param.OutputSize.xy) + vec2(0.5)) - 0.5) / 255.0;
    }
}
