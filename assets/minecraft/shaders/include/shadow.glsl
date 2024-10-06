#version 330

#ifndef _SHADOW_GLSL
#define _SHADOW_GLSL

#extension GL_MC_moj_import : enable
#moj_import <minecraft:random.glsl>
#moj_import <minecraft:matrices.glsl>
#moj_import <minecraft:constants.glsl>

float getDistortionFactor(vec4 clipSpace) {
    return length(clipSpace.xy) + 0.1;
}

float getDistortionBias(float distortionFactor) {
    float numerator = distortionFactor * distortionFactor;
    return 0.25 / 1024.0 * numerator / 0.1;
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
    return (hash(floatBitsToUint(time + 13.0)) % 8u) == 0u;
}

const float sunPathRotationX = radians(30.0);
const mat3 sunRotationMatrix = MAT3_ROTATE_X(sunPathRotationX);

const vec3 shadowMapLocations[] = vec3[](
    sunRotationMatrix * vec3(1, 0, 0),
    sunRotationMatrix * vec3(0.995185, 0.0980171, 0),
    sunRotationMatrix * vec3(0.980785, 0.19509, 0),
    sunRotationMatrix * vec3(0.95694, 0.290285, 0),
    sunRotationMatrix * vec3(0.92388, 0.382683, 0),
    sunRotationMatrix * vec3(0.881921, 0.471397, 0),
    sunRotationMatrix * vec3(0.83147, 0.55557, 0),
    sunRotationMatrix * vec3(0.77301, 0.634393, 0),
    sunRotationMatrix * vec3(0.707107, 0.707107, 0),
    sunRotationMatrix * vec3(0.634393, 0.77301, 0),
    sunRotationMatrix * vec3(0.55557, 0.83147, 0),
    sunRotationMatrix * vec3(0.471397, 0.881921, 0),
    sunRotationMatrix * vec3(0.382683, 0.92388, 0),
    sunRotationMatrix * vec3(0.290285, 0.95694, 0),
    sunRotationMatrix * vec3(0.19509, 0.980785, 0),
    sunRotationMatrix * vec3(0.0980171, 0.995185, 0),
    sunRotationMatrix * vec3(0, 1, 0),
    sunRotationMatrix * vec3(-0.0980171, 0.995185, 0),
    sunRotationMatrix * vec3(-0.19509, 0.980785, 0),
    sunRotationMatrix * vec3(-0.290285, 0.95694, 0),
    sunRotationMatrix * vec3(-0.382683, 0.92388, 0),
    sunRotationMatrix * vec3(-0.471397, 0.881921, 0),
    sunRotationMatrix * vec3(-0.55557, 0.83147, 0),
    sunRotationMatrix * vec3(-0.634393, 0.77301, 0),
    sunRotationMatrix * vec3(-0.707107, 0.707107, 0),
    sunRotationMatrix * vec3(-0.77301, 0.634393, 0),
    sunRotationMatrix * vec3(-0.83147, 0.55557, 0),
    sunRotationMatrix * vec3(-0.881921, 0.471397, 0),
    sunRotationMatrix * vec3(-0.92388, 0.382683, 0),
    sunRotationMatrix * vec3(-0.95694, 0.290285, 0),
    sunRotationMatrix * vec3(-0.980785, 0.19509, 0),
    sunRotationMatrix * vec3(-0.995185, 0.0980171, 0),
    sunRotationMatrix * vec3(-1, 0, 0)
);

vec3 getShadowEyeLocation(float skyFactor, float time) {
    vec3 sunDirection;

    float rand = random01(time) - 0.0000001;
    if (skyFactor > 0.24 && skyFactor < 1.0) {
        float x = acos(0.5 * (((skyFactor - 0.05) / 0.95 - 0.2) / 0.8) - 0.1);
        float alpha = rand >= 0.5 ? x : 2.0 * PI - x;

        sunDirection = rotateAroundZMatrix(3.0 * PI / 2.0 - alpha) * vec3(1.0, 0.0, 0.0);
        sunDirection = sunRotationMatrix * sunDirection;
    } else {
        int id = int(floor(rand * 33.0));
        sunDirection = shadowMapLocations[id];
    }

    return sunDirection * 256.0;
}

mat4 shadowProjectionMatrix() {
    return orthographicProjectionMatrix(-256.0, 256.0, -256.0, 256.0, 0.05, 512.0);
}

mat4 shadowTransformationMatrix(float skyFactor, float time) {
    vec3 eye = getShadowEyeLocation(skyFactor, time);
    return lookAtTransformationMatrix(eye, vec3(0.0), vec3(0.0, 1.0, 0.0));
}

#endif // _SHADOW_GLSL