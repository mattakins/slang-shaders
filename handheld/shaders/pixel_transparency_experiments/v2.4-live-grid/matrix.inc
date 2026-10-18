#pragma stage vertex
layout(location = PT_MATRIX_RED) flat out vec3 grid_red;
layout(location = PT_MATRIX_GREEN) flat out vec3 grid_green;
layout(location = PT_MATRIX_BLUE) flat out vec3 grid_blue;
void prepareGridMatrix() {
    grid_red = pow(vec3(global.RSUBPIX_R, global.RSUBPIX_G, global.RSUBPIX_B), vec3(2.2));
    grid_green = pow(vec3(global.GSUBPIX_R, global.GSUBPIX_G, global.GSUBPIX_B), vec3(2.2));
    grid_blue = pow(vec3(global.BSUBPIX_R, global.BSUBPIX_G, global.BSUBPIX_B), vec3(2.2));
}
#pragma stage fragment
layout(location = PT_MATRIX_RED) flat in vec3 grid_red;
layout(location = PT_MATRIX_GREEN) flat in vec3 grid_green;
layout(location = PT_MATRIX_BLUE) flat in vec3 grid_blue;
