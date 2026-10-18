// Preserve each LCD family's native controls and defaults.
#pragma parameter PT_FUSED_LAYER "Grid Placement: 0 Below / 1 Above" 0.0 0.0 1.0 1.0
#if defined(PT_GRID_LCD1X)
#define PT_LCD_UNIFORMS \
    float PT_FUSED_LAYER; \
    float BRIGHTEN_SCANLINES; \
    float BRIGHTEN_LCD;
#elif defined(PT_GRID_LCD3X)
#define PT_LCD_UNIFORMS \
    float PT_FUSED_LAYER; \
    float brighten_scanlines; \
    float brighten_lcd;
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
    float GBAGAMMA;
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
    float BGR;
#else
#error Select an integrated grid family
#endif
