// Coverage was rendered separately; only the layer blend runs here.
layout(set = 0, binding = 6) uniform sampler2D PTGridCoverage;
vec4 finishGrid(vec4 color) {
    if (global.PT_FUSED_LAYER > 0.5 &&
        (global.PT_HIDE_CONTENT < 0.5 || param.PT_ENABLE < 0.5)) {
        vec3 coverage = texture(PTGridCoverage, vTexCoord).rgb;
        vec3 line = global.PT_FUSED_BRIGHTNESS * vec3(global.PT_FUSED_RED, global.PT_FUSED_GREEN, global.PT_FUSED_BLUE);
        vec3 linear = max(color.rgb, vec3(0.0));
        color.rgb = sqrt(linear * linear * coverage + line * line * (vec3(1.0) - coverage));
    }
    return color;
}
