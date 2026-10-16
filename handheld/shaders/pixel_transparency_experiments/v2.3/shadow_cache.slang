#version 450
// Copyright (C) 2025-2026 Matt Akins.
// Cache all nearest-filtered shadow phases, including the wider blur settings.
// Three horizontal phases occupy adjacent texels; RGB stores three vertical phases.
#include "cached_parameters.inc"
#pragma name PixelShadowCache
#pragma format R32G32B32A32_SFLOAT
layout(std140,set=0,binding=0) uniform UBO {
    mat4 MVP;
    vec4 LCDInputSize;
    float PT_BRIGHTNESS_MODE;
    float PT_SHADOW_EDGE_ENABLE;
    float PT_SHADOW_FAST_BLUR;
    float PT_SHADOW_BLUR;
} global;
layout(push_constant) uniform Push { vec4 OutputSize; } param;
#pragma stage vertex
layout(location=0) in vec4 Position;
layout(location=1) in vec2 TexCoord;
layout(location=0) out vec2 vTexCoord;
void main() { gl_Position=global.MVP*Position; vTexCoord=TexCoord; }
#pragma stage fragment
layout(location=0) in vec2 vTexCoord;
layout(location=0) out vec4 FragColor;
layout(set=0,binding=2) uniform sampler2D Original;
float caster(ivec2 cell, ivec2 size) {
    if (any(lessThan(cell,ivec2(0))) || any(greaterThanEqual(cell,size)))
        return global.PT_SHADOW_EDGE_ENABLE > 0.5 ? 1.0 : 0.0;
    vec3 color=texture(Original,(vec2(cell)+0.5)/vec2(size)).rgb;
    float brightness=global.PT_BRIGHTNESS_MODE < 0.5
        ? (color.r+color.g+color.b)/3.0
        : (0.2126*color.r)+(0.7152*color.g)+(0.0722*color.b);
    return 1.0-brightness;
}
float evaluateKernel(vec2 native, vec2 radius, ivec2 size) {
    float center=caster(ivec2(floor(native)),size);
    float value=center*4.0;
    value+=caster(ivec2(floor(native-vec2(radius.x,0.0))),size)*2.0;
    value+=caster(ivec2(floor(native+vec2(radius.x,0.0))),size)*2.0;
    value+=caster(ivec2(floor(native-vec2(0.0,radius.y))),size)*2.0;
    value+=caster(ivec2(floor(native+vec2(0.0,radius.y))),size)*2.0;
    if (global.PT_SHADOW_FAST_BLUR<0.5) return value/12.0;
    value+=caster(ivec2(floor(native-radius)),size);
    value+=caster(ivec2(floor(native+vec2(radius.x,-radius.y))),size);
    value+=caster(ivec2(floor(native+vec2(-radius.x,radius.y))),size);
    value+=caster(ivec2(floor(native+radius)),size);
    return value/16.0;
}
void main() {
    ivec2 output_cell=ivec2(floor(vTexCoord*param.OutputSize.xy));
    int phase=output_cell.x%3;
    ivec2 cell=ivec2(output_cell.x/3-3,output_cell.y-3);
    ivec2 size=textureSize(Original,0);
    if (any(lessThan(cell,ivec2(-3))) || any(greaterThanEqual(cell,size+ivec2(3)))) {
        discard;
    }
    float scale=sqrt((global.LCDInputSize.x/640.0)*(global.LCDInputSize.y/480.0));
    vec2 radius=global.PT_SHADOW_BLUR>0.1
        ? global.PT_SHADOW_BLUR*scale*global.LCDInputSize.zw*vec2(size) : vec2(0.0);
    if (global.PT_SHADOW_BLUR<=0.1) {
        float value=caster(cell,size);FragColor=vec4(value,value,value,1.0);return;
    }
    // Neighbor indices change only at the fractional radius and its complement.
    // One representative of each interval preserves nearest-filtered sampling.
    if (any(greaterThanEqual(radius,vec2(0.499)))) {
        vec2 fraction=fract(radius);
        vec2 low=min(fraction,vec2(1.0)-fraction);
        vec2 high=max(fraction,vec2(1.0)-fraction);
        float x=phase==0 ? low.x*0.5 : phase==1 ? 0.5 : (high.x+1.0)*0.5;
        FragColor=vec4(evaluateKernel(vec2(cell)+vec2(x,low.y*0.5),radius,size),
                       evaluateKernel(vec2(cell)+vec2(x,0.5),radius,size),
                       evaluateKernel(vec2(cell)+vec2(x,(high.y+1.0)*0.5),radius,size),1.0);
        return;
    }
    // Small kernels need only the current cell and its immediate neighbors.
    int side=phase-1;
    float middle=caster(cell,size);
    float up=caster(cell+ivec2(0,-1),size);
    float down=caster(cell+ivec2(0,1),size);
    float other=caster(cell+ivec2(side,0),size);
    if (global.PT_SHADOW_FAST_BLUR < 0.5) {
        float horizontal=6.0*middle+2.0*other;
        FragColor=vec4((horizontal+2.0*up+2.0*middle)/12.0,
                       (horizontal+4.0*middle)/12.0,
                       (horizontal+2.0*middle+2.0*down)/12.0,1.0);
    } else {
        float hmiddle=3.0*middle+other;
        float hup=3.0*up+caster(cell+ivec2(side,-1),size);
        float hdown=3.0*down+caster(cell+ivec2(side,1),size);
        FragColor=vec4((hup+3.0*hmiddle)/16.0,hmiddle/4.0,
                       (3.0*hmiddle+hdown)/16.0,1.0);
    }
}
