#version 450
// Copyright (C) 2025-2026 Matt Akins.
#define PT_ADAPTIVE_CACHE
#include "cached_common.inc"

#pragma stage fragment
void main() {
    vec3 original_pixel;
    float original_brightness;
    renderPixelTransparency(original_pixel, original_brightness);
}
