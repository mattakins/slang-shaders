// Live selection keeps each family's controls and their stored values.
#pragma parameter PT_GRID_STYLE "Grid: 0 Auth / 1 LCD1 / 2 LCD3 / 3 V2 / 4 Tex / 5 Fast" 0.0 0.0 5.0 1.0
#include "../v2.4-grid-axis-cache/grid_parameters.inc"
#pragma parameter BRIGHTEN_SCANLINES "LCD1x: Brighten Scanlines" 16.0 1.0 32.0 0.5
#pragma parameter BRIGHTEN_LCD "LCD1x: Brighten LCD" 4.0 1.0 12.0 0.1
#pragma parameter brighten_scanlines "LCD3x: Brighten Scanlines" 16.0 1.0 32.0 0.5
#pragma parameter brighten_lcd "LCD3x: Brighten LCD" 4.0 1.0 12.0 0.1
#include "../v2.4-integrated-grids/grids/lcd-grid-v2/parameters.inc"
#include "../v2.4-integrated-grids/grids/simpletex_lcd/parameters.inc"
#include "../v2.4-integrated-grids/grids/zfast_lcd/parameters.inc"

#undef PT_LCD_UNIFORMS
#define PT_LCD_UNIFORMS \
    float PT_GRID_STYLE; \
    uint Rotation; \
    float AUTH_GBC_BRIG; \
    float AUTH_GBC_BLUR; \
    float AUTH_GBC_SUBPX; \
    float AUTH_GBC_SUBPX_ORIENTATION; \
    float PT_FUSED_LAYER; \
    float PT_FUSED_STRENGTH; \
    float PT_FUSED_BRIGHTNESS; \
    float PT_FUSED_RED; \
    float PT_FUSED_GREEN; \
    float PT_FUSED_BLUE; \
    float PT_FUSED_BIAS; \
    float BRIGHTEN_SCANLINES; \
    float BRIGHTEN_LCD; \
    float brighten_scanlines; \
    float brighten_lcd; \
    float GRID_INTENSITY; \
    float GRID_WIDTH; \
    float GRID_BIAS; \
    float DARKEN_GRID; \
    float DARKEN_COLOUR; \
    float BACKGROUND_INTENSITY; \
    float BORDERMULT; \
    float GBAGAMMA; \
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
