#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;

uniform vec2 InSize;

in vec2 texCoord;
flat in mat4 invViewProj;

out vec4 fragColor;

vec3 getPositionWorldSpace(in vec2 uv, in float z) {
    vec4 positionClip = vec4(uv, z, 1.0) * 2.0 - 1.0;
    vec4 positionWorld = invViewProj * positionClip;
    return positionWorld.xyz / positionWorld.w;
}

float unpackDepth(vec4 color) {
    uvec4 depthData = uvec4(color * 255.0);
    uint bits = (depthData.r << 24) | (depthData.g << 16) | (depthData.b << 8) | depthData.a;
    return uintBitsToFloat(bits);
}

vec3 getNormal(sampler2D s, vec2 uv) {
    vec2 uv0 = uv;
    float depth0 = unpackDepth(texture(s, uv0, 0));
    if (depth0 == 1.0) {
        return vec3(0.0);
    }

    vec2 uv1 = uv + vec2(1, 0) / InSize;
    vec2 uv2 = uv + vec2(0, 1) / InSize;
    vec2 uv3 = uv + vec2(-1, 0) / InSize;
    vec2 uv4 = uv + vec2(0, -1) / InSize;

    float depth1 = unpackDepth(texture(s, uv1, 0));
    float depth2 = unpackDepth(texture(s, uv2, 0));
    float depth3 = unpackDepth(texture(s, uv3, 0));
    float depth4 = unpackDepth(texture(s, uv4, 0));

    float sgn = 1.0;
    vec3 p0 = getPositionWorldSpace(uv0, depth0);
    vec3 p1, p2;
    if (abs(depth1 - depth0) < abs(depth3 - depth0)) {
        p1 = getPositionWorldSpace(uv1, depth1);
    } else {
        p1 = getPositionWorldSpace(uv3, depth3);
        sgn = -1.0;
    }
    if (abs(depth2 - depth0) < abs(depth4 - depth0)) {
        p2 = getPositionWorldSpace(uv2, depth2);
        sgn *= -1.0;
    } else {
        p2 = getPositionWorldSpace(uv4, depth4);
    }

    return sgn * normalize(cross(p2 - p0, p1 - p0));
}

void main() {
    vec3 worldNormal = getNormal(DiffuseDepthSampler, texCoord);
    fragColor = vec4(worldNormal * 0.5 + 0.5, 1.0);
}