#version 450
// Keep grid geometry out of the transparency compositor.
#pragma name PTGridCoverage
#pragma format R16G16B16A16_SFLOAT
#include "grid_parameters.inc"
#define PT_GRID_OVERLAY_ONLY
layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    vec4 OriginalSize;
    PT_LCD_UNIFORMS
} global;
layout(push_constant) uniform Push { vec4 OutputSize; } param;
#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
void prepareLCD();
void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
    prepareLCD();
}
#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Original;
#include "grid.inc"
#pragma stage fragment
void main() {
    // A uniform bypass avoids coverage work for the default below-effects mode.
    if (global.PT_FUSED_LAYER < 0.5) {
        FragColor = vec4(1.0);
        return;
    }
    ivec2 cell, offset;
    vec3 w0, w1, w2, w3;
    float area;
    lcdWeights(cell, offset, w0, w1, w2, w3, area);
    vec3 coverage = clamp((w0 + w1 + w2 + w3) / area, 0.0, 1.0);
    float strength = global.PT_FUSED_STRENGTH;
    if (global.PT_FUSED_BIAS > 0.0) {
        float luma = dot(texture(Original, vTexCoord).rgb, vec3(0.2126, 0.7152, 0.0722));
        strength *= mix(1.0, luma, global.PT_FUSED_BIAS);
    }
    FragColor = vec4(mix(vec3(1.0), coverage, strength), 1.0);
}
