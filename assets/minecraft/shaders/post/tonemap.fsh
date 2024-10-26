#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:encodings.glsl>
#moj_import <minecraft:tonemapping/aces.glsl>
#moj_import <minecraft:srgb.glsl>

uniform sampler2D InSampler;
uniform sampler2D BloomSampler;

in vec2 texCoord;

out vec4 fragColor;

void main() {
    vec3 color = decodeLogLuv(texture(InSampler, texCoord));
    vec3 bloom = decodeLogLuv(texture(BloomSampler, texCoord));

    color = mix(color, bloom, 0.04);

    color = acesFitted(color);
    color = linearToSrgb(color);

    fragColor = vec4(color, 1.0);
}