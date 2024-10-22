#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:atlas.glsl>

uniform sampler2D UvSampler;
uniform sampler2D AtlasSampler;

in vec2 texCoord;

out vec4 fragColor;

void main() {
    vec4 uv = texture(UvSampler, texCoord);
    if (uv.a == 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    fragColor = sampleCombinedAtlas(AtlasSampler, uv, ATLAS_SPECULAR);
}