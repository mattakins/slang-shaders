#version 450
// Copyright (C) 2025-2026 Matt Akins.
// Restore native input after the shadow cache, before the unchanged LCD chain.
// Preserve sampled RGB565 values without an extra 8-bit rounding step.
#pragma format R32G32B32A32_SFLOAT
layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;

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
layout(set = 0, binding = 2) uniform sampler2D Original;
void main() {
    FragColor = vec4(texture(Original, vTexCoord).rgb, 1.0);
}
