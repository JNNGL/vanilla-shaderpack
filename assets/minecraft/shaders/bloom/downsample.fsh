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

vec3 textureClamped(sampler2D samp, vec2 texCoord) {
    texCoord = clamp(texCoord, 1.5 / OutSize, 1.0 - 1.5 / OutSize);
    vec3 hdr = decodeLogLuv(texture(samp, texCoord));
    if (Iteration == 1.0) hdr = max(hdr - 0.2, 0.0);
    return hdr;
}

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    if (any(greaterThanEqual(coord, outRes))) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 texCoord = gl_FragCoord.xy / vec2(outRes);
    texCoord *= vec2(inRes) / OutSize;

    float x = 1.0 / OutSize.x;
    float y = 1.0 / OutSize.y;

    vec3 a = textureClamped(InSampler, vec2(texCoord.x - 2 * x, texCoord.y + 2 * y));
    vec3 b = textureClamped(InSampler, vec2(texCoord.x,         texCoord.y + 2 * y));
    vec3 c = textureClamped(InSampler, vec2(texCoord.x + 2 * x, texCoord.y + 2 * y));

    vec3 d = textureClamped(InSampler, vec2(texCoord.x - 2 * x, texCoord.y));
    vec3 e = textureClamped(InSampler, vec2(texCoord.x,         texCoord.y));
    vec3 f = textureClamped(InSampler, vec2(texCoord.x + 2 * x, texCoord.y));

    vec3 g = textureClamped(InSampler, vec2(texCoord.x - 2 * x, texCoord.y - 2 * y));
    vec3 h = textureClamped(InSampler, vec2(texCoord.x,         texCoord.y - 2 * y));
    vec3 i = textureClamped(InSampler, vec2(texCoord.x + 2 * x, texCoord.y - 2 * y));

    vec3 j = textureClamped(InSampler, vec2(texCoord.x - x, texCoord.y + y));
    vec3 k = textureClamped(InSampler, vec2(texCoord.x + x, texCoord.y + y));
    vec3 l = textureClamped(InSampler, vec2(texCoord.x - x, texCoord.y - y));
    vec3 m = textureClamped(InSampler, vec2(texCoord.x + x, texCoord.y - y));

    vec3 color = e * 0.125;
    color += (a + c + g + i) * 0.03125;
    color += (b + d + f + h) * 0.0625;
    color += (j + k + l + m) * 0.125;

    fragColor = encodeLogLuv(color);
}