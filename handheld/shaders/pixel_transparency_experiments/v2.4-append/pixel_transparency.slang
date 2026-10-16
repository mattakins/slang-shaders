#version 450
// Copyright (C) 2025-2026 Matt Akins.
// Pixel Transparency v2.4: generic append compositor with bounded shadow cache.
#define PT_BOUNDED_CACHE
#define PT_ADAPTIVE_CACHE
#define PT_SHIFTED_SHADOW_CACHE
#define PT_VERTEX_SHADOW_OFFSET
#include "cached_common.inc"

#pragma stage fragment
void main() {
    vec3 original_pixel;
    float original_brightness;
    renderPixelTransparency(original_pixel, original_brightness);
}