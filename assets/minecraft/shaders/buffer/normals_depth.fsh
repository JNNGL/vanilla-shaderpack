#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:encodings.glsl>

uniform sampler2D HistorySampler;
uniform sampler2D DepthSampler;
uniform sampler2D NormalSampler;

in vec2 texCoord;
flat in int shouldUpdate;

out vec4 fragColor;

void main() {
    if (shouldUpdate == 0) {
        fragColor = texelFetch(HistorySampler, ivec2(gl_FragCoord.xy), 0);
        return;
    }
        
    vec2 normal = texture(NormalSampler, texCoord).rg;
    float depth = texture(DepthSampler, texCoord).r;

    fragColor = vec4(normal, packF01U16toF8x2(depth));
}