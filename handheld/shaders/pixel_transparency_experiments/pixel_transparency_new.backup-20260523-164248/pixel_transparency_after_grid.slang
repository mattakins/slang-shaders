#version 450

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
                          |_|              AFTER-GRID PASS  |___/
    v2.2 by mattakins
    Copyright (C) 2025 Matt Akins.

    Grid shaders look great on Game Boy Color games - except for one glaring issue.

    With no backlight, the original devices didn't render white pixels. Light pixels
    appeared as transparent areas where the backing material of the screen showed through.
    Many games relied on this effect for transparent backgrounds that now render on modern
    displays as eye-searing white pixels. No more! Pixel Transparency simulates this unique effect.

    Just choose your favorite LCD grid preset to reduce eye strain and maximize nostalgia.

    3-pass pipeline: before → grid → after(this)
    Grid intensity control, conditional polarizer, dither.
    For the shimmer edition with rainbow/glare, use sunlight_shimmer_after_grid.slang.

*/

// Re-declared — already in pass 0, needed here for uniform binding
#pragma parameter PT_GRID_ENABLE 		"== GRID == (0=Off 1=Overlay 2=Pass-through)" 1.0 0.0 2.0 1.0
#pragma parameter PT_GRID_MIX 			"      ↳ Grid opacity" 1.0 0.0 1.0 0.05
#pragma parameter PT_GRID_STRENGTH 		"      ↳ Grid darkness" 1.0 0.0 1.0 0.05
#pragma parameter PT_GRID_FADE 			"      ↳ Fade on bright pixels" 0.0 0.0 1.0 0.05
#pragma parameter PT_GRID_COUPLING 		"      ↳ Grid-transparency coupling" 0.0 0.0 1.0 0.05

#pragma parameter PT_POLARIZER 			"--- Front polarizer tint (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_POLARIZER_TINT 	"      ↳ Intensity" 1.0 0.0 1.0 0.05
#pragma parameter PT_POLARIZER_ORDER 	"      ↳ Order (0=Pre-grid 1=Post-rainbow 2=Pre-rainbow)" 1.0 0.0 2.0 1.0

#pragma parameter PT_BASE_ALPHA 		"      ↳ Transparency amount" 0.20 0.0 1.0 0.01

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
} param;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    float PT_GRID_ENABLE;
    float PT_GRID_MIX;
    float PT_GRID_STRENGTH;
    float PT_GRID_FADE;
    float PT_GRID_COUPLING;
    float PT_BASE_ALPHA;
    float PT_POLARIZER;
    float PT_POLARIZER_TINT;
    float PT_POLARIZER_ORDER;
} global;

#include "pt_after_grid.inc"
