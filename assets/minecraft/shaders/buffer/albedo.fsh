#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:atlas.glsl>
#moj_import <minecraft:encodings.glsl>
#moj_import <settings:settings.glsl>

uniform sampler2D InSampler;
uniform sampler2D UvSampler;
uniform sampler2D AtlasSampler;
uniform sampler2D DepthSampler;

in vec2 texCoord;

out vec4 fragColor;

float maskAlpha(float alpha) {
    return float(int(alpha * 255.0) & 0xF0) / 255.0;
}

void main() {
    vec4 uv = texture(UvSampler, texCoord);
    if (uv.a == 1.0) {
        fragColor = texture(InSampler, texCoord);
        fragColor.a = 1.0;
        return;
    }

    if ((int(uv.a * 255.0) >> 4) == 15) {
        mat4 candidateMatrix = mat4(
            textureOffset(InSampler, texCoord, ivec2(+1, 0)),
            textureOffset(InSampler, texCoord, ivec2(-1, 0)),
            textureOffset(InSampler, texCoord, ivec2(0, +1)),
            textureOffset(InSampler, texCoord, ivec2(0, -1))
        );
        fragColor = vec4(0.0);
        for (int i = 0; i < 4; i++) {
            if ((int(candidateMatrix[i].a * 255.0) >> 4) == 15) {
                fragColor = candidateMatrix[i];
                break;
            }
        }
        fragColor.a = 1.0;
        return;
    }

    fragColor = sampleCombinedAtlas(AtlasSampler, uv, ATLAS_ALBEDO);
    fragColor.a = 1.0;

    vec4 color = texture(InSampler, texCoord);
    ivec2 fragCoord = ivec2(gl_FragCoord.xy);
    ivec2 local = fragCoord % 2;
    if (local == ivec2(1, 1)) {
#if (ENABLE_DIRECTIONAL_LIGHTMAP == yes)
        uint lowerBits;
        fragColor.rgb *= decodeYCoCg776(color.rgb, lowerBits);
        fragColor.a = float(lowerBits) / 255.0;
#else
        fragColor.rgb *= color.rgb;
#endif // ENABLE_DIRECTIONAL_LIGHTMAP
        return;
    }

    fragCoord += 1 - local;

    mat4 candidateMatrix = mat4(
        texelFetch(InSampler, fragCoord + ivec2(0, +2), 0),
        texelFetch(InSampler, fragCoord + ivec2(0, -2), 0),
        texelFetch(InSampler, fragCoord + ivec2(+2, 0), 0),
        texelFetch(InSampler, fragCoord + ivec2(-2, 0), 0)
    );

    vec4 vertexColor = candidateMatrix[2];

    color.a = maskAlpha(color.a);
    for (int i = 0; i < 4; i++) {
        if (candidateMatrix[i].a == 1.0) continue;
        candidateMatrix[i].a = maskAlpha(candidateMatrix[i].a);
        if (candidateMatrix[i].a == color.a || vertexColor.a == 1.0) {
            vertexColor = candidateMatrix[i];
        }
    }

    if (vertexColor.a != 1.0) {
#if (ENABLE_DIRECTIONAL_LIGHTMAP == yes)
        uint lowerBits;
        fragColor.rgb *= decodeYCoCg776(vertexColor.rgb, lowerBits);
        fragColor.a = float(lowerBits) / 255.0;
#else
        fragColor.rgb *= vertexColor.rgb;
#endif // ENABLE_DIRECTIONAL_LIGHTMAP
    }
}