#version 330

#ifndef _SHADOW_GLSL
#define _SHADOW_GLSL

#extension GL_MC_moj_import : enable
#moj_import <minecraft:matrices.glsl>

float getDistortionFactor(vec4 clipSpace) {
    return length(clipSpace.xy) + 0.1;
}

float getDistortionBias(float distortionFactor) {
    float numerator = distortionFactor * distortionFactor;
    return 1.5 / 1024.0 * numerator / 0.1;
}

vec4 applyDistortion(vec4 clipSpace, float distortionFactor) {
    return vec4(clipSpace.xy / distortionFactor, clipSpace.zw);
}

vec4 distortShadow(vec4 clipSpace, out float bias) {
    float distortionFactor = getDistortionFactor(clipSpace);
    bias = getDistortionBias(distortionFactor);
    return applyDistortion(clipSpace, distortionFactor);
}

vec4 distortShadow(vec4 clipSpace) {
    return applyDistortion(clipSpace, getDistortionFactor(clipSpace));
}

bool isShadowMapFrame(float time) {
    return (int(round(time * 514229.0)) % 15) == 0;
}

vec3 getShadowEyeLocation(float time) {
    // mat3 rotation = rotationZMatrix(-radians(mod(degrees(time * 50), 180)));
    // return rotation * vec3(128.0, 0.0, 15.0);
    // return vec3(10, 8.6, 5);
    // return vec3(40.0, 34.0, 20.0);
    // return vec3(40.0, 15.0, 7.0); ////// sunset
    return vec3(30.0, 8.0, 40.0) * 2.5;
    
    // return vec3(300.0, 500.0, 400.0) * 0.5;
    // return vec3(40.0, 34.0, 0.0);
}

mat4 shadowProjectionMatrix() {
    return orthographicProjectionMatrix(-128.0, 128.0, -128.0, 128.0, 0.05, 128.0);
}

mat4 shadowTransformationMatrix(float time) {
    vec3 eye = getShadowEyeLocation(time);
    return lookAtTransformationMatrix(eye, vec3(0.0), vec3(0.0, 1.0, 0.0));
}

#endif // _SHADOW_GLSL