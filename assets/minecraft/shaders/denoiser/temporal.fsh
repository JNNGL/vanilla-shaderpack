#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:bilinear.glsl>
#moj_import <settings:settings.glsl>

uniform sampler2D InSampler;
uniform sampler2D DataSampler;
uniform sampler2D NormalSampler;
uniform sampler2D DepthSampler;
uniform sampler2D HistoryNDSampler;
uniform sampler2D SpecularSampler;
uniform sampler2D HistorySampler;

uniform vec2 InSize;
uniform vec2 HistorySize;

in vec2 texCoord;
flat in mat4 invProjViewMat;
flat in mat4 prevProjViewMat;
flat in vec3 viewOffset;
flat in int isShadowMap;
flat in vec2 planes;

out vec4 fragColor;

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
    
#if (DENOISE_BLOCK_REFLECTIONS == yes)
    vec3 normal = decodeDirectionFromF8x2(texture(NormalSampler, texCoord).rg);
    float depth = texture(DepthSampler, texCoord).r;
    if (depth == 1.0) {
        return;
    }

    vec3 worldSpace = unprojectScreenSpace(invProjViewMat, texCoord, depth);
    vec3 screenSpace = projectAndDivide(prevProjViewMat, worldSpace - viewOffset) * 0.5 + 0.5;
    if (clamp(screenSpace.xy, 1.5 / InSize, 1.0 - 1.0 / InSize) != screenSpace.xy) {
        return;
    }

    vec4 historyND = texture(HistoryNDSampler, screenSpace.xy * (InSize / HistorySize));
    vec3 historyNormal = decodeDirectionFromF8x2(historyND.xy);

    if (dot(normal, historyNormal) < 0.7) {
        vec2 oneTexel = 1.0 / InSize;

        const vec2[] offsets = vec2[](
            vec2(+1.0, 0.0),
            vec2(-1.0, 0.0),
            vec2(0.0, +1.0),
            vec2(0.0, -1.0)
        );

        bool notFound = true;
        for (int i = 0; i < 4; i++) {
            vec2 neighbour = clamp(screenSpace.xy + offsets[i] * oneTexel, 1.5 / InSize, 1.0 - 1.0 / InSize);

            historyND = texture(HistoryNDSampler, neighbour * (InSize / HistorySize));
            historyNormal = decodeDirectionFromF8x2(historyND.xy);

            if (dot(normal, historyNormal) > 0.5) {
                screenSpace.xy = neighbour;
                notFound = false;
                break;
            }
        }

        if (notFound) {
            return;
        }
    }

    float historyDepth = linearizeDepth(unpackF01U16fromF8x2(historyND.zw), planes);
    float currentDepth = linearizeDepth(floor(screenSpace.z * 65535.0) / 65535.0, planes);
    if (abs(currentDepth - historyDepth) > 0.5 + 10.0 * currentDepth / planes.y) {
        return;
    }

    float roughness = 1.0 - texture(SpecularSampler, texCoord).r;

    float distanceFactor = clamp((length(worldSpace) - 8.0) / 8.0, -2.0, 5.0);
    float roughnessFactor = clamp(pow(roughness, 2.0) * 50.0, 0.0, 10.0);
    float staticFactor = (float(dot(viewOffset, viewOffset) < 0.0001) + roughness) * 5.0;

    vec3 previousSample = decodeLogLuv(texture(HistorySampler, screenSpace.xy * (InSize / HistorySize)));
    vec3 currentSample = decodeLogLuv(fragColor);
    vec3 mixedSample = mix(previousSample, currentSample, 1.0 / clamp(1.0 + roughnessFactor + distanceFactor + staticFactor, 1.0, 10.0));

    fragColor = encodeLogLuv(mixedSample);
#endif // DENOISE_BLOCK_REFLECTIONS
}
