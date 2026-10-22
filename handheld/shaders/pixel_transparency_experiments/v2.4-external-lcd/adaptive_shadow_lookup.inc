// Copyright (C) 2025-2026 Matt Akins.
#define PT_CACHE_BRIGHTNESS param.PT_BRIGHTNESS_MODE
#define PT_CACHE_BLUR param.PT_SHADOW_BLUR
#define PT_CACHE_SMOOTH param.PT_SHADOW_FAST_BLUR
#include "adaptive_shadow_kernel.inc"

float cachedShadow(vec2 center) {
    ivec2 size = textureSize(Original, 0);
    vec2 native = center * vec2(size);
    ivec2 cell = ivec2(floor(native));
    vec2 radius = param.PT_SHADOW_BLUR > 0.1
        ? param.PT_SHADOW_BLUR * shadow_scale_factor * texel * vec2(size) : vec2(0.0);

    // Outside cells still need the full kernel: blur can reach back into the image.
    if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, size)))
        return adaptiveShadowKernel(native, radius, size);

    vec2 fraction = fract(radius);
    vec2 low = min(fraction, vec2(1.0) - fraction);
    vec2 high = max(fraction, vec2(1.0) - fraction);
    vec2 position = fract(native);
    ivec2 phase = ivec2(greaterThanEqual(position, low))
        + ivec2(greaterThanEqual(position, high));
    vec4 values = texelFetch(PixelShadowCache, ivec2(3 * cell.x + phase.x, cell.y), 0);
    return values[phase.y];
}
