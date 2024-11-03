#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:luminance.glsl>
#moj_import <minecraft:encodings.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D HistorySampler;
uniform sampler2D DataSampler;

uniform vec2 HistorySize;
uniform vec2 InSize;

in vec2 texCoord;
flat in mat4 invProjViewMat;
flat in mat4 prevProjViewMat;
flat in vec3 viewOffset;
flat in int shouldUpdate;
flat in int frame;

out vec4 fragColor;

float filterCubic(float x, float B, float C) {
    float y = 0.0;
    float x2 = x * x;
    float x3 = x2 * x;
    if (x < 1.0) y = (12.0 - 9.0 * B - 6.0 * C) * x3 + (-18.0 + 12.0 * B + 6.0 * C) * x2 + (6.0 - 2.0 * B);
    else if (x <= 2.0) y = (-B - 6.0 * C) * x3 + (6.0 * B + 30.0 * C) * x2 + (-12.0 * B - 48.0 * C) * x + (8.0 * B + 24.0 * C);
    return y / 6.0;
}

float mitchell(float x) {
    x = 2.0 * x;
    return filterCubic(x, 1.0 / 3.0, 1.0 / 3.0);
}

vec3 textureClamped(sampler2D samp, vec2 coord) {
    coord = clamp(coord, vec2(0.5, 1.5) / InSize, (InSize - 0.5) / HistorySize);
    return decodeLogLuv(texture(samp, coord));
}

vec3 sampleTextureCatmullRom(sampler2D tex, vec2 uv, vec2 texSize) {
    vec2 samplePos = uv * texSize;
    vec2 texPos1 = floor(samplePos - 0.5) + 0.5;

    vec2 f = samplePos - texPos1;

    vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
    vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
    vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
    vec2 w3 = f * f * (-0.5 + 0.5 * f);
    
    vec2 w12 = w1 + w2;
    vec2 offset12 = w2 / w12;

    vec2 texPos0 = texPos1 - 1;
    vec2 texPos3 = texPos1 + 2;
    vec2 texPos12 = texPos1 + offset12;

    texSize = textureSize(tex, 0).xy;
    texPos0 /= texSize;
    texPos3 /= texSize;
    texPos12 /= texSize;

    vec3 result = vec3(0.0);
    result += textureClamped(tex, vec2(texPos0.x, texPos0.y)) * w0.x * w0.y;
    result += textureClamped(tex, vec2(texPos12.x, texPos0.y)) * w12.x * w0.y;
    result += textureClamped(tex, vec2(texPos3.x, texPos0.y)) * w3.x * w0.y;

    result += textureClamped(tex, vec2(texPos0.x, texPos12.y)) * w0.x * w12.y;
    result += textureClamped(tex, vec2(texPos12.x, texPos12.y)) * w12.x * w12.y;
    result += textureClamped(tex, vec2(texPos3.x, texPos12.y)) * w3.x * w12.y;

    result += textureClamped(tex, vec2(texPos0.x, texPos3.y)) * w0.x * w3.y;
    result += textureClamped(tex, vec2(texPos12.x, texPos3.y)) * w12.x * w3.y;
    result += textureClamped(tex, vec2(texPos3.x, texPos3.y)) * w3.x * w3.y;

    return result;
}

void main() {
    if (shouldUpdate == 0) {
        fragColor = texelFetch(HistorySampler, ivec2(gl_FragCoord.xy), 0);
        return;
    }

    if (overlayTemporal(gl_FragCoord.xy, fragColor, (frame + 1) % 8)) {
        return;
    }

    if (int(gl_FragCoord.y) == 0) {
        fragColor = texture(DataSampler, texCoord);
        return;
    }

    vec3 sourceSampleTotal = vec3(0.0);
    float sourceSampleWeight = 0.0;
    vec3 nMin = vec3(1.0e5);
    vec3 nMax = vec3(-1.0e5);
    float closestDepth = 1.0;
    ivec2 closestDepthPos = ivec2(0, 0);

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            ivec2 pixelPosition = ivec2(gl_FragCoord.xy) + ivec2(x, y);
            pixelPosition = clamp(pixelPosition, ivec2(0, 0), ivec2(InSize) - 1);

            vec3 neighbour = decodeLogLuv(texelFetch(InSampler, pixelPosition, 0));
            float subSampleDistance = length(vec2(x, y));
            float subSampleWeight = mitchell(subSampleDistance);

            sourceSampleTotal += neighbour * subSampleWeight;
            sourceSampleWeight += subSampleWeight;

            nMin = min(nMin, neighbour);
            nMax = max(nMax, neighbour);

            float currentDepth = texelFetch(DepthSampler, pixelPosition, 0).r;
            if (currentDepth < closestDepth) {
                closestDepth = currentDepth;
                closestDepthPos = pixelPosition;
            }
        }
    }

    vec3 sourceSample = sourceSampleTotal / sourceSampleWeight;
    fragColor = encodeLogLuv(sourceSample);

    vec3 worldSpace = unprojectScreenSpace(invProjViewMat, texCoord, closestDepth);
    vec3 historyTexCoord = projectAndDivide(prevProjViewMat, worldSpace - viewOffset) * 0.5 + 0.5;

    if (clamp(historyTexCoord.xy, 1.5 / InSize, 1.0 - 1.0 / InSize) != historyTexCoord.xy) {
        return;
    }

    vec3 historySample = sampleTextureCatmullRom(HistorySampler, historyTexCoord.xy, InSize);
    historySample = clamp(historySample, nMin, nMax);

    float sourceWeight = 0.1;
    float historyWeight = 1.0 - sourceWeight;
    vec3 compressedSource = sourceSample / (max(max(sourceSample.r, sourceSample.g), sourceSample.b) + 1.0);
    vec3 compressedHistory = historySample / (max(max(historySample.r, historySample.g), historySample.b) + 1.0);
    float luminanceSource = luminance(compressedSource);
    float luminanceHistory = luminance(compressedHistory);

    sourceWeight *= 1.0 / (1.0 + luminanceSource);
    historyWeight *= 1.0 / (1.0 + luminanceHistory);

    vec3 result = (sourceSample * sourceWeight + historySample * historyWeight) / max(sourceWeight + historyWeight, 0.00001);

    fragColor = encodeLogLuv(result);
}