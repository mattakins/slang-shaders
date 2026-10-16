#version 450
// Copyright (C) 2025-2026 Matt Akins.
#define PT_ADAPTIVE_CACHE
#define PT_SHIFTED_SHADOW_CACHE
#define PT_VERTEX_SHADOW_OFFSET
#define PT_LIGHT_FIELD
#include "cached_common.inc"
#include "cached_light_parameters.inc"

#pragma stage fragment
#include "cached_sunlight.inc"

// Match the original FP16 transparency target's observed truncation before
// sunlight, without restoring a separate full-resolution transparency pass.
vec2 originalTransparencyPrecision(vec2 value) {
    uint packed = packHalf2x16(value);
    vec2 rounded = unpackHalf2x16(packed);
    uvec2 halves = uvec2(packed & 65535u, packed >> 16u);
    halves -= uvec2(greaterThan(abs(rounded), abs(value)));
    return unpackHalf2x16(halves.x | (halves.y << 16u));
}

void main() {
    vec3 original_pixel;
    float original_brightness;
    if (renderPixelTransparency(original_pixel, original_brightness)) {
        FragColor = vec4(originalTransparencyPrecision(FragColor.rg),
                         originalTransparencyPrecision(FragColor.ba));
        FragColor = applyCachedSunlight(FragColor, original_pixel, original_brightness);
    }
}
