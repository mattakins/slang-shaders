#version 450

/*
    Reflective LCD Off-Axis Viewing Angle
    v1.0 by mattakins
    Copyright (C) 2025 Matt Akins.

    Simulates the subtle legibility, contrast, and color shifts of a reflective
    color LCD viewed off-axis. The GBC-sized panel should shift as a whole with
    only mild edge variation.

    Driven by tilt (accelerometer) only; no virtual light source.
*/

#pragma parameter OFFAXIS_ENABLE   "=== Off-axis === (OFF/ON)"         1.0 0.0 1.0 1.0
#pragma parameter OFFAXIS_INTENSITY "      ↳ Strength"                 0.25 0.0 1.0 0.05
#pragma parameter OFFAXIS_GAMMA    "      ↳ Gamma shift"               0.5 0.0 2.0 0.05
#pragma parameter OFFAXIS_CONTRAST "      ↳ Contrast shift"            0.45 0.0 1.0 0.05
#pragma parameter OFFAXIS_HUE      "      ↳ Hue shift"                 0.1 0.0 1.0 0.05
#pragma parameter OFFAXIS_SPATIAL  "      ↳ Spatial gradient (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter OFFAXIS_TN      "      ↳ Reflective LCD mode (0=Simple 1=GBC)" 1.0 0.0 1.0 1.0

#pragma parameter ACCEL_ENABLE      "== MOTION == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter ACCEL_SENSITIVITY "      ↳ Tilt sensitivity" 1.0 0.1 5.0 0.05

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    float OFFAXIS_ENABLE;
    float OFFAXIS_INTENSITY;
    float OFFAXIS_GAMMA;
    float OFFAXIS_CONTRAST;
    float OFFAXIS_HUE;
    float OFFAXIS_SPATIAL;
    float OFFAXIS_TN;
    float ACCEL_ENABLE;
    float ACCEL_SENSITIVITY;
} param;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    #ifdef _HAS_SENSOR_UNIFORMS
    vec3 Gyroscope;
    vec3 Accelerometer;
    vec3 AccelerometerRest;
    #endif
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 gravity;

vec2 getOrientedTilt(vec3 accel) {
    float magnitude = length(accel);
    if (magnitude < 0.01) return vec2(0.0);
    vec3 dir = accel / magnitude;
    return vec2(-dir.x, dir.y);
}

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
    gravity = vec2(0.0);

    #ifdef _HAS_SENSOR_UNIFORMS
    if (param.OFFAXIS_ENABLE > 0.5 && param.ACCEL_ENABLE > 0.5) {
        vec3 accel = global.Accelerometer;
        if (length(accel) > 0.01) {
            vec3 rest = global.AccelerometerRest;
            gravity = clamp(getOrientedTilt(accel) - getOrientedTilt(rest), vec2(-1.0), vec2(1.0));
            gravity = clamp(gravity * param.ACCEL_SENSITIVITY, vec2(-1.0), vec2(1.0));
        }
    }
    #endif
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 gravity;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
    vec3 color = texture(Source, vTexCoord).rgb;

    if (param.OFFAXIS_ENABLE > 0.5) {
        // RetroArch's accelerometer orientation is opposite the screen-side response we want.
        float tilt_y = -gravity.y;
        float tilt_x = -gravity.x;

        if (param.OFFAXIS_TN > 0.5) {
            // GBC mode: vertical and horizontal axes kept separate.
            // Vertical off-axis dominates; horizontal contributes more mildly.
            float angle_y, angle_x;
            if (param.OFFAXIS_SPATIAL > 0.5) {
                angle_y = tilt_y * (0.65 + (vTexCoord.y - 0.5) * 0.7) * param.OFFAXIS_INTENSITY;
                angle_x = tilt_x * (0.65 + (vTexCoord.x - 0.5) * 0.7) * param.OFFAXIS_INTENSITY;
            } else {
                angle_y = tilt_y * param.OFFAXIS_INTENSITY;
                angle_x = tilt_x * 0.5 * param.OFFAXIS_INTENSITY;
            }

            // Vertical dominates; horizontal contributes mildly on the small GBC panel.
            float off_angle = angle_y + angle_x * 0.2;

            // Gamma — positive = from above (wash out), negative = from below (darken)
            float gamma_factor = 1.0 + off_angle * param.OFFAXIS_GAMMA;
            gamma_factor = max(gamma_factor, 0.1);
            color = pow(max(color, vec3(0.0)), vec3(1.0 / gamma_factor));

            // Contrast: asymmetric. From above: blacks lift. From below: whites compress
            // + inversion tendency — darks lift toward grey as TN cell response begins to flip.
            float black_lift = max(off_angle, 0.0) * param.OFFAXIS_CONTRAST * 0.1;
            float white_compress = max(-off_angle, 0.0) * param.OFFAXIS_CONTRAST * 0.05;
            float inv_depth = max(-off_angle - 0.2, 0.0) * param.OFFAXIS_CONTRAST;
            float inv_luma = 1.0 - dot(color, vec3(0.2126, 0.7152, 0.0722));
            color = color * (1.0 - white_compress) + vec3(black_lift + inv_depth * inv_luma * 0.15);

            // Subtle warm cast when the reflective stack washes out.
            float warm_strength = clamp(angle_y * param.OFFAXIS_HUE, 0.0, 1.0);
            color *= mix(vec3(1.0), vec3(1.0, 0.97, 0.93), warm_strength);

            // Side tilt mostly reduces color confidence rather than fully shifting hue.
            float side_strength = clamp(abs(angle_x) * param.OFFAXIS_HUE * 0.35, 0.0, 1.0);
            float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
            color = mix(color, vec3(luma), side_strength);

        } else {
            // Simple: symmetric gamma/contrast, warm shift on all off-axis directions.
            float off_angle;
            if (param.OFFAXIS_SPATIAL > 0.5) {
                float pixel_tilt = tilt_y * (vTexCoord.y - 0.5) * 2.0
                                 + tilt_x * (vTexCoord.x - 0.5) * 2.0;
                off_angle = pixel_tilt * param.OFFAXIS_INTENSITY;
            } else {
                off_angle = (tilt_y + tilt_x * 0.5) * param.OFFAXIS_INTENSITY;
            }

            float gamma_factor = 1.0 + off_angle * param.OFFAXIS_GAMMA;
            gamma_factor = max(gamma_factor, 0.1);
            color = pow(max(color, vec3(0.0)), vec3(1.0 / gamma_factor));

            float black_lift = max(off_angle * param.OFFAXIS_CONTRAST * 0.1, 0.0);
            float white_compress = max(-off_angle * param.OFFAXIS_CONTRAST * 0.05, 0.0);
            color = color * (1.0 - white_compress) + vec3(black_lift);

            float hue_strength = abs(off_angle) * param.OFFAXIS_HUE;
            color *= mix(vec3(1.0), vec3(1.0, 0.97, 0.93), hue_strength);
        }
    }

    FragColor = vec4(color, 1.0);
}
