#version 330

uniform sampler2D DepthSampler0;
uniform sampler2D DepthSampler1;
uniform sampler2D DepthSampler2;
uniform sampler2D DepthSampler3;
uniform sampler2D DepthSampler4;
uniform sampler2D DepthSampler5;

in vec2 texCoord;

out vec4 fragColor;

float unpackDepth(vec4 color) {
    uvec4 depthData = uvec4(color * 255.0);
    uint bits = (depthData.r << 24) | (depthData.g << 16) | (depthData.b << 8) | depthData.a;
    return uintBitsToFloat(bits);
}

void main() {
    float depth = 1.0;
    depth = min(depth, unpackDepth(texture(DepthSampler0, texCoord)));
    // depth = min(depth, texture(DepthSampler1, texCoord).r);
    // depth = min(depth, texture(DepthSampler2, texCoord).r);
    // depth = min(depth, texture(DepthSampler3, texCoord).r);
    // depth = min(depth, texture(DepthSampler4, texCoord).r);
    // depth = min(depth, texture(DepthSampler5, texCoord).r);

    uint bits = floatBitsToUint(depth);
    // fragColor = unpackUnorm4x8(bits);
    fragColor = vec4(bits >> 24, (bits >> 16) & 0xFFu, (bits >> 8) & 0xFFu, bits & 0xFFu) / 255.0;
    // fragColor = vec4(vec3(texture(DepthSampler3, texCoord).r), 1.0);
}
