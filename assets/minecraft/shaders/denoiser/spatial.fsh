#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:luminance.glsl>
#moj_import <minecraft:encodings.glsl>
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:bilinear.glsl>
#moj_import <settings:settings.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D NormalSampler;
uniform sampler2D SpecularSampler;

uniform vec2 InSize;
uniform float Step;

in vec2 texCoord;
flat in int isShadowMap;
flat in mat4 invProjection;

out vec4 fragColor;

void main() {
    float centerDepth = texture(DepthSampler, texCoord).r;
    if (isShadowMap > 0 || int(gl_FragCoord.y) == 0 || centerDepth == 1.0) {
        return;
    }

    vec3 centerColor = decodeLogLuv(texture(InSampler, texCoord));
    vec3 centerNormal = decodeDirectionFromF8x2(texture(NormalSampler, texCoord).xy);
    float centerLuma = luminance(centerColor);
    float centerSmooth = texture(SpecularSampler, texCoord).r;

    vec3 viewSpace = unprojectScreenSpace(invProjection, texCoord, centerDepth);
    float dist = length(viewSpace);

    float normalExp = clamp(2048.0 - dist * 8.0, 4.0, 2048.0);
    float smoothMult = clamp(10.0 - dist / 64.0, 1.0, 10.0);

    float wSum = 1.0;
    vec3 cSum = centerColor * wSum;

    float roughnessSqrt = 1.0 - centerSmooth;

    float step = Step;
#if (DENOISE_BLOCK_REFLECTIONS == yes)
    if (step * step <= roughnessSqrt * 400.0) {
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

                float wNorm = pow(max(0.0, dot(centerNormal, normal)), normalExp);
                float wLum = abs(luma - centerLuma) * 0.8;
                float wSmooth = abs(smoothness - centerSmooth) * smoothMult;
                float w = exp(-wLum - wSmooth - mix(0.1, 2.0, pow(centerSmooth, 5.0)) * length(sampleOffset)) * wNorm;

                wSum += w;
                cSum += color * w;
            }
        }
    }
#else
    if (step > 10000.0) { // Minecraft unloads the pack if the Step uniform is not used in the shader.
        wSum += 1.0e-6;
    }
#endif // DENOISE_BLOCK_REFLECTIONS

    cSum /= wSum;
    fragColor = encodeLogLuv(cSum);
}
