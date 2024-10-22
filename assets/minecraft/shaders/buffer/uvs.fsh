#version 330

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;

in vec2 texCoord;

out vec4 fragColor;

void main() {
    float depth = texture(DepthSampler, texCoord).r;
    vec4 color = texture(InSampler, texCoord);

    if (depth == 1.0 || color.a == 1.0) {
        fragColor = vec4(0.0);
        fragColor.a = 1.0;
        return;
    }

    ivec2 fragCoord = ivec2(gl_FragCoord.xy);
    ivec2 local = fragCoord % 2;
    if (local.x != local.y) {
        fragColor = color;
        return;
    }

    mat4 candidateMatrix = mat4(
        textureOffset(InSampler, texCoord, ivec2(0, +1)),
        textureOffset(InSampler, texCoord, ivec2(0, -1)),
        textureOffset(InSampler, texCoord, ivec2(+1, 0)),
        textureOffset(InSampler, texCoord, ivec2(-1, 0))
    );

    int alpha = int(color.a * 255.0);
    int quadOnly = alpha >> 4;

    fragColor = candidateMatrix[2];
    for (int i = 0; i < 4; i++) {
        if (candidateMatrix[i].a == 1.0) continue;
        int candidateAlpha = int(candidateMatrix[i].a * 255.0);

        int mipLevel = candidateAlpha & 7;
        int powMip = int(round(pow(2.0, mipLevel)));
        int subX = (int(candidateMatrix[i].r * 255.0) / powMip) & 3;
        int subY = (int(candidateMatrix[i].g * 255.0) / powMip) & 3;
        int restoredAlpha = ((candidateAlpha >> 4) << 4) | (subX << 2) | subY;

        if (restoredAlpha == alpha) {
            fragColor = candidateMatrix[i];
            break;
        } else if ((candidateAlpha >> 4) == quadOnly) {
            fragColor = candidateMatrix[i];
        }
    }

    int fragAlpha = int(fragColor.a * 255.0);
    int mipLevel = fragAlpha & 7;
    if (mipLevel == 0) {
        ivec2 rg = ivec2(fragColor.rg * 255.0);
        rg = (rg & 252) | ivec2((alpha >> 2) & 3, alpha & 3);
        fragColor.rg = vec2(rg) / 255.0;
    }
}