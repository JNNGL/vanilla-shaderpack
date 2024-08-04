#version 330

uniform sampler2D DiffuseSampler;

in vec2 texCoord;

out vec4 fragColor;

float unpackDepthClipSpace(uint bits) {
    float sgn = (bits & (1u << 23u)) > 0u ? -1.0 : 1.0;
    bits = (bits & 0x007FFFFFu) | 0x3F800000u;
    float depth12 = uintBitsToFloat(bits);
    return (depth12 - 1.0) * sgn;
}

float unpackDepthClipSpaceRGB8(vec3 rgb) {
    uvec3 data = uvec3(round(rgb * 255.0));
    uint bits = (data.r << 16) | (data.g << 8) | data.b;
    return unpackDepthClipSpace(bits);
}

void main() {
    vec4 color = texture(DiffuseSampler, texCoord);
    float depth = unpackDepthClipSpaceRGB8(color.rgb) * 0.5 + 0.5;
    fragColor = vec4(depth, depth, depth, 1.0);
}