#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D ShadowSampler;

in vec2 texCoord;

out vec4 fragColor;

void main() {
    float shadow = texture(ShadowSampler, texCoord).r;
    fragColor = texture(DiffuseSampler, texCoord);
    fragColor.rgb *= 0.5 + 0.5 * (1.0 - shadow);
}