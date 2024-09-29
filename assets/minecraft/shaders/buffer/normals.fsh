#version 330

#extension GL_MC_moj_import : enable
#moj_import <projections.glsl>

uniform sampler2D DepthSampler;

uniform vec2 OutSize;

in vec2 texCoord;
flat in mat4 invProjViewMat;

out vec4 fragColor;

// based on https://atyuwen.github.io/posts/normal-reconstruction/
vec3 getNormal(vec2 uv) {
    float depthCenter = texture(DepthSampler, uv).r;
    if (depthCenter == 1.0) {
        return vec3(0.0);
    }

    vec3 positionCenter = unprojectScreenSpace(invProjViewMat, uv, depthCenter);

    vec4 horizontal = vec4(
        texture(DepthSampler, uv + vec2(-1.0, 0.0) / OutSize).r,
        texture(DepthSampler, uv + vec2(+1.0, 0.0) / OutSize).r,
        texture(DepthSampler, uv + vec2(-2.0, 0.0) / OutSize).r,
        texture(DepthSampler, uv + vec2(+2.0, 0.0) / OutSize).r
    );

    vec4 vertical = vec4(
        texture(DepthSampler, uv + vec2(0.0, -1.0) / OutSize).r,
        texture(DepthSampler, uv + vec2(0.0, +1.0) / OutSize).r,
        texture(DepthSampler, uv + vec2(0.0, -2.0) / OutSize).r,
        texture(DepthSampler, uv + vec2(0.0, +2.0) / OutSize).r
    );

    vec3 positionLeft  = unprojectScreenSpace(invProjViewMat, uv + vec2(-1.0, 0.0) / OutSize, horizontal.x);
    vec3 positionRight = unprojectScreenSpace(invProjViewMat, uv + vec2(+1.0, 0.0) / OutSize, horizontal.y);
    vec3 positionDown  = unprojectScreenSpace(invProjViewMat, uv + vec2(0.0, -1.0) / OutSize, vertical.x);
    vec3 positionUp    = unprojectScreenSpace(invProjViewMat, uv + vec2(0.0, +1.0) / OutSize, vertical.y);

    vec3 left  = positionCenter - positionLeft;
    vec3 right = positionRight  - positionCenter;
    vec3 down  = positionCenter - positionDown;
    vec3 up    = positionUp     - positionCenter;

    vec2 he = abs((2.0 * horizontal.xy - horizontal.zw) - depthCenter);
    vec2 ve = abs((2.0 * vertical.xy - vertical.zw) - depthCenter);

    vec3 horizontalDeriv = he.x < he.y ? left : right;
    vec3 verticalDeriv = ve.x < ve.y ? down : up;

    return normalize(cross(horizontalDeriv, verticalDeriv));
}

void main() {
    vec3 normal = getNormal(texCoord);
    fragColor = vec4(normal * 0.5 + 0.5, 1.0);
}