#version 330

#ifndef _FRESNEL_GLSL
#define _FRESNEL_GLSL

#extension GL_MC_moj_import : enable
#moj_import <minecraft:metals.glsl>

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * clamp(pow(1.0 - cosTheta, 5.0), 0.0, 1.0);
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

vec3 F0toIOR(vec3 f0) {
    vec3 r = sqrt(f0);
    return (1.0 + r) / max(1.0 - r, 1.0e-5);
}

vec3 fresnel(int metalId, float cosTheta, vec3 albedo, vec3 f0) {
    cosTheta = max(cosTheta, 0.0);

    if (metalId >= 230) {
        mat2x3 NK = metalId > 237 ? mat2x3(F0toIOR(albedo), vec3(0.0)) : HARDCODED_METALS[metalId - 230];
        return fresnelConductor(cosTheta, NK[0], NK[1]);
    } else {
        vec3 F0 = f0;
        return fresnelSchlick(cosTheta, F0);
    }
}

#endif // _FRESNEL_GLSL