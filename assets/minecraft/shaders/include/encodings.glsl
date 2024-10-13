#version 330

#ifndef _ENCODINGS_GLSL
#define _ENCODINGS_GLSL

vec3 packSI24toF8x3(int i) {
    int sgn = int(i < 0);
    i = abs(i);
    return vec3(i & 0xFF, (i >> 8) & 0xFF, ((i >> 16) & 0x7F) | (sgn << 7)) / 255.0;
}

int unpackSI24fromF8x3(vec3 v) {
    ivec3 data = ivec3(v * 255.0);
    int sgn = data.b >> 7;
    int n = data.r | (data.g << 8) | ((data.b & 0x7F) << 16);
    return (sgn > 0 ? -1 : 1) * (n);
}

vec3 packUI24toF8x3(uint u) {
    return vec3(u & 0xFFu, (u >> 8u) & 0xFFu, (u >> 16u) & 0xFFu) / 255.0;
}

uint unpackUI24fromF8x3(vec3 v) {
    uvec3 data = uvec3(v * 255.0);
    return data.r | (data.g << 8u) | (data.b << 16u);
}

#define FP_PRECISION_UNIT   8388607.0
#define FP_PRECISION_HIGH   400000.0
#define FP_PRECISION_MEDIUM 10000.0
#define FP_PRECISION_LOW    1000.0

vec3 packFPtoF8x3(float x, float fpPrecision) {
    int i = int(round(x * fpPrecision));
    return packSI24toF8x3(i);
}

float unpackFPfromF8x3(vec3 v, float fpPrecision) {
    return float(unpackSI24fromF8x3(v)) / fpPrecision;
}

vec4 packUI32toF8x4(uint u) {
    return vec4(u >> 24u, (u >> 16u) & 0xFFu, (u >> 8u) & 0xFFu, u & 0xFFu) / 255.0;
}

uint unpackUI32fromF8x4(vec4 v) {
    uvec4 data = uvec4(v * 255.0);
    return (data.r << 24u) | (data.g << 16u) | (data.b << 8u) | data.a;
}

vec4 packSI32toF8x4(int i) {
    return vec4(i >> 24, (i >> 16) & 0xFF, (i >> 8) & 0xFF, i & 0xFF) / 255.0;
}

int unpackSI32fromF8x4(vec4 v) {
    ivec4 data = ivec4(v * 255.0);
    return (data.r << 24) | (data.g << 16) | (data.b << 8) | data.a;
}

float unpackF32fromF8x4(vec4 v) {
    uint bits = unpackUI32fromF8x4(v);
    return uintBitsToFloat(bits);
}

vec4 packF32toF8x4(float f) {
    uint bits = floatBitsToUint(f);
    return packUI32toF8x4(bits);
}

vec4 packR11G11B10LtoF8x4(vec3 rgb) {
    uint bits = 0u;
    bits |= (uint(rgb.r * 2047.0) & 0x7FFu) << 21u;
    bits |= (uint(rgb.g * 2047.0) & 0x7FFu) << 10u;
    bits |= (uint(rgb.b * 1023.0) & 0x3FFu);
    return packUI32toF8x4(bits);
}

vec3 unpackR11G11B10LfromF8x4(vec4 v) {
    uint bits = unpackUI32fromF8x4(v);
    uint r = bits >> 21u;
    uint g = (bits >> 10u) & 0x7FFu;
    uint b = bits & 0x3FFu;
    return vec3(float(r) / 2047.0, float(g) / 2047.0, float(b) / 1023.0);
}

#define RGBM_MAX_RANGE 30.0

vec4 encodeRGBM(vec3 rgb) {
    float maxRGB = max(rgb.x, max(rgb.y, rgb.z));
    float m = maxRGB / RGBM_MAX_RANGE;
    m = ceil(m * 255.0) / 255.0;
    return vec4(rgb / (m * RGBM_MAX_RANGE), m);
}

vec3 decodeRGBM(vec4 rgbm) {
    return rgbm.rgb * (rgbm.a * RGBM_MAX_RANGE);
}

#endif // _ENCODINGS_GLSL