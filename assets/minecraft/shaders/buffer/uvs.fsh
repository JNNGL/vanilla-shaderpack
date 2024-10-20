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

    fragColor = candidateMatrix[0];
    for (int i = 1; i < 4; i++) {
        if (candidateMatrix[i].a == color.a || (fragColor.a == 1.0 && candidateMatrix[i].a < 1.0)) {
            fragColor = candidateMatrix[i];
        }
    }
}