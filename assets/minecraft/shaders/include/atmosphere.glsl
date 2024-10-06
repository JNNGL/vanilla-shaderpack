#version 330

#ifndef _ATMOSPHERE_GLSL
#define _ATMOSPHERE_GLSL

#extension GL_MC_moj_import : enable
#moj_import <minecraft:constants.glsl>
#moj_import <minecraft:intersectors.glsl>
#moj_import <minecraft:encodings.glsl>
#moj_import <minecraft:random.glsl>
#moj_import <minecraft:shadow.glsl>
#moj_import <minecraft:bilinear.glsl>

const float cameraHeight = 2000;

const float atmosphereRadius = 6460.0e3;
const float earthRadius = 6360.0e3;

const vec3 rayleighScatteringBeta = vec3(5.8e-6, 13.5e-6, 33.1e-6);
const vec4 rayleighDensityProfile = vec4(1.0, 1.0 / 8.0e3, 0.0, 0.0);

const float mieScatteringBeta = 3.9e-5;
const vec4 mieDensityProfile = vec4(1.0, 1.0 / 1.2e3, 0.0, 0.0);
const float mieAnisotropyFactor = 0.7;

const vec3 ozoneAbsorption = vec3(0.650e-6, 1.881e-6, 0.085e-6);
const vec4 ozoneDensityProfile = vec4(0.0, 0.0, -1.0e-3 / 15.0, 8.0 / 3.0);

float rayleighPhaseFunction(float cosTheta) {
    return 3.0 / (16.0 * PI) * (1.0 + cosTheta * cosTheta);
}

float miePhaseFunction(float cosTheta) {
    const float g = mieAnisotropyFactor;
    float n = (1.0 - g * g) * (1.0 + cosTheta * cosTheta);
    float d = (2.0 + g * g) * pow((1.0 + g * g - 2.0 * g * cosTheta), 1.5);
    return 3.0 / (8.0 * PI) * (n / d);
}

float atmosphereDensity(float height, vec4 densityProfile) {
    return clamp(densityProfile.x * exp(-densityProfile.y * height) + densityProfile.z * height + densityProfile.w, 0.0, 1.0);
}

float distanceToAtmosphereBoundary(vec3 position, vec3 direction) {
    vec2 t = raySphereIntersection(position, direction, atmosphereRadius);
    return t.x < 0.0 ? t.y : t.x;
}

float distanceToEarth(vec3 position, vec3 direction) {
    vec2 t = raySphereIntersection(position, direction, earthRadius);
    return t.x < 0.0 ? t.y : t.x;
}

vec3 sampleTransmittanceLUT(sampler2D lut, vec3 position, vec3 sunDirection) {
    float height = length(position);
    vec3 direction = position / height;
    float cosTheta = dot(direction, sunDirection);
    float x = cosTheta * 0.5 + 0.5;
    float y = (height - earthRadius) / (atmosphereRadius - earthRadius);
    return textureBilinearR11G11B10L(lut, clamp(vec2(x, y), 0.0, 1.0));
}

vec3 computeTransmittanceToBoundary(vec3 position, vec3 direction, float travelDistance) {
    const int samples = 40;

    float rayleighOpticalLength = 0.0;
    float mieOpticalLength = 0.0;
    float ozoneOpticalLength = 0.0;

    float stepDistance = travelDistance / float(samples);
    for (int i = 0; i <= samples; i++) {
        float dt = stepDistance * (i == 0 || i == samples ? 0.5 : 1.0);

        vec3 samplePosition = position + direction * (i + 0.5) * stepDistance;
        float height = length(samplePosition) - earthRadius;

        rayleighOpticalLength += atmosphereDensity(height, rayleighDensityProfile) * dt;
        mieOpticalLength += atmosphereDensity(height, mieDensityProfile) * dt;
        ozoneOpticalLength += atmosphereDensity(height, ozoneDensityProfile) * dt;
    }

    vec3 extinction = rayleighOpticalLength * rayleighScatteringBeta + mieOpticalLength * mieScatteringBeta * 1.1 + ozoneOpticalLength * ozoneAbsorption;
    return exp(-extinction);
}

vec3 projectShadowMap(sampler2D shadowMap, mat4 lightProj, vec3 position, vec3 normal) {
    vec4 lightSpace = lightProj * vec4(position, 1.0);

    float bias;
    lightSpace = distortShadow(lightSpace, bias);
    lightSpace.xyz += (lightProj * vec4(normal, 1.0)).xyz * bias;

    vec3 projLightSpace = lightSpace.xyz * 0.5 + 0.5;
    if (clamp(projLightSpace, 0.0, 1.0) == projLightSpace) {
        float closestDepth = unpackF32fromF8x4(texture(shadowMap, projLightSpace.xy));
        return vec3(projLightSpace.z, closestDepth, bias);
    }

    return vec3(-1.0, -1.0, 0.0);
}

bool checkOcclusion(vec3 projection, vec3 lightDir, vec3 normal) {
    float NdotL = dot(normal, lightDir);
    return projection.x - projection.z / (abs(NdotL) * 0.3) > projection.y;
}

mat2x3 raymarchAtmosphericScattering(sampler2D lut, sampler2D noise, sampler2D shadowMap, mat4 lightProj, vec3 normal, vec2 fragCoord, vec3 position, vec3 direction, vec3 shadowPosition, vec3 sunDirection, float travelDistance, float scale) {
    const int samples = 32;

    float cosTheta = dot(direction, sunDirection);
    float rayleighPhase = rayleighPhaseFunction(cosTheta);
    float miePhase = miePhaseFunction(cosTheta);

    vec3 luminance = vec3(0.0);
    vec3 transmittance = vec3(1.0);
    float stepDistance = travelDistance / float(samples);
    for (int i = 0; i < samples; i++) {
        float dt = (i == 0 ? 0.5 : 1.0) * stepDistance * scale;

        float jitter = random(noise, fragCoord, i).x * 254.0 / 255.0;

        vec3 shadowSamplePosition = shadowPosition + direction * (float(i) + jitter) * stepDistance;
        vec3 samplePosition = position + direction * (float(i) + 0.5) * stepDistance * scale;

        vec3 projection = projectShadowMap(shadowMap, lightProj, shadowSamplePosition, normal);
        bool occlusion = checkOcclusion(projection, sunDirection, normal);

        float height = length(samplePosition) - earthRadius;

        float rayleighDensity = atmosphereDensity(height, rayleighDensityProfile);
        float mieDensity = atmosphereDensity(height, mieDensityProfile);
        float ozoneDensity = atmosphereDensity(height, ozoneDensityProfile);

        vec3 rayleighScattering = rayleighDensity * rayleighScatteringBeta;
        float mieScattering = mieDensity * mieScatteringBeta;
        vec3 scatteringIn = rayleighScattering * rayleighPhase + mieScattering * miePhase;

        if (!occlusion) {
            vec3 lightTransmittance = sampleTransmittanceLUT(lut, samplePosition, sunDirection);
            luminance += scatteringIn * transmittance * lightTransmittance * dt;
        }

        vec3 extinction = rayleighScattering + 1.1 * mieScattering + ozoneDensity * ozoneAbsorption;
        transmittance *= exp(-dt * extinction);
    }

    return mat2x3(luminance, transmittance);
}

#endif // _ATMOSPHERE_GLSL