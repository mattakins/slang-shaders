// Authentic GBC by fishku, Copyright (C) 2024-2025, CC0.
// Coverage adapted from authentic_gbc_fast.slang for reusable grid stages.
// Keep the standalone LCD shader and its native colour-conversion pass intact.

#pragma stage vertex
#include "../../authentic_gbc/shared.inc"
// Four packed locations keep this renderer within 16 varying locations,
// including the shared compositor's light and shadow coordinates.
layout(location = 12) out vec4 lcd_subpx_rect1;
layout(location = 13) out vec4 lcd_subpx_rect2;
layout(location = 14) out vec4 lcd_geometry;
layout(location = 15) out vec3 lcd_coord;

void prepareLCD() {
    vec2 subpx_offset, tx_coord, tx_to_px, tx_orig_offs;
    calculate_lcd_params(global.OriginalSize.xy, param.OutputSize.xy, global.Rotation,
                         global.AUTH_GBC_SUBPX, uint(global.AUTH_GBC_SUBPX_ORIENTATION),
                         global.AUTH_GBC_BRIG, TexCoord, lcd_subpx_rect1, lcd_subpx_rect2,
                         subpx_offset, tx_coord, tx_to_px, tx_orig_offs);
    float eff_blur = 0.7 * global.AUTH_GBC_BLUR * min(tx_to_px.x, tx_to_px.y) * 0.5;
    float half_px = 0.5 * clamp(1.0 + eff_blur, 1.0, min(tx_to_px.x, tx_to_px.y));
    lcd_geometry = vec4(subpx_offset, tx_orig_offs);
    lcd_coord = vec3(tx_coord, half_px);
}

#pragma stage fragment
layout(location = 12) in vec4 lcd_subpx_rect1;
layout(location = 13) in vec4 lcd_subpx_rect2;
layout(location = 14) in vec4 lcd_geometry;
layout(location = 15) in vec3 lcd_coord;

vec3 lcd_coverage;
vec3 lcd_line_color;

vec3 overlap(vec3 lo, vec3 hi, vec3 origin, float start, float end) {
    return max(min(hi, origin + end) - max(lo, origin + start), vec3(0.0));
}

void horizontal_coverage(float origin, vec2 tx_to_px, out vec3 first, out vec3 second) {
    vec3 offset = vec3(-lcd_geometry.x, 0.0, lcd_geometry.x);
    vec3 subpixel = vec3(origin) + vec3(lcd_geometry.z - tx_to_px.x / 3.0,
                                       lcd_geometry.z,
                                       lcd_geometry.z + tx_to_px.x / 3.0);
    first = overlap(offset - lcd_coord.z, offset + lcd_coord.z, subpixel,
                    lcd_subpx_rect1.x, lcd_subpx_rect1.z);
    second = overlap(offset - lcd_coord.z, offset + lcd_coord.z, subpixel,
                     lcd_subpx_rect2.x, lcd_subpx_rect2.z);
}

void vertical_coverage(float origin, out vec3 first, out vec3 second) {
    float subpixel = origin + lcd_geometry.w;
    if (lcd_geometry.y == 0.0) {
        first = vec3(max(min(lcd_coord.z, subpixel + lcd_subpx_rect1.w) -
                         max(-lcd_coord.z, subpixel + lcd_subpx_rect1.y), 0.0));
        second = vec3(max(min(lcd_coord.z, subpixel + lcd_subpx_rect2.w) -
                          max(-lcd_coord.z, subpixel + lcd_subpx_rect2.y), 0.0));
    } else {
        vec3 offset = vec3(-lcd_geometry.y, 0.0, lcd_geometry.y);
        first = overlap(offset - lcd_coord.z, offset + lcd_coord.z, vec3(subpixel),
                        lcd_subpx_rect1.y, lcd_subpx_rect1.w);
        second = overlap(offset - lcd_coord.z, offset + lcd_coord.z, vec3(subpixel),
                         lcd_subpx_rect2.y, lcd_subpx_rect2.w);
    }
}

void lcdWeights(out ivec2 cell, out ivec2 offset, out vec3 w0, out vec3 w1,
                out vec3 w2, out vec3 w3, out float area) {
    vec2 tx_coord_i;
    vec2 tx_coord_f = modf(lcd_coord.xy, tx_coord_i);
    vec2 tx_coord_off = step(vec2(0.5), tx_coord_f) * 2.0 - 1.0;
    cell = ivec2(tx_coord_i);
    offset = ivec2(tx_coord_off);
    vec2 tx_to_px = param.OutputSize.xy / global.OriginalSize.xy;
    vec3 x0_first, x0_second, x1_first, x1_second;
    vec3 y0_first, y0_second, y1_first, y1_second;
    horizontal_coverage(-tx_coord_f.x * tx_to_px.x, tx_to_px, x0_first, x0_second);
    horizontal_coverage((tx_coord_off.x - tx_coord_f.x) * tx_to_px.x, tx_to_px, x1_first, x1_second);
    vertical_coverage(-tx_coord_f.y * tx_to_px.y, y0_first, y0_second);
    vertical_coverage((tx_coord_off.y - tx_coord_f.y) * tx_to_px.y, y1_first, y1_second);
    w0 = x0_first * y0_first + x0_second * y0_second;
    w1 = x1_first * y0_first + x1_second * y0_second;
    w2 = x0_first * y1_first + x0_second * y1_second;
    w3 = x1_first * y1_first + x1_second * y1_second;
    area = 4.0 * lcd_coord.z * lcd_coord.z;
}

#ifndef PT_GRID_OVERLAY_ONLY
vec3 nativeSample(ivec2 cell) {
    // Match the separate LCD pass's nearest input and transparent border.
    // Explicit bounds avoid undefined out-of-range texelFetch behaviour.
    if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, ivec2(global.OriginalSize.xy))))
        return vec3(0.0);
    return texelFetch(LCDInput, cell, 0).rgb;
}

vec3 quantizeLCD(vec3 color) {
    // Preserve the removed R8G8B8A8_UNORM framebuffer's clipping and rounding.
#ifdef PT_GRID_INPUT_ONLY
    return color; // The separate framebuffer performs the quantization.
#else
    return roundEven(clamp(color, 0.0, 1.0) * 255.0) / 255.0;
#endif
}

vec4 sampleLCD() {
    ivec2 cell, offset;
    vec3 w0, w1, w2, w3;
    float area;
    lcdWeights(cell, offset, w0, w1, w2, w3, area);
    vec3 samples[] = {nativeSample(cell), nativeSample(cell + ivec2(offset.x, 0)),
                      nativeSample(cell + ivec2(0, offset.y)), nativeSample(cell + offset)};
    vec3 res = (w0 * samples[0] + w1 * samples[1] + w2 * samples[2] + w3 * samples[3]) / area;

#ifdef PT_GRID_INPUT_ONLY
    bool above = global.PT_FUSED_LAYER > 0.5;
#else
    bool above = global.PT_FUSED_LAYER > 0.5 && param.PT_ENABLE > 0.5;
#endif
    if (!above && global.PT_FUSED_STRENGTH == 1.0 &&
        global.PT_FUSED_BRIGHTNESS == 0.0 && global.PT_FUSED_BIAS == 0.0)
        return vec4(quantizeLCD(sqrt(res)), 1.0);

    vec3 coverage = clamp((w0 + w1 + w2 + w3) / area, 0.0, 1.0);
    vec3 native_color = mix(samples[0], res / max(coverage, vec3(0.000001)),
                           greaterThan(coverage, vec3(0.000001)));
#ifdef PT_GRID_INPUT_ONLY
    // The output stage owns grid styling when it is above the effects.
    if (above)
        return vec4(sqrt(max(native_color, vec3(0.0))), 1.0);
#endif
    float strength = global.PT_FUSED_STRENGTH;
    if (global.PT_FUSED_BIAS > 0.0)
        strength *= mix(1.0, getPerceptualBrightness(sqrt(max(native_color, vec3(0.0)))), global.PT_FUSED_BIAS);
    lcd_coverage = mix(vec3(1.0), coverage, strength);
    vec3 line = global.PT_FUSED_BRIGHTNESS * vec3(global.PT_FUSED_RED, global.PT_FUSED_GREEN, global.PT_FUSED_BLUE);
    lcd_line_color = line * line;
    if (above)
        return vec4(quantizeLCD(sqrt(max(native_color, vec3(0.0)))), 1.0);
    vec3 colored = native_color * lcd_coverage + lcd_line_color * (vec3(1.0) - lcd_coverage);
    return vec4(quantizeLCD(sqrt(max(colored, vec3(0.0)))), 1.0);
}

#ifndef PT_GRID_INPUT_ONLY
vec4 finishLCD(vec4 color) {
    if (global.PT_FUSED_LAYER > 0.5 && global.PT_HIDE_CONTENT < 0.5) {
        // Apply coverage at the output pixel; paper and light never pass through
        // native-resolution sampling. Dither is added once after this blend.
        vec3 linear = max(color.rgb, vec3(0.0));
        color.rgb = sqrt(linear * linear * lcd_coverage + lcd_line_color * (vec3(1.0) - lcd_coverage));
    }
    return color;
}

#endif
#endif
