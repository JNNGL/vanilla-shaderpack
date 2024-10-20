#version 330

#ifndef _GGX_GLSL
#define _GGX_GLSL

#extension GL_MC_moj_import : enable
#moj_import <minecraft:constants.glsl>

float DistributionGGX(vec3 N, vec3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float nominator = a2;
    float denominator = (NdotH2 * (a2 - 1.0) + 1.0);
    denominator *= denominator * PI;

    return nominator / denominator;
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;

    float nominator = NdotV;
    float denominator = NdotV * (1.0 - k) + k;

    return nominator / denominator;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx1 = GeometrySchlickGGX(NdotV, roughness);
    float ggx2 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

#endif // _GGX_GLSL