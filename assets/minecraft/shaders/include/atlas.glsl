#version 330

#ifndef _ATLAS_GLSL
#define _ATLAS_GLSL

#define ATLAS_ALBEDO    0
#define ATLAS_SPECULAR  1
#define ATLAS_NORMAL    2

vec4 sampleCombinedAtlas(sampler2D atlas, vec3 uv, const int atlasId) {
    ivec2 atlasSize = ivec2(textureSize(atlas, 0)) / 2;
    ivec3 coord = ivec3(uv * 255.0);

    int subX = coord.x & 0xF;
    int subY = coord.y & 0xF;
    int index = ((coord.x & 0xF0) | (coord.y >> 4)) * 256 + coord.z;

    int baseX = (index * 16) % atlasSize.x;
    int baseY = ((index * 16) / atlasSize.x) * 16;

    ivec2 texCoord = ivec2(baseX + subX, baseY + subY);
    if (atlasId == ATLAS_SPECULAR) texCoord.x += atlasSize.x;
    else if (atlasId == ATLAS_NORMAL) texCoord.y += atlasSize.y;

    return texelFetch(atlas, texCoord, 0);
}

#endif // _ATLAS_GLSL