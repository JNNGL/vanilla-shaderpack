#version 330

#extension GL_MC_moj_import : enable
#moj_import <normals.glsl>

uniform sampler2D DepthSampler;

uniform vec2 OutSize;

in vec2 texCoord;
flat in mat4 invProjViewMat;

out vec4 fragColor;

void main() {
    vec3 normal = reconstructNormal(DepthSampler, invProjViewMat, texCoord, OutSize);
    fragColor = vec4(normal * 0.5 + 0.5, 1.0);
}