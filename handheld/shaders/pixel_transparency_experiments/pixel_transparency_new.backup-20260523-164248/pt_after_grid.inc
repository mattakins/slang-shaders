/*
    Pixel Transparency — After-Grid Pass Include
    v2.2 by mattakins
    Copyright (C) 2025 Matt Akins.

    Shared by both Pixel Transparency and Sunlight Shimmer after-grid passes.
    Define PT_SHIMMER before including for rainbow/glare (sunlight shimmer edition).

    Expects before #include:
    - push_constant 'param' with shared members
    - UBO 'global' with shared members
*/

// --- Vertex Shader ---

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
#ifdef PT_SHIMMER
layout(location = 1) out vec2 light_pos;
#endif

#ifdef PT_SHIMMER
vec2 getOrientedTilt(vec3 accel) {
    float magnitude = length(accel);
    if (magnitude < 0.01) return vec2(0.0);
    vec3 dir = accel / magnitude;
    return vec2(-dir.x, dir.y);
}
#endif

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

#ifdef PT_SHIMMER
    if (param.PT_SUNLIGHT_ENABLE > 0.5 && (param.PT_RAINBOW_ENABLE > 0.5 || param.PT_GLARE_ENABLE > 0.5)) {
        light_pos = vec2(param.LIGHT_X, param.LIGHT_Y);

        #ifdef _HAS_SENSOR_UNIFORMS
        if (param.ACCEL_ENABLE > 0.5) {
            vec3 accel = global.Accelerometer;
            bool has_sensors = length(accel) > 0.01;
            if (has_sensors) {
                vec2 gravity;
                if (param.ACCEL_RELATIVE > 0.5) {
                    vec3 rest = global.AccelerometerRest;
                    gravity = clamp(getOrientedTilt(accel) - getOrientedTilt(rest), vec2(-1.0), vec2(1.0));
                } else {
                    gravity = getOrientedTilt(accel);
                }
                gravity = clamp(gravity * param.ACCEL_SENSITIVITY, vec2(-1.0), vec2(1.0));
                light_pos += vec2(gravity.x, -gravity.y) * param.LIGHT_RANGE;
            }
        }
        #endif
    } else {
        light_pos = vec2(0.5, 0.5);
    }
#endif
}

// --- Fragment Shader ---

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
#ifdef PT_SHIMMER
layout(location = 1) in vec2 light_pos;
#endif
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D Original;
layout(set = 0, binding = 4) uniform sampler2D PassOutput0;

// ITU-R BT.709 perceptual luminance weights
#define LUMA_R 0.2126
#define LUMA_G 0.7152
#define LUMA_B 0.0722

float getPerceptualBrightness(vec3 color) {
    return (LUMA_R * color.r) + (LUMA_G * color.g) + (LUMA_B * color.b);
}

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

#ifdef PT_SHIMMER
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

// GBC Quarter-Wave Plate (QWP) chromatic dispersion model.
// Computes the spectral reflectance tint caused by the rear circular polarizer's
// QWP film. Uses cos²(4π·γ/λ) — warm, vivid rainbow with rich color cycling.
// Returns a normalized RGB tint (peak channel = 1.0).
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
#endif

void main() {
    vec3 grid_output = texture(Source, vTexCoord).rgb;
    vec3 pre_output = texture(PassOutput0, vTexCoord).rgb;
    vec3 original_pixel = texture(Original, vTexCoord).rgb;

    // Grid compositing — three modes via PT_GRID_ENABLE:
    //   0 = off: skip grid, use PT output (pre_output) directly
    //   1 = overlay: authentic_gbc_fast_overlay mode — grid_output = coverage × original_pixel,
    //               extract coverage factor and apply to pre_output
    //   2 = passthrough: grid shader received pre_output as Source and applied grid correctly,
    //               blend pre_output/grid_output with full modulation (simpletex, zfast, etc.)
    vec3 color;
    if (global.PT_GRID_ENABLE > 1.5) {
        // Passthrough: grid shader received pre_output as Source and applied grid correctly.
        // Blend between pre_output (no grid) and grid_output (gridded) with full modulation.
        vec3 scaled_grid = mix(pre_output, grid_output, global.PT_GRID_STRENGTH);

        float grid_mix = global.PT_GRID_MIX;
        if (global.PT_GRID_FADE > 0.001) {
            float brightness = getPerceptualBrightness(original_pixel);
            float transparency = clamp(global.PT_BASE_ALPHA * brightness * 2.665, 0.0, 1.0);
            grid_mix *= 1.0 - transparency * global.PT_GRID_FADE;
        }
        color = mix(pre_output, scaled_grid, grid_mix);

        if (global.PT_GRID_COUPLING > 0.001) {
            float pre_luma = getPerceptualBrightness(pre_output);
            float grid_luma = getPerceptualBrightness(color);
            float darkening = clamp(pre_luma - grid_luma, 0.0, 1.0);
            color = mix(color, pre_output, darkening * global.PT_GRID_COUPLING);
        }
    } else if (global.PT_GRID_ENABLE > 0.5) {
        // Overlay extraction: grid_output = coverage × original_pixel (authentic_gbc_fast_overlay).
        // Divide by original_pixel to isolate pure geometric coverage, then apply to pre_output.
        vec3 safe_original = max(original_pixel, vec3(0.001));
        vec3 grid_factor = grid_output / safe_original;
        grid_factor = mix(vec3(1.0), grid_factor, global.PT_GRID_STRENGTH);
        vec3 gridded_pt = pre_output * grid_factor;

        float grid_mix = global.PT_GRID_MIX;
        if (global.PT_GRID_FADE > 0.001) {
            float brightness = getPerceptualBrightness(original_pixel);
            float transparency = clamp(global.PT_BASE_ALPHA * brightness * 2.665, 0.0, 1.0);
            grid_mix *= 1.0 - transparency * global.PT_GRID_FADE;
        }
        color = mix(pre_output, gridded_pt, grid_mix);

        // Grid-transparency coupling — gridline darkness pushes pixels toward backing
        if (global.PT_GRID_COUPLING > 0.001) {
            float pre_luma = getPerceptualBrightness(pre_output);
            float grid_luma = getPerceptualBrightness(color);
            float darkening = clamp(pre_luma - grid_luma, 0.0, 1.0);
            color = mix(color, pre_output, darkening * global.PT_GRID_COUPLING);
        }
    } else {
        // Off: ignore pass 1, output PT compositing only.
        color = pre_output;
    }

#ifdef PT_SHIMMER
    // Polarizer ORDER=2: before rainbow (non-physical — tints base before spectral dispersion)
    if (global.PT_POLARIZER_ORDER > 1.5 && global.PT_POLARIZER > 0.5 && global.PT_POLARIZER_TINT > 0.001) {
        vec3 polarizer = mix(vec3(1.0), vec3(0.94, 1.0, 0.865), global.PT_POLARIZER_TINT);
        color *= polarizer;
    }

    // Rainbow — QWP chromatic dispersion
    if (param.PT_SUNLIGHT_ENABLE > 0.5 && (param.PT_RAINBOW_ENABLE > 0.5 || param.PT_GLARE_ENABLE > 0.5)) {
        float aspect_ratio = param.OutputSize.x / param.OutputSize.y;
        vec2 to_light = (vTexCoord - light_pos) * vec2(aspect_ratio, 1.0);
        float dist_xy = length(to_light);

        if (param.PT_RAINBOW_ENABLE > 0.5 && global.PT_RAINBOW_INTENSITY > 0.001) {
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
                vec2 noise_uv = vec2(vTexCoord.x * aspect_ratio, vTexCoord.y);
                float noise = filmNoise(noise_uv, global.PT_FILM_SCALE) - 0.4375;
                gamma_eff *= (1.0 + noise * global.PT_FILM_NOISE);
            }

            vec3 tint = qwpSpectralTint(gamma_eff);
            float tint_strength = global.PT_RAINBOW_INTENSITY;
            float reflectivity = mix(0.03, 1.0, getPerceptualBrightness(original_pixel));
            tint_strength *= reflectivity;
            tint *= original_pixel * original_pixel;

            // Grid compensation — boost rainbow to offset grid darkening
            if (global.PT_RAINBOW_GRID_COMP > 0.001) {
                float darkening = clamp(pre_output.g - color.g, 0.0, 1.0);
                tint_strength *= 1.0 + darkening * global.PT_RAINBOW_GRID_COMP * 3.0;
            }

            // Suppress rainbow on pixels where the grid added brightness (e.g. simpletex
            // white gridlines). Rainbow tints reflected game light, not grid-added light.
            float grid_brightening = clamp(getPerceptualBrightness(color) - getPerceptualBrightness(pre_output), 0.0, 1.0);
            tint_strength *= 1.0 - grid_brightening;

            vec3 tinted = color * mix(vec3(1.0), tint, tint_strength);
            float orig_luma = getPerceptualBrightness(color);
            float tinted_luma = getPerceptualBrightness(tinted);
            if (tinted_luma > 0.001) tinted *= orig_luma / tinted_luma;
            color = tinted;
        }

        // Polarizer ORDER=1: after rainbow, before glare (physically correct)
        if (global.PT_POLARIZER_ORDER > 0.5 && global.PT_POLARIZER_ORDER < 1.5 && global.PT_POLARIZER > 0.5 && global.PT_POLARIZER_TINT > 0.001) {
            vec3 polarizer = mix(vec3(1.0), vec3(0.94, 1.0, 0.865), global.PT_POLARIZER_TINT);
            color *= polarizer;
        }

        // Specular glare
        if (param.PT_GLARE_ENABLE > 0.5 && global.PT_GLARE_INTENSITY > 0.001) {
            float size_sq = global.PT_GLARE_SIZE * global.PT_GLARE_SIZE;
            float glare_strength = exp(-dist_xy * dist_xy / (2.0 * size_sq)) * global.PT_GLARE_INTENSITY;
            color = mix(color, vec3(1.0), clamp(glare_strength, 0.0, 0.85));
        }
    } else {
        // Sunlight disabled — still apply polarizer if ORDER=1 or 2
        if (global.PT_POLARIZER_ORDER > 0.5 && global.PT_POLARIZER > 0.5 && global.PT_POLARIZER_TINT > 0.001) {
            vec3 polarizer = mix(vec3(1.0), vec3(0.94, 1.0, 0.865), global.PT_POLARIZER_TINT);
            color *= polarizer;
        }
    }
#else
    // Non-shimmer: polarizer applies here when ORDER=1 or 2
    if (global.PT_POLARIZER_ORDER > 0.5 && global.PT_POLARIZER > 0.5 && global.PT_POLARIZER_TINT > 0.001) {
        vec3 polarizer = mix(vec3(1.0), vec3(0.94, 1.0, 0.865), global.PT_POLARIZER_TINT);
        color *= polarizer;
    }
#endif

    // Anti-banding dither
    color += (hash(gl_FragCoord.xy) - 0.5) / 255.0;

    FragColor = vec4(color, 1.0);
}
