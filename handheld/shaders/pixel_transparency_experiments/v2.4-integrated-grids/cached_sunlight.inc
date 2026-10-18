// Copyright (C) 2025-2026 Matt Akins.

// Apply optical tint to full-resolution game pixels and LCD detail.
vec4 applyCachedSunlight(vec4 output_color, vec3 original_pixel, float original_brightness) {
    if (global.PT_SUNLIGHT_ENABLE < 0.5 ||
        (param.PT_RAINBOW_ENABLE < 0.5 && param.PT_GLARE_ENABLE < 0.5 &&
         global.PT_REFLECT_ENABLE < 0.5)) {
        // Keep final dither when the light effects are bypassed.
#ifndef PT_CUSTOM_FINAL_DITHER
        output_color.rgb += (hash(floor(vTexCoord*param.OutputSize.xy)+vec2(0.5)) - 0.5) / 255.0;
#endif
        return output_color;
    }
    {
        vec4 light_sample = texture(LightField, light_coord);
        float aspect_ratio = param.OutputSize.x / param.OutputSize.y;
        vec2 to_light = (vTexCoord - light_pos) * vec2(aspect_ratio, 1.0);
        float dist_sq = 0.0;
        if (global.PT_REFLECT_ENABLE > 0.5) {
            dist_sq = dot(to_light, to_light);
        }

        // Rainbow effect — QWP chromatic dispersion with 3D light source geometry.
        if (param.PT_RAINBOW_ENABLE > 0.5 && global.PT_RAINBOW_INTENSITY > 0.001 && any(notEqual(output_color.rgb,vec3(0.0)))) {
            vec3 tint = light_sample.rgb;

            float tint_strength = global.PT_RAINBOW_INTENSITY;

            // Brightness gating — rainbow light double-passes through the LC layer,
            // so dark pixels attenuate the reflection. Linear with 0.03 floor from
            // ~30:1 contrast ratio of reflective TFT.
            float reflectivity = mix(0.03, 1.0, original_brightness);
            tint_strength *= reflectivity;

            // Color filter — rainbow light double-passes through RGB sub-pixel color filters
            // (in and out), so pixel color is squared for physical two-pass attenuation
            tint *= original_pixel * original_pixel;

            // Luminance-preserving tint blend:
            // Multiply by the spectral tint (shifts color), then restore original luminance.
            vec3 tinted = output_color.rgb * mix(vec3(1.0), tint, tint_strength);
            float orig_luma = getPerceptualBrightness(output_color.rgb);
            float tinted_luma = getPerceptualBrightness(tinted);
            if (tinted_luma > 0.001) {
                tinted *= orig_luma / tinted_luma;
            }
            output_color.rgb = tinted;
        }

        // Ambient front-surface reflection — broad sheen centered on the light source.
        if (global.PT_REFLECT_ENABLE > 0.5) {
            float spread_sq = global.PT_REFLECT_SPREAD * global.PT_REFLECT_SPREAD;
            float reflect_strength = exp(-dist_sq / (2.0 * spread_sq));
            reflect_strength = reflect_strength * global.PT_REFLECT_INTENSITY + global.PT_REFLECT_BIAS;

            vec3 reflect_color = mix(vec3(1.0), vec3(1.0, 0.95, 0.85), global.PT_REFLECT_WARM);
            output_color.rgb += reflect_color * reflect_strength;
        }

        // Specular glare — soft white hotspot centered on the light source.
        if (param.PT_GLARE_ENABLE > 0.5 && global.PT_GLARE_INTENSITY > 0.001) {
            float glare_strength = light_sample.a;

            output_color.rgb = mix(output_color.rgb, vec3(1.0), clamp(glare_strength, 0.0, 0.85));
        }
    }

    // Anti-banding dither runs after light optics, before quantization.
#ifndef PT_CUSTOM_FINAL_DITHER
    output_color.rgb += (hash(floor(vTexCoord*param.OutputSize.xy)+vec2(0.5)) - 0.5) / 255.0;
#endif

    return output_color;
}
