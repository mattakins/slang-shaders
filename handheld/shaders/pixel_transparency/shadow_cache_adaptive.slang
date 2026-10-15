#version 450
// Copyright (C) 2025-2026 Matt Akins.
// Size this first pass to three times the input width and one times its height.
// X packs horizontal phases; RGB stores vertical phases. No fixed-size border.
// Match the parameter ordering of the paired Authentic GBC presets.
#include "../authentic_gbc/parameters.inc"
#include "cached_parameters.inc"
#pragma name PixelShadowCache
#pragma format R32G32B32A32_SFLOAT

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    vec4 FinalViewportSize;
    float PT_BRIGHTNESS_MODE;
    float PT_SHADOW_EDGE_ENABLE;
    float PT_SHADOW_FAST_BLUR;
    float PT_SHADOW_BLUR;
} global;
layout(push_constant) uniform Push { vec4 OutputSize; } param;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Original;
#define PT_CACHE_BRIGHTNESS global.PT_BRIGHTNESS_MODE
#define PT_CACHE_BLUR global.PT_SHADOW_BLUR
#define PT_CACHE_SMOOTH global.PT_SHADOW_FAST_BLUR
#include "adaptive_shadow_kernel.inc"

void main() {
    ivec2 output_cell = ivec2(floor(vTexCoord * param.OutputSize.xy));
    int phase = output_cell.x % 3;
    ivec2 cell = ivec2(output_cell.x / 3, output_cell.y);
    ivec2 size = textureSize(Original, 0);
    float scale = sqrt((global.FinalViewportSize.x / 640.0)
        * (global.FinalViewportSize.y / 480.0));
    vec2 radius = global.PT_SHADOW_BLUR > 0.1
        ? global.PT_SHADOW_BLUR * scale * global.FinalViewportSize.zw * vec2(size)
        : vec2(0.0);
    if (global.PT_SHADOW_BLUR <= 0.1) {
        float value = adaptiveShadowCaster(cell, size);
        FragColor = vec4(value, value, value, 1.0);
        return;
    }
    if (all(lessThan(radius, vec2(0.499)))) {
        // Small kernels need only the current cell and its immediate neighbors.
        int side=phase-1;
        float middle=adaptiveShadowCaster(cell,size);
        float up=adaptiveShadowCaster(cell+ivec2(0,-1),size);
        float down=adaptiveShadowCaster(cell+ivec2(0,1),size);
        float other=adaptiveShadowCaster(cell+ivec2(side,0),size);
        if (global.PT_SHADOW_FAST_BLUR < 0.5) {
            float horizontal=6.0*middle+2.0*other;
            FragColor=vec4((horizontal+2.0*up+2.0*middle)/12.0,
                           (horizontal+4.0*middle)/12.0,
                           (horizontal+2.0*middle+2.0*down)/12.0,1.0);
        } else {
            float hmiddle=3.0*middle+other;
            float hup=3.0*up+adaptiveShadowCaster(cell+ivec2(side,-1),size);
            float hdown=3.0*down+adaptiveShadowCaster(cell+ivec2(side,1),size);
            FragColor=vec4((hup+3.0*hmiddle)/16.0,hmiddle/4.0,
                           (3.0*hmiddle+hdown)/16.0,1.0);
        }
        return;
    }
    vec2 fraction = fract(radius);
    vec2 low = min(fraction, vec2(1.0) - fraction);
    vec2 high = max(fraction, vec2(1.0) - fraction);
    float x = phase == 0 ? low.x * 0.5 : phase == 1 ? 0.5 : (high.x + 1.0) * 0.5;
    FragColor = vec4(
        adaptiveShadowKernel(vec2(cell) + vec2(x, low.y * 0.5), radius, size),
        adaptiveShadowKernel(vec2(cell) + vec2(x, 0.5), radius, size),
        adaptiveShadowKernel(vec2(cell) + vec2(x, (high.y + 1.0) * 0.5), radius, size), 1.0);
}
