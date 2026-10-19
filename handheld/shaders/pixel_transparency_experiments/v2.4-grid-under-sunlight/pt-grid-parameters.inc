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
                          |_|                               |___/

    PT | GRID PARAMETERS
    v2.4 integrated grid pipeline

    Shared placement control and uniform layouts for the five non-Authentic grids.
    Each family supplies its original LCD control declarations.
*/

// Preserve each LCD family's native controls and defaults.
#pragma parameter PT_FUSED_LAYER "Grid Placement: 0 Below / 1 Over paper, under light" 0.0 0.0 1.0 1.0
#if defined(PT_GRID_LCD1X)
#define PT_LCD_UNIFORMS \
    float PT_FUSED_LAYER; \
    float BRIGHTEN_SCANLINES; \
    float BRIGHTEN_LCD; \
    float PT_FUSED_BRIGHTNESS;
#elif defined(PT_GRID_LCD3X)
#define PT_LCD_UNIFORMS \
    float PT_FUSED_LAYER; \
    float brighten_scanlines; \
    float brighten_lcd; \
    float PT_FUSED_BRIGHTNESS;
#elif defined(PT_GRID_SIMPLETEX_LCD)
#define PT_LCD_UNIFORMS \
    float PT_FUSED_LAYER; \
    float GRID_INTENSITY; \
    float GRID_WIDTH; \
    float GRID_BIAS; \
    float DARKEN_GRID; \
    float DARKEN_COLOUR; \
    float BACKGROUND_INTENSITY;
#elif defined(PT_GRID_ZFAST_LCD)
#define PT_LCD_UNIFORMS \
    float PT_FUSED_LAYER; \
    float BORDERMULT; \
    float GBAGAMMA; \
    float PT_FUSED_BRIGHTNESS;
#elif defined(PT_GRID_LCD_GRID_V2)
#define PT_LCD_UNIFORMS \
    float PT_FUSED_LAYER; \
    float RSUBPIX_R; \
    float RSUBPIX_G; \
    float RSUBPIX_B; \
    float GSUBPIX_R; \
    float GSUBPIX_G; \
    float GSUBPIX_B; \
    float BSUBPIX_R; \
    float BSUBPIX_G; \
    float BSUBPIX_B; \
    float gain; \
    float gamma; \
    float blacklevel; \
    float ambient; \
    float BGR; \
    float PT_FUSED_BRIGHTNESS;
#else
#error Select an integrated grid family
#endif
