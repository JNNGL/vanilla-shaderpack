#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:luminance.glsl>
#moj_import <minecraft:encodings.glsl>
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:bilinear.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D NormalSampler;
uniform sampler2D SpecularSampler;

uniform vec2 InSize;
uniform float Step;

in vec2 texCoord;
flat in int isShadowMap;

out vec4 fragColor;

const ivec2[] temporalOffsets = ivec2[](
    ivec2(0, 0),
    ivec2(1, 0),
    ivec2(0, 1),
    ivec2(1, 1)
);

void main() {
    if (isShadowMap > 0 || int(gl_FragCoord.y) == 0) {
        return;
    }

    vec3 centerColor = decodeLogLuv(texture(InSampler, texCoord));
    vec3 centerNormal = decodeDirectionFromF8x2(texture(NormalSampler, texCoord).xy);
    float centerDepth = texture(DepthSampler, texCoord).r;
    float centerLuma = luminance(centerColor);
    float centerSmooth = texture(SpecularSampler, texCoord).r;

    float wSum = 1.0;
    vec3 cSum = centerColor;

    float roughnessSq = 1.0 - centerSmooth;

    float step = Step;
    if (step <= roughnessSq * 20.0) {
        const int radius = 2;
        for (int x = -radius; x <= radius; x++) {
            for (int y = -radius; y <= radius; y++) {
                if (x == 0 && y == 0) continue;

                vec2 sampleOffset = vec2(x, y);
                vec2 sampleCoord = gl_FragCoord.xy + vec2(x, y) * step;
                if (sampleCoord.y <= 1.5) continue;

                vec2 sampleUV = sampleCoord / InSize;
                vec3 color = decodeLogLuv(texture(InSampler, sampleUV));
                vec3 normal = decodeDirectionFromF8x2(texture(NormalSampler, sampleUV).xy);
                float depth = texture(DepthSampler, sampleUV).r;
                float smoothness = texture(SpecularSampler, sampleUV).r;
                float luma = luminance(color);

                float wNorm = pow(max(0.0, dot(centerNormal, normal)), 2048.0);
                float wLum = abs(luma - centerLuma) * 0.8;
                float wSmooth = abs(smoothness - centerSmooth) * 10.0;
                float w = exp(-wLum - wSmooth - 0.1 * length(sampleOffset)) * wNorm;

                wSum += w;
                cSum += color * w;
            }
        }
    }

    cSum /= wSum;
    fragColor = encodeLogLuv(cSum);
}
