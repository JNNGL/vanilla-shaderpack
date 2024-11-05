#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:bilinear.glsl>
#moj_import <settings:settings.glsl>

uniform sampler2D InSampler;
uniform sampler2D DataSampler;
uniform sampler2D DepthSampler;
uniform sampler2D SpecularSampler;
uniform sampler2D HistorySampler;

uniform vec2 InSize;
uniform vec2 HistorySize;

in vec2 texCoord;
flat in mat4 invProjViewMat;
flat in mat4 prevProjViewMat;
flat in vec3 viewOffset;
flat in int isShadowMap;
flat in int frameCounter;

out vec4 fragColor;

const ivec2[] temporalOffsets = ivec2[](
    ivec2(0, 0),
    ivec2(1, 0),
    ivec2(0, 1),
    ivec2(1, 1)
);

void main() {
    if (isShadowMap > 0) {
        fragColor = texelFetch(HistorySampler, ivec2(gl_FragCoord.xy), 0);
        return;
    }

    if (int(gl_FragCoord.y) == 0) {
        fragColor = texelFetch(DataSampler, ivec2(gl_FragCoord.xy), 0);
        return;
    }

    fragColor = texture(InSampler, texCoord);
    
    float depth = texture(DepthSampler, texCoord).r;
    if (depth == 1.0) {
        return;
    }

    vec3 worldSpace = unprojectScreenSpace(invProjViewMat, texCoord, depth);
    vec3 screenSpace = projectAndDivide(prevProjViewMat, worldSpace - viewOffset) * 0.5 + 0.5;
    if (clamp(screenSpace.xy, 1.5 / InSize, 1.0 - 1.0 / InSize) != screenSpace.xy) {
        return;
    }

    float roughness = 1.0 - texture(SpecularSampler, texCoord).r;

    float distanceFactor = clamp((length(worldSpace) - 8.0) / 8.0, 0.0, 5.0);
    float roughnessFactor = clamp(pow(roughness, 2.3) * 50.0, 0.0, 10.0);

    vec3 previousSample = decodeLogLuv(texture(HistorySampler, screenSpace.xy * (InSize / HistorySize)));
    vec3 currentSample = decodeLogLuv(fragColor);
    vec3 mixedSample = mix(previousSample, currentSample, 1.0 / (1.0 + roughnessFactor + distanceFactor));

    fragColor = encodeLogLuv(mixedSample);
}
