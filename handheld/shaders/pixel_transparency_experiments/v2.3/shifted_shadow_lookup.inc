// Copyright (C) 2025-2026 Matt Akins.
// The cache window includes every shifted source cell, even beyond screen edges.
float cachedShadow(vec2 center) {
    ivec2 size = ivec2(global.OriginalSize.xy);
    vec2 native = center * global.OriginalSize.xy;
    ivec2 cell = clamp(ivec2(floor(native)) - shadow_origin, ivec2(0), size);
    vec2 position = fract(native);
    ivec2 phase = ivec2(greaterThanEqual(position, shadow_phase_low))
        + ivec2(greaterThanEqual(position, shadow_phase_high));
    vec4 values = texelFetch(PixelShadowCache, ivec2(3 * cell.x + phase.x, cell.y), 0);
    return values[phase.y];
}
