// Coverage was rendered separately; only the layer blend runs here.
layout(set = 0, binding = 6) uniform sampler2D PTGridX;
layout(set = 0, binding = 7) uniform sampler2D PTGridY;
vec4 finishGrid(vec4 color) {
    if (global.PT_FUSED_LAYER > 0.5 &&
        (global.PT_HIDE_CONTENT < 0.5 || param.PT_ENABLE < 0.5)) {
        ivec2 pixel = ivec2(floor(vTexCoord * param.OutputSize.xy));
        vec4 xFirst = texelFetch(PTGridX, ivec2(pixel.x, 4), 0);
        vec3 xSecond = texelFetch(PTGridX, ivec2(pixel.x, 5), 0).rgb;
        vec3 yFirst = texelFetch(PTGridY, ivec2(4, pixel.y), 0).rgb;
        vec3 ySecond = texelFetch(PTGridY, ivec2(5, pixel.y), 0).rgb;
        vec3 coverage = clamp((xFirst.rgb * yFirst + xSecond * ySecond) / xFirst.a, 0.0, 1.0);
        float strength = global.PT_FUSED_STRENGTH;
        if (global.PT_FUSED_BIAS > 0.0)
            strength *= mix(1.0, dot(texture(Original, vTexCoord).rgb, vec3(0.2126, 0.7152, 0.0722)), global.PT_FUSED_BIAS);
        coverage = mix(vec3(1.0), coverage, strength);
        vec3 line = global.PT_FUSED_BRIGHTNESS * vec3(global.PT_FUSED_RED, global.PT_FUSED_GREEN, global.PT_FUSED_BLUE);
        vec3 linear = max(color.rgb, vec3(0.0));
        color.rgb = sqrt(linear * linear * coverage + line * line * (vec3(1.0) - coverage));
    }
    return color;
}
