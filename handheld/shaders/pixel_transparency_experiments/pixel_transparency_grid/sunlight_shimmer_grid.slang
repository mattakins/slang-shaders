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
                          |_|     SUNLIGHT SHIMMER + GRID   |___/
    v1.0 by mattakins
    Copyright (C) 2025 Matt Akins.

    Single-pass pixel transparency with integrated LCD grid and sunlight shimmer.
    All 6 grid styles built in: lcd1x, lcd3x, zfast, simpletex, lcd-grid-v2, authentic_gbc.
    Grid can be applied before or after transparency for different visual looks.

*/

#define PT_SHIMMER
#define PT_GRID

// ========== PIXEL TRANSPARENCY ==========
#pragma parameter PT_ENABLE         "=== Pixel Transparency v2.1 - SHIMMER + GRID === (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_HIDE_CONTENT   " *  Single-pass: transparency + grid + sunlight effects." 0.0 0.0 2.0 1.0
#pragma parameter NOTE2             " *  Turn ON Core > Color Correction & Interframe Blending" 0.0 0.0 1.0 1.0

// ========== GRID ==========
#pragma parameter PT_GRID_ENABLE    "== GRID == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_GRID_STYLE     "      ↳ 0=lcd1x 1=lcd3x 2=zfast 3=stex 4=gridv2 5=gbc" 5.0 0.0 5.0 1.0
#pragma parameter PT_GRID_ORDER     "      ↳ Order (0=After transp., 1=Before)" 0.0 0.0 1.0 1.0
#pragma parameter PT_GRID_LAYER      "     ↳ Shimmer layer (0=Above grid, 1=Below)" 0.0 0.0 1.0 1.0
#pragma parameter PT_GRID_PRESET    "       Settings (0=Original, 1=Custom)" 0.0 0.0 1.0 1.0
#pragma parameter PT_GRID_COLOR     "          ↳ Line color (0=Trans ← 1=Dark → 2=Light)" 1.0 0.0 2.0 0.05
#pragma parameter PT_GRID_INTENSITY "          ↳ Intensity" 1.0 0.0 1.0 0.01
#pragma parameter PT_GRID_WEIGHT    "          ↳ Line weight" 0.5 0.0 1.0 0.05
#pragma parameter AUTH_GBC_BRIG     "          ↳ GBC subpixel brightness (style 5 only)" 0.6 0.0 1.0 0.05
#pragma parameter PT_GRID_BIAS      "          ↳ Luma bias (-1=dark, 0=uniform, 1=bright)" 0.0 -1.0 1.0 0.05
#pragma parameter PT_GRID_SUBPX     "          ↳ Subpixels (OFF/ON)" 0.0 0.0 1.0 1.0
#pragma parameter PT_GRID_SUBPX_DIR "          ↳ Subpixel dir (0=RGB H,1=V,2=BGR H,3=V)" 0.0 0.0 3.0 1.0
#pragma parameter PT_BRIGHTNESS_GRID "     ↳ Grid influences transparency (Before)" 0.0 0.0 1.0 1.0

// ========== COLOR ==========
#pragma parameter SECTION1              "== COLOR ==" 0.0 0.0 1.0 1.0
#pragma parameter PT_PALETTE            "--- 1. Backing tint (0=OFF, 1/2=Warm, 3/4=Neutral)" 3.0 0.0 4.0 1.0
#pragma parameter PT_PALETTE_INTENSITY  "      ↳ Intensity" 1.0 0.0 2.0 0.05
#pragma parameter PT_BACKING_BRIGHTNESS "      ↳ Brightness" 0.48 0.20 0.65 0.01

#pragma parameter PT_POLARIZER       "--- 2. Front polarizer tint (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_POLARIZER_TINT  "      ↳ Intensity" 1.0 0.0 1.0 0.05
#pragma parameter PT_POLARIZER_ORDER "      ↳ Position (0=Before grid, 1=After rainbow)" 1.0 0.0 1.0 1.0

#pragma parameter PT_SATURATION     "--- 3. Color saturation" 1.0 0.5 1.5 0.05

#pragma parameter PT_HIGHLIGHTS     "--- 4. Pixel brightness (0=OFF, -Dim / +Bright)" 0.05 -1.0 1.0 0.01
#pragma parameter PT_DARKEN_COLOUR  "--- 5. Darken colors" 0.0 0.0 2.0 0.05

// ========== TRANSPARENCY ==========
#pragma parameter SECTION2              "== TRANSPARENCY ==" 0.0 0.0 1.0 1.0
#pragma parameter PT_PIXEL_MODE         "--- 6. Transparent pixels (0=White only, 1=Bright, 2=All)" 1.0 0.0 2.0 1.0
#pragma parameter PT_BASE_ALPHA         "      ↳ Transparency amount" 0.20 0.0 1.0 0.01

#pragma parameter PT_THRESHOLD          "--- 7. White pixel detection threshold" 0.90 0.0 1.0 0.01

#pragma parameter PT_WHITE_BOOST        "--- 8. Boost white pixel transparency (OFF/ON)" 0.0 0.0 1.0 1.0
#pragma parameter PT_WHITE_TRANSPARENCY "      ↳ Boost amount" 0.50 0.0 1.0 0.01

#pragma parameter PT_BRIGHTNESS_MODE    "--- 9. Brightness mode (0=Simple, 1=Natural)" 1.0 0.0 1.0 1.0

// ========== SUNLIGHT ==========
#pragma parameter SECTION3              "== SUNLIGHT ==" 0.0 0.0 1.0 1.0
#pragma parameter PT_GLARE_ENABLE       "--- 10. Glare (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_GLARE_INTENSITY    "      ↳ Strength" 0.15 0.0 1.0 0.05
#pragma parameter PT_GLARE_SIZE         "      ↳ Spread" 0.25 0.05 1.0 0.05

#pragma parameter PT_RAINBOW_ENABLE     "--- 11. Rainbow shimmer (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_RAINBOW_INTENSITY  "      ↳ Intensity" 0.15 0.0 1.0 0.01
#pragma parameter PT_FILM_TUNING        "      ↳ Color shift" 1.0 0.5 2.0 0.05
#pragma parameter LIGHT_SPREAD          "      ↳ Band density" 1.8 0.5 4.0 0.1

#pragma parameter PT_FILM_NOISE         "       Film splotchiness" 0.5 0.0 1.0 0.05
#pragma parameter PT_FILM_SCALE         "          ↳ Splotch size" 0.6 0.1 3.0 0.05

#pragma parameter LIGHT_HEIGHT          "       Light source distance (0=Flat, 1=Far)" 0.0 0.0 1.0 0.05
#pragma parameter LIGHT_RANGE           "          ↳ Tilt range" 0.6 0.0 2.0 0.05
#pragma parameter LIGHT_X               "          ↳ X" 0.5 -1.0 2.0 0.01
#pragma parameter LIGHT_Y               "          ↳ Y" 0.5 -1.0 2.0 0.01

// ========== SHADOWS ==========
#pragma parameter PT_SHADOW_ENABLE      "== 12. SHADOWS == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_MOTION      "       Shadow motion (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_MAX_OFFSET  "          ↳ Max offset" 2.50 0.0 30.0 0.5
#pragma parameter PT_SHADOW_MOTION_X    "          ↳ Neutral X" 2.0 -30.0 30.0 0.5
#pragma parameter PT_SHADOW_MOTION_Y    "          ↳ Neutral Y" 2.0 -30.0 30.0 0.5

#pragma parameter PT_SHADOW_OFFSET_X    "      ↳ X offset" 3.0 -30.0 30.0 0.5
#pragma parameter PT_SHADOW_OFFSET_Y    "      ↳ Y offset" 3.0 -30.0 30.0 0.5

#pragma parameter PT_SHADOW_OPACITY     "      ↳ Opacity" 0.50 0.0 1.0 0.01
#pragma parameter PT_SHADOW_BLUR        "      ↳ Blur amount" 1.0 0.0 5.0 0.1

// ========== MOTION ==========
#pragma parameter ACCEL_ENABLE          "== 13. MOTION == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter NOTE3                 " *  Motion enabled on latest RetroArch nightly build." 0.0 0.0 1.0 1.0
#pragma parameter ACCEL_RELATIVE        "      ↳ Tilt neutral (0=Device flat, 1=From hold)" 0.0 0.0 1.0 1.0
#pragma parameter ACCEL_SENSITIVITY     "      ↳ Tilt sensitivity" 1.0 0.1 5.0 0.05

// ========== PERFORMANCE ==========
#pragma parameter SECTION_PERF          "== PERFORMANCE ==" 0.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_FAST_BLUR   "      ↳ Shadow quality (0=Low, 1=High)" 1.0 0.0 1.0 1.0

// ============================================================
// Push constant — vertex-stage + hot fragment params (120 bytes)
// ============================================================
layout(push_constant) uniform Push {
    vec4 OutputSize;
    vec4 OriginalSize;
    uint Rotation;
    // Grid (vertex-stage for authentic_gbc geometry)
    float PT_GRID_STYLE;
    float AUTH_GBC_BRIG;
    float PT_GRID_SUBPX;
    float PT_GRID_SUBPX_DIR;
    // Shimmer (vertex-stage for light position)
    float PT_RAINBOW_ENABLE;
    float PT_GLARE_ENABLE;
    float LIGHT_RANGE;
    float LIGHT_X;
    float LIGHT_Y;
    // Fragment hot params
    float PT_ENABLE;
    float PT_BRIGHTNESS_MODE;
    float PT_SHADOW_ENABLE;
    float PT_SHADOW_BLUR;
    float PT_SHADOW_OPACITY;
    float PT_THRESHOLD;
    float PT_SHADOW_FAST_BLUR;
    float PT_PIXEL_MODE;
    float PT_BASE_ALPHA;
    float PT_GRID_WEIGHT;
    float PT_GRID_PRESET;
} param;

// ============================================================
// UBO — everything else (vertex-accessible for motion/shadow)
// ============================================================
layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    #ifdef _HAS_SENSOR_UNIFORMS
    vec3 Gyroscope;
    vec3 Accelerometer;
    vec3 AccelerometerRest;
    #endif
    // Motion (vertex-stage, moved from push_constant to save space)
    float ACCEL_ENABLE;
    float ACCEL_RELATIVE;
    float ACCEL_SENSITIVITY;
    float PT_SHADOW_MOTION;
    float PT_SHADOW_MAX_OFFSET;
    float PT_SHADOW_MOTION_X;
    float PT_SHADOW_MOTION_Y;
    float PT_SHADOW_OFFSET_X;
    float PT_SHADOW_OFFSET_Y;
    // Grid appearance
    float PT_GRID_ENABLE;
    float PT_GRID_INTENSITY;
    float PT_GRID_COLOR;
    float PT_GRID_ORDER;
    float PT_GRID_BIAS;
    float PT_BRIGHTNESS_GRID;
    float PT_GRID_LAYER;
    // Transparency / color
    float PT_HIDE_CONTENT;
    float PT_PALETTE;
    float PT_PALETTE_INTENSITY;
    float PT_BACKING_BRIGHTNESS;
    float PT_POLARIZER;
    float PT_POLARIZER_TINT;
    float PT_POLARIZER_ORDER;
    float PT_SATURATION;
    float PT_HIGHLIGHTS;
    float PT_DARKEN_COLOUR;
    float PT_WHITE_BOOST;
    float PT_WHITE_TRANSPARENCY;
    // Shimmer
    float PT_GLARE_INTENSITY;
    float PT_GLARE_SIZE;
    float PT_RAINBOW_INTENSITY;
    float PT_FILM_TUNING;
    float PT_FILM_NOISE;
    float PT_FILM_SCALE;
    float LIGHT_HEIGHT;
    float LIGHT_SPREAD;
} global;

#include "pt_shimmer_grid.inc"

    FragColor = output_color;
}
