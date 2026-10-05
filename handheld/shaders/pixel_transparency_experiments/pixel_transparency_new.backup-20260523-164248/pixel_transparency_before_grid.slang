#version 450

/*
  ____  _          _
 |  _ \(_)_  _____| |
 | |_) | \ \/ / _ \ |
 |  __/| |>  <  __/ |
 |_|___|_/_/\_\___|_|
 |_   _| __ __ _ _ __  ___ _ __   __ _ _ __ ___ _ __   ___ _   _
   | || '__/ _` | '_ \/ __| '_ \ / _` | '__/ _ \ '_ \ / __| | | |
   | || | | (_| | | | \__ \ |_) | (_| | | |  __/ | | | (__| |_| |
   |_||_|  \__,_|_| |_|___/ .__/ \__,_|_|  \___|_| |_|\___|\__, |
                          |_|             BEFORE-GRID PASS  |___/
    v2.2 by mattakins
    Copyright (C) 2025 Matt Akins.

    Grid shaders look great on Game Boy Color games - except for one glaring issue.

    With no backlight, the original devices didn't render white pixels. Light pixels
    appeared as transparent areas where the backing material of the screen showed through.
    Many games relied on this effect for transparent backgrounds that now render on modern
    displays as eye-searing white pixels. No more! Pixel Transparency simulates this unique effect.

    Just choose your favorite LCD grid preset to reduce eye strain and maximize nostalgia.

    3-pass pipeline: before (this) → grid → after
    Compositing, shadows, polarizer, highlights, saturation.
    Shared by both Pixel Transparency and Sunlight Shimmer after passes.

*/

#pragma parameter PT_ENABLE 			"=== Pixel Transparency v2.2 === (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_HIDE_CONTENT 		" *  3-pass: before grid → grid → after grid" 0.0 0.0 2.0 1.0

// Claim pass 2 grid control slots so they appear above pass 1's grid shader params
#pragma parameter PT_GRID_ENABLE 		"== GRID == (0=Off 1=Overlay 2=Pass-through)" 1.0 0.0 2.0 1.0
#pragma parameter PT_GRID_MIX 			"      ↳ Grid opacity" 1.0 0.0 1.0 0.05
#pragma parameter PT_GRID_FADE 			"      ↳ Fade on bright pixels" 0.0 0.0 1.0 0.05
#pragma parameter PT_GRID_COUPLING 		"      ↳ Grid-transparency coupling" 0.0 0.0 1.0 0.05

#pragma parameter SECTION1 				"== COLOR ==" 0.0 0.0 1.0 1.0
#pragma parameter PT_PALETTE 			"--- Backing tint (0=OFF, 1/2=Warm, 3/4=Neutral)" 3.0 0.0 4.0 1.0
#pragma parameter PT_PALETTE_INTENSITY 	"      ↳ Intensity" 1.0 0.0 2.0 0.05
#pragma parameter PT_BACKING_BRIGHTNESS "      ↳ Brightness" 0.48 0.20 0.65 0.01

#pragma parameter PT_POLARIZER 			"--- Front polarizer tint (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_POLARIZER_TINT 	"      ↳ Intensity" 1.0 0.0 1.0 0.05
#pragma parameter PT_POLARIZER_ORDER 	"      ↳ Order (0=Pre-grid 1=Post-rainbow 2=Pre-rainbow)" 1.0 0.0 2.0 1.0

#pragma parameter PT_SATURATION 		"--- Color saturation" 1.0 0.5 1.5 0.05

#pragma parameter PT_HIGHLIGHTS 		"--- Pixel brightness (0=OFF, -Dim / +Bright)" 0.05 -1.0 1.0 0.01

#pragma parameter SECTION2 				"== TRANSPARENCY ==" 0.0 0.0 1.0 1.0
#pragma parameter PT_PIXEL_MODE 		"--- Transparent pixels (0=White only, 1=Bright, 2=All)" 1.0 0.0 2.0 1.0
#pragma parameter PT_BASE_ALPHA 		"      ↳ Transparency amount" 0.20 0.0 1.0 0.01

#pragma parameter PT_THRESHOLD 			"--- White pixel detection threshold" 0.90 0.0 1.0 0.01

#pragma parameter PT_WHITE_BOOST 		"--- Boost white pixel transparency (OFF/ON)" 0.0 0.0 1.0 1.0
#pragma parameter PT_WHITE_TRANSPARENCY "      ↳ Boost amount" 0.50 0.0 1.0 0.01

#pragma parameter PT_BRIGHTNESS_MODE 	"--- Brightness mode (0=Simple, 1=Natural)" 1.0 0.0 1.0 1.0

#pragma parameter PT_SHADOW_ENABLE 		"== SHADOWS == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_MOTION 		"       Shadow motion (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_MAX_OFFSET 	"          ↳ Max offset" 2.50 0.0 30.0 0.5
#pragma parameter PT_SHADOW_MOTION_X 	"          ↳ Neutral X" 2.0 -30.0 30.0 0.5
#pragma parameter PT_SHADOW_MOTION_Y 	"          ↳ Neutral Y" 2.0 -30.0 30.0 0.5

#pragma parameter PT_SHADOW_OFFSET_X 	"      ↳ X offset" 3.0 -30.0 30.0 0.5
#pragma parameter PT_SHADOW_OFFSET_Y 	"      ↳ Y offset" 3.0 -30.0 30.0 0.5

#pragma parameter PT_SHADOW_OPACITY 	"      ↳ Opacity" 0.50 0.0 1.0 0.01
#pragma parameter PT_SHADOW_BLUR 		"      ↳ Blur amount" 1.0 0.0 5.0 0.1
#pragma parameter PT_SHADOW_FAST_BLUR 	"      ↳ Shadow quality (0=Fast, 1=High)" 1.0 0.0 1.0 1.0

#pragma parameter ACCEL_ENABLE 		"== MOTION == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter NOTE3 				" *  Motion enabled on latest RetroArch nightly build." 0.0 0.0 1.0 1.0
#pragma parameter ACCEL_RELATIVE 		"      ↳ Tilt neutral (0=Device flat, 1=From hold)" 0.0 0.0 1.0 1.0
#pragma parameter ACCEL_SENSITIVITY 	"      ↳ Tilt sensitivity" 1.0 0.1 5.0 0.05

#pragma parameter SECTION_GRID 			"== GRID SHADER PARAMS ==" 0.0 0.0 1.0 1.0

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    float ACCEL_ENABLE;
    float ACCEL_RELATIVE;
    float ACCEL_SENSITIVITY;
    float PT_SHADOW_MOTION;
    float PT_SHADOW_MAX_OFFSET;
    float PT_SHADOW_MOTION_X;
    float PT_SHADOW_MOTION_Y;
    float PT_SHADOW_OFFSET_X;
    float PT_SHADOW_OFFSET_Y;
    float PT_ENABLE;
    float PT_BRIGHTNESS_MODE;
    float PT_SHADOW_ENABLE;
    float PT_SHADOW_BLUR;
    float PT_SHADOW_OPACITY;
    float PT_THRESHOLD;
    float PT_SHADOW_FAST_BLUR;
    float PT_PIXEL_MODE;
    float PT_BASE_ALPHA;
} param;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    #ifdef _HAS_SENSOR_UNIFORMS
    vec3 Gyroscope;
    vec3 Accelerometer;
    vec3 AccelerometerRest;
    #endif
    float PT_HIDE_CONTENT;
    float PT_PALETTE;
    float PT_PALETTE_INTENSITY;
    float PT_BACKING_BRIGHTNESS;
    float PT_POLARIZER;
    float PT_POLARIZER_TINT;
    float PT_POLARIZER_ORDER;
    float PT_SATURATION;
    float PT_HIGHLIGHTS;
    float PT_WHITE_BOOST;
    float PT_WHITE_TRANSPARENCY;
} global;

// --- Vertex Shader ---

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 texel;
layout(location = 2) out float shadow_scale_factor;
layout(location = 3) out vec2 shadow_offset_raw;

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

    float scale_x = param.OutputSize.x / 640.0;
    float scale_y = param.OutputSize.y / 480.0;
    shadow_scale_factor = sqrt(scale_x * scale_y);

    vec2 gravity = vec2(0.0);

    #ifdef _HAS_SENSOR_UNIFORMS
    if (param.ACCEL_ENABLE > 0.5) {
        vec3 accel = global.Accelerometer;
        bool has_sensors = length(accel) > 0.01;
        if (has_sensors) {
            if (param.ACCEL_RELATIVE > 0.5) {
                vec3 rest = global.AccelerometerRest;
                gravity = clamp(getOrientedTilt(accel) - getOrientedTilt(rest), vec2(-1.0), vec2(1.0));
            } else {
                gravity = getOrientedTilt(accel);
            }
            gravity = clamp(gravity * param.ACCEL_SENSITIVITY, vec2(-1.0), vec2(1.0));
        }
    }
    #endif

    if (param.PT_SHADOW_MOTION > 0.5 && param.ACCEL_ENABLE > 0.5) {
        vec2 base = vec2(param.PT_SHADOW_MOTION_X, param.PT_SHADOW_MOTION_Y);
        shadow_offset_raw = base + gravity * param.PT_SHADOW_MAX_OFFSET;
    } else {
        shadow_offset_raw = vec2(param.PT_SHADOW_OFFSET_X, param.PT_SHADOW_OFFSET_Y);
    }
}

// --- Fragment Shader ---

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 texel;
layout(location = 2) in float shadow_scale_factor;
layout(location = 3) in vec2 shadow_offset_raw;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D Original;

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

vec3 generateProceduralBackground(vec2 uv) {
    vec3 baseColor = vec3(global.PT_BACKING_BRIGHTNESS);
    const float grainIntensity = 0.065;
    const float scale = 0.25;
    float grain = paperNoise(uv, scale);
    float grainOffset = (grain - 0.4375) * grainIntensity;
    return baseColor + vec3(grainOffset);
}

void main() {
    vec4 lcd_color = texture(Source, vTexCoord);
    vec3 original_pixel = texture(Original, vTexCoord).rgb;

    vec4 output_color = lcd_color;

    if (param.PT_ENABLE < 0.5) {
        FragColor = output_color;
        return;
    }

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

    vec4 background = vec4(generateProceduralBackground(vTexCoord), 1.0);

    // Drop shadows
    if (param.PT_SHADOW_ENABLE > 0.5 && global.PT_HIDE_CONTENT < 1.5) {
        vec2 shadow_offset = -shadow_offset_raw * shadow_scale_factor * texel;

        vec3 center_source = texture(Original, vTexCoord + shadow_offset).rgb;
        float shadow_strength = 0.0;

        if (param.PT_SHADOW_BLUR > 0.1) {
            vec2 blur_dist = param.PT_SHADOW_BLUR * shadow_scale_factor * texel;
            float blurred_shadow = 0.0;

            if (param.PT_SHADOW_FAST_BLUR < 0.5) {
                vec2 sample_offsets[5] = vec2[](
                        vec2(0.0, 0.0),
                        vec2(-1.0, 0.0),
                        vec2(1.0, 0.0),
                        vec2(0.0, -1.0),
                        vec2(0.0, 1.0)
                    );
                for (int i = 0; i < 5; i++) {
                    vec2 sample_pos = vTexCoord + shadow_offset + (sample_offsets[i] * blur_dist);
                    vec3 blur_sample = texture(Original, sample_pos).rgb;
                    float w = (i == 0) ? 4.0 : 2.0;
                    float blur_brightness = getBrightness(blur_sample);
                    blurred_shadow += (1.0 - blur_brightness) * w;
                }
                shadow_strength = (blurred_shadow / 12.0) * param.PT_SHADOW_OPACITY;
            } else {
                vec2 sample_offsets[9] = vec2[](
                        vec2(0.0, 0.0),
                        vec2(-1.0, 0.0),
                        vec2(1.0, 0.0),
                        vec2(0.0, -1.0),
                        vec2(0.0, 1.0),
                        vec2(-1.0, -1.0),
                        vec2(1.0, -1.0),
                        vec2(-1.0, 1.0),
                        vec2(1.0, 1.0)
                    );
                for (int i = 0; i < 9; i++) {
                    vec2 sample_pos = vTexCoord + shadow_offset + (sample_offsets[i] * blur_dist);
                    vec3 blur_sample = texture(Original, sample_pos).rgb;
                    float w = (i == 0) ? 4.0 : (i < 5 ? 2.0 : 1.0);
                    float blur_brightness = getBrightness(blur_sample);
                    blurred_shadow += (1.0 - blur_brightness) * w;
                }
                shadow_strength = (blurred_shadow / 16.0) * param.PT_SHADOW_OPACITY;
            }
        } else {
            float shadow_source_brightness = getBrightness(center_source);
            shadow_strength = (1.0 - shadow_source_brightness) * param.PT_SHADOW_OPACITY;
        }

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
                vec3(
                    bg_palette_color.r + mix(-1.0, 1.0, background.r),
                    bg_palette_color.g + mix(-1.0, 1.0, background.g),
                    bg_palette_color.b + mix(-1.0, 1.0, background.b)
                ), 0.0, 1.0
            );

        background.rgb = mix(background.rgb, tinted_background, global.PT_PALETTE_INTENSITY);
    }

    // Transparency compositing
    vec3 brightness_source = original_pixel;

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

    // Polarizer — gated by PT_POLARIZER_ORDER for 3-pass split
    // ORDER=0: apply here (legacy). ORDER=1: skip (post pass applies after rainbow).
    if (global.PT_POLARIZER_ORDER < 0.5) {
        if (global.PT_POLARIZER > 0.5 && global.PT_POLARIZER_TINT > 0.001) {
            vec3 polarizer = mix(vec3(1.0), vec3(0.94, 1.0, 0.865), global.PT_POLARIZER_TINT);
            output_color.rgb *= polarizer;
        }
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

    // No dither — after-grid pass handles it

    FragColor = output_color;
}
