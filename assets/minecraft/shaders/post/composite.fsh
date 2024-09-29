#version 330

uniform sampler2D InSampler;
uniform sampler2D FallbackSampler;

flat in int isShadowMap;

out vec4 fragColor;

void main() {
    if (isShadowMap > 0) {
        fragColor = texelFetch(FallbackSampler, ivec2(gl_FragCoord.xy), 0);
    } else {
        fragColor = texelFetch(InSampler, ivec2(gl_FragCoord.xy), 0);
    }
}