#version 450

/*
 * sharp-shimmerless-plus
 *
 * A shimmer-free upscaler with tunable pixel edge sharpness and an
 * optional area-correct pixel grid overlay.
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
 * The pixel grid uses the same area-intersection technique as the GB dot
 * matrix shader: exact sub-pixel coverage of grid lines is computed per
 * output pixel, producing smooth anti-aliased grid lines with no moiré
 * at fractional scales. Grid coverage is intentionally kept at linear
 * area-weighting (no sharpening curve applied) to maximize moiré
 * suppression.
 *
 * At SHARPNESS = 0: identical to Sharp-Shimmerless (linear area blend)
 * At SHARPNESS = 1: near point-sampling, still shimmer-free
 *
 * Based on:
 *   sharp-shimmerless by zadpos (Public domain)
 *   Slang optimizations by Hyllian (2025)
 *   Sharpening curve & area-intersection techniques from
 *     Game Boy Dot Matrix Shader v1.1 by Harlequin/mattakins (GPL v3)
 *
 * Copyright (C) 2025 Matt Akins
 * License: GPL v3
 */

#pragma parameter SSP_SETTINGS   "=== SHARP SHIMMERLESS PLUS ===" 0.0 0.0 1.0 1.0
#pragma parameter SHARPNESS      "     Sharpness (0=Shimmerless, 1=Near point)" 0.5 0.0 1.0 0.05
#pragma parameter CURVE_TYPE     "     Curve type (0=Sigmoid, 1=Power)" 0.0 0.0 1.0 1.0
#pragma parameter SSP_GRID_HDR   "     --- Pixel Grid ---" 0.0 0.0 1.0 1.0
#pragma parameter GRID_ENABLE    "     Enable pixel grid" 0.0 0.0 1.0 1.0
#pragma parameter GRID_WIDTH     "     Grid line width" 0.1 0.01 0.5 0.01
#pragma parameter GRID_INTENSITY "     Grid intensity" 0.5 0.0 1.0 0.05
#pragma parameter GRID_BRIGHT    "     Grid brightness" 0.5 0.0 1.0 0.05
#pragma parameter SSP_MOIRE_HDR  "     --- Moiré Reduction ---" 0.0 0.0 1.0 1.0
#pragma parameter MOIRE_ADAPT    "     Adaptive softness (reduces moiré)" 0.0 0.0 1.0 1.0
#pragma parameter PERCEPTUAL_BLEND "     Perceptual blend (reduces dark moiré)" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push
{
    vec4 OutputSize;
    vec4 OriginalSize;
    vec4 SourceSize;
    uint FrameCount;
    float SHARPNESS;
    float CURVE_TYPE;
    float SSP_GRID_HDR;
    float GRID_ENABLE;
    float GRID_WIDTH;
    float GRID_INTENSITY;
    float GRID_BRIGHT;
    float SSP_MOIRE_HDR;
    float MOIRE_ADAPT;
    float PERCEPTUAL_BLEND;
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
layout(location = 3) out vec2 grid_tc;

void main()
{
    gl_Position = global.MVP * Position;
    pixel    = TexCoord * params.OutputSize.xy * params.SourceSize.xy * params.OriginalSize.zw;
    scale    = params.OutputSize.xy * params.SourceSize.zw;
    invscale = 1.0 / scale;

    // Texel-space position for grid (uses OriginalSize so the grid
    // aligns with the game's native pixel grid in multi-pass setups)
    grid_tc = TexCoord * params.OriginalSize.xy;
}

///////////////////////////////////////////////////////////////////////////
// Fragment shader
///////////////////////////////////////////////////////////////////////////

#pragma stage fragment
layout(location = 0) in vec2 pixel;
layout(location = 1) in vec2 scale;
layout(location = 2) in vec2 invscale;
layout(location = 3) in vec2 grid_tc;
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

    // Adaptive softness: reduce sharpness at fractional scales to suppress moiré
    float sharpness = params.SHARPNESS;
    if (params.MOIRE_ADAPT > 0.5) {
        vec2 fract_scale = fract(scale);
        // 0 at integer scales, 0.5 at worst fractional (x.5)
        float fract_factor = max(
            0.5 - abs(fract_scale.x - 0.5),
            0.5 - abs(fract_scale.y - 0.5)
        );
        // Reduce sharpness proportionally to fractional severity
        sharpness *= (1.0 - fract_factor);
    }

    // Apply sharpening curve to the overlap weight
    vec2 sharp_overlap;
    if (sharpness < 0.01) {
        // Pure linear - identical to original Sharp-Shimmerless
        sharp_overlap = overlap;
    } else if (params.CURVE_TYPE < 0.5) {
        // Sigmoid mode: k maps sharpness [0,1] to steepness [0,20]
        sharp_overlap = sigmoid_sharpen(overlap, sharpness * 20.0);
        sharp_overlap *= same_texel;
    } else {
        // Power mode: p maps sharpness [0,1] to exponent [1,10]
        sharp_overlap = power_sharpen(overlap, 1.0 + sharpness * 9.0);
        sharp_overlap *= same_texel;
    }

    // Encode sharpened weight as texture coordinate for hardware bilinear blend
    vec2 mod_texel = texel_borders.zw + 0.5 - sharp_overlap;

    FragColor = vec4(texture(Source, mod_texel * params.SourceSize.zw).rgb, 1.0);

    ///////////////////////////////////////////////////////////////////
    // Pixel grid overlay (area-correct, no sharpening to minimize moiré)
    //
    // Uses the same line-segment intersection technique as the GB dot
    // matrix shader: computes exact sub-pixel coverage of grid lines
    // for each output pixel. Because coverage varies smoothly across
    // output pixels, grid brightness changes gradually — no moiré
    // beating pattern even at fractional scales.
    //
    // Grid coverage is kept at LINEAR area-weighting intentionally.
    // Applying the sharpening curve to grid coverage would amplify
    // small coverage differences between adjacent output pixels,
    // reintroducing the moiré we're trying to suppress.
    ///////////////////////////////////////////////////////////////////

    if (params.GRID_ENABLE > 0.5)
    {
        // Fractional position within the original texel [0, 1)
        vec2 tc_frac = fract(grid_tc);

        // Signed distance from output pixel center to nearest texel boundary
        // Maps [0,1) -> [-0.5, 0.5): 0 = exactly on boundary
        vec2 s = tc_frac - step(0.5, tc_frac);

        // Output pixel half-width in original texel space
        vec2 ph = 0.5 * params.OriginalSize.xy * params.OutputSize.zw;

        // Grid line half-width in texel space
        vec2 gh = vec2(params.GRID_WIDTH * 0.5);

        // 1D line-segment intersection per axis:
        // output pixel extent [s-ph, s+ph] vs grid line extent [-gh, gh]
        vec2 cov_lo = max(s - ph, -gh);
        vec2 cov_hi = min(s + ph,  gh);
        vec2 grid_1d = clamp((cov_hi - cov_lo) / (2.0 * ph), 0.0, 1.0);

        // 2D: union of horizontal and vertical grid lines
        float grid_cov = grid_1d.x + grid_1d.y - grid_1d.x * grid_1d.y;

        // Blend grid color over texel color
        if (params.PERCEPTUAL_BLEND > 0.5) {
            // Linearize before blending to equalize moiré visibility across brightness
            vec3 linear_color = pow(FragColor.rgb, vec3(2.2));
            vec3 linear_grid  = pow(vec3(params.GRID_BRIGHT), vec3(2.2));
            FragColor.rgb = pow(mix(linear_color, linear_grid, grid_cov * params.GRID_INTENSITY), vec3(1.0 / 2.2));
        } else {
            FragColor.rgb = mix(FragColor.rgb, vec3(params.GRID_BRIGHT), grid_cov * params.GRID_INTENSITY);
        }
    }
}
