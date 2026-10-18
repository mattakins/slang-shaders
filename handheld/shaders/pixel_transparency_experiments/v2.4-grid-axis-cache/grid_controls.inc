// Shared controls for the optional Authentic GBC grid experiments.
#include "../../authentic_gbc/parameters.inc"
#pragma parameter PT_FUSED_SETTINGS "=== Integrated grid experiment ===" 0.0 0.0 1.0 1.0
#pragma parameter PT_FUSED_STRENGTH "Grid strength" 1.0 0.0 1.0 0.05
#pragma parameter PT_FUSED_BRIGHTNESS "Grid line brightness (0=Dark, 1=Light)" 0.0 0.0 1.0 0.05
#pragma parameter PT_FUSED_RED "Grid tint: Red" 1.0 0.0 1.0 0.05
#pragma parameter PT_FUSED_GREEN "Grid tint: Green" 1.0 0.0 1.0 0.05
#pragma parameter PT_FUSED_BLUE "Grid tint: Blue" 1.0 0.0 1.0 0.05
#pragma parameter PT_FUSED_BIAS "Grid brightness bias (protect dark pixels)" 0.0 0.0 1.0 0.05

#define PT_LCD_UNIFORMS \
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
    float PT_FUSED_BIAS;
