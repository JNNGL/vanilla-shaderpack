#version 330

#ifndef _BRDF_GLSL
#define _BRDF_GLSL

#extension GL_MC_moj_import : enable
#moj_import <minecraft:constants.glsl>

float GetNoHSquared(float radiusTan, float NoL, float NoV, float VoL) {
    float radiusCos = inversesqrt(1.0 + radiusTan * radiusTan);

    float RoL = 2.0 * NoL * NoV - VoL;
    if (RoL >= radiusCos) {
        return 1.0;
    }

    float rOverLengthT = radiusCos * radiusTan * inversesqrt(1.0 - RoL * RoL);
    float NoTr = rOverLengthT * (NoV - RoL * NoL);
    float VoTr = rOverLengthT * (2.0 * NoV * NoV - 1.0 - RoL * VoL);

    float triple = sqrt(clamp(1.0 - NoL * NoL - NoV * NoV - VoL * VoL + 2.0 * NoL * NoV * VoL, 0.0, 1.0));

    float NoBr = rOverLengthT * triple, VoBr = rOverLengthT * (2.0 * triple * NoV);
    float NoLVTr = NoL * radiusCos + NoV + NoTr, VoLVTr = VoL * radiusCos + 1.0 + VoTr;
    float p = NoBr * VoLVTr, q = NoLVTr * VoLVTr, s = VoBr * NoLVTr;
    float xNum = q * (-0.5 * p + 0.25 * VoBr * NoLVTr);
    float xDenom = p * p + s * ((s - 2.0 * p)) + NoLVTr * ((NoL * radiusCos + NoV) * VoLVTr * VoLVTr + q * (-0.5 * (VoLVTr + VoL * radiusCos) - 0.5));
    float twoX1 = 2.0 * xNum / (xDenom * xDenom + xNum * xNum);
    float sinTheta = twoX1 * xDenom;
    float cosTheta = 1.0 - twoX1 * xNum;
    NoTr = cosTheta * NoTr + sinTheta * NoBr;
    VoTr = cosTheta * VoTr + sinTheta * VoBr;

    float newNoL = NoL * radiusCos + NoTr;
    float newVoL = VoL * radiusCos + VoTr;
    float NoH = NoV + newNoL;
    float HoH = 2.0 * newVoL + 2.0;
    return max(0.0, NoH * NoH / HoH);
}

float DistributionGGX(float NdotH2, float a) {
    float a2 = a * a;

    float numerator = a2;
    float denominator = (NdotH2 * (a2 - 1.0) + 1.0);
    denominator *= denominator * PI;

    return numerator / denominator;
}

float SmithGGXMasking(vec3 N, vec3 V, float a) {
    a *= a;

    float NdotV = max(1.0e-5, dot(N, V));
    float denom = sqrt(a + (1.0 - a) * NdotV * NdotV) + NdotV;

    return 2.0 * NdotV / max(denom, 1.0e-6);
}

float SmithGGXMaskingShadowing(vec3 N, vec3 V, vec3 L, float a) {
    a *= a;

    float NdotL = max(1.0e-5, dot(N, L));
    float NdotV = max(1.0e-5, dot(N, V));

    float denomA = NdotV * sqrt(a + (1.0 - a) * NdotL * NdotL);
    float denomB = NdotL * sqrt(a + (1.0 - a) * NdotV * NdotV);
    
    return 2.0 * NdotL * NdotV / max(denomA + denomB, 1.0e-6);
}

vec3 sampleGGXVNDF(vec3 V, float roughness, vec2 u) {
    V = normalize(vec3(V.xy * roughness, V.z));
    
    float phi = 2.0 * PI * u.x;
    float z = (1.0 - u.y) * (1.0 + V.z) - V.z;
    float r = sqrt(clamp(1.0 - z * z, 0.0, 1.0));
    vec2 xy = vec2(cos(phi), sin(phi)) * r;

    vec3 H = vec3(xy, z) + V;
    return normalize(vec3(H.xy * roughness, H.z));
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

#endif // _BRDF_GLSL