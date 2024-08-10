#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D FallbackSampler;

in vec2 texCoord;
flat in int shadowMapFrame;

out vec4 fragColor;

void main() {
    if (shadowMapFrame > 0) {
        fragColor = texture(FallbackSampler, texCoord);
    } else {
        fragColor = texture(DiffuseSampler, texCoord);
    }
}