#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:encodings.glsl>
#moj_import <minecraft:tonemapping/aces.glsl>
#moj_import <minecraft:srgb.glsl>
#moj_import <settings:settings.glsl>

uniform sampler2D InSampler;
uniform sampler2D BloomSampler;

uniform vec2 InSize;

in vec2 texCoord;

out vec4 fragColor;

void main() {
    vec2 clampedTex = texCoord;
    clampedTex.y = max(2.0 / InSize.y, clampedTex.y);

    vec3 color = decodeLogLuv(texture(InSampler, clampedTex));
    vec3 bloom = decodeLogLuv(texture(BloomSampler, clampedTex));

    color = mix(color, bloom, BLOOM_STRENGTH);

    color = acesFitted(color);
    color = linearToSrgb(color);

    fragColor = vec4(color, 1.0);
}