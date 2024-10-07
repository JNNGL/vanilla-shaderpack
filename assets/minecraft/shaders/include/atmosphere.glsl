#version 330

#ifndef _ATMOSPHERE_GLSL
#define _ATMOSPHERE_GLSL

#extension GL_MC_moj_import : enable
#moj_import <minecraft:constants.glsl>
#moj_import <minecraft:intersectors.glsl>
#moj_import <minecraft:encodings.glsl>
#moj_import <minecraft:bilinear.glsl>

const float cameraHeight = 2000;

const float sunIntensity = 30.0;

const float atmosphereRadius = 6460.0e3;
const float earthRadius = 6360.0e3;

const vec3 rayleighScatteringBeta = vec3(5.8e-6, 13.5e-6, 33.1e-6);
const vec4 rayleighDensityProfile = vec4(1.0, 1.0 / 8.0e3, 0.0, 0.0);

const float mieScatteringBeta = 2.0e-5;
const vec4 mieDensityProfile = vec4(1.0, 1.0 / 1.2e3, 0.0, 0.0);
const float mieAnisotropyFactor = 0.7;

const vec3 ozoneAbsorption = vec3(0.650e-6, 1.881e-6, 0.085e-6);
const vec4 ozoneDensityProfile = vec4(0.0, 0.0, -1.0e-3 / 15.0, 8.0 / 3.0);

const ivec3 aerialPerspectiveResolution = ivec3(24);
const float aerialPerspectiveScale = 40.0;

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
        ozoneOpticalLength += max(0.0, 1.0 - abs(height / 1000.0 - 25.0) / 15.0) * dt;
    }

    vec3 extinction = rayleighOpticalLength * rayleighScatteringBeta + mieOpticalLength * mieScatteringBeta * 1.1 + ozoneOpticalLength * ozoneAbsorption;
    return exp(-extinction);
}

mat2x3 raymarchAtmosphericScattering(sampler2D lut, vec3 position, vec3 direction, vec3 sunDirection, float travelDistance) {
    const int samples = 16;

    float cosTheta = dot(direction, sunDirection);
    float rayleighPhase = rayleighPhaseFunction(cosTheta);
    float miePhase = miePhaseFunction(cosTheta);

    vec3 luminance = vec3(0.0);
    vec3 transmittance = vec3(1.0);
    float stepDistance = travelDistance / float(samples);
    for (int i = 0; i < samples; i++) {
        float dt = (i == 0 ? 0.5 : 1.0) * stepDistance;

        vec3 samplePosition = position + direction * (float(i) + 0.5) * stepDistance;

        float height = length(samplePosition) - earthRadius;

        float rayleighDensity = atmosphereDensity(height, rayleighDensityProfile);
        float mieDensity = atmosphereDensity(height, mieDensityProfile);
        float ozoneDensity = max(0.0, 1.0 - abs(height / 1000.0 - 25.0) / 15.0);

        vec3 rayleighScattering = rayleighDensity * rayleighScatteringBeta;
        float mieScattering = mieDensity * mieScatteringBeta;
        vec3 scatteringIn = rayleighScattering * rayleighPhase + mieScattering * miePhase;

        vec3 lightTransmittance = sampleTransmittanceLUT(lut, samplePosition, sunDirection);
        luminance += scatteringIn * transmittance * lightTransmittance * dt;

        vec3 extinction = rayleighScattering + 1.1 * mieScattering + ozoneDensity * ozoneAbsorption;
        transmittance *= exp(-dt * extinction);
    }

    return mat2x3(luminance, transmittance);
}

vec3 sampleSkyLUT(sampler2D lut, vec3 direction, vec3 sunDirection) {
    float height = earthRadius + cameraHeight;
    vec3 normal = vec3(0.0, 1.0, 0.0);

    float horizonAngle = acos(sqrt(height * height - earthRadius * earthRadius) / height);
    float altitudeAngle = horizonAngle - acos(dot(direction, normal));
    
    float azimuthAngle = 0.0;
    if (abs(altitudeAngle) > 0.5 * PI - 0.0001) {
        azimuthAngle = 0.0;
    } else {
        vec3 right = cross(sunDirection, normal);
        vec3 forward = cross(normal, right);

        vec3 projectedDirection = normalize(direction - normal * dot(direction, normal));
        float sinTheta = dot(projectedDirection, right);
        float cosTheta = dot(projectedDirection, forward);

        azimuthAngle = atan(sinTheta, cosTheta) + PI;
    }

    float v = 0.5 + 0.5 * sign(altitudeAngle) * sqrt(abs(altitudeAngle) * 2.0 / PI);
    vec2 uv = vec2(azimuthAngle / (2.0 * PI), v);
    
    vec2 texSize = textureSize(lut, 0);
    vec2 scale = (texSize - 2.0) / texSize;

    return textureBilinearR11G11B10Lpow2(lut, uv * scale + 1.0 / texSize);
}

#endif // _ATMOSPHERE_GLSL