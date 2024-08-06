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

// based on https://atyuwen.github.io/posts/normal-reconstruction/
vec3 getNormal(vec2 uv) {
    float depthCenter = unpackDepth(texture(DiffuseDepthSampler, uv));
    vec3 positionCenter = getPositionWorldSpace(uv, depthCenter);

    vec4 horizontal = vec4(
        unpackDepth(texture(DiffuseDepthSampler, uv + vec2(-1.0, 0.0) / InSize)),
        unpackDepth(texture(DiffuseDepthSampler, uv + vec2(+1.0, 0.0) / InSize)),
        unpackDepth(texture(DiffuseDepthSampler, uv + vec2(-2.0, 0.0) / InSize)),
        unpackDepth(texture(DiffuseDepthSampler, uv + vec2(+2.0, 0.0) / InSize))
    );

    vec4 vertical = vec4(
        unpackDepth(texture(DiffuseDepthSampler, uv + vec2(0.0, -1.0) / InSize)),
        unpackDepth(texture(DiffuseDepthSampler, uv + vec2(0.0, +1.0) / InSize)),
        unpackDepth(texture(DiffuseDepthSampler, uv + vec2(0.0, -2.0) / InSize)),
        unpackDepth(texture(DiffuseDepthSampler, uv + vec2(0.0, +2.0) / InSize))
    );

    vec3 positionLeft = getPositionWorldSpace(uv + vec2(-1.0, 0.0) / InSize, horizontal.x);
    vec3 positionRight = getPositionWorldSpace(uv + vec2(1.0, 0.0) / InSize, horizontal.y);
    vec3 positionDown = getPositionWorldSpace(uv + vec2(0.0, -1.0) / InSize, vertical.x);
    vec3 positionUp = getPositionWorldSpace(uv + vec2(0.0, 1.0) / InSize, vertical.y);

    vec3 left = positionCenter - positionLeft;
    vec3 right = positionRight - positionCenter;
    vec3 down = positionCenter - positionDown;
    vec3 up = positionUp - positionCenter;

    vec2 he = abs((2 * horizontal.xy - horizontal.zw) - depthCenter);
    vec2 ve = abs((2 * vertical.xy - vertical.zw) - depthCenter);

    vec3 horizontalDeriv = he.x < he.y ? left : right;
    vec3 verticalDeriv = ve.x < ve.y ? down : up;

    return normalize(cross(horizontalDeriv, verticalDeriv));
}

void main() {
    vec3 worldNormal = getNormal(texCoord);
    fragColor = vec4(worldNormal * 0.5 + 0.5, 1.0);
}