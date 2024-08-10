#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D ShadowCacheSampler;

uniform vec2 InSize;

in vec2 texCoord;
flat in int shadowMapFrame;
flat in vec3 offset;
flat in mat4 lightProjMat;
flat in mat4 invLightProjMat;

out vec4 fragColor;

vec4 packFloat(float f) {
    uint bits = floatBitsToUint(f);
    return vec4(bits >> 24, (bits >> 16) & 0xFFu, (bits >> 8) & 0xFFu, bits & 0xFFu) / 255.0;
}

float unpackFloat(vec4 color) {
    uvec4 data = uvec4(color * 255.0);
    uint bits = (data.r << 24) | (data.g << 16) | (data.b << 8) | data.a;
    return uintBitsToFloat(bits);
}

void main() {
    if (shadowMapFrame > 0) {
        if (int(gl_FragCoord.y) == 0) {
            int index = int(gl_FragCoord.x) - 64;
            if (index >= 0 && index < 3) {
                fragColor = packFloat(0.0);
                return;
            }
        }
        float depth = texture(DiffuseDepthSampler, texCoord).r;
        fragColor = packFloat(depth);
    } else {
        if (int(gl_FragCoord.y) == 0) {
            int index = int(gl_FragCoord.x) - 64;
            if (index >= 0 && index < 3) {
                fragColor = packFloat(offset[index]);
                return;
            }
        }
        fragColor = texture(ShadowCacheSampler, texCoord);
    }
    if (int(gl_FragCoord.y) == 0) {
        fragColor = texture(DiffuseSampler, texCoord);
        return;
    }
}