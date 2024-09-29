#version 330

#ifndef _SRGB_GLSL
#define _SRGB_GLSL

// TODO: Better approximation
vec3 linearToSrgb(vec3 linear) {
    return pow(linear, vec3(1.0 / 2.2));
}

vec3 srgbToLinear(vec3 srgb) {
    return pow(srgb, vec3(2.2));
}

#endif // _SRGB_GLSL