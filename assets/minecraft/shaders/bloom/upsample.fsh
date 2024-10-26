#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:encodings.glsl>

uniform sampler2D InSampler;
uniform sampler2D DownsampledSampler;

uniform float Iteration;
uniform vec2 OutSize;

flat in ivec2 inRes;
flat in ivec2 outRes;

out vec4 fragColor;

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
    
    vec3 a = decodeLogLuv(texture(InSampler, vec2(texCoord.x - x, texCoord.y + y)));
    vec3 b = decodeLogLuv(texture(InSampler, vec2(texCoord.x,     texCoord.y + y)));
    vec3 c = decodeLogLuv(texture(InSampler, vec2(texCoord.x + x, texCoord.y + y)));

    vec3 d = decodeLogLuv(texture(InSampler, vec2(texCoord.x - x, texCoord.y)));
    vec3 e = decodeLogLuv(texture(InSampler, vec2(texCoord.x,     texCoord.y)));
    vec3 f = decodeLogLuv(texture(InSampler, vec2(texCoord.x + x, texCoord.y)));

    vec3 g = decodeLogLuv(texture(InSampler, vec2(texCoord.x - x, texCoord.y - y)));
    vec3 h = decodeLogLuv(texture(InSampler, vec2(texCoord.x,     texCoord.y - y)));
    vec3 i = decodeLogLuv(texture(InSampler, vec2(texCoord.x + x, texCoord.y - y)));

    vec3 color = e * 4.0;
    color += (b + d + f + h) * 2.0;
    color += (a + c + g + i);
    color *= 1.0 / 16.0;

    if (Iteration > 1.0) {
        color += decodeLogLuv(texture(DownsampledSampler, texCoord * (vec2(outRes) / vec2(inRes))));
    }

    fragColor = encodeLogLuv(color.rgb);
}