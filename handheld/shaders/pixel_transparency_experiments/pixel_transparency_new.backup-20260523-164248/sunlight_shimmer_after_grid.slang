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
                          |_|     SUNLIGHT SHIMMER EDITION  |___/
									       AFTER-GRID PASS
    v2.2 by mattakins
    Copyright (C) 2025 Matt Akins.

    Grid shaders look great on Game Boy Color games - except for one glaring issue.

    With no backlight, the original devices didn't render white pixels. Light pixels
    appeared as transparent areas where the backing material of the screen showed through.
    Many games relied on this effect for transparent backgrounds that now render on modern
    displays as eye-searing white pixels. No more! Pixel Transparency simulates this unique effect.

    SUNLIGHT SHIMMER EDITION: Light and shadows move with your device!
    Tilt your device and shadows shift with it. Glare sweeps across your screen. And just like the
    Game Boy Color in sunlight, you see a brilliant rainbow shimmer in the background.

    3-pass pipeline: before → grid → after(this)
    Grid intensity control, rainbow shimmer, specular glare, conditional polarizer, dither.
    Physically correct: rainbow (QWP layer 6) and glare (lens layer 9) are above the grid (layer 4).

*/

// Re-declared — already in pass 0, needed here for uniform binding
#pragma parameter PT_ENABLE 			"=== Pixel Transparency v2.2 === (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_HIDE_CONTENT 		" *  3-pass: before grid → grid → after grid" 0.0 0.0 2.0 1.0

#pragma parameter PT_GRID_ENABLE 		"== GRID == (0=Off 1=Overlay 2=Pass-through)" 1.0 0.0 2.0 1.0
#pragma parameter PT_GRID_MIX 			"      ↳ Grid opacity" 1.0 0.0 1.0 0.05
#pragma parameter PT_GRID_STRENGTH 		"      ↳ Grid darkness" 1.0 0.0 1.0 0.05
#pragma parameter PT_GRID_FADE 			"      ↳ Fade on bright pixels" 0.0 0.0 1.0 0.05
#pragma parameter PT_GRID_COUPLING 		"      ↳ Grid-transparency coupling" 0.0 0.0 1.0 0.05

#pragma parameter PT_BASE_ALPHA 		"      ↳ Transparency amount" 0.20 0.0 1.0 0.01

#pragma parameter PT_POLARIZER 			"--- Front polarizer tint (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_POLARIZER_TINT 	"      ↳ Intensity" 1.0 0.0 1.0 0.05
#pragma parameter PT_POLARIZER_ORDER 	"      ↳ Order (0=Pre-grid 1=Post-rainbow 2=Pre-rainbow)" 1.0 0.0 2.0 1.0

#pragma parameter ACCEL_ENABLE 		"== MOTION == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter ACCEL_RELATIVE 		"      ↳ Tilt neutral (0=Device flat, 1=From hold)" 0.0 0.0 1.0 1.0
#pragma parameter ACCEL_SENSITIVITY 	"      ↳ Tilt sensitivity" 1.0 0.1 5.0 0.05

// Sunlight Shimmer params — Exclusive to this pass
#pragma parameter PT_SUNLIGHT_ENABLE 	"== SUNLIGHT SHIMMER == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_GLARE_ENABLE 		"--- Glare (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_GLARE_INTENSITY 	"      ↳ Strength" 0.15 0.0 1.0 0.05
#pragma parameter PT_GLARE_SIZE 		"      ↳ Spread" 0.25 0.05 1.0 0.05

#pragma parameter PT_RAINBOW_ENABLE 	"--- Rainbow shimmer (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_RAINBOW_INTENSITY 	"      ↳ Intensity" 0.15 0.0 1.0 0.01
#pragma parameter PT_RAINBOW_GRID_COMP 	"      ↳ Grid compensation" 0.5 0.0 1.0 0.05
#pragma parameter PT_FILM_TUNING 		"      ↳ Color shift" 1.0 0.5 2.0 0.05
#pragma parameter LIGHT_SPREAD 			"      ↳ Band density" 1.8 0.5 4.0 0.1

#pragma parameter PT_FILM_NOISE 		"       Film splotchiness" 0.5 0.0 1.0 0.05
#pragma parameter PT_FILM_SCALE 		"          ↳ Splotch size" 0.6 0.1 3.0 0.05

#pragma parameter LIGHT_HEIGHT 			"--- Light source distance (0=Flat, 1=Far)" 0.0 0.0 1.0 0.05
#pragma parameter LIGHT_RANGE 			"      ↳ Tilt range" 0.6 0.0 2.0 0.05
#pragma parameter LIGHT_X 				"--- Light source X" 0.5 -1.0 2.0 0.01
#pragma parameter LIGHT_Y 				"      ↳ Y" 0.5 -1.0 2.0 0.01

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    float PT_RAINBOW_ENABLE;
    float PT_GLARE_ENABLE;
    float LIGHT_RANGE;
    float LIGHT_X;
    float LIGHT_Y;
    float ACCEL_ENABLE;
    float ACCEL_RELATIVE;
    float ACCEL_SENSITIVITY;
    float PT_SUNLIGHT_ENABLE;
} param;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    #ifdef _HAS_SENSOR_UNIFORMS
    vec3 Gyroscope;
    vec3 Accelerometer;
    vec3 AccelerometerRest;
    #endif
    float PT_GRID_ENABLE;
    float PT_GRID_MIX;
    float PT_GRID_STRENGTH;
    float PT_GRID_FADE;
    float PT_GRID_COUPLING;
    float PT_BASE_ALPHA;
    float PT_POLARIZER;
    float PT_POLARIZER_TINT;
    float PT_POLARIZER_ORDER;
    float PT_GLARE_INTENSITY;
    float PT_GLARE_SIZE;
    float PT_RAINBOW_INTENSITY;
    float PT_RAINBOW_GRID_COMP;
    float PT_FILM_TUNING;
    float PT_FILM_NOISE;
    float PT_FILM_SCALE;
    float LIGHT_HEIGHT;
    float LIGHT_SPREAD;
} global;

#define PT_SHIMMER
#include "pt_after_grid.inc"
