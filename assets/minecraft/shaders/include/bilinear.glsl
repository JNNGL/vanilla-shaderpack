#version 330

#ifndef _BILINEAR_GLSL
#define _BILINEAR_GLSL

#extension GL_MC_moj_import : enable
#moj_import <minecraft:encodings.glsl>

#define _BL_OVERLOAD(ret, func) ret func(sampler2D samp, vec2 texCoord) { return func(samp, textureSize(samp, 0), texCoord); }

vec4 textureBilinear(sampler2D samp, vec2 texSize, vec2 texCoord) {
    vec2 p = texCoord * texSize - 0.5;
    ivec2 coord = ivec2(floor(p));
    vec2 frac = p - coord;
    
    return mix(
        mix(texelFetch(samp, coord + ivec2(0, 0), 0), texelFetch(samp, coord + ivec2(1, 0), 0), frac.x),
        mix(texelFetch(samp, coord + ivec2(0, 1), 0), texelFetch(samp, coord + ivec2(1, 1), 0), frac.x),
        frac.y
    );
}

_BL_OVERLOAD(vec4, textureBilinear)

vec3 textureBilinearR11G11B10L(sampler2D samp, vec2 texSize, vec2 texCoord) {
    vec2 p = texCoord * texSize - 0.5;
    ivec2 coord = ivec2(floor(p));
    vec2 frac = p - coord;
    
    return mix(
        mix(unpackR11G11B10LfromF8x4(texelFetch(samp, coord + ivec2(0, 0), 0)), unpackR11G11B10LfromF8x4(texelFetch(samp, coord + ivec2(1, 0), 0)), frac.x),
        mix(unpackR11G11B10LfromF8x4(texelFetch(samp, coord + ivec2(0, 1), 0)), unpackR11G11B10LfromF8x4(texelFetch(samp, coord + ivec2(1, 1), 0)), frac.x),
        frac.y
    );
}

_BL_OVERLOAD(vec3, textureBilinearR11G11B10L)

#undef _BL_OVERLOAD

#endif // _BILINEAR_GLSL