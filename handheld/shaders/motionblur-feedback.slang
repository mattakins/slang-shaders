#version 450

// Motion blur feedback that reads its own previous output through the
// MotionBlur alias, so it can sit at any pass index. The shared
// motionblur/shaders/feedback.slang reads PassFeedback0 and only works as
// the first pass.

layout(push_constant) uniform Push
{
    float mixfactor;
} param;

#pragma parameter mixfactor "Motionblur Fadeout" 0.75 0.0 1.0 0.01

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord   = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D MotionBlurFeedback;

void main()
{
    vec4 current = pow(texture(Source,             vTexCoord), vec4(2.2));
    vec4 fdback  = pow(texture(MotionBlurFeedback, vTexCoord), vec4(2.2));
    vec4 mixed   = (1.0 - param.mixfactor) * current + param.mixfactor * fdback;

    FragColor = pow(mixed, vec4(1.0 / 2.2));
}
