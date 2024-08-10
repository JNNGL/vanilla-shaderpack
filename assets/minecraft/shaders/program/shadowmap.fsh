#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D ShadowCacheSampler;

uniform vec2 InSize;

in vec2 texCoord;
flat in int shadowMapFrame;
flat in vec3 offset;
flat in vec3 blockOffset;
flat in mat4 lightProjMat;
flat in mat4 invLightProjMat;

out vec4 fragColor;

vec4 packDepth(float depth) {
    uint bits = floatBitsToUint(depth);
    return vec4(bits >> 24, (bits >> 16) & 0xFFu, (bits >> 8) & 0xFFu, bits & 0xFFu) / 255.0;
}

float unpackDepth(vec4 color) {
    uvec4 depthData = uvec4(color * 255.0);
    uint bits = (depthData.r << 24) | (depthData.g << 16) | (depthData.b << 8) | depthData.a;
    return uintBitsToFloat(bits);
}

void main() {
    if (int(gl_FragCoord.y) == 0) {
        fragColor = texture(DiffuseSampler, texCoord);
        return;
    }
    if (shadowMapFrame > 0) {
        float depth = texture(DiffuseDepthSampler, texCoord).r;
        vec3 worldSpace = (invLightProjMat * vec4(texCoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0)).xyz;
        vec3 newTexCoord = (lightProjMat * vec4(worldSpace - blockOffset, 1.0)).xyz * 0.5 + 0.5;
        vec3 currentTexCoord = vec3(texCoord, depth);
        vec3 projOffset = newTexCoord - currentTexCoord;
        vec2 projTexCoord = currentTexCoord.xy - projOffset.xy;
        if (clamp(projTexCoord, 0.0, 1.0) != projTexCoord) {
            fragColor = packDepth(1.0);
            return;
        }
        float projDepth = texture(DiffuseDepthSampler, projTexCoord).r * 2.0 - 1.0;
        fragColor = packDepth((projDepth + projOffset.z * 2.0) * 0.5 + 0.5);
    } else {
        float depth = unpackDepth(texture(ShadowCacheSampler, texCoord));
        vec3 worldSpace = (invLightProjMat * vec4(texCoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0)).xyz;
        vec3 newTexCoord = (lightProjMat * vec4(worldSpace + offset, 1.0)).xyz * 0.5 + 0.5;
        vec3 currentTexCoord = vec3(texCoord, depth);
        vec3 projOffset = newTexCoord - currentTexCoord;
        vec2 projTexCoord = currentTexCoord.xy - projOffset.xy;
        if (clamp(projTexCoord, 0.0, 1.0) != projTexCoord) {
            fragColor = packDepth(1.0);
            return;
        }
        float projDepth = unpackDepth(texture(ShadowCacheSampler, projTexCoord)) * 2.0 - 1.0;
        fragColor = packDepth((projDepth + projOffset.z * 2.0) * 0.5 + 0.5);
    }
}