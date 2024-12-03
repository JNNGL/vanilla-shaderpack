#version 330

#ifndef _ATMOSPHERE_GLSL
#define _ATMOSPHERE_GLSL

// Multiple scattering & LUTs from https://www.shadertoy.com/view/slSXRW

#extension GL_MC_moj_import : enable
#moj_import <minecraft:constants.glsl>
#moj_import <minecraft:intersectors.glsl>
#moj_import <minecraft:encodings.glsl>
#moj_import <settings:settings.glsl>

const float cameraHeight = CAMERA_HEIGHT;

const float sunIntensity = SUN_INTENSITY;

const float atmosphereRadius = ATMOSPHERE_RADIUS;
const float earthRadius = EARTH_RADIUS;

const vec3 rayleighScatteringBeta = RAYLEIGH_SCATTERING_BETA;
const vec4 rayleighDensityProfile = RAYLEIGH_DENSITY_PROFILE;

const float mieScatteringBeta = MIE_SCATTERING_BETA;
const vec4 mieDensityProfile = MIE_DENSITY_PROFILE;
const float mieAbsorptionBase = MIE_ABSORPTION_BASE;
const float mieAnisotropyFactor = MIE_ANISOTROPY_FACTOR;

const vec3 ozoneAbsorption = OZONE_ABSORPTION;
const vec4 ozoneDensityProfile = OZONE_DENSITY_PROFILE;

const vec3 groundAlbedo = EARTH_ALBEDO;

const ivec3 aerialPerspectiveResolution = ivec3(24);
const float aerialPerspectiveScale = AERIAL_PERSPECTIVE_SCALE;

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
    float densityExponential = densityProfile.x * exp(-densityProfile.y * height);
    float densityLinear = densityProfile.w == 0.0 ? 0.0 : 1.0 - abs(height / 1000.0 + densityProfile.z) / densityProfile.w;
    return clamp(densityExponential + densityLinear, 0.0, 1.0);
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
    vec2 texSize = textureSize(lut, 0);
    return decodeLogLuv(texture(lut, clamp(vec2(x, y), 1.0 / texSize, 1.0 - 1.0 / texSize)));
}

vec3 sampleMultipleScatteringLUT(sampler2D lut, vec3 position, vec3 sunDirection) {
    float height = length(position);
    vec3 direction = position / height;
    float cosTheta = dot(direction, sunDirection);
    float x = cosTheta * 0.5 + 0.5;
    float y = (height - earthRadius) / (atmosphereRadius - earthRadius);
    vec2 texSize = textureSize(lut, 0);
    return decodeLogLuv(texture(lut, clamp(vec2(x, y), 1.0 / texSize, 1.0 - 1.0 / texSize))) / 5.0;
}

vec3 computeTransmittanceToBoundary(vec3 position, vec3 direction, float travelDistance, int samples) {
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

    vec3 extinction = rayleighOpticalLength * rayleighScatteringBeta + mieOpticalLength * mieScatteringBeta + mieOpticalLength * mieAbsorptionBase + ozoneOpticalLength * ozoneAbsorption;
    return exp(-extinction);
}

vec3 computeTransmittanceToBoundary(vec3 position, vec3 direction, float travelDistance) {
    return computeTransmittanceToBoundary(position, direction, travelDistance, ATMOSPHERE_TRANSMITTANCE_SAMPLES);
}

mat2x3 raymarchAtmosphericScattering(sampler2D lut, sampler2D ms, vec3 position, vec3 direction, vec3 sunDirection, float travelDistance) {
    const int samples = ATMOSPHERE_RAYMARCH_SAMPLES;

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
        float ozoneDensity = atmosphereDensity(height, ozoneDensityProfile);

        vec3 lightTransmittance = sampleTransmittanceLUT(lut, samplePosition, sunDirection);
        vec3 psi = sampleMultipleScatteringLUT(ms, samplePosition, sunDirection);

        vec3 rayleighScattering = rayleighDensity * rayleighScatteringBeta;
        float mieScattering = mieDensity * mieScatteringBeta;
        vec3 scatteringIn = rayleighScattering * (rayleighPhase * lightTransmittance + psi) + mieScattering * (miePhase * lightTransmittance + psi);
        // vec3 scatteringIn = rayleighScattering * rayleighPhase * lightTransmittance + mieScattering * miePhase * lightTransmittance;

        vec3 extinction = rayleighScattering + mieScattering + mieDensity * mieAbsorptionBase + ozoneDensity * ozoneAbsorption;

        vec3 sampleTransmittance = exp(-dt * extinction);
        luminance += transmittance * (scatteringIn - scatteringIn * sampleTransmittance) / extinction;
        transmittance *= sampleTransmittance;
    }

    return mat2x3(luminance, transmittance);
}

vec3 computeMultipleScattering(sampler2D lut, vec3 position, vec3 sunDirection, out vec3 fms) {
    vec3 luminance = vec3(0.0);
    fms = vec3(0.0);

    const int tpSamples = ATMOSPHERE_MS_SAMPLES.x;
    const int msSamples = ATMOSPHERE_MS_SAMPLES.y;

    float invSamples = 1.0 / float(tpSamples * tpSamples);

    for (int i = 0; i < tpSamples; i++) {
        for (int j = 0; j < tpSamples; j++) {
            float theta = PI * (float(i) + 0.5) / float(tpSamples);
            float phi = acos(1.0 - 2.0 * (float(j) + 0.5) / float(tpSamples));
            vec3 rayDirection = vec3(sin(phi) * sin(theta), cos(phi), sin(phi) * cos(theta));
        
            float travelDistance = distanceToAtmosphereBoundary(position, rayDirection);
            float distanceToGround = distanceToEarth(position, rayDirection);
            if (distanceToGround > 0.0) travelDistance = distanceToGround;

            float cosTheta = dot(rayDirection, sunDirection);

            float miePhase = miePhaseFunction(cosTheta);
            float rayleighPhase = rayleighPhaseFunction(cosTheta);

            vec3 sampleLuminance = vec3(0.0);
            vec3 luminanceFactor = vec3(0.0);
            vec3 transmittance = vec3(1.0);

            float stepDistance = travelDistance / float(msSamples);
            for (int s = 0; s < msSamples; s++) {
                float dt = (s == 0 ? 0.5 : 1.0) * stepDistance;

                vec3 samplePosition = position + rayDirection * (float(s) + 0.5) * stepDistance;

                float height = length(samplePosition) - earthRadius;

                float rayleighDensity = atmosphereDensity(height, rayleighDensityProfile);
                float mieDensity = atmosphereDensity(height, mieDensityProfile);
                float ozoneDensity = atmosphereDensity(height, ozoneDensityProfile);

                vec3 rayleighScattering = rayleighDensity * rayleighScatteringBeta;
                float mieScattering = mieDensity * mieScatteringBeta;
                vec3 extinction = rayleighScattering + mieScattering + mieDensity * mieAbsorptionBase + ozoneDensity * ozoneAbsorption;

                vec3 sampleTransmittance = exp(-dt * extinction);

                vec3 scatteringNoPhase = rayleighScattering + mieScattering;
                vec3 scatteringF = (scatteringNoPhase - scatteringNoPhase * sampleTransmittance) / extinction;
                luminanceFactor += transmittance * scatteringF;

                vec3 lightTransmittance = sampleTransmittanceLUT(lut, samplePosition, sunDirection);
                vec3 scatteringIn = (rayleighScattering * rayleighPhase + mieScattering * miePhase) * lightTransmittance;

                sampleLuminance += transmittance * (scatteringIn - scatteringIn * sampleTransmittance) / extinction;
                transmittance *= sampleTransmittance;
            }

            if (distanceToGround > 0.0) {
                vec3 intersection = position + distanceToGround * rayDirection;
                if (dot(position, sunDirection) > 0.0) {
                    intersection = normalize(intersection) * earthRadius;
                    sampleLuminance += transmittance * groundAlbedo * sampleTransmittanceLUT(lut, intersection, sunDirection);
                }
            }

            fms += luminanceFactor * invSamples;
            luminance += sampleLuminance * invSamples;
        }
    }

    return luminance;
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

    return decodeLogLuv(texture(lut, uv * scale + 1.0 / texSize));
}

mat2x3 fetchAerialPerspectiveLUT(sampler2D lut, vec2 coord, vec2 invTexSize) {
    coord *= invTexSize;

    vec3 atmosphereLuminance = decodeLogLuv(texture(lut, coord));
    vec3 atmosphereTransmittance = decodeLogLuv(texture(lut, coord + vec2(0.0, 0.5)));
    return mat2x3(atmosphereLuminance, atmosphereTransmittance);
}

mat2x3 lerpAerialPerspectiveFroxels(mat2x3 a, mat2x3 b, float alpha) {
    return mat2x3(mix(a[0], b[0], alpha), mix(a[1], b[1], alpha));
}

mat2x3 sampleAerialPerspectiveLUT(sampler2D lut, vec2 texCoord, float linearDepth, vec2 planes) {
    const vec2 invLutRes = 1.0 / vec2(aerialPerspectiveResolution.x * aerialPerspectiveResolution.z, aerialPerspectiveResolution.y * 2);
    vec3 screenSpace = vec3(texCoord, (linearDepth - planes.x) / (planes.y - planes.x));

    vec3 froxelCoord = screenSpace * aerialPerspectiveResolution;
    
    int froxelZ = int(floor(froxelCoord.z)) - 1;
    int zMask = int(froxelZ != aerialPerspectiveResolution.z - 1);

    froxelCoord.xy = clamp(froxelCoord.xy, vec2(0.5), aerialPerspectiveResolution.xy - 0.5);
    vec2 fragCoord = vec2(froxelZ * aerialPerspectiveResolution.x + froxelCoord.x, froxelCoord.y);

    mat2x3 z0 = mat2x3(vec3(0.0), vec3(1.0));
    if (froxelZ >= 0) z0 = fetchAerialPerspectiveLUT(lut, fragCoord, invLutRes);
    mat2x3 z1 = fetchAerialPerspectiveLUT(lut, fragCoord + vec2(zMask * aerialPerspectiveResolution.x, 0.0), invLutRes);

    return lerpAerialPerspectiveFroxels(z0, z1, fract(froxelCoord.z));
}

#endif // _ATMOSPHERE_GLSL