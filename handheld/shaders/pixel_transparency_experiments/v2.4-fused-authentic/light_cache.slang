#version 450
// Lighting follows the viewport even when LCDInput is the native colour buffer.
#define PT_LIGHT_VIEWPORT FinalViewportSize
#include "../../pixel_transparency/light_cache.inc"
