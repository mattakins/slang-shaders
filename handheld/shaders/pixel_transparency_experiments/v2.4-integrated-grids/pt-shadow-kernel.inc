/*
  ____  _          _
 |  _ \(_)_  _____| |
 | |_) | \ \/ / _ \ |
 |  __/| |>  <  __/ |
 |_|___|_/_/\_\___|_|
 |_   _| __ __ _ _ __  ___ _ __   __ _ _ __ ___ _ __   ___ _   _
   | || '__/ _` | '_ \/ __| '_ \ / _` | '__/ _ \ '_ \ / __| | | |
   | || | | (_| | | | \__ \ |_) | (_| | | |  __/ | | | (__| |_| |
   |_||_|  \__,_|_| |_|___/ .__/ \__,_|_|  \___|_| |_|\___|\__, |
                          |_|                               |___/

    PT | SHADOW KERNEL
    v2.4 integrated grid pipeline

    Shared nearest-filtered shadow kernel for the cache and compositor fallbacks.
*/

// Copyright (C) 2025-2026 Matt Akins.
// Shared nearest-filtered kernel for cached cells and samples outside the image.
float adaptiveShadowCaster(ivec2 cell, ivec2 size) {
    if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, size)))
        return global.PT_SHADOW_EDGE_ENABLE > 0.5 ? 1.0 : 0.0;
    vec3 color = texelFetch(Original, cell, 0).rgb;
    float brightness = PT_CACHE_BRIGHTNESS < 0.5
        ? (color.r + color.g + color.b) / 3.0
        : (0.2126 * color.r) + (0.7152 * color.g) + (0.0722 * color.b);
    return 1.0 - brightness;
}

float adaptiveShadowKernel(vec2 native, vec2 radius, ivec2 size) {
    if (PT_CACHE_BLUR <= 0.1)
        return adaptiveShadowCaster(ivec2(floor(native)), size);
    float value = adaptiveShadowCaster(ivec2(floor(native)), size) * 4.0;
    value += adaptiveShadowCaster(ivec2(floor(native - vec2(radius.x, 0.0))), size) * 2.0;
    value += adaptiveShadowCaster(ivec2(floor(native + vec2(radius.x, 0.0))), size) * 2.0;
    value += adaptiveShadowCaster(ivec2(floor(native - vec2(0.0, radius.y))), size) * 2.0;
    value += adaptiveShadowCaster(ivec2(floor(native + vec2(0.0, radius.y))), size) * 2.0;
    if (PT_CACHE_SMOOTH < 0.5) return value / 12.0;
    value += adaptiveShadowCaster(ivec2(floor(native - radius)), size);
    value += adaptiveShadowCaster(ivec2(floor(native + vec2(radius.x, -radius.y))), size);
    value += adaptiveShadowCaster(ivec2(floor(native + vec2(-radius.x, radius.y))), size);
    value += adaptiveShadowCaster(ivec2(floor(native + radius)), size);
    return value / 16.0;
}
