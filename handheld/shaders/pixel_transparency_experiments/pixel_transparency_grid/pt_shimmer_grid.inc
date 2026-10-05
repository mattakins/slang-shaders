/*
    Pixel Transparency + Sunlight Shimmer + Integrated Grid
    Combined include file — vertex shader, grid functions, fragment shader.

    Expects before #include:
    - #define PT_SHIMMER
    - #define PT_GRID
    - push_constant 'param' with shared members
    - UBO 'global' with shared members

    Fragment main() is left OPEN — the including file must close it.
*/

// Authentic GBC subpixel geometry
#include "../../authentic_gbc/shared.inc"

// Rectangle intersection for authentic_gbc coverage
#include "../../../../misc/shaders/coverage/coverage.inc"

// Piecewise linear: w=0→lo, w=0.5→mid, w=1→hi
float mapWeight(float w, float lo, float mid, float hi) {
    return (w < 0.5) ? mix(lo, mid, w * 2.0) : mix(mid, hi, (w - 0.5) * 2.0);
}

// Effective grid parameters — original mode snaps to standalone shader defaults
struct GridParams {
    float weight;
    float intensity;
    float bias;
    float color;
    float darken;
    bool subpx;
    bool bgr;
};

GridParams getGridParams(float style, bool custom) {
    GridParams gp;
    if (custom) {
        gp.weight    = param.PT_GRID_WEIGHT;
        gp.intensity = global.PT_GRID_INTENSITY;
        gp.bias      = global.PT_GRID_BIAS;
        gp.color     = global.PT_GRID_COLOR;
        gp.darken    = global.PT_DARKEN_COLOUR;
        gp.subpx     = param.PT_GRID_SUBPX > 0.5;
        gp.bgr       = param.PT_GRID_SUBPX_DIR > 1.5;
    } else {
        // Original defaults per style
        gp.weight    = 0.5;
        gp.intensity = 1.0;
        gp.bias      = 0.0;
        gp.color     = 1.0;  // Dark (multiplicative) for most styles
        gp.darken    = 0.0;
        gp.subpx     = false;
        gp.bgr       = false;

        if (style > 0.5 && style < 1.5) {
            // lcd3x: always subpixels
            gp.subpx = true;
        } else if (style > 2.5 && style < 3.5) {
            // simpletex: preset defaults (white lines, bias, slight darken)
            gp.color  = 2.0;
            gp.bias   = 0.6;
            gp.darken = 0.05;
        } else if (style > 3.5 && style < 4.5) {
            // lcd-grid-v2: preset defaults (gain=1.5, subpixels on)
            gp.subpx  = true;
            gp.weight = 0.75;  // maps to gain=1.5
        }
    }
    return gp;
}

// ============================================================
//  VERTEX SHADER
// ============================================================
#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
// Shimmer varyings
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 texel;
layout(location = 2) out float shadow_scale_factor;
layout(location = 3) out vec2 shadow_offset_raw;
layout(location = 4) out vec2 light_pos;
// Authentic GBC grid varyings (computed when style=5)
layout(location = 5) out vec4 lcd_subpx_rect1;
layout(location = 6) out vec4 lcd_subpx_rect2;
layout(location = 7) out vec2 subpx_offset_in_px;
layout(location = 8) out vec2 tx_coord;
layout(location = 9) out vec2 tx_to_px;
layout(location = 10) out vec2 tx_orig_offs;
layout(location = 11) out float half_px_size;

vec2 getOrientedTilt(vec3 accel) {
    float magnitude = length(accel);
    if (magnitude < 0.01) return vec2(0.0);
    vec3 dir = accel / magnitude;
    return vec2(-dir.x, dir.y);
}

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
    texel = param.OutputSize.zw;

    // Resolution scale for shadow compensation (reference: 640x480)
    float scale_x = param.OutputSize.x / 640.0;
    float scale_y = param.OutputSize.y / 480.0;
    shadow_scale_factor = sqrt(scale_x * scale_y);

    // Gravity/tilt from accelerometer (motion params now in UBO)
    vec2 gravity = vec2(0.0);
    bool has_sensors = false;

    #ifdef _HAS_SENSOR_UNIFORMS
    if (global.ACCEL_ENABLE > 0.5) {
        vec3 accel = global.Accelerometer;
        has_sensors = length(accel) > 0.01;
        if (has_sensors) {
            if (global.ACCEL_RELATIVE > 0.5) {
                vec3 rest = global.AccelerometerRest;
                gravity = clamp(getOrientedTilt(accel) - getOrientedTilt(rest), vec2(-1.0), vec2(1.0));
            } else {
                gravity = getOrientedTilt(accel);
            }
            gravity = clamp(gravity * global.ACCEL_SENSITIVITY, vec2(-1.0), vec2(1.0));
        }
    }
    #endif

    // Light position (shimmer)
    if (param.PT_RAINBOW_ENABLE > 0.5 || param.PT_GLARE_ENABLE > 0.5) {
        light_pos = vec2(param.LIGHT_X, param.LIGHT_Y);
        if (global.ACCEL_ENABLE > 0.5 && has_sensors) {
            light_pos += vec2(gravity.x, -gravity.y) * param.LIGHT_RANGE;
        }
    } else {
        light_pos = vec2(0.5, 0.5);
    }

    // Shadow offset (motion params in UBO)
    if (global.PT_SHADOW_MOTION > 0.5 && global.ACCEL_ENABLE > 0.5 && has_sensors) {
        vec2 base = vec2(global.PT_SHADOW_MOTION_X, global.PT_SHADOW_MOTION_Y);
        shadow_offset_raw = base + gravity * global.PT_SHADOW_MAX_OFFSET;
    } else {
        shadow_offset_raw = vec2(global.PT_SHADOW_OFFSET_X, global.PT_SHADOW_OFFSET_Y);
    }

    // Authentic GBC grid geometry (style 5 only)
    if (param.PT_GRID_STYLE > 4.5) {
        // Map universal params to authentic_gbc values
        bool custom = param.PT_GRID_PRESET > 0.5;
        float brig = custom ? param.AUTH_GBC_BRIG : 0.6;
        float blur_weight = custom ? param.PT_GRID_WEIGHT : 0.5;
        float blur_amount = mapWeight(blur_weight, 0.0, 0.3, 1.0);

        calculate_lcd_params(param.OriginalSize.xy, param.OutputSize.xy, param.Rotation,
                             param.PT_GRID_SUBPX, uint(param.PT_GRID_SUBPX_DIR),
                             brig, TexCoord, lcd_subpx_rect1, lcd_subpx_rect2,
                             subpx_offset_in_px, tx_coord, tx_to_px, tx_orig_offs);

        float eff_blur = 0.7 * blur_amount * min(tx_to_px.x, tx_to_px.y) * 0.5;
        half_px_size = 0.5 * clamp(1.0 + eff_blur, 1.0, min(tx_to_px.x, tx_to_px.y));
    } else {
        // Zero out varyings for non-authentic_gbc styles
        lcd_subpx_rect1 = vec4(0.0);
        lcd_subpx_rect2 = vec4(0.0);
        subpx_offset_in_px = vec2(0.0);
        tx_coord = TexCoord * param.OriginalSize.xy;
        tx_to_px = param.OutputSize.xy / param.OriginalSize.xy;
        tx_orig_offs = vec2(0.0);
        half_px_size = 0.5;
    }
}

// ============================================================
//  FRAGMENT SHADER
// ============================================================
#pragma stage fragment
// Shimmer varyings
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 texel;
layout(location = 2) in float shadow_scale_factor;
layout(location = 3) in vec2 shadow_offset_raw;
layout(location = 4) in vec2 light_pos;
// Authentic GBC grid varyings
layout(location = 5) in vec4 lcd_subpx_rect1;
layout(location = 6) in vec4 lcd_subpx_rect2;
layout(location = 7) in vec2 subpx_offset_in_px;
layout(location = 8) in vec2 tx_coord;
layout(location = 9) in vec2 tx_to_px;
layout(location = 10) in vec2 tx_orig_offs;
layout(location = 11) in float half_px_size;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D Original;

// ============================================================
//  HELPER FUNCTIONS
// ============================================================
#ifndef PI
#define PI 3.141592654
#endif
#define LUMA_R 0.2126
#define LUMA_G 0.7152
#define LUMA_B 0.0722

float getPerceptualBrightness(vec3 color) {
    return (LUMA_R * color.r) + (LUMA_G * color.g) + (LUMA_B * color.b);
}

float getGameBoyRGBSum(vec3 color) {
    return (color.r + color.g + color.b) / 3.0;
}

float getBrightness(vec3 color) {
    if (param.PT_BRIGHTNESS_MODE < 0.5) {
        return getGameBoyRGBSum(color);
    } else {
        return getPerceptualBrightness(color);
    }
}

bool isWhitePixel(vec3 color, float threshold) {
    float brightness = getPerceptualBrightness(color);
    float min_channel = min(min(color.r, color.g), color.b);
    return (brightness > threshold && min_channel > threshold * 0.9);
}

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float paperNoise(vec2 uv, float scale) {
    vec2 p = uv * scale * 512.0;
    float n = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < 3; i++) {
        n += hash(p * frequency) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return n;
}

float smoothValue(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float filmNoise(vec2 uv, float scale) {
    vec2 p = uv * scale * 8.0;
    float n = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < 3; i++) {
        n += smoothValue(p * frequency) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return n;
}

vec3 generateProceduralBackground(vec2 uv) {
    vec3 baseColor = vec3(global.PT_BACKING_BRIGHTNESS);
    const float grainIntensity = 0.065;
    const float scale = 0.25;
    float grain = paperNoise(uv, scale);
    float grainOffset = (grain - 0.4375) * grainIntensity;
    return baseColor + vec3(grainOffset);
}

vec3 qwpSpectralTint(float gamma_eff) {
    vec3 tint = vec3(0.0);
    const vec3 s0 = vec3(0.000000, 0.000000, 0.026075);
    const vec3 s1 = vec3(0.141223, 0.000000, 0.368894);
    const vec3 s2 = vec3(0.000000, 0.480861, 0.473477);
    const vec3 s3 = vec3(0.081095, 0.812848, 0.339825);
    const vec3 s4 = vec3(0.783356, 0.793891, 0.134941);
    const vec3 s5 = vec3(0.972432, 0.423991, 0.215476);
    const vec3 s6 = vec3(0.648322, 0.114430, 0.000000);
    const float k0 = 0.031415927;
    const float k1 = 0.028399638;
    const float k2 = 0.025874228;
    const float k3 = 0.023809524;
    const float k4 = 0.021991149;
    const float k5 = 0.020462441;
    const float k6 = 0.019138570;
    float c0 = cos(k0 * gamma_eff); tint += s0 * c0 * c0;
    float c1 = cos(k1 * gamma_eff); tint += s1 * c1 * c1;
    float c2 = cos(k2 * gamma_eff); tint += s2 * c2 * c2;
    float c3 = cos(k3 * gamma_eff); tint += s3 * c3 * c3;
    float c4 = cos(k4 * gamma_eff); tint += s4 * c4 * c4;
    float c5 = cos(k5 * gamma_eff); tint += s5 * c5 * c5;
    float c6 = cos(k6 * gamma_eff); tint += s6 * c6 * c6;
    float peak = max(tint.r, max(tint.g, tint.b));
    if (peak > 0.001) tint /= peak;
    return tint;
}

// ============================================================
//  GRID STYLE FUNCTIONS — all return vec3 factor in [0, 1]
// ============================================================

// Style 0: lcd1x — sinusoidal, scalar (no subpixels)
vec3 grid_lcd1x(vec2 uv, vec2 origSize, float h, float v) {
    vec2 pixelCoord = uv * origSize;
    vec2 angle = 2.0 * PI * (pixelCoord - 0.25);
    float yfactor = (h + sin(angle.y)) / (h + 1.0);
    float xfactor = (v + sin(angle.x)) / (v + 1.0);
    return vec3(yfactor * xfactor);
}

// Style 1: lcd3x — sinusoidal with RGB subpixel phase offsets
vec3 grid_lcd3x(vec2 uv, vec2 origSize, float h, float v, bool subpx, bool bgr) {
    vec2 omega = 2.0 * PI * uv * origSize;
    float yfactor = (h + sin(omega.y)) / (h + 1.0);
    if (subpx) {
        vec3 offsets = vec3(PI) * vec3(0.5, 0.5 - 2.0/3.0, 0.5 - 4.0/3.0);
        vec3 xfactors = (v + sin(omega.x + offsets)) / (v + 1.0);
        if (bgr) xfactors.rgb = xfactors.bgr;
        return vec3(yfactor) * xfactors;
    } else {
        float xfactor = (v + sin(omega.x + PI * 0.5)) / (v + 1.0);
        return vec3(yfactor * xfactor);
    }
}

// Style 2: zfast — cubic polynomial distance-from-center
vec3 grid_zfast(vec2 uv, vec2 origSize, float bordermult) {
    vec2 pixelCoord = uv * origSize;
    vec2 centerCoord = floor(pixelCoord) + vec2(0.5);
    vec2 dist = abs(centerCoord - pixelCoord);
    float Y = max(dist.x, dist.y);
    Y = Y * Y;
    float YY = Y * Y;
    float YYY = YY * Y;
    float lineWeight = YY - 2.7 * YYY;
    float factor = 1.0 - bordermult * lineWeight;
    return vec3(clamp(factor, 0.0, 1.0));
}

// Style 3: simpletex — sextic polynomial
vec3 grid_simpletex(vec2 uv, vec2 origSize, float grid_w) {
    vec2 pixelCoord = uv * origSize;
    vec2 centerCoord = floor(pixelCoord) + vec2(0.5);
    vec2 dist = abs(centerCoord - pixelCoord);
    float x = max(dist.x, dist.y);
    float xSq = x * x;
    float x4 = xSq * xSq;
    float lineWeight = 48.0 * (x4 - (8.0/3.0) * x4 * xSq);
    lineWeight = lineWeight * (lineWeight + ((1.0 - lineWeight) * grid_w)) * grid_w;
    return vec3(1.0 - clamp(lineWeight, 0.0, 1.0));
}

// Style 4: lcd-grid-v2 — analytical polynomial integration with subpixels
float coeffs_x[7] = float[](1.0, -2.0/3.0, -1.0/5.0, 4.0/7.0, -1.0/9.0, -2.0/11.0, 1.0/13.0);
float coeffs_y[7] = float[](1.0,      0.0, -4.0/5.0, 2.0/7.0,  4.0/9.0, -4.0/11.0, 1.0/13.0);

float intsmear_func(float z, float coeffs[7]) {
    float z2 = z * z;
    float zn = z;
    float ret = 0.0;
    for (int i = 0; i < 7; i++) {
        ret += zn * coeffs[i];
        zn *= z2;
    }
    return ret;
}

float intsmear(float x, float dx, float d, float coeffs[7]) {
    float zl = clamp((x - dx * 0.5) / d, -1.0, 1.0);
    float zh = clamp((x + dx * 0.5) / d, -1.0, 1.0);
    return d * (intsmear_func(zh, coeffs) - intsmear_func(zl, coeffs)) / dx;
}

vec3 grid_lcd_grid_v2(vec2 uv, vec2 origSize, vec2 outputSize, bool subpx, bool bgr, float gain) {
    vec2 texelSize = 1.0 / origSize;
    vec2 range = 1.0 / outputSize;

    ivec2 tli = ivec2(floor(uv / texelSize - vec2(0.4999)));

    // X-axis: subpixel coverage
    float subpix_x = (uv.x / texelSize.x - 0.4999 - float(tli.x)) * 3.0;
    float rsubpix_x = range.x / texelSize.x * 3.0;

    vec3 lcol, rcol;
    if (subpx) {
        lcol = vec3(intsmear(subpix_x + 1.0, rsubpix_x, 1.5, coeffs_x),
                    intsmear(subpix_x,       rsubpix_x, 1.5, coeffs_x),
                    intsmear(subpix_x - 1.0, rsubpix_x, 1.5, coeffs_x));
        rcol = vec3(intsmear(subpix_x - 2.0, rsubpix_x, 1.5, coeffs_x),
                    intsmear(subpix_x - 3.0, rsubpix_x, 1.5, coeffs_x),
                    intsmear(subpix_x - 4.0, rsubpix_x, 1.5, coeffs_x));
        if (bgr) { lcol.rgb = lcol.bgr; rcol.rgb = rcol.bgr; }
    } else {
        float l = intsmear(subpix_x, rsubpix_x, 1.5, coeffs_x);
        float r = intsmear(subpix_x - 3.0, rsubpix_x, 1.5, coeffs_x);
        lcol = vec3(l);
        rcol = vec3(r);
    }

    // Y-axis coverage
    float subpix_y = uv.y / texelSize.y - 0.4999 - float(tli.y);
    float rsubpix_y = range.y / texelSize.y;
    float tcol = intsmear(subpix_y,       rsubpix_y, 0.63, coeffs_y);
    float bcol = intsmear(subpix_y - 1.0, rsubpix_y, 0.63, coeffs_y);

    // Total coverage = (lcol + rcol) * (tcol + bcol)
    vec3 grid_factor = (lcol + rcol) * (tcol + bcol);

    grid_factor *= gain;

    return clamp(grid_factor, vec3(0.0), vec3(1.0));
}

// Style 5: authentic_gbc — v2 batched rectangle coverage (uses vertex shader varyings)
// Computes 4 intersection areas simultaneously via vec4 operations.
vec4 gbc_batch_rect_area(float px_xlo, float px_ylo, float px_xhi, float px_yhi,
                         vec4 orig_x, vec4 orig_y, vec4 rect) {
    vec4 bl_x = max(vec4(px_xlo), orig_x + rect.xxxx);
    vec4 bl_y = max(vec4(px_ylo), orig_y + rect.yyyy);
    vec4 tr_x = min(vec4(px_xhi), orig_x + rect.zzzz);
    vec4 tr_y = min(vec4(px_yhi), orig_y + rect.wwww);
    return max(tr_x - bl_x, vec4(0.0)) * max(tr_y - bl_y, vec4(0.0));
}

// Specialized for rect1 where .xy = (0,0): skips 2 vec4 additions.
vec4 gbc_batch_rect_area_r1(float px_xlo, float px_ylo, float px_xhi, float px_yhi,
                            vec4 orig_x, vec4 orig_y, vec4 rect) {
    vec4 bl_x = max(vec4(px_xlo), orig_x);
    vec4 bl_y = max(vec4(px_ylo), orig_y);
    vec4 tr_x = min(vec4(px_xhi), orig_x + rect.zzzz);
    vec4 tr_y = min(vec4(px_yhi), orig_y + rect.wwww);
    return max(tr_x - bl_x, vec4(0.0)) * max(tr_y - bl_y, vec4(0.0));
}

// Shared setup for batched authentic_gbc: computes px_square corners and packed origins.
// Returns coverage per channel as vec3, with 4 per-texel coverages in cov_r/g/b.
struct GbcBatchData {
    float norm;  // 4.0 * half_px_size * half_px_size
    vec4 cov_r, cov_g, cov_b;  // Per-channel coverage (4 texels packed in vec4)
    vec2 tx_coord_i, tx_coord_off;  // Decomposed tx_coord for texture sampling
};

GbcBatchData gbc_compute_batch() {
    GbcBatchData d;

    vec2 tx_coord_f = modf(tx_coord, d.tx_coord_i);
    d.tx_coord_off = step(vec2(0.5), tx_coord_f) * 2.0 - 1.0;
    d.norm = 4.0 * half_px_size * half_px_size;

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

    // Pack 4 texel origins
    vec4 base_x = (vec4(0.0, d.tx_coord_off.x, 0.0, d.tx_coord_off.x) - tx_coord_f.x) * tx_to_px.x;
    vec4 base_y = (vec4(0.0, 0.0, d.tx_coord_off.y, d.tx_coord_off.y) - tx_coord_f.y) * tx_to_px.y;
    vec4 orig_y   = base_y + tx_orig_offs.y;
    vec4 orig_g_x = base_x + tx_orig_offs.x;
    float subpx_third = tx_to_px.x / 3.0;
    vec4 orig_r_x = orig_g_x - subpx_third;
    vec4 orig_b_x = orig_g_x + subpx_third;

    // 6 batched vec4 intersections (rect1 specialized)
    d.cov_r = gbc_batch_rect_area_r1(r_xlo, r_ylo, r_xhi, r_yhi, orig_r_x, orig_y, lcd_subpx_rect1)
            + gbc_batch_rect_area(r_xlo, r_ylo, r_xhi, r_yhi, orig_r_x, orig_y, lcd_subpx_rect2);
    d.cov_g = gbc_batch_rect_area_r1(g_xlo, g_ylo, g_xhi, g_yhi, orig_g_x, orig_y, lcd_subpx_rect1)
            + gbc_batch_rect_area(g_xlo, g_ylo, g_xhi, g_yhi, orig_g_x, orig_y, lcd_subpx_rect2);
    d.cov_b = gbc_batch_rect_area_r1(b_xlo, b_ylo, b_xhi, b_yhi, orig_b_x, orig_y, lcd_subpx_rect1)
            + gbc_batch_rect_area(b_xlo, b_ylo, b_xhi, b_yhi, orig_b_x, orig_y, lcd_subpx_rect2);

    return d;
}

// "After" mode: total coverage as grid overlay factor
vec3 grid_authentic_gbc() {
    GbcBatchData d = gbc_compute_batch();
    vec3 grid = vec3(dot(d.cov_r, vec4(1.0)),
                     dot(d.cov_g, vec4(1.0)),
                     dot(d.cov_b, vec4(1.0))) / d.norm;

    // sqrt compensates for sRGB-space multiplication to match the linear pipeline
    return sqrt(clamp(grid, vec3(0.0), vec3(1.0)));
}

// "Before" mode: full 4-sample linearized blend (exact original pipeline)
vec3 gbc_before_blend() {
    GbcBatchData d = gbc_compute_batch();

    vec2 tx_coord_offs[4] = vec2[](vec2(0.0), vec2(d.tx_coord_off.x, 0.0),
                                    vec2(0.0, d.tx_coord_off.y), d.tx_coord_off);

    // Sample 4 neighboring game pixels and linearize
    vec3 samples[4];
    for (int i = 0; i < 4; i++) {
        vec3 s = texture(Original, (d.tx_coord_i + tx_coord_offs[i] + 0.5) * param.OriginalSize.zw).rgb;
        samples[i] = s * s;
    }

    // Coverage-weighted blend via dot products
    vec4 s_r = vec4(samples[0].r, samples[1].r, samples[2].r, samples[3].r);
    vec4 s_g = vec4(samples[0].g, samples[1].g, samples[2].g, samples[3].g);
    vec4 s_b = vec4(samples[0].b, samples[1].b, samples[2].b, samples[3].b);

    return sqrt(max(vec3(dot(d.cov_r, s_r), dot(d.cov_g, s_g), dot(d.cov_b, s_b)) / d.norm, vec3(0.0)));
}

// Shared helper: apply GBC before-blend with intensity and bias
vec3 applyGbcBefore(vec3 color, vec3 original_pixel, GridParams gp) {
    vec3 gbc_result = gbc_before_blend();
    float intensity = gp.intensity;
    if (abs(gp.bias) > 0.01) {
        float luma = getPerceptualBrightness(original_pixel);
        float scale = (gp.bias > 0.0) ? luma : (1.0 - luma);
        intensity *= mix(1.0, scale, abs(gp.bias));
    }
    return mix(color, gbc_result, intensity);
}

// ============================================================
//  GRID DISPATCHER — calls the right style function
// ============================================================

vec3 computeGridFactor(vec2 uv, GridParams gp) {
    float style = param.PT_GRID_STYLE;

    vec3 factor;
    if (style < 0.5) {
        float h = mapWeight(gp.weight, 32.0, 16.0, 1.0);
        float v = mapWeight(gp.weight, 12.0, 4.0, 1.0);
        factor = grid_lcd1x(uv, param.OriginalSize.xy, h, v);
    } else if (style < 1.5) {
        float h = mapWeight(gp.weight, 32.0, 16.0, 1.0);
        float v = mapWeight(gp.weight, 12.0, 4.0, 1.0);
        factor = grid_lcd3x(uv, param.OriginalSize.xy, h, v, gp.subpx, gp.bgr);
    } else if (style < 2.5) {
        float bm = mapWeight(gp.weight, 0.0, 14.0, 40.0);
        factor = grid_zfast(uv, param.OriginalSize.xy, bm);
    } else if (style < 3.5) {
        float gw = mapWeight(gp.weight, 0.0, 0.65, 1.0);
        factor = grid_simpletex(uv, param.OriginalSize.xy, gw);
    } else if (style < 4.5) {
        float gain = mapWeight(gp.weight, 0.5, 1.0, 2.0);
        factor = grid_lcd_grid_v2(uv, param.OriginalSize.xy, param.OutputSize.xy, gp.subpx, gp.bgr, gain);
    } else {
        factor = grid_authentic_gbc();
    }

    return factor;
}

// Apply grid to a color with given line color, factor, intensity, and bias
vec3 applyGrid(vec3 color, vec3 grid_factor, vec3 grid_line_color, float intensity, float bias, vec3 original_pixel) {
    if (intensity < 0.001) return color;

    // Bias: adjust intensity per pixel based on luminosity
    float biased_intensity = intensity;
    if (abs(bias) > 0.01) {
        float luma = getPerceptualBrightness(original_pixel);
        float scale = (bias > 0.0) ? luma : (1.0 - luma);
        biased_intensity *= mix(1.0, scale, abs(bias));
    }

    // Apply: blend toward grid line color at gap positions
    vec3 gridded = mix(grid_line_color, color, grid_factor);
    return mix(color, gridded, biased_intensity);
}

// Polarizer tint — extracted for flexible positioning
void applyPolarizer(inout vec3 color) {
    if (global.PT_POLARIZER > 0.5 && global.PT_POLARIZER_TINT > 0.001) {
        vec3 polarizer = mix(vec3(1.0), vec3(0.94, 1.0, 0.865), global.PT_POLARIZER_TINT);
        color *= polarizer;
    }
}

// Rainbow shimmer (QWP layer 6)
void applyRainbow(inout vec3 color, vec3 orig_pixel, vec2 uv, vec2 lpos) {
    if (param.PT_RAINBOW_ENABLE < 0.5 || global.PT_RAINBOW_INTENSITY < 0.001) return;

    float aspect_ratio = param.OutputSize.x / param.OutputSize.y;
    vec2 to_light = (uv - lpos) * vec2(aspect_ratio, 1.0);
    float dist_xy = length(to_light);

    const float GAMMA_BASE = 275.0;
    const float N_FILM = 1.5;
    float gamma_0 = GAMMA_BASE * global.PT_FILM_TUNING;

    float angle_incidence;
    if (global.LIGHT_HEIGHT < 0.01) {
        angle_incidence = dist_xy * global.LIGHT_SPREAD;
    } else {
        angle_incidence = atan(dist_xy, global.LIGHT_HEIGHT) * global.LIGHT_SPREAD;
    }
    angle_incidence = clamp(angle_incidence, 0.0, 1.4);

    float sin_theta_r = sin(angle_incidence) / N_FILM;
    float cos_theta_r = sqrt(1.0 - sin_theta_r * sin_theta_r);
    float gamma_eff = gamma_0 * cos_theta_r;

    if (global.PT_FILM_NOISE > 0.001) {
        vec2 noise_uv = vec2(uv.x * aspect_ratio, uv.y);
        float noise = filmNoise(noise_uv, global.PT_FILM_SCALE) - 0.4375;
        gamma_eff *= (1.0 + noise * global.PT_FILM_NOISE);
    }

    vec3 tint = qwpSpectralTint(gamma_eff);
    float tint_strength = global.PT_RAINBOW_INTENSITY;
    float reflectivity = mix(0.03, 1.0, getBrightness(orig_pixel));
    tint_strength *= reflectivity;
    tint *= orig_pixel * orig_pixel;

    vec3 tinted = color * mix(vec3(1.0), tint, tint_strength);
    float orig_luma = getPerceptualBrightness(color);
    float tinted_luma = getPerceptualBrightness(tinted);
    if (tinted_luma > 0.001) tinted *= orig_luma / tinted_luma;
    color = tinted;
}

// Specular glare (lens surface, layer 9)
void applyGlare(inout vec3 color, vec2 uv, vec2 lpos) {
    if (param.PT_GLARE_ENABLE < 0.5 || global.PT_GLARE_INTENSITY < 0.001) return;

    float aspect_ratio = param.OutputSize.x / param.OutputSize.y;
    vec2 to_light = (uv - lpos) * vec2(aspect_ratio, 1.0);
    float dist_xy = length(to_light);

    float size_sq = global.PT_GLARE_SIZE * global.PT_GLARE_SIZE;
    float glare_strength = exp(-dist_xy * dist_xy / (2.0 * size_sq)) * global.PT_GLARE_INTENSITY;
    color = mix(color, vec3(1.0), clamp(glare_strength, 0.0, 0.85));
}

// ============================================================
//  FRAGMENT MAIN
// ============================================================
void main() {
    vec4 lcd_color = texture(Source, vTexCoord);
    vec3 original_pixel = texture(Original, vTexCoord).rgb;

    vec4 output_color = lcd_color;

    // Resolve grid params once (original vs custom)
    GridParams gp = getGridParams(param.PT_GRID_STYLE, param.PT_GRID_PRESET > 0.5);

    // Early exit if PT disabled
    if (param.PT_ENABLE < 0.5) {
        // Grid-only mode (or no effects at all)
        if (global.PT_GRID_ENABLE < 0.5) { FragColor = output_color; return; }

        // Color darkening in grid-only mode
        if (gp.darken > 0.001) {
            output_color.rgb = pow(output_color.rgb, vec3(1.0 + gp.darken));
        }

        if (param.PT_GRID_STYLE > 4.5) {
            output_color.rgb = applyGbcBefore(output_color.rgb, original_pixel, gp);
        } else {
            vec3 gf = computeGridFactor(vTexCoord, gp);
            // No background available — clamp to dark-light range
            vec3 glc = vec3(clamp(gp.color - 1.0, 0.0, 1.0));
            output_color.rgb = applyGrid(output_color.rgb, gf, glc,
                                         gp.intensity, gp.bias, output_color.rgb);
        }
        FragColor = output_color;
        return;
    }

    // Debug: replace game image with white to isolate shader effects
    if (global.PT_HIDE_CONTENT > 0.5) {
        lcd_color = vec4(1.0);
        original_pixel = vec3(1.0);
        output_color = lcd_color;
    }

    // Highlight adjustment — negative dims lcd_color before compositing
    if (global.PT_HIGHLIGHTS < -0.001) {
        float luma = getPerceptualBrightness(lcd_color.rgb);
        lcd_color.rgb *= max(1.0 + global.PT_HIGHLIGHTS * luma, 0.0);
    }

    bool current_is_white = isWhitePixel(original_pixel, param.PT_THRESHOLD);

    // =============== BACKGROUND ===============
    // Snap background UV to game pixel center when grid is active — makes composited
    // output uniform per game pixel, matching multi-pass nearest-neighbor behavior.
    vec2 bg_uv = vTexCoord;
    if (global.PT_GRID_ENABLE > 0.5) {
        bg_uv = (floor(vTexCoord * param.OriginalSize.xy) + 0.5) * param.OriginalSize.zw;
    }
    vec4 background = vec4(generateProceduralBackground(bg_uv), 1.0);

    // Drop shadows (suppressed in debug mode 2)
    if (param.PT_SHADOW_ENABLE > 0.5 && global.PT_HIDE_CONTENT < 1.5) {
        vec2 shadow_offset = -shadow_offset_raw * shadow_scale_factor * texel;
        float shadow_strength = 0.0;

        if (param.PT_SHADOW_BLUR > 0.1) {
            vec2 blur_dist = param.PT_SHADOW_BLUR * shadow_scale_factor * texel;
            vec2 base_pos = vTexCoord + shadow_offset;
            float blurred_shadow = 0.0;

            if (param.PT_SHADOW_FAST_BLUR < 0.5) {
                vec2 sample_offsets[5] = vec2[](
                    vec2(0.0, 0.0), vec2(-1.0, 0.0), vec2(1.0, 0.0),
                    vec2(0.0, -1.0), vec2(0.0, 1.0));
                for (int i = 0; i < 5; i++) {
                    vec3 blur_sample = texture(Original, base_pos + sample_offsets[i] * blur_dist).rgb;
                    float w = (i == 0) ? 4.0 : 2.0;
                    blurred_shadow += (1.0 - getBrightness(blur_sample)) * w;
                }
                shadow_strength = (blurred_shadow / 12.0) * param.PT_SHADOW_OPACITY;
            } else {
                vec2 sample_offsets[9] = vec2[](
                    vec2(0.0, 0.0), vec2(-1.0, 0.0), vec2(1.0, 0.0),
                    vec2(0.0, -1.0), vec2(0.0, 1.0), vec2(-1.0, -1.0),
                    vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(1.0, 1.0));
                for (int i = 0; i < 9; i++) {
                    vec3 blur_sample = texture(Original, base_pos + sample_offsets[i] * blur_dist).rgb;
                    float w = (i == 0) ? 4.0 : (i < 5 ? 2.0 : 1.0);
                    blurred_shadow += (1.0 - getBrightness(blur_sample)) * w;
                }
                shadow_strength = (blurred_shadow / 16.0) * param.PT_SHADOW_OPACITY;
            }
        } else {
            vec3 center_source = texture(Original, vTexCoord + shadow_offset).rgb;
            shadow_strength = (1.0 - getBrightness(center_source)) * param.PT_SHADOW_OPACITY;
        }

        // Deadzone — suppress faint shadows from near-white pixels
        float deadzone = (1.0 - param.PT_THRESHOLD) * param.PT_SHADOW_OPACITY;
        if (deadzone > 0.001) {
            shadow_strength = smoothstep(0.0, deadzone, shadow_strength) * shadow_strength;
        }

        background.rgb = mix(background.rgb, background.rgb * 0.2, shadow_strength);
    }

    // Background tinting
    if (global.PT_PALETTE > 0.5) {
        vec3 bg_palette_color;
        if (global.PT_PALETTE < 1.5) {
            bg_palette_color = vec3(0.651, 0.675, 0.518);
        } else if (global.PT_PALETTE < 2.5) {
            bg_palette_color = vec3(0.72, 0.73, 0.66);
        } else if (global.PT_PALETTE < 3.5) {
            bg_palette_color = vec3(0.766, 0.73, 0.763);
        } else {
            bg_palette_color = vec3(0.76);
        }
        float max_ch = max(bg_palette_color.r, max(bg_palette_color.g, bg_palette_color.b));
        bg_palette_color *= 0.675 / max_ch;

        vec3 tinted_background = clamp(
            vec3(bg_palette_color.r + mix(-1.0, 1.0, background.r),
                 bg_palette_color.g + mix(-1.0, 1.0, background.g),
                 bg_palette_color.b + mix(-1.0, 1.0, background.b)), 0.0, 1.0);
        background.rgb = mix(background.rgb, tinted_background, global.PT_PALETTE_INTENSITY);
    }

    // =============== GRID COMPUTATION ===============
    // Skip for authentic_gbc in before mode — gbc_before_blend computes its own coverage.
    vec3 grid_factor = vec3(1.0);
    bool skip_grid_factor = global.PT_GRID_ORDER > 0.5 && param.PT_GRID_STYLE > 4.5;
    if (global.PT_GRID_ENABLE > 0.5 && !skip_grid_factor) {
        grid_factor = computeGridFactor(vTexCoord, gp);
    }

    // Determine grid line color: 0=Trans(background) ← 1=Dark(black) → 2=Light(white)
    vec3 grid_line_color;
    if (gp.color < 1.0) {
        grid_line_color = mix(background.rgb, vec3(0.0), gp.color);
    } else {
        grid_line_color = vec3(gp.color - 1.0);
    }

    // =============== GRID BEFORE TRANSPARENCY ===============
    if (global.PT_GRID_ENABLE > 0.5 && global.PT_GRID_ORDER > 0.5) {
        if (param.PT_GRID_STYLE > 4.5) {
            lcd_color.rgb = applyGbcBefore(lcd_color.rgb, original_pixel, gp);
        } else {
            // All other styles: apply grid via universal function
            lcd_color.rgb = applyGrid(lcd_color.rgb, grid_factor, grid_line_color,
                                      gp.intensity, gp.bias, original_pixel);
        }
        output_color = lcd_color;
    }

    // =============== TRANSPARENCY COMPOSITING ===============
    if (param.PT_ENABLE > 0.5) {
        // Brightness source selection
        vec3 brightness_source = original_pixel;
        if (global.PT_BRIGHTNESS_GRID > 0.5 && global.PT_GRID_ORDER > 0.5) {
            // Grid applied before transparency — use gridded color for brightness
            brightness_source = lcd_color.rgb;
            if (current_is_white) {
                float white_blend = smoothstep(0.05, 1.0, global.PT_BRIGHTNESS_GRID);
                brightness_source = mix(original_pixel, lcd_color.rgb, white_blend);
            }
        }

        if (param.PT_PIXEL_MODE > 0.5 && param.PT_PIXEL_MODE < 1.5) {
            float pixel_intensity = getBrightness(brightness_source);
            float transparency = (param.PT_BASE_ALPHA * pixel_intensity) * 2.665;
            if (current_is_white && global.PT_WHITE_BOOST > 0.5) {
                transparency = max(transparency, global.PT_WHITE_TRANSPARENCY);
            }
            transparency = clamp(transparency, 0.0, 1.0);
            output_color.rgb = mix(lcd_color.rgb, background.rgb, transparency);
        } else {
            bool should_apply = (param.PT_PIXEL_MODE < 0.5) ? current_is_white : true;
            if (should_apply) {
                float pixel_intensity = getBrightness(brightness_source);
                float pixel_alpha = (pixel_intensity / 3.0) + param.PT_BASE_ALPHA;
                if (current_is_white && global.PT_WHITE_BOOST > 0.5) {
                    pixel_alpha = max(pixel_alpha, global.PT_WHITE_TRANSPARENCY);
                }
                pixel_alpha = clamp(pixel_alpha, 0.0, 1.0);
                output_color.rgb = mix(lcd_color.rgb, background.rgb, pixel_alpha);
            }
        }
    }

    // =============== POST-COMPOSITING EFFECTS ===============

    // Polarizer before grid/rainbow (legacy mode, PT_POLARIZER_ORDER=0)
    bool polarizer_after_rainbow = global.PT_POLARIZER_ORDER > 0.5;
    if (!polarizer_after_rainbow) {
        applyPolarizer(output_color.rgb);
    }

    // Highlight adjustment — positive brightens after compositing
    if (global.PT_HIGHLIGHTS > 0.001) {
        float luma = getPerceptualBrightness(output_color.rgb);
        output_color.rgb = clamp(output_color.rgb * (1.0 + global.PT_HIGHLIGHTS * luma), 0.0, 1.0);
    }

    // Saturation
    if (abs(global.PT_SATURATION - 1.0) > 0.001) {
        float luma = getPerceptualBrightness(output_color.rgb);
        output_color.rgb = clamp(mix(vec3(luma), output_color.rgb, global.PT_SATURATION), 0.0, 1.0);
    }

    // =============== GRID & SHIMMER LAYER ORDER ===============
    // PT_GRID_LAYER=0 (default): shimmer above grid (physically correct)
    // PT_GRID_LAYER=1: shimmer below grid (matches multi-pass pregrid behavior)
    bool grid_after = global.PT_GRID_ENABLE > 0.5 && global.PT_GRID_ORDER < 0.5;
    bool shimmer_below = global.PT_GRID_LAYER > 0.5;

    if (shimmer_below && grid_after) {
        // Shimmer below grid: rainbow → polarizer → glare → darken → grid
        applyRainbow(output_color.rgb, original_pixel, vTexCoord, light_pos);
        if (polarizer_after_rainbow) applyPolarizer(output_color.rgb);
        applyGlare(output_color.rgb, vTexCoord, light_pos);
        if (gp.darken > 0.001) {
            output_color.rgb = pow(output_color.rgb, vec3(1.0 + gp.darken));
        }
        output_color.rgb = applyGrid(output_color.rgb, grid_factor, grid_line_color,
                                     gp.intensity, gp.bias, output_color.rgb);
    } else {
        // Shimmer above grid (default): darken → grid → rainbow → polarizer → glare
        if (gp.darken > 0.001) {
            output_color.rgb = pow(output_color.rgb, vec3(1.0 + gp.darken));
        }
        if (grid_after) {
            output_color.rgb = applyGrid(output_color.rgb, grid_factor, grid_line_color,
                                         gp.intensity, gp.bias, output_color.rgb);
        }
        applyRainbow(output_color.rgb, original_pixel, vTexCoord, light_pos);
        if (polarizer_after_rainbow) applyPolarizer(output_color.rgb);
        applyGlare(output_color.rgb, vTexCoord, light_pos);
    }

    // Anti-banding dither
    output_color.rgb += (hash(gl_FragCoord.xy) - 0.5) / 255.0;

    // output_color is ready — main() continues in including file
