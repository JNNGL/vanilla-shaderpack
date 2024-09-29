#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:datamarker.glsl>

uniform sampler2D DataSampler;
uniform sampler2D DepthSampler;
uniform sampler2D PreviousSampler;

in vec2 texCoord;
flat in int shadowMapFrame;
flat in mat4 lightProjMat;
flat in mat4 invLightProjMat;
flat in vec3 offset;

out vec4 fragColor;

void main() {
    if (shadowMapFrame > 0) {
        if (overlayShadowMap(gl_FragCoord.xy, fragColor, vec3(0.0))) {
            return;
        }
        float depth = texture(DepthSampler, texCoord).r;
        fragColor = packF32toF8x4(depth);
    } else {
        if (overlayShadowMap(gl_FragCoord.xy, fragColor, offset)) {
            return;
        }
        fragColor = texture(PreviousSampler, texCoord);
    }

    if (int(gl_FragCoord.y) == 0) {
        fragColor = texelFetch(DataSampler, ivec2(gl_FragCoord.xy), 0);
    }
}