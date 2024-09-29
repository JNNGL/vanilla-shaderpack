#version 330

#ifndef _WAVING_GLSL
#define _WAVING_GLSL

#extension GL_MC_moj_import : enable
#moj_import <minecraft:constants.glsl>

vec3 applyWaving(vec3 position, float time) {
    float animation = time * PI;
    float magnitude = sin(animation * 136 + position.z * PI / 4.0 + position.y * PI / 4.0) * 0.04 + 0.04;
    
    float d0 = sin(animation * 636);
    float d1 = sin(animation * 446);
    float d2 = sin(animation * 570);

    vec3 wave;
    wave.x = sin(animation * 316 + d0 + d1 - position.x * PI / 4.0 + position.z * PI / 4.0 + position.y * PI / 4.0) * magnitude;
    wave.z = sin(animation * 1120 + d1 + d2 + position.x * PI / 4.0 - position.z * PI / 4.0 + position.y * PI / 4.0) * magnitude;
    wave.y = sin(animation * 70 + d2 + d0 + position.z * PI / 4.0 + position.y * PI / 4.0 - position.y * PI / 4.0) * magnitude;

    vec3 newPosition = position;
    newPosition.x += 0.2 * (wave.x * 2.0 + wave.y * 1.0);
    newPosition.z += 0.2 * (wave.z * 0.75);
    newPosition.x += 0.01 * sin(sin(animation * 100) * 8.0 + (position.x + position.y) / 4.0 * PI);
    newPosition.z += 0.01 * sin(sin(animation * 60) * 6.0 + 978.0 + (position.z + position.y) / 4.0 * PI);

    return newPosition;
}

#endif // _WAVING_GLSL