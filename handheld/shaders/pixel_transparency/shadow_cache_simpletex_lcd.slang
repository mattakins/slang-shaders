#version 450
// Copyright (C) 2025-2026 Matt Akins.
// Keep this LCD profile's parameter order before the shared cache controls.
#pragma parameter GRID_INTENSITY "Grid Intensity" 1.0 0.0 1.0 0.05
#pragma parameter GRID_WIDTH "Grid Width" 1.0 0.0 1.0 0.05
#pragma parameter GRID_BIAS "Grid Bias" 0.0 0.0 1.0 0.05
#pragma parameter DARKEN_GRID "Darken Grid" 0.0 0.0 1.0 0.05
#pragma parameter DARKEN_COLOUR "Darken Colours" 0.0 0.0 2.0 0.05
#pragma parameter BACKGROUND_INTENSITY "Background Intensity" 1.0 0.0 1.0 0.05
#include "shadow_cache.inc"
