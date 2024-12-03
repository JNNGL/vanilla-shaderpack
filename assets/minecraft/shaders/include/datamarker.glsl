#version 330

#ifndef _DATAMARKER_GLSL
#define _DATAMARKER_GLSL

#extension GL_MC_moj_import : enable
#moj_import <encodings.glsl>

// layout
// 0-15 - projection matrix
// 16 - fog start
// 17 - fog end
// 18-20 - chunk offset
// 21-22 - game time
// 23-31 - view matrix
// 32-34 - sun direction
// 35-36 - sky factor
// 37-38 - proj unjitter
// 39 - fog color

bool discardDataMarker(ivec2 pixel) {
    return pixel.y >= 1 || pixel.x > 39;
}

bool discardSunData(vec2 fragCoord) {
    ivec2 pixel = ivec2(fragCoord);
    return pixel.y == 0 && pixel.x >= 32 && pixel.x <= 34;
}

vec4 writeDataMarker(ivec2 pixel, mat4 projMat, float fogStart, float fogEnd, vec3 chunkOffset, float gameTime, bool isShadowMap, mat3 viewMat, float skyFactor, vec2 projUnjitter, vec3 fogColor) {
    if (pixel.x <= 15) { // projection matrix
        int index = int(pixel.x);
        return vec4(packFPtoF8x3(projMat[index / 4][index % 4], FP_PRECISION_HIGH), 1.0);
    } else if (pixel.x == 16) { // fog start
        return vec4(packFPtoF8x3(fogStart, FP_PRECISION_LOW), 1.0);
    } else if (pixel.x == 17) { // fog end
        return vec4(packFPtoF8x3(fogEnd, FP_PRECISION_LOW), 1.0);
    } else if (pixel.x <= 20) { // chunk offset
        int index = int(pixel.x) - 18;
        return vec4(packFPtoF8x3(mod(chunkOffset[index], 16.0) / 16.0, FP_PRECISION_HIGH), 1.0);
    } else if (pixel.x <= 22) { // game time
        int index = int(pixel.x) - 21;
        vec4 data = packF32toF8x4(gameTime);
        return vec4(data[index * 2], data[index * 2 + 1], isShadowMap ? 1.0 : 0.0, 1.0);
    } else if (pixel.x <= 31) { // view matrix
        int index = int(pixel.x) - 23;
        return vec4(packFPtoF8x3(viewMat[index / 3][index % 3], FP_PRECISION_HIGH), 1.0); 
    } else if (pixel.x <= 34) { // sun direction
        return vec4(0.0);
    } else if (pixel.x <= 36) { // sky factor
        int index = int(pixel.x) - 35;
        vec4 data = packF32toF8x4(skyFactor);
        return vec4(data[index * 2], data[index * 2 + 1], 0.0, 1.0);
    } else if (pixel.x <= 38) { // proj unjitter
        int index = int(pixel.x) - 37;
        return vec4(packFPtoF8x3(projUnjitter[index], FP_PRECISION_HIGH), 1.0);
    } else if (pixel.x <= 39) {
        return vec4(fogColor, 1.0);
    }

    return vec4(0.0);
}

bool overlaySunData(vec2 fragCoord, inout vec4 color, vec3 sunDirection) {
    if (int(fragCoord.y) == 0) {
        int index = int(fragCoord.x) - 32;
        if (index >= 0 && index < 3) {
            color = vec4(packFPtoF8x3(sunDirection[index], FP_PRECISION_HIGH), 1.0);
            return true;
        }
    }
    return false;
}

mat4 decodeProjectionMatrix(sampler2D dataSampler) {
    mat4 projection;
    
    for (int i = 0; i < 16; i++) {
        vec3 color = texelFetch(dataSampler, ivec2(i, 0), 0).rgb;
        projection[i / 4][i % 4] = unpackFPfromF8x3(color, FP_PRECISION_HIGH);
    }

    return projection;
}

float decodeFogStart(sampler2D dataSampler) {
    vec3 color = texelFetch(dataSampler, ivec2(16, 0), 0).rgb;
    return unpackFPfromF8x3(color, FP_PRECISION_LOW);
}

float decodeFogEnd(sampler2D dataSampler) {
    vec3 color = texelFetch(dataSampler, ivec2(17, 0), 0).rgb;
    return unpackFPfromF8x3(color, FP_PRECISION_LOW);
}

vec3 decodeChunkOffset(sampler2D dataSampler) {
    vec3 chunkOffset;

    for (int i = 0; i < 3; i++) {
        vec3 color = texelFetch(dataSampler, ivec2(18 + i, 0), 0).rgb;
        chunkOffset[i] = unpackFPfromF8x3(color, FP_PRECISION_HIGH) * 16.0;
    }

    return chunkOffset;
}

float decodeGameTime(sampler2D dataSampler) {
    vec4 data;
    data.xy = texelFetch(dataSampler, ivec2(21, 0), 0).rg;
    data.zw = texelFetch(dataSampler, ivec2(22, 0), 0).rg;
    return unpackF32fromF8x4(data);
}

bool decodeIsShadowMap(sampler2D dataSampler) {
    return texelFetch(dataSampler, ivec2(21, 0), 0).b > 0.5;
}

mat3 decodeModelViewMatrix(sampler2D dataSampler) {
    mat3 modelView;
    
    for (int i = 0; i < 9; i++) {
        vec3 color = texelFetch(dataSampler, ivec2(23 + i, 0), 0).rgb;
        modelView[i / 3][i % 3] = unpackFPfromF8x3(color, FP_PRECISION_HIGH);
    }

    return modelView;
}

vec3 decodeSunDirection(sampler2D dataSampler) {
    vec3 sunDirection;

    for (int i = 0; i < 3; i++) {
        vec3 color = texelFetch(dataSampler, ivec2(32 + i, 0), 0).rgb;
        sunDirection[i] = unpackFPfromF8x3(color, FP_PRECISION_HIGH);
    }

    return normalize(sunDirection);
}

float decodeSkyFactor(sampler2D dataSampler) {
    vec4 data;
    data.xy = texelFetch(dataSampler, ivec2(35, 0), 0).rg;
    data.zw = texelFetch(dataSampler, ivec2(36, 0), 0).rg;
    return unpackF32fromF8x4(data);
}

mat4 decodeUnjitteredProjection(sampler2D dataSampler) {
    mat4 projection = decodeProjectionMatrix(dataSampler);

    vec2 unjitter;
    for (int i = 0; i < 2; i++) {
        vec3 color = texelFetch(dataSampler, ivec2(37 + i, 0), 0).rgb;
        unjitter[i] = unpackFPfromF8x3(color, FP_PRECISION_HIGH);
    }

    projection[2].xy = unjitter;
    return projection;
}

vec3 decodeFogColor(sampler2D dataSampler) {
    return texelFetch(dataSampler, ivec2(39, 0), 0).rgb;
}



// shadowmap
// 64-66 - shadow offset
// 67 - time
// 68 - sky factor
// 69-71 - total offset

bool overlayShadowMap(vec2 fragCoord, inout vec4 color, vec3 shadowOffset, float time, float skyFactor, vec3 totalOffset) {
    if (int(fragCoord.y) == 0) {
        int index = int(fragCoord.x) - 64;
        if (index >= 0 && index < 3) {
            color = packF32toF8x4(shadowOffset[index]);
            return true;
        }
        if (index == 3) {
            color = packF32toF8x4(time);
            return true;
        }
        if (index == 4) {
            color = packF32toF8x4(skyFactor);
            return true;
        }
        if (index >= 5 && index < 8) {
            color = packF32toF8x4(totalOffset[index - 5]);
            return true;
        }
    }
    return false;
}

vec3 decodeShadowOffset(sampler2D dataSampler) {
    vec3 shadowOffset;
    
    for (int i = 0; i < 3; i++) {
        vec4 color = texelFetch(dataSampler, ivec2(64 + i, 0), 0);
        shadowOffset[i] = unpackF32fromF8x4(color);
    }

    return shadowOffset;
}

float decodeShadowTime(sampler2D dataSampler) {
    return unpackF32fromF8x4(texelFetch(dataSampler, ivec2(67, 0), 0));
}

float decodeShadowSkyFactor(sampler2D dataSampler) {
    return unpackF32fromF8x4(texelFetch(dataSampler, ivec2(68, 0), 0));
}

vec3 decodeTotalOffset(sampler2D dataSampler) {
    vec3 totalOffset;
    
    for (int i = 0; i < 3; i++) {
        vec4 color = texelFetch(dataSampler, ivec2(69 + i, 0), 0);
        totalOffset[i] = unpackF32fromF8x4(color);
    }

    return totalOffset;
}



// temporal
// 64 - frame

bool overlayTemporal(vec2 fragCoord, inout vec4 color, int frame) {
    if (ivec2(fragCoord) == ivec2(64, 0)) {
        color = packUI32toF8x4(uint(frame));
        return true;
    }
    return false;
}

int decodeTemporalFrame(sampler2D dataSampler) {
    return int(unpackUI32fromF8x4(texelFetch(dataSampler, ivec2(64, 0), 0)));
}

#endif // _DATAMARKER_GLSL