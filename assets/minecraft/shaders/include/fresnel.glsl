#version 330

#ifndef _FRESNEL_GLSL
#define _FRESNEL_GLSL

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * clamp(pow(1.0 - cosTheta, 5.0), 0.0, 1.0);
}

vec3 fresnelConductor(float cosTheta, vec3 N, vec3 K) {
    float cosTheta2 = cosTheta * cosTheta;  
    float sinTheta2 = 1.0 - cosTheta2;  
    vec3 n2 = N * N, k2 = K * K;

    vec3 t0 = n2 - k2 - sinTheta2;
    vec3 a2b2 = sqrt(t0 * t0 + 4.0 * n2 * k2);
    vec3 t1 = a2b2 + cosTheta2;
    vec3 a = sqrt(0.5 * (a2b2 + t0));
    vec3 t2 = 2.0 * a * cosTheta;
    vec3 Rs = (t1 - t2) / (t1 + t2);

    vec3 t3 = cosTheta2 * a2b2 + sinTheta2 * sinTheta2;
    vec3 t4 = t2 * sinTheta2;
    vec3 Rp = Rs * (t3 - t4) / (t3 + t4);

    return 0.5 * (Rp + Rs);
}

vec3 F0toIOR(vec3 f0) {
    vec3 r = sqrt(f0);
    return (1.0 + r) / max(1.0 - r, 1.0e-5);
}

vec3 fresnel(int metalId, float cosTheta, vec3 albedo, vec3 f0) {
    cosTheta = max(cosTheta, 0.0);

    if (metalId >= 230) {
        mat2x3 NK = mat2x3(F0toIOR(albedo), vec3(0.0));
        return fresnelConductor(cosTheta, NK[0], NK[1]);
    } else {
        vec3 F0 = f0;
        return fresnelSchlick(cosTheta, F0);
    }
}

#endif // _FRESNEL_GLSL