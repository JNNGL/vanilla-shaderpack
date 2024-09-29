#version 330

#ifndef _BILINEAR_GLSL
#define _BILINEAR_GLSL

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

#endif // _BILINEAR_GLSL