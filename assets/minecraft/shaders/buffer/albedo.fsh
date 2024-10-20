#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:atlas.glsl>

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
        return;
    }

    fragColor = sampleCombinedAtlas(AtlasSampler, uv.xyz, ATLAS_ALBEDO);

    vec4 color = texture(InSampler, texCoord);
    ivec2 fragCoord = ivec2(gl_FragCoord.xy);
    ivec2 local = fragCoord % 2;
    if (local == ivec2(1, 1)) {
        fragColor *= color;
        return;
    }

    fragCoord += 1 - local;
    vec4 vertexColor = texelFetch(InSampler, fragCoord, 0);

    float depth = texture(DepthSampler, texCoord).r;

    mat4 candidateMatrix = mat4(
        texelFetch(InSampler, fragCoord + ivec2(0, +2), 0),
        texelFetch(InSampler, fragCoord + ivec2(0, -2), 0),
        texelFetch(InSampler, fragCoord + ivec2(+2, 0), 0),
        texelFetch(InSampler, fragCoord + ivec2(-2, 0), 0)
    );

    color.a = maskAlpha(color.a);
    for (int i = 0; i < 4; i++) {
        if (candidateMatrix[i].a == 1.0) continue;
        candidateMatrix[i].a = maskAlpha(candidateMatrix[i].a);
        if (candidateMatrix[i].a == color.a || vertexColor.a == 1.0) {
            vertexColor = candidateMatrix[i];
        }
    }

    fragColor *= vertexColor;
}