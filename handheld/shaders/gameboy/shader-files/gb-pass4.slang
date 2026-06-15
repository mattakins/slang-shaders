#version 450

  /////////////////////////////////////////////////////////////////////////
//    _________    __  _________   ____  ______  __                      //
//   / ____/   |  /  |/  / ____/  / __ )/ __ \ \/ /                      //
//  / / __/ /| | / /|_/ / __/    / __  / / / /\  /                       //
// / /_/ / ___ |/ /  / / /___   / /_/ / /_/ / / /                        //
// \____/_/  |_/_/  /_/_____/  /_____/\____/ /_/                         //
//  ==================== DOT MATRIX SHADER v1.3                          //
//                                                                       //
// Copyright (C) 2013 Harlequin : unknown92835@gmail.com                 //
// Copyright (C) 2024-2026 Matt Akins                                    //
//                                                                       //
// This program is free software: you can redistribute it and/or modify  //
// it under the terms of the GNU General Public License as published by  //
// the Free Software Foundation, either version 3 of the License, or     //
// (at your option) any later version.                                   //
//                                                                       //
// This program is distributed in the hope that it will be useful,       //
// but WITHOUT ANY WARRANTY; without even the implied warranty of        //
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         //
// GNU General Public License for more details.                          //
//                                                                       //
// You should have received a copy of the GNU General Public License     //
// along with this program.  If not, see <http://www.gnu.org/licenses/>. //
//                                                                       //
/////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////
 // gb-pass4 - Final compositing with background & shadows              //
/////////////////////////////////////////////////////////////////////////

#include "gb-params.inc"

layout(push_constant) uniform Push
{
	vec4 OutputSize;
	vec4 OriginalSize;
	vec4 SourceSize;
	vec4 PassOutputSize1;
	float contrast;
	float screen_light;
	float pixel_opacity;
	float bg_smoothing;
	float shadow_opacity;
	float baseline_alpha;
	float shadow_offset_x;
	float shadow_offset_y;
	float screen_offset_x;
	float screen_offset_y;
	float shadow_enable;
	float palette;
	float integer_mode;
	float shadow_motion;
	float shadow_max_offset;
	float shadow_edge_clamp_debug;
} registers;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    #ifdef _HAS_SENSOR_UNIFORMS
    vec3 Gyroscope;
    vec3 Accelerometer;
    vec3 AccelerometerRest;
    #endif
    float video_scale;
    float shadow_scale_mode;
} global;

  /////////////////////////////////////////////////////////////////////////
 // Vertex shader                                                       //
/////////////////////////////////////////////////////////////////////////

vec2 get_current_gb_scale() {
    if (registers.integer_mode > 1.5) {
        return vec2(global.video_scale);
    } else if (registers.integer_mode > 0.5) {
        return vec2(floor(registers.OutputSize.y * registers.OriginalSize.w));
    }
    return registers.OutputSize.xy * registers.OriginalSize.zw;
}

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 texel;
layout(location = 2) out vec2 shadow_offset;

vec2 getOrientedTilt(vec3 accel) {
    float magnitude = length(accel);
    if (magnitude < 0.01) return vec2(0.0);
    vec3 dir = accel / magnitude;
    return vec2(-dir.x, dir.y);
}

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord * 1.0001;

    vec2 gravity = vec2(0.0);

    #ifdef _HAS_SENSOR_UNIFORMS
    if (registers.shadow_motion > 0.5) {
        vec3 accel = global.Accelerometer;
        bool has_sensors = length(accel) > 0.01;
        if (has_sensors) {
            gravity = getOrientedTilt(accel);
        }
    }
    #endif

    vec2 shadow_offset_px = vec2(registers.shadow_offset_x, registers.shadow_offset_y);
    if (registers.shadow_motion > 0.5) {
        shadow_offset_px += gravity * registers.shadow_max_offset;
    }

    float scale_x = registers.OutputSize.x / 640.0;
    float scale_y = registers.OutputSize.y / 480.0;
    vec2 remote_shadow_step = registers.SourceSize.zw * sqrt(scale_x * scale_y);
    vec2 reference_shadow_step = registers.SourceSize.zw * (get_current_gb_scale() / GB_LCD_REFERENCE_SCALE);
    vec2 shadow_step = (global.shadow_scale_mode > 0.5) ? reference_shadow_step : remote_shadow_step;
    shadow_offset = shadow_offset_px * shadow_step;

    texel = registers.SourceSize.zw;
}

  /////////////////////////////////////////////////////////////////////////
 // Fragment definitions                                                //
/////////////////////////////////////////////////////////////////////////

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 texel;
layout(location = 2) in vec2 shadow_offset;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D Source;
layout(set = 0, binding = 2) uniform sampler2D PassOutput1;
layout(set = 0, binding = 3) uniform sampler2D BACKGROUND;
layout(set = 0, binding = 4) uniform sampler2D COLOR_PALETTE;

// Background palette color selection
vec4 get_bg_color() {
    if (registers.palette < 0.5) {
        return texture(COLOR_PALETTE, vec2(0.25, 0.5)); // 0: Original texture
    } else if (registers.palette < 1.5) {
        return vec4(0.651, 0.675, 0.518, 1.0); // 1: #A6AC84
    } else if (registers.palette < 2.5) {
        return vec4(0.737, 0.737, 0.737, 1.0); // 2: #BCBCBC
    } else if (registers.palette < 3.5) {
        return vec4(1.0, 1.0, 1.0, 1.0); // 3: #FFFFFF
    } else if (registers.palette < 4.5) {
        return vec4(0.627, 0.667, 0.024, 1.0); // 4: #A0AA06
    } else if (registers.palette < 5.5) {
        return vec4(0.027, 0.729, 0.369, 1.0); // 5: #07BA5E
    } else {
        return vec4(0.027, 0.729, 0.608, 1.0); // 6: #07BA9B
    }
}

#define bg_color get_bg_color()

#define shadow_alpha (registers.contrast * registers.shadow_opacity * registers.shadow_enable)

float inside_range(float value, float lower, float upper) {
    return step(lower, value) * step(value, upper);
}

float inside_rect(vec2 coord, vec2 lower, vec2 upper) {
    return inside_range(coord.x, lower.x, upper.x) *
           inside_range(coord.y, lower.y, upper.y);
}

float soft_inside_range(float value, float lower, float upper, float feather) {
    return smoothstep(lower - feather, lower + feather, value) *
           (1.0 - smoothstep(upper - feather, upper + feather, value));
}

float soft_inside_rect(vec2 coord, vec2 lower, vec2 upper, vec2 feather) {
    return soft_inside_range(coord.x, lower.x, upper.x, feather.x) *
           soft_inside_range(coord.y, lower.y, upper.y, feather.y);
}

  /////////////////////////////////////////////////////////////////////////
 // Fragment shader                                                     //
/////////////////////////////////////////////////////////////////////////

void main()
{
    vec2 tex = floor(registers.PassOutputSize1.xy * vTexCoord);
    tex = (tex + 0.5) * registers.PassOutputSize1.zw;

    // Cache background color to avoid multiple function calls
    vec4 bg_color_cached = get_bg_color();

    // Preserve the historical one-texel compositor alignment, separately from
    // the user-facing texel screen nudge. Fullscreen gets a one-texel baseline
    // nudge to match a 1,1 offset without changing pixel-perfect positioning.
    vec2 compositor_alignment = -texel;
    vec2 fullscreen_alignment = (registers.integer_mode < 0.5) ? texel : vec2(0.0);
    vec2 screen_offset = compositor_alignment + fullscreen_alignment + vec2(
        registers.screen_offset_x * texel.x,
        registers.screen_offset_y * texel.y
    );

    // Sample all the relevant textures
    vec4 foreground = texture(PassOutput1, tex - screen_offset);
    vec4 background = texture(BACKGROUND, vTexCoord);
    vec2 shadow_sample = vTexCoord - (shadow_offset + screen_offset);
    vec4 shadows = texture(Source, shadow_sample);

    vec2 gb_scale = get_current_gb_scale();
    vec2 source_bounds = min((registers.OriginalSize.xy * gb_scale) * registers.SourceSize.zw, vec2(1.0));
    vec2 source_min = vec2(0.5) - source_bounds * 0.5;
    vec2 source_max = vec2(0.5) + source_bounds * 0.5;
    vec2 screen_min = source_min + screen_offset;
    vec2 screen_max = source_max + screen_offset;
    vec2 shadow_min = screen_min + shadow_offset;
    vec2 shadow_max = screen_max + shadow_offset;
    vec2 shadow_feather = texel * 4.0;
    if (global.shadow_scale_mode > 0.5) {
        shadow_feather *= gb_scale / GB_LCD_REFERENCE_SCALE;
    }
    float inside_screen = inside_rect(vTexCoord, screen_min, screen_max);
    float screen_shadow = soft_inside_rect(vTexCoord, shadow_min, shadow_max, shadow_feather);
    shadows.a = max(shadows.a, registers.baseline_alpha * screen_shadow * (1.0 - inside_screen));

    if (registers.shadow_edge_clamp_debug > 0.5) {
        vec2 legacy_source_max = source_max - texel;
        vec2 legacy_screen_min = source_min + screen_offset;
        vec2 legacy_screen_max = legacy_source_max + screen_offset;
        vec2 shadow_sample_clamped = clamp(shadow_sample, vec2(0.0), vec2(1.0) - texel);
        vec2 screen_shadow_sample = clamp(vTexCoord - screen_offset, vec2(0.0), vec2(1.0) - texel);
        float legacy_inside_screen = inside_rect(vTexCoord, legacy_screen_min, legacy_screen_max);
        float baseline_shadow = min(texture(Source, screen_shadow_sample).a, registers.baseline_alpha);
        shadows = texture(Source, shadow_sample_clamped);
        shadows.a = max(shadows.a, baseline_shadow) * legacy_inside_screen;
    }

    // Foreground and background are blended with the background color
    foreground *= bg_color_cached;

    float bg_test = 0.0;
    if ( foreground.a > 0.0 )
        bg_test = 1.0;

    background -= (background - 0.5) * registers.bg_smoothing * bg_test;

    // Allows for highlights,
    // background = bg_color when the background color is 0.5 gray
    background.rgb = clamp(
        vec3(
            bg_color_cached.r + mix(-1.0, 1.0, background.r),
            bg_color_cached.g + mix(-1.0, 1.0, background.g),
            bg_color_cached.b + mix(-1.0, 1.0, background.b)
        ),
        0.0, 1.0
    );

    // Shadows are alpha blended with the background.
    vec4 out_color = (shadows * shadows.a * shadow_alpha) + (background * (1.0 - shadows.a * shadow_alpha));

    // Foreground is alpha blended with the shadowed background
    out_color = (foreground * foreground.a * registers.contrast) + (out_color * (registers.screen_light - foreground.a * registers.contrast * registers.pixel_opacity));

    FragColor = out_color;
}