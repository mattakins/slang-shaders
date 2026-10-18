#version 450
#define PT_MATRIX_RED 1
#define PT_MATRIX_GREEN 2
#define PT_MATRIX_BLUE 3
#include "parameters.inc"
#define PT_GRID_INPUT_ONLY
#define LCDInput PTNativeColour
#define prepareLCD prepareAuthentic
#define sampleLCD sampleAuthentic
layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    vec4 OriginalSize;
    vec4 FinalViewportSize;
    PT_LCD_UNIFORMS
} global;
layout(push_constant) uniform Push { vec4 OutputSize; } param;
#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
void prepareAuthentic();
void prepareGridMatrix();
void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
    prepareAuthentic();
    prepareGridMatrix();
}
#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D PTNativeColour;
layout(set = 0, binding = 3) uniform sampler2D PTNativeInput;
layout(set = 0, binding = 6) uniform sampler2D PTGridX;
layout(set = 0, binding = 7) uniform sampler2D PTGridY;
float getPerceptualBrightness(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
#include "../v2.4-grid-axis-cache/grid.inc"
#undef sampleLCD
#undef prepareLCD
#undef LCDInput
#include "matrix.inc"
#pragma stage fragment
#include "grid.inc"
void main() {
    if (global.PT_GRID_STYLE < 0.5) {
        FragColor = sampleAuthentic();
        return;
    }
    vec2 center = (floor(vTexCoord * global.OriginalSize.xy) + vec2(0.5)) * global.OriginalSize.zw;
    if (global.PT_FUSED_LAYER > 0.5) {
        FragColor = vec4(texture(PTNativeInput, center).rgb, 1.0);
    } else if (global.PT_GRID_STYLE > 2.5 && global.PT_GRID_STYLE < 3.5) {
        vec4 left, right, vertical;
        gridWeights(vTexCoord, left, right, vertical);
        vec2 origin = vec2(left.a, vertical.z);
        vec3 tl = gridLinear(texture(PTNativeInput, (origin + vec2(0.5, 0.5)) * global.OriginalSize.zw).rgb);
        vec3 br = gridLinear(texture(PTNativeInput, (origin + vec2(1.5, 1.5)) * global.OriginalSize.zw).rgb);
        vec3 bl = gridLinear(texture(PTNativeInput, (origin + vec2(0.5, 1.5)) * global.OriginalSize.zw).rgb);
        vec3 tr = gridLinear(texture(PTNativeInput, (origin + vec2(1.5, 0.5)) * global.OriginalSize.zw).rgb);
        vec3 color = tl * left.rgb * vertical.x + br * right.rgb * vertical.y
                   + bl * left.rgb * vertical.y + tr * right.rgb * vertical.x;
        FragColor = vec4(gridEncode(color), 0.0);
    } else {
        vec2 coord = global.PT_GRID_STYLE > 3.5 ? center : vTexCoord;
        FragColor = vec4(applyGrid(texture(PTNativeInput, coord).rgb, vTexCoord, param.OutputSize.xy), 1.0);
    }
}
