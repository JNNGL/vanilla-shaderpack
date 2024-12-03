#version 330

#ifndef _UTILS_GLSL
#define _UTILS_GLSL

bool isUnderWater(vec3 fogColor) {
    float t = fogColor.b * (1.0 / 7.0);
    return fogColor.r <= t && fogColor.g <= t;
}

#endif // _UTILS_GLSL