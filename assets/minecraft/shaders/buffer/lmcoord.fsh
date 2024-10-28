#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:encodings.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;

in vec2 texCoord;

out vec4 fragColor;

float maskAlpha(float alpha) {
    return float(int(alpha * 255.0) & 0xF0) / 255.0;
}

void main() {
    float depth = texture(DepthSampler, texCoord).r;
    vec4 color = texture(InSampler, texCoord);

    if (depth == 1.0) {
        fragColor = vec4(0.0);
        fragColor.a = 1.0;
        return;
    }

    ivec2 fragCoord = ivec2(gl_FragCoord.xy);
    ivec2 local = fragCoord % 2;
    if (local == ivec2(0, 0)) {
        fragColor = color;
        return;
    }

    fragCoord -= local;
    fragColor = texelFetch(InSampler, fragCoord, 0);

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
        if (candidateMatrix[i].a == color.a) {
            fragColor = candidateMatrix[i];
            break;
        } else if (fragColor.a == 1.0) {
            fragColor = candidateMatrix[i];
        }
    }
}