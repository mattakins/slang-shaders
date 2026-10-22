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
void main() {
    vec3 original_pixel;
    float original_brightness;
    if (renderPixelTransparency(original_pixel, original_brightness))
        FragColor = applyCachedSunlight(FragColor, original_pixel, original_brightness);
}