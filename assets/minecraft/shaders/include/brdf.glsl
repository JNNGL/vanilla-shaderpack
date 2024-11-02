#version 330

#ifndef _GGX_GLSL
#define _GGX_GLSL

#extension GL_MC_moj_import : enable
#moj_import <minecraft:constants.glsl>

float DistributionGGX(vec3 N, vec3 H, float a) {
    float a2 = a * a;

    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float numerator = a2;
    float denominator = (NdotH2 * (a2 - 1.0) + 1.0);
    denominator *= denominator * PI;

    return numerator / denominator;
}

float SmithGGXMasking(vec3 N, vec3 V, float a) {
    a *= a;

    float NdotV = max(0.0, dot(N, V));
    float denom = sqrt(a + (1.0 - a) * NdotV * NdotV) + NdotV;

    return 2.0 * NdotV / max(denom, 1.0e-5);
}

float SmithGGXMaskingShadowing(vec3 N, vec3 V, vec3 L, float a) {
    a *= a;

    float NdotL = max(0.0, dot(N, L));
    float NdotV = max(0.0, dot(N, V));

    float denomA = NdotV * sqrt(a + (1.0 - a) * NdotL * NdotL);
    float denomB = NdotL * sqrt(a + (1.0 - a) * NdotV * NdotV);
    
    return 2.0 * NdotL * NdotV / max(denomA + denomB, 1.0e-5);
}

vec3 hammonDiffuse(vec3 albedo, vec3 N, vec3 V, vec3 L, vec3 H, vec3 F, float alpha) {
    float NdotV = max(0.0, dot(N, V));
    float LdotV = dot(L, V);
    float NdotH = max(0.05, dot(N, H));
    
    float facing = 0.5 + 0.5 * LdotV;
    float rough = facing * (0.9 - 0.4 * facing) * ((0.5 + NdotH) / NdotH);
    vec3 spec = 1.05 * (1.0 - F) * (1.0 - pow(1.0 - NdotV, 5.0));
    vec3 single = mix(spec, vec3(rough), alpha) / PI;
    float multi = 0.1159 * alpha;

    return albedo * (single + albedo * multi);
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 fresnelConductor(float cosT, vec3 N, vec3 K) {
    float cosT2 = cosT * cosT;
    float sinT2 = 1.0 - cosT2;
    float sinT4 = sinT2 * sinT2;

    vec3 N2K2sT = N * N - K * K - sinT2;
    vec3 a2b2 = sqrt(N2K2sT * N2K2sT + 4.0 * N * N * K * K);
    vec3 a = sqrt((a2b2 + N2K2sT) * 0.5);
    vec3 AcT = 2.0 * a * cosT;
    vec3 Rs = (a2b2 - AcT + cosT2) / (a2b2 + AcT + cosT2); // => (a2 + b2 - 2*a*cos + cos^2) / (a2 + b2 + 2*a*cos + cos^2)
    AcT *= sinT2; a2b2 *= cosT2; // => 2*a*cos*sin^2 ; cos^2 * (a2 + b2)
    vec3 Rp = Rs * (a2b2 - AcT + sinT4) / (a2b2 + AcT + sinT4); // => Rs * (cos^2 * (a2 + b2) - 2*a*cos*sin^2 + sin^4) / (cos^2 * (a2 + b2) + 2*a*cos*sin^2 + sin^4)

    return clamp((Rs + Rp) * 0.5, 0.0, 1.0);
}

#endif // _GGX_GLSL