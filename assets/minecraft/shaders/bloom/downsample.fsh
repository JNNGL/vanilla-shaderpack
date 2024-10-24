#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:encodings.glsl>
#moj_import <minecraft:luminance.glsl>

uniform sampler2D InSampler;

uniform vec2 OutSize;
uniform float Iteration;

flat in ivec2 inRes;
flat in ivec2 outRes;

out vec4 fragColor;

vec3 decodeAndMask(vec4 data) {
    vec3 color = decodeRGBM(data);
    return color;
}

vec3 bilinear(sampler2D s, vec2 tex) {
    tex = clamp(tex, 0.0, 1.0);
    tex *= inRes;
    tex -= 0.5;

    ivec2 coord = ivec2(floor(tex));
    vec2 frac = fract(tex);

    return mix(
        mix(decodeAndMask(texelFetch(s, coord + ivec2(0, 0), 0)), decodeAndMask(texelFetch(s, coord + ivec2(1, 0), 0)), frac.x),
        mix(decodeAndMask(texelFetch(s, coord + ivec2(0, 1), 0)), decodeAndMask(texelFetch(s, coord + ivec2(1, 1), 0)), frac.x),
        frac.y);
}

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    if (any(greaterThanEqual(coord, outRes))) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 texCoord = gl_FragCoord.xy / vec2(outRes);

    vec2 srcTexelSize = 1.0 / inRes;
    float x = srcTexelSize.x;
    float y = srcTexelSize.y;

    vec3 a = bilinear(InSampler, vec2(texCoord.x - 2 * x, texCoord.y + 2 * y));
    vec3 b = bilinear(InSampler, vec2(texCoord.x,         texCoord.y + 2 * y));
    vec3 c = bilinear(InSampler, vec2(texCoord.x + 2 * x, texCoord.y + 2 * y));

    vec3 d = bilinear(InSampler, vec2(texCoord.x - 2 * x, texCoord.y));
    vec3 e = bilinear(InSampler, vec2(texCoord.x,         texCoord.y));
    vec3 f = bilinear(InSampler, vec2(texCoord.x + 2 * x, texCoord.y));

    vec3 g = bilinear(InSampler, vec2(texCoord.x - 2 * x, texCoord.y - 2 * y));
    vec3 h = bilinear(InSampler, vec2(texCoord.x,         texCoord.y - 2 * y));
    vec3 i = bilinear(InSampler, vec2(texCoord.x + 2 * x, texCoord.y - 2 * y));

    vec3 j = bilinear(InSampler, vec2(texCoord.x - x, texCoord.y + y));
    vec3 k = bilinear(InSampler, vec2(texCoord.x + x, texCoord.y + y));
    vec3 l = bilinear(InSampler, vec2(texCoord.x - x, texCoord.y - y));
    vec3 m = bilinear(InSampler, vec2(texCoord.x + x, texCoord.y - y));

    vec3 color = e * 0.125;
    color += (a + c + g + i) * 0.03125;
    color += (b + d + f + h) * 0.0625;
    color += (j + k + l + m) * 0.125;

    fragColor = encodeRGBM(color);
}