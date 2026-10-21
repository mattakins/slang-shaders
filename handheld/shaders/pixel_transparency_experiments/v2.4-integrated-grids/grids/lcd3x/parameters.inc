// Controls from handheld/shaders/lcd3x.slang (Gigaherz, public domain).
#pragma parameter PT_FUSED_LAYER 	"== GRID - LCD3x == (0=Soft, 1=Accurate)" 0.0 0.0 1.0 1.0
#pragma parameter brighten_scanlines "      • Brighten scanlines" 16.0 1.0 32.0 0.5
#pragma parameter brighten_lcd "      • Brighten LCD" 4.0 1.0 12.0 0.1
#pragma parameter PT_FUSED_BRIGHTNESS "      • Line brightness (0=Dark, 1=Light)" 0.0 0.0 1.0 0.05

#define PT_LCD_UNIFORMS \
    float PT_FUSED_LAYER; \
    float brighten_scanlines; \
    float brighten_lcd; \
    float PT_FUSED_BRIGHTNESS;
#include "../../pt-grid-parameters.inc"
