#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D ShadowCacheSampler;

uniform vec2 InSize;

in vec2 texCoord;
flat in int part;
flat in vec3 offset;
flat in mat4 lightProjMat;
flat in mat4 invLightProjMat;

out vec4 fragColor;

const vec2 shadowMapOffsets[] = vec2[](
    vec2(-1.0, -1.0),
    vec2(+1.0, -1.0),
    vec2(-1.0, +1.0),
    vec2(+1.0, +1.0)
);

uint packDepthClipSpace(float depth) {
    uint value = depth < 0.0 ? (1u << 23u) : 0u;
    float depth12 = abs(depth) + 1.0;
    uint bits = floatBitsToUint(depth12);
    value |= (bits & 0x7FFFFFu);
    return value;
}

vec3 packDepthClipSpaceRGB8(float depth) {
    uint bits = packDepthClipSpace(depth);
    return vec3(bits >> 16, (bits >> 8) & 0xFFu, bits & 0xFFu) / 255.0;
}

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

#define FAR 0.9999999 // TODO: rewrite depth packing to work with [0, 1] range

const ivec2 shadowOffsets[] = ivec2[](ivec2(0, 0), ivec2(1, 0), ivec2(1, 1), ivec2(1, 0));

void main() {
    vec2 partTexCoord = ((texCoord * 2.0 - 1.0) * 2.0 + shadowMapOffsets[part]) * 0.5 + 0.5;
    if (clamp(partTexCoord, 0.0, 1.0) != partTexCoord) {
        // TODO: compute the offset in vertex shader
        float depthClip = unpackDepthClipSpaceRGB8(texture(ShadowCacheSampler, texCoord).rgb);
        vec3 worldSpace = (invLightProjMat * vec4(texCoord * 2.0 - 1.0, depthClip, 1.0)).xyz;
        vec3 newTexCoord = (lightProjMat * vec4(worldSpace + offset, 1.0)).xyz * 0.5 + 0.5;
        vec3 currentTexCoord = vec3(texCoord, depthClip * 0.5 + 0.5);
        vec3 projOffset = newTexCoord - currentTexCoord;
        vec2 projTexCoord = currentTexCoord.xy - projOffset.xy;
        if (clamp(projTexCoord, 0.0, 1.0) != projTexCoord) {
            fragColor = vec4(packDepthClipSpaceRGB8(FAR), 1.0);
            return;
        }
        float projDepth = unpackDepthClipSpaceRGB8(texture(ShadowCacheSampler, projTexCoord).rgb);
        fragColor = vec4(packDepthClipSpaceRGB8(projDepth + projOffset.z * 2.0), 1.0);
        return;
    }
    ivec2 coord = (ivec2(partTexCoord * (InSize.xy - 1)) >> 1) * 2 + 1 - shadowOffsets[part];
    fragColor = texelFetch(DiffuseSampler, coord, 0);
    float depth = texelFetch(DiffuseDepthSampler, coord, 0).r;
    if (depth >= 0.5) {
        fragColor = vec4(packDepthClipSpaceRGB8(FAR), 1.0);
    }
}