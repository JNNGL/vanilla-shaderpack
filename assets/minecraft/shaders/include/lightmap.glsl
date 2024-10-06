#version 330

#ifndef _LIGHTMAP_GLSL
#define _LIGHTMAP_GLSL

#extension GL_MC_moj_import : enable
#moj_import <minecraft:encodings.glsl>

// lightmap
// 0 - ambient light factor
// 1 - sky factor
// 2 - block factor
// 3 - bright lightmap
// 4-6 - sky light color
// 7 - night vision factor
// 8 - darkness scale
// 9 - darken world factor
// 10 - brightness factor

float decodeLightmapFloat(sampler2D lightMap, int index) {
    int y = index / 16;
    int x = index % 16;
    vec4 texel = texelFetch(lightMap, ivec2(x, y), 0);
    return unpackF32fromF8x4(texel);
}

float getAmbientLightFactor(sampler2D lightMap) {
    return decodeLightmapFloat(lightMap, 0);
}

float getSkyFactor(sampler2D lightMap) {
    return decodeLightmapFloat(lightMap, 1);
}

float getBlockFactor(sampler2D lightMap) {
    return decodeLightmapFloat(lightMap, 2);
}

float getUseBrightLightmap(sampler2D lightMap) {
    return decodeLightmapFloat(lightMap, 3);
}

vec3 getSkyLightColor(sampler2D lightMap) {
    return vec3(decodeLightmapFloat(lightMap, 4),
                decodeLightmapFloat(lightMap, 5),
                decodeLightmapFloat(lightMap, 6));
}

float getNightVisionFactor(sampler2D lightMap) {
    return decodeLightmapFloat(lightMap, 7);
}

float getDarknessScale(sampler2D lightMap) {
    return decodeLightmapFloat(lightMap, 8);
}

float getDarkenWorldFactor(sampler2D lightMap) {
    return decodeLightmapFloat(lightMap, 9);
}

float getBrightnessFactor(sampler2D lightMap) {
    return decodeLightmapFloat(lightMap, 10);
}

#endif // _LIGHTMAP_GLSL