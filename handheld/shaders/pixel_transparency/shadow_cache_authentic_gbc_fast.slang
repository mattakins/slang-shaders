#version 450
// Copyright (C) 2025-2026 Matt Akins.
// Keep this LCD profile's parameter order before the shared cache controls.
#pragma parameter AUTH_GBC_SETTINGS "=== Authentic GBC v2.2 settings ===" 0.0 0.0 1.0 1.0
#pragma parameter AUTH_GBC_BRIG "Add brightness" 0.6 0.0 1.0 0.05
#pragma parameter AUTH_GBC_BLUR "Anti-banding smoothing" 0.3 0.0 1.0 0.05
#pragma parameter AUTH_GBC_SUBPX "Enable subpixel rendering" 0.0 0.0 1.0 1.0
#pragma parameter AUTH_GBC_SUBPX_ORIENTATION "Subpixel layout (0=RGB, 1=RGB vert., 2=BGR, 3=BGR vert.)" 0.0 0.0 3.0 1.0
#include "shadow_cache.inc"
