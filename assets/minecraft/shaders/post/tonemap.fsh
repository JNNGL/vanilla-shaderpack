#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:encodings.glsl>
#moj_import <minecraft:tonemapping/aces.glsl>
#moj_import <minecraft:srgb.glsl>

uniform sampler2D InSampler;

in vec2 texCoord;

out vec4 fragColor;

void main() {
    vec3 color = decodeRGBM(texture(InSampler, texCoord));

    color = acesFitted(color);
    color = linearToSrgb(color);

    fragColor = vec4(color, 1.0);
}