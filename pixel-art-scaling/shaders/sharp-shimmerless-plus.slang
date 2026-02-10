#version 450

/*
 * sharp-shimmerless-plus
 *
 * A shimmer-free upscaler with tunable pixel edge sharpness.
 *
 * Combines the area-based pixel model from Sharp-Shimmerless (zadpos)
 * with geometric sharpening curves adapted from the Game Boy Dot Matrix
 * Shader (Harlequin/mattakins).
 *
 * Sharp-Shimmerless computes area-overlap weights linearly - correct but
 * can look soft at certain fractional scales. This shader passes those
 * weights through a sharpening curve (sigmoid or power) before the
 * hardware bilinear blend, pushing transitions toward binary while
 * remaining continuous — guaranteeing zero shimmer at any sharpness.
 *
 * Because the sharpening function is symmetric around 0.5, blend weights
 * always sum to 1.0, so brightness is preserved by construction — no
 * grey balance compensation needed.
 *
 * At SHARPNESS = 0: identical to Sharp-Shimmerless (linear area blend)
 * At SHARPNESS = 1: near point-sampling, still shimmer-free
 *
 * Based on:
 *   sharp-shimmerless by zadpos (Public domain)
 *   Slang optimizations by Hyllian (2025)
 *   Sharpening curve techniques from Game Boy Dot Matrix Shader v1.1
 *     by Harlequin/mattakins (GPL v3)
 *
 * Copyright (C) 2025 Matt Akins
 * License: GPL v3
 */

#pragma parameter SSP_SETTINGS "=== SHARP SHIMMERLESS PLUS ===" 0.0 0.0 1.0 1.0
#pragma parameter SHARPNESS    "     Sharpness (0=Shimmerless, 1=Near point)" 0.5 0.0 1.0 0.05
#pragma parameter CURVE_TYPE   "     Curve type (0=Sigmoid, 1=Power)" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 OutputSize;
    vec4 OriginalSize;
    vec4 SourceSize;
    uint FrameCount;
    float SHARPNESS;
    float CURVE_TYPE;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#define FIX(c) max(abs(c), 1e-5)

///////////////////////////////////////////////////////////////////////////
// Sharpening curves - symmetric around 0.5, map [0,1] -> [0,1]
// Both satisfy f(0)=0, f(1)=1, f(x)+f(1-x)=1 (weights sum to 1.0)
///////////////////////////////////////////////////////////////////////////

// Sigmoid: S-curve with parametric steepness k
// Produces a "digital" feel - flat at extremes, sharp transition zone
vec2 sigmoid_sharpen(vec2 x, float k) {
    vec2 s  = 1.0 / (1.0 + exp(-k * (x - 0.5)));
    float s0 = 1.0 / (1.0 + exp(k * 0.5));
    return (s - s0) / (1.0 - 2.0 * s0);
}

// Power: symmetric power curve with exponent p
// Produces smoother, more gradual transitions
vec2 power_sharpen(vec2 x, float p) {
    return mix(
        0.5 * pow(2.0 * x, vec2(p)),
        1.0 - 0.5 * pow(2.0 * (1.0 - x), vec2(p)),
        step(0.5, x)
    );
}

///////////////////////////////////////////////////////////////////////////
// Vertex shader - pre-calculate frame-constant scaling values
///////////////////////////////////////////////////////////////////////////

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 pixel;
layout(location = 1) out vec2 scale;
layout(location = 2) out vec2 invscale;

void main()
{
    gl_Position = global.MVP * Position;
    pixel    = TexCoord * params.OutputSize.xy * params.SourceSize.xy * params.OriginalSize.zw;
    scale    = params.OutputSize.xy * params.SourceSize.zw;
    invscale = 1.0 / scale;
}

///////////////////////////////////////////////////////////////////////////
// Fragment shader
///////////////////////////////////////////////////////////////////////////

#pragma stage fragment
layout(location = 0) in vec2 pixel;
layout(location = 1) in vec2 scale;
layout(location = 2) in vec2 invscale;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    // Output pixel edges in pixel-grid space
    vec4 pixel_borders = vec4(floor(pixel), ceil(pixel));

    // Which input texels those edges fall on
    vec4 texel_borders = floor(invscale.xyxy * pixel_borders);

    // Does this output pixel straddle a texel boundary?
    vec2 same_texel = step(FIX(0.0), abs(texel_borders.xy - texel_borders.zw));

    // Linear area-overlap weight: fraction of output pixel on the left/upper texel
    // In [0,1] when spanning a boundary, zeroed when entirely within one texel
    vec2 overlap = clamp((scale * texel_borders.zw - pixel_borders.xy), 0.0, 1.0) * same_texel;

    // Apply sharpening curve to the overlap weight
    vec2 sharp_overlap;
    if (params.SHARPNESS < 0.01) {
        // Pure linear - identical to original Sharp-Shimmerless
        sharp_overlap = overlap;
    } else if (params.CURVE_TYPE < 0.5) {
        // Sigmoid mode: k maps SHARPNESS [0,1] to steepness [0,20]
        sharp_overlap = sigmoid_sharpen(overlap, params.SHARPNESS * 20.0);
        sharp_overlap *= same_texel;
    } else {
        // Power mode: p maps SHARPNESS [0,1] to exponent [1,10]
        sharp_overlap = power_sharpen(overlap, 1.0 + params.SHARPNESS * 9.0);
        sharp_overlap *= same_texel;
    }

    // Encode sharpened weight as texture coordinate for hardware bilinear blend
    vec2 mod_texel = texel_borders.zw + 0.5 - sharp_overlap;

    FragColor = vec4(texture(Source, mod_texel * params.SourceSize.zw).rgb, 1.0);
}
