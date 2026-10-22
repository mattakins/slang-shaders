// Copyright (C) 2025-2026 Matt Akins.
// The cache window includes every shifted source cell, even beyond screen edges.
#ifdef PT_BOUNDED_CACHE
#define PT_CACHE_BRIGHTNESS param.PT_BRIGHTNESS_MODE
#define PT_CACHE_BLUR param.PT_SHADOW_BLUR
#define PT_CACHE_SMOOTH param.PT_SHADOW_FAST_BLUR
#include "adaptive_shadow_kernel.inc"
#endif

float cachedShadow(vec2 center) {
    ivec2 size = ivec2(global.OriginalSize.xy);
    vec2 native = center * global.OriginalSize.xy;
#ifdef PT_BOUNDED_CACHE
    ivec2 capacity = textureSize(PixelShadowCache, 0);
    if (capacity.x < 3 * (size.x + 1) || capacity.y < size.y + 1) {
        vec2 radius = param.PT_SHADOW_BLUR > 0.1
            ? param.PT_SHADOW_BLUR * shadow_scale_factor * texel * vec2(size) : vec2(0.0);
        return adaptiveShadowKernel(native, radius, size);
    }
#endif
    ivec2 cell = clamp(ivec2(floor(native)) - shadow_origin, ivec2(0), size);
    vec2 position = fract(native);
    ivec2 phase = ivec2(greaterThanEqual(position, shadow_phase_low))
        + ivec2(greaterThanEqual(position, shadow_phase_high));
    vec4 values = texelFetch(PixelShadowCache, ivec2(3 * cell.x + phase.x, cell.y), 0);
    return values[phase.y];
}
