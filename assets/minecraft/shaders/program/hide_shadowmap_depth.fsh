#version 330

uniform sampler2D DiffuseDepthSampler;
uniform sampler2D PreviousDepthSampler;

uniform vec2 InSize;

flat in int part;

out vec4 fragColor;

const ivec2 shadowOffsets[] = ivec2[](ivec2(0, 0), ivec2(1, 1), ivec2(1, 0), ivec2(0, 1));

float unpackDepth(vec4 color) {
    uvec4 depthData = uvec4(color * 255.0);
    uint bits = (depthData.r << 24) | (depthData.g << 16) | (depthData.b << 8) | depthData.a;
    return uintBitsToFloat(bits);
}

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    float depth = texelFetch(DiffuseDepthSampler, coord, 0).r;
    if (coord.x <= InSize.x && coord.y <= InSize.y) {
        if (((coord + shadowOffsets[part]) % 2) == ivec2(0, 0)) {
            bool canReuse = true;
            float depthLeft = texelFetch(DiffuseDepthSampler, coord - ivec2(1, 0), 0).r;
            float depthDown = texelFetch(DiffuseDepthSampler, coord - ivec2(0, 1), 0).r;
            float depthRight = texelFetch(DiffuseDepthSampler, coord + ivec2(1, 0), 0).r;
            float depthUp = texelFetch(DiffuseDepthSampler, coord + ivec2(0, 1), 0).r;
            if (abs(unpackDepth(texelFetch(PreviousDepthSampler, coord - ivec2(1, 0), 0)) - depthLeft) > 0.0) canReuse = false;
            if (abs(unpackDepth(texelFetch(PreviousDepthSampler, coord - ivec2(0, 1), 0)) - depthDown) > 0.0) canReuse = false;
            if (abs(unpackDepth(texelFetch(PreviousDepthSampler, coord + ivec2(1, 0), 0)) - depthRight) > 0.0) canReuse = false;
            if (abs(unpackDepth(texelFetch(PreviousDepthSampler, coord + ivec2(0, 1), 0)) - depthUp) > 0.0) canReuse = false;
            if (canReuse) {
                fragColor = texelFetch(PreviousDepthSampler, coord, 0);
                return;
            } else {
                depth = texelFetch(DiffuseDepthSampler, coord + ivec2(0, 1), 0).r;
                depth += texelFetch(DiffuseDepthSampler, coord - ivec2(0, 1), 0).r;
                depth *= 0.5;
            }
        }
    }
    uint bits = floatBitsToUint(depth);
    fragColor = vec4(bits >> 24, (bits >> 16) & 0xFFu, (bits >> 8) & 0xFFu, bits & 0xFFu) / 255.0;
}