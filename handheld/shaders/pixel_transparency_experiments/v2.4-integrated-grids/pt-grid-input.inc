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
                          |_|                               |___/

    PT | GRID INPUT
    v2.4 integrated grid pipeline

    Shared input pass for the five non-Authentic grid families.
    Reconstructs game pixels and applies the grid when placement is Below.
*/

#include "pt-grid-parameters.inc"
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
void main() { gl_Position = global.MVP * Position; vTexCoord = TexCoord; prepareLCD(); }
#include "pt-grid.inc"
#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D PTNativeInput;

void main() {
    if (global.PT_FUSED_LAYER > 0.5) {
        vec2 center = (floor(vTexCoord * global.OriginalSize.xy) + vec2(0.5)) * global.OriginalSize.zw;
        FragColor = vec4(texture(PTNativeInput, center).rgb, 1.0);
        return;
    }
#ifdef PT_GRID_LCD_GRID_V2
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
#else
#if defined(PT_GRID_SIMPLETEX_LCD) || defined(PT_GRID_ZFAST_LCD)
    vec2 coord = (floor(vTexCoord * global.OriginalSize.xy) + vec2(0.5)) * global.OriginalSize.zw;
#else
    vec2 coord = vTexCoord;
#endif
    FragColor = vec4(applyGrid(texture(PTNativeInput, coord).rgb, vTexCoord, param.OutputSize.xy), 1.0);
#endif
}
