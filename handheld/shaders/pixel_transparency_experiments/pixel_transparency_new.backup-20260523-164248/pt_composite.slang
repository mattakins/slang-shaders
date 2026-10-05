#version 450

/*
    Pixel Transparency — Grid Compositor
    Blends the pre-grid PT pass (PassOutput0) with the grid pass (Source).
    Supports passthrough (mode 2) and overlay-extraction (mode 1) compositing
    with full grid modulation controls.

    Use as pass 2 in a 4-pass pipeline:
        pass 0: sunlight_shimmer.slang  (transparency + rainbow)
        pass 1: grid shader
        pass 2: pt_composite.slang      (this file)
        pass 3: handheld/shaders/glare.slang
*/

#pragma parameter PT_GRID_ENABLE   "== GRID == (0=Off 1=Overlay 2=Pass-through)" 2.0 0.0 2.0 1.0
#pragma parameter PT_GRID_MIX      "      ↳ Grid opacity"                        1.0 0.0 1.0 0.05
#pragma parameter PT_GRID_STRENGTH "      ↳ Grid darkness"                       1.0 0.0 1.0 0.05
#pragma parameter PT_GRID_FADE     "      ↳ Fade on bright pixels"               0.0 0.0 1.0 0.05
#pragma parameter PT_GRID_COUPLING "      ↳ Grid-transparency coupling"          0.0 0.0 1.0 0.05
#pragma parameter PT_BASE_ALPHA    "      ↳ Transparency amount"                 0.20 0.0 1.0 0.01

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    float PT_GRID_ENABLE;
    float PT_GRID_MIX;
    float PT_GRID_STRENGTH;
    float PT_GRID_FADE;
    float PT_GRID_COUPLING;
    float PT_BASE_ALPHA;
} param;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

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
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D Original;
layout(set = 0, binding = 4) uniform sampler2D PassOutput0;

#define LUMA_R 0.2126
#define LUMA_G 0.7152
#define LUMA_B 0.0722

float getPerceptualBrightness(vec3 color) {
    return (LUMA_R * color.r) + (LUMA_G * color.g) + (LUMA_B * color.b);
}

void main() {
    vec3 grid_output    = texture(Source,      vTexCoord).rgb;
    vec3 pre_output     = texture(PassOutput0, vTexCoord).rgb;
    vec3 original_pixel = texture(Original,    vTexCoord).rgb;

    vec3 color;

    if (param.PT_GRID_ENABLE > 1.5) {
        // Passthrough: grid shader received pre_output as Source.
        vec3 scaled_grid = mix(pre_output, grid_output, param.PT_GRID_STRENGTH);

        float grid_mix = param.PT_GRID_MIX;
        if (param.PT_GRID_FADE > 0.001) {
            float brightness   = getPerceptualBrightness(original_pixel);
            float transparency = clamp(param.PT_BASE_ALPHA * brightness * 2.665, 0.0, 1.0);
            grid_mix *= 1.0 - transparency * param.PT_GRID_FADE;
        }
        color = mix(pre_output, scaled_grid, grid_mix);

        if (param.PT_GRID_COUPLING > 0.001) {
            float pre_luma  = getPerceptualBrightness(pre_output);
            float grid_luma = getPerceptualBrightness(color);
            float darkening = clamp(pre_luma - grid_luma, 0.0, 1.0);
            color = mix(color, pre_output, darkening * param.PT_GRID_COUPLING);
        }

    } else if (param.PT_GRID_ENABLE > 0.5) {
        // Overlay extraction: grid_output = coverage × original_pixel (authentic_gbc_fast_overlay).
        vec3 safe_original = max(original_pixel, vec3(0.001));
        vec3 grid_factor   = grid_output / safe_original;
        grid_factor        = mix(vec3(1.0), grid_factor, param.PT_GRID_STRENGTH);
        vec3 gridded_pt    = pre_output * grid_factor;

        float grid_mix = param.PT_GRID_MIX;
        if (param.PT_GRID_FADE > 0.001) {
            float brightness   = getPerceptualBrightness(original_pixel);
            float transparency = clamp(param.PT_BASE_ALPHA * brightness * 2.665, 0.0, 1.0);
            grid_mix *= 1.0 - transparency * param.PT_GRID_FADE;
        }
        color = mix(pre_output, gridded_pt, grid_mix);

        if (param.PT_GRID_COUPLING > 0.001) {
            float pre_luma  = getPerceptualBrightness(pre_output);
            float grid_luma = getPerceptualBrightness(color);
            float darkening = clamp(pre_luma - grid_luma, 0.0, 1.0);
            color = mix(color, pre_output, darkening * param.PT_GRID_COUPLING);
        }

    } else {
        color = pre_output;
    }

    FragColor = vec4(color, 1.0);
}
