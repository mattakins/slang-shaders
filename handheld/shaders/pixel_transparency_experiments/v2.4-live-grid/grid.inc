// LCD1x: jdgleaver, adapted from Gigaherz's public-domain LCD3x.
// Simpletex: jdgleaver, using Greg Hogan's line-weight equation.
// zfast_lcd: Copyright (C) 2017 Greg Hogan (SoltanGris42).
// These adaptations are licensed under GPL version 2 or later.
// LCD Grid v2 geometry and colour reconstruction follow lcd-cgwg/lcd-grid-v2.slang.

layout(set = 0, binding = 8) uniform sampler2D BACKGROUND;
vec3 gridLinear(vec3 color) {
    return pow(global.gain * color + vec3(global.blacklevel), vec3(global.gamma)) + vec3(global.ambient);
}
vec3 gridEncode(vec3 color) {
    return pow(mat3(grid_red, grid_green, grid_blue) * color, vec3(1.0 / 2.2));
}
void gridWeights(vec2 uv, out vec4 left, out vec4 right, out vec4 vertical) {
    ivec2 extent = ivec2(textureSize(PTGridX, 0).x, textureSize(PTGridY, 0).y);
    ivec2 pixel = clamp(ivec2(uv * vec2(extent)), ivec2(0), extent - 1);
    left = texelFetch(PTGridX, ivec2(pixel.x, 0), 0);
    right = texelFetch(PTGridX, ivec2(pixel.x, 1), 0);
    vertical = texelFetch(PTGridY, ivec2(0, pixel.y), 0);
}

// The same operator runs either on native colour or the full-resolution effects.
vec3 applyGrid(vec3 color, vec2 uv, vec2 outputSize) {
    if (global.PT_GRID_STYLE < 2.5) {
        float y;
        vec3 x;
        if (global.PT_GRID_STYLE < 1.5) {
            vec2 angle = 2.0 * 3.141592654 * (uv * global.OriginalSize.xy - 0.25);
            y = (global.BRIGHTEN_SCANLINES + sin(angle.y)) / (global.BRIGHTEN_SCANLINES + 1.0);
            x = vec3((global.BRIGHTEN_LCD + sin(angle.x)) / (global.BRIGHTEN_LCD + 1.0));
        } else {
            vec2 angle = uv * (vec2(3.141592654) * vec2(2.0) * global.OriginalSize.xy);
            const vec3 offsets = vec3(3.141592654) * vec3(0.5, 0.5 - 2.0 / 3.0, 0.5 - 4.0 / 3.0);
            y = (global.brighten_scanlines + sin(angle.y)) / (global.brighten_scanlines + 1.0);
            x = (global.brighten_lcd + sin(angle.x + offsets)) / (global.brighten_lcd + 1.0);
        }
        return y * x * color;
    } else if (global.PT_GRID_STYLE > 3.5) {
        vec2 coordinate = uv * global.OriginalSize.xy;
        vec2 distance = abs(floor(coordinate) + vec2(0.5) - coordinate);
        float d2 = max(distance.x, distance.y);
        d2 *= d2;
        float d4 = d2 * d2;
        if (global.PT_GRID_STYLE < 4.5) {
            color = pow(color, vec3(1.0 + global.DARKEN_COLOUR));
            float weight = 48.0 * (d4 - (8.0 / 3.0 * d4 * d2));
            weight *= (weight + (1.0 - weight) * global.GRID_WIDTH) * global.GRID_INTENSITY;
            float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
            weight *= luma + (1.0 - luma) * (1.0 - global.GRID_BIAS);
            color = mix(color, vec3(1.0 - global.DARKEN_GRID), weight);
            if (global.BACKGROUND_INTENSITY > 0.0) {
                vec2 paper = (floor(uv * outputSize) + vec2(0.5)) / 2048.0;
                vec3 background = texture(BACKGROUND, paper).rgb * color;
                color = mix(color, background, dot(color, vec3(0.2126, 0.7152, 0.0722)) * global.BACKGROUND_INTENSITY);
            }
        } else {
            float d6 = d4 * d2;
            color *= 1.0 - global.BORDERMULT * (d4 - 2.7 * d6);
            if (global.GBAGAMMA > 0.5) color *= 0.6 + 0.4 * color;
        }
        return color;
    } else {
        vec4 left, right, vertical;
        gridWeights(uv, left, right, vertical);
        vec3 linearColor = gridLinear(color);
        // Preserve the source shader's summation order, including non-diagonal matrices.
        vec3 weighted = linearColor * left.rgb * vertical.x + linearColor * right.rgb * vertical.y
                      + linearColor * left.rgb * vertical.y + linearColor * right.rgb * vertical.x;
        return gridEncode(weighted);
    }
}
