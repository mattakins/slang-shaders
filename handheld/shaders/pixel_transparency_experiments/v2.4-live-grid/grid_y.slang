#version 450
// Authentic and LCD Grid v2 share narrow caches at the output pixel spacing.
#pragma name PTGridY
#pragma format R32G32B32A32_SFLOAT
#include "parameters.inc"
#define PT_GRID_OVERLAY_ONLY
#define PT_GRID_AXIS_ONLY
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
void prepareLCD();
void main() { gl_Position = global.MVP * Position; prepareLCD(); }
#pragma stage fragment
layout(location = 0) out vec4 FragColor;
#include "../v2.4-grid-axis-cache/grid.inc"
#include "../v2.4-integrated-grids/grids/lcd-grid-v2/integral.inc"
#pragma stage fragment
void main() {
    if (global.PT_GRID_STYLE > 2.5 && global.PT_GRID_STYLE < 3.5) {
        if (int(gl_FragCoord.x) > 0) { FragColor = vec4(0.0); return; }
        float coordinate = gl_FragCoord.y / global.FinalViewportSize.y / global.OriginalSize.w - 0.4999;
        float origin = floor(coordinate);
        float phase = coordinate - origin;
        float width = global.FinalViewportSize.w / global.OriginalSize.w;
        FragColor = vec4(intsmear(phase, width, 0.63, coeffs_y),
                         intsmear(phase - 1.0, width, 0.63, coeffs_y), origin, 0.0);
        return;
    }
    if (global.PT_GRID_STYLE > 0.5) { FragColor = vec4(0.0); return; }
    float coordinate = gl_FragCoord.y * global.OriginalSize.y / global.FinalViewportSize.y;
    float part = fract(coordinate);
    float neighbor = step(0.5, part) * 2.0 - 1.0;
    vec3 first0, second0, first1, second1;
    vertical_coverage(-part * lcd_scale.y, first0, second0);
    vertical_coverage((neighbor - part) * lcd_scale.y, first1, second1);
    int stripe = int(gl_FragCoord.x);
    vec3 value;
    if (stripe == 0) value = first0;
    else if (stripe == 1) value = second0;
    else if (stripe == 2) value = first1;
    else if (stripe == 3) value = second1;
    else if (stripe == 4) value = first0 + first1;
    else value = second0 + second1;
    // Cache the sampling decisions alongside their weights. At half-cell
    // boundaries, different render targets can round coordinates differently.
    float metadata = stripe == 0 ? floor(coordinate) :
                     stripe == 1 ? neighbor : 4.0 * lcd_coord.z * lcd_coord.z;
    FragColor = vec4(value, metadata);
}
