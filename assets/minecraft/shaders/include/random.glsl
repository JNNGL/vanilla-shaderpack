#version 330

#ifndef _RANDOM_GLSL
#define _RANDOM_GLSL

#extension GL_MC_moj_import : enable
#moj_import <minecraft:constants.glsl>

vec3 random(sampler2D noiseSampler, vec2 fragCoord, float seed) {
    ivec2 coord = ivec2(mod(fragCoord.xy + vec2(0.7548, 0.5698) * 512.0 * seed, 512));
    return texelFetch(noiseSampler, coord, 0).xyz;
}

vec2 randomPointOnDisk(sampler2D noiseSampler, vec2 fragCoord, float seed) {
    vec3 rand = random(noiseSampler, fragCoord, seed);
    float angle = rand.y * 2.0 * PI;
    float sr = sqrt(rand.x);
    return vec2(sr * cos(angle), sr * sin(angle));
}

vec3 randomPointOnSphere(sampler2D noiseSampler, vec2 fragCoord, float seed) {
    vec3 rand = random(noiseSampler, fragCoord, seed);
    float angle = rand.x * 2.0 * PI;
    float u = rand.y * 2.0 - 1.0;
    float sr = sqrt(1.0 - u * u);
    return vec3(sr * cos(angle), sr * sin(angle), u);
}

vec3 randomPointOnHemisphere(sampler2D noiseSampler, vec2 fragCoord, float seed) {
    vec3 point = randomPointOnSphere(noiseSampler, fragCoord, seed);
    point.y = abs(point.y);
    return point;
}

vec3 randomPointOnHemisphere(sampler2D noiseSampler, vec2 fragCoord, float seed, vec3 normal) {
    vec3 onSphere = randomPointOnSphere(noiseSampler, fragCoord, seed);
    return onSphere * sign(dot(onSphere, normal));
}

vec3 randomCosineWeightedPointOnHemisphere(sampler2D noiseSampler, vec2 fragCoord, float seed) {
    vec2 p = randomPointOnDisk(noiseSampler, fragCoord, seed);
    return vec3(p, sqrt(1.0 - dot(p, p))); // p.p = r*cos^2+r*sin^2 = r
}

vec3 randomCosineWeightedPointOnHemisphere(sampler2D noiseSampler, vec2 fragCoord, float seed, vec3 n) {
    vec3 p = randomCosineWeightedPointOnHemisphere(noiseSampler, fragCoord, seed);
    vec3 t = normalize(cross(vec3(0, 1, 1), n));
    return t * p.x + cross(t, n) * p.y + n * p.z;
}

#endif // _RANDOM_GLSL