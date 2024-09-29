#version 330

#ifndef _ACES_GLSL
#define _ACES_GLSL

// https://github.com/TheRealMJP/BakingLab/blob/master/BakingLab/ACES.hlsl
const mat3 acesInputMat = mat3(
    0.59719, 0.07600, 0.02840,
    0.35458, 0.90834, 0.13383,
    0.04823, 0.01566, 0.83777
);

const mat3 acesOutputMat = mat3(
    1.60475, -0.10208, -0.00327,
    -0.53108, 1.10813, -0.07276,
    -0.07367, -0.00605, 1.07602
);

vec3 RRTandODTfit(vec3 v) {
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return a / b;
}

vec3 acesFitted(vec3 color) {
    color = acesInputMat * color;
    color = RRTandODTfit(color);
    color = acesOutputMat * color;
    return clamp(color, 0.0, 1.0);
}

#endif // _ACES_GLSL