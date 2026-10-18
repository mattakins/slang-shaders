#pragma stage vertex
#ifdef PT_GRID_LCD_GRID_V2
layout(location = 12) flat out vec3 grid_red;
layout(location = 13) flat out vec3 grid_green;
layout(location = 14) flat out vec3 grid_blue;
#endif
void prepareLCD() {
#ifdef PT_GRID_LCD_GRID_V2
    grid_red = pow(vec3(global.RSUBPIX_R, global.RSUBPIX_G, global.RSUBPIX_B), vec3(2.2));
    grid_green = pow(vec3(global.GSUBPIX_R, global.GSUBPIX_G, global.GSUBPIX_B), vec3(2.2));
    grid_blue = pow(vec3(global.BSUBPIX_R, global.BSUBPIX_G, global.BSUBPIX_B), vec3(2.2));
#endif
}
#pragma stage fragment
#ifdef PT_GRID_LCD_GRID_V2
layout(location = 12) flat in vec3 grid_red;
layout(location = 13) flat in vec3 grid_green;
layout(location = 14) flat in vec3 grid_blue;
#endif
