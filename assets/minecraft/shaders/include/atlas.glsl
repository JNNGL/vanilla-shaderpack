#version 330

#ifndef _ATLAS_GLSL
#define _ATLAS_GLSL

#extension GL_MC_moj_import : enable
#moj_import <minecraft:bilinear.glsl>

#define ATLAS_ALBEDO    0
#define ATLAS_SPECULAR  1
#define ATLAS_NORMAL    2

vec4 sampleCombinedAtlas(sampler2D atlas, vec4 uv, const int atlasId) {
    ivec2 texSize = ivec2(textureSize(atlas, 0));
    ivec2 atlasSize = texSize / 2;
    ivec4 coord = ivec4(uv * 255.0);

    int mipLevel = coord.w & 7;
    int mipPower = int(round(pow(2, mipLevel)));
    ivec2 mipOffset = (texSize * (mipPower - 1)) / mipPower;

    int subX = coord.x & 0xF;
    int subY = coord.y & 0xF;
    int index = ((coord.x & 0xF0) | (coord.y >> 4)) * 256 + coord.z;

    int baseX = (index * 16) % atlasSize.x;
    int baseY = ((index * 16) / atlasSize.x) * 16;

    ivec2 texCoord = ivec2(baseX + subX, baseY + subY);
    if (atlasId == ATLAS_SPECULAR) texCoord.x += atlasSize.x;
    else if (atlasId == ATLAS_NORMAL) texCoord.y += atlasSize.y;

    if (mipLevel > 0 && mipLevel < 4) {
        vec2 mipCoord = texCoord / mipPower + mipOffset + 0.5;
        return textureBilinear(atlas, vec2(texSize), mipCoord / vec2(texSize));
    }

    return texelFetch(atlas, texCoord / mipPower + mipOffset, 0);
}

#endif // _ATLAS_GLSL