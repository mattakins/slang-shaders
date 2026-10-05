#version 450

// Grid overlay version of authentic_gbc_fast.
// Samples Original (game texture) at pixel centers for proper color weighting,
// while allowing a pregrid pass to provide PT effects via after_grid mixing.
//
// Unlike the non-overlay version, this shader is designed for 3-pass pipelines:
//   before_grid (PT effects) → this shader (grid) → after_grid (mixing + rainbow)
// The after_grid pass mixes this output with the PT-processed pregrid output.

#include "../authentic_gbc/parameters.inc"
#include "../authentic_gbc/shared.inc"

layout(push_constant) uniform Push {
    vec4 OriginalSize;
    vec4 OutputSize;
    uint Rotation;
    float AUTH_GBC_BRIG;
    float AUTH_GBC_BLUR;
    float AUTH_GBC_SUBPX;
    float AUTH_GBC_SUBPX_ORIENTATION;
}
param;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; }
global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec4 lcd_subpx_rect1;
layout(location = 1) out vec4 lcd_subpx_rect2;
layout(location = 2) out vec2 subpx_offset_in_px;
layout(location = 3) out vec2 tx_coord;
layout(location = 4) out vec2 tx_to_px;
layout(location = 5) out vec2 tx_orig_offs;
layout(location = 6) out float half_px_size;

void main() {
    gl_Position = global.MVP * Position;

    calculate_lcd_params(param.OriginalSize.xy, param.OutputSize.xy, param.Rotation,
                         param.AUTH_GBC_SUBPX, uint(param.AUTH_GBC_SUBPX_ORIENTATION),
                         param.AUTH_GBC_BRIG, TexCoord, lcd_subpx_rect1, lcd_subpx_rect2,
                         subpx_offset_in_px, tx_coord, tx_to_px, tx_orig_offs);

    float eff_blur_in_px = 0.7 * param.AUTH_GBC_BLUR * min(tx_to_px.x, tx_to_px.y) * 0.5;
    half_px_size = 0.5 * clamp(1.0 + eff_blur_in_px, 1.0, min(tx_to_px.x, tx_to_px.y));
}

#pragma stage fragment
layout(location = 0) in vec4 lcd_subpx_rect1;
layout(location = 1) in vec4 lcd_subpx_rect2;
layout(location = 2) in vec2 subpx_offset_in_px;
layout(location = 3) in vec2 tx_coord;
layout(location = 4) in vec2 tx_to_px;
layout(location = 5) in vec2 tx_orig_offs;
layout(location = 6) in float half_px_size;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D Original;

// Batched rect-rect intersection (v2 approach — 6 vec4 ops replace 24 scalar ones): computes 4 intersection areas at once.
vec4 batch_rect_area(float px_xlo, float px_ylo, float px_xhi, float px_yhi,
                     vec4 orig_x, vec4 orig_y, vec4 rect) {
    vec4 bl_x = max(vec4(px_xlo), orig_x + rect.xxxx);
    vec4 bl_y = max(vec4(px_ylo), orig_y + rect.yyyy);
    vec4 tr_x = min(vec4(px_xhi), orig_x + rect.zzzz);
    vec4 tr_y = min(vec4(px_yhi), orig_y + rect.wwww);
    return max(tr_x - bl_x, vec4(0.0)) * max(tr_y - bl_y, vec4(0.0));
}

// Specialized for rect1 where .xy = (0,0): skips 2 vec4 additions.
vec4 batch_rect_area_r1(float px_xlo, float px_ylo, float px_xhi, float px_yhi,
                        vec4 orig_x, vec4 orig_y, vec4 rect) {
    vec4 bl_x = max(vec4(px_xlo), orig_x);
    vec4 bl_y = max(vec4(px_ylo), orig_y);
    vec4 tr_x = min(vec4(px_xhi), orig_x + rect.zzzz);
    vec4 tr_y = min(vec4(px_yhi), orig_y + rect.wwww);
    return max(tr_x - bl_x, vec4(0.0)) * max(tr_y - bl_y, vec4(0.0));
}

void main() {
    // Figure out four nearest texels and sample them from Original (game texture).
    vec2 tx_coord_i;
    const vec2 tx_coord_f = modf(tx_coord, tx_coord_i);
    const vec2 tx_coord_off = step(vec2(0.5), tx_coord_f) * 2.0 - 1.0;
    const vec2 tx_coord_offs[] = {vec2(0.0), vec2(tx_coord_off.x, 0.0), vec2(0.0, tx_coord_off.y),
                                  tx_coord_off};

    // Sample 4 game pixels from Original at pixel centers
    vec3 samples[] = {
        texture(Original, (tx_coord_i + tx_coord_offs[0] + 0.5) * param.OriginalSize.zw).rgb,
        texture(Original, (tx_coord_i + tx_coord_offs[1] + 0.5) * param.OriginalSize.zw).rgb,
        texture(Original, (tx_coord_i + tx_coord_offs[2] + 0.5) * param.OriginalSize.zw).rgb,
        texture(Original, (tx_coord_i + tx_coord_offs[3] + 0.5) * param.OriginalSize.zw).rgb};

    const float norm = 4.0 * half_px_size * half_px_size;

    // Precompute px_square corners
    float r_xlo = -subpx_offset_in_px.x - half_px_size;
    float r_ylo = -subpx_offset_in_px.y - half_px_size;
    float r_xhi = -subpx_offset_in_px.x + half_px_size;
    float r_yhi = -subpx_offset_in_px.y + half_px_size;
    float g_xlo = -half_px_size;
    float g_ylo = -half_px_size;
    float g_xhi =  half_px_size;
    float g_yhi =  half_px_size;
    float b_xlo =  subpx_offset_in_px.x - half_px_size;
    float b_ylo =  subpx_offset_in_px.y - half_px_size;
    float b_xhi =  subpx_offset_in_px.x + half_px_size;
    float b_yhi =  subpx_offset_in_px.y + half_px_size;

    // Pack 4 texel origins into vec4s
    vec4 base_x = (vec4(0.0, tx_coord_off.x, 0.0, tx_coord_off.x) - tx_coord_f.x) * tx_to_px.x;
    vec4 base_y = (vec4(0.0, 0.0, tx_coord_off.y, tx_coord_off.y) - tx_coord_f.y) * tx_to_px.y;
    vec4 orig_y   = base_y + tx_orig_offs.y;
    vec4 orig_g_x = base_x + tx_orig_offs.x;
    float subpx_third = tx_to_px.x / 3.0;
    vec4 orig_r_x = orig_g_x - subpx_third;
    vec4 orig_b_x = orig_g_x + subpx_third;

    // 6 batched vec4 intersections for coverage calculation
    vec4 cov_r = batch_rect_area_r1(r_xlo, r_ylo, r_xhi, r_yhi, orig_r_x, orig_y, lcd_subpx_rect1)
               + batch_rect_area(r_xlo, r_ylo, r_xhi, r_yhi, orig_r_x, orig_y, lcd_subpx_rect2);
    vec4 cov_g = batch_rect_area_r1(g_xlo, g_ylo, g_xhi, g_yhi, orig_g_x, orig_y, lcd_subpx_rect1)
               + batch_rect_area(g_xlo, g_ylo, g_xhi, g_yhi, orig_g_x, orig_y, lcd_subpx_rect2);
    vec4 cov_b = batch_rect_area_r1(b_xlo, b_ylo, b_xhi, b_yhi, orig_b_x, orig_y, lcd_subpx_rect1)
               + batch_rect_area(b_xlo, b_ylo, b_xhi, b_yhi, orig_b_x, orig_y, lcd_subpx_rect2);

    // Weight each texel's color channels by their coverage
    // No sqrt() here - we're operating in sRGB space, not linear.
    // The after_grid pass will extract the grid factor and apply to PT output.
    vec3 res = vec3(
        dot(cov_r, vec4(samples[0].r, samples[1].r, samples[2].r, samples[3].r)),
        dot(cov_g, vec4(samples[0].g, samples[1].g, samples[2].g, samples[3].g)),
        dot(cov_b, vec4(samples[0].b, samples[1].b, samples[2].b, samples[3].b))
    ) / norm;

    FragColor = vec4(res, 1.0);
}
